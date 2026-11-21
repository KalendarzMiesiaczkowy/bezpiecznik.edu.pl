# /// script
# requires-python = ">=3.11"
# dependencies = ["osmium"]
# ///
"""Build ``points.sqlite`` (shelter points DB) from an OpenStreetMap PBF extract.

Contract: bezpiecznik/04-dane/kontrakty-tresci.md, section "Baza punktow".
The ``points`` / ``points_rtree`` DDL below is copied verbatim from the contract.

Usage::

    uv run --script tools/build_points.py \
        [--pbf ~/development/data/zachodniopomorskie-latest.osm.pbf] \
        [--out app/assets/generated/points.sqlite] \
        [--manual tools/data/points_manual.csv] \
        [--include-post-mvp] [--check]

``--check`` only runs the self-check on an existing database (no build).

OSM tag -> ``kind`` mapping (MVP kinds only by default)
-------------------------------------------------------
``shelter``
  * ``building=bunker`` (contract: always kind shelter, confirmed=0), EXCEPT:
      - historic / ruined / disused / abandoned objects (``historic=*``,
        ``ruins=yes``, ``disused=yes``, ``abandoned=yes``, ``disused:*``,
        ``abandoned:*``, ``ruins:*`` prefixes);
      - objects whose ``bunker_type`` is a purely military type (pillbox,
        munitions, gun_emplacement, ...). Only bunker_type in CIVIL_BUNKER_TYPES
        (bomb_shelter, air_raid_shelter, civil_shelter, shelter, ...) or an
        absent bunker_type is accepted.
  * ``military=bunker`` ONLY when ``bunker_type`` is in CIVIL_BUNKER_TYPES
    (military bunkers are not civil-protection shelters).
  * ``amenity=shelter`` ONLY when ``shelter_type`` in {bomb_shelter, bomb,
    nuclear}. Every other ``amenity=shelter`` (bus stops = public_transport,
    picnic_shelter, weather_shelter, lean_to, gazebo, basic_hut, ...) is a
    weather shelter, NOT a civil-protection shelter, and is excluded.
  * ``amenity=shelter`` without ``shelter_type`` is excluded (unknown).
  * Objects with ``access=private`` or ``access=no`` are excluded (a person
    in need cannot use them).

``hiding_place`` and ``emergency_shelter``
  No OSM tag maps to them without inventing semantics (KG PSP "ukrycie" /
  "miejsce doraznego schronienia" are institutional categories).
  ``emergency=assembly_point`` is an evacuation assembly point, not a shelter,
  so it is NOT mapped. These kinds can only arrive via the manual CSV.

Post-MVP kinds (only with ``--include-post-mvp``; the MVP spec says the DB
holds shelters only, so they are off by default): ``amenity=hospital`` /
``healthcare=hospital`` -> hospital, ``amenity=fire_station`` -> fire_station,
``amenity=pharmacy`` -> pharmacy, ``emergency=defibrillator`` -> aed.
``water`` has no clean OSM tag and is not mapped.

Fields: every OSM point has ``confirmed = 0``, ``source = 'OpenStreetMap'``,
``verified_at`` = extract date (PBF header replication timestamp, fallback:
file mtime). Ways -> centroid (mean of node coordinates; relations/multi
polygons are skipped). The OSM object id is kept in the auxiliary table
``points_osm`` (the contract table has no column for it). ``open_24h = 1``
when ``opening_hours`` is ``24/7``, else NULL; ``availability`` holds the raw
``opening_hours`` text or NULL.

Manual (institution) points: ``tools/data/points_manual.csv`` (header only by
default). Rows must carry ``source`` and ``verified_at``; ``confirmed=1`` is
only for data of public institutions.
"""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import math
import sqlite3
import sys
from pathlib import Path
from typing import Iterable, Iterator

KINDS = (
    "shelter", "hiding_place", "emergency_shelter", "hospital",
    "fire_station", "water", "pharmacy", "aed",
)
MVP_KINDS = ("shelter", "hiding_place", "emergency_shelter")

SCHEMA = """
CREATE TABLE points (
  id           INTEGER PRIMARY KEY,
  kind         TEXT NOT NULL CHECK (kind IN (
                 'shelter', 'hiding_place', 'emergency_shelter', 'hospital',
                 'fire_station', 'water', 'pharmacy', 'aed')),
  name         TEXT,
  address      TEXT,
  lat          REAL NOT NULL,
  lon          REAL NOT NULL,
  availability TEXT,                 -- tekst ze zrodla; NULL = "Dostepnosc: brak danych"
  open_24h     INTEGER CHECK (open_24h IN (0, 1)),   -- NULL = brak danych
  source       TEXT NOT NULL,        -- np. 'KG PSP', 'OpenStreetMap'
  verified_at  TEXT NOT NULL,        -- data ISO 8601; dla OSM data wyciagu
  confirmed    INTEGER NOT NULL CHECK (confirmed IN (0, 1))  -- 1 tylko dane instytucji publicznych
);

CREATE VIRTUAL TABLE points_rtree USING rtree(id, min_lat, max_lat, min_lon, max_lon);

-- Auxiliary (not part of the contract): OSM provenance of a point.
CREATE TABLE points_osm (
  point_id INTEGER PRIMARY KEY REFERENCES points(id),
  osm_type TEXT NOT NULL CHECK (osm_type IN ('node', 'way')),
  osm_id   INTEGER NOT NULL
);
"""

CIVIL_BUNKER_TYPES = frozenset({
    "bomb_shelter", "air_raid_shelter", "civil_shelter", "shelter", "nuclear",
})
SHELTER_TYPES_CIVIL = frozenset({"bomb_shelter", "bomb", "nuclear"})
EXCLUDED_ACCESS = frozenset({"private", "no"})
LIFECYCLE_PREFIXES = ("disused:", "abandoned:", "ruins:", "was:")

MANUAL_COLUMNS = (
    "kind", "name", "address", "lat", "lon", "availability", "open_24h",
    "source", "verified_at", "confirmed",
)

# Szczecin centre, used by the self-check.
SZCZECIN = (53.4285, 14.5528)


def _is_lifecycle_dead(tags: dict[str, str]) -> bool:
    if tags.get("historic") not in (None, "", "no"):
        return True
    for key in ("ruins", "disused", "abandoned"):
        if tags.get(key) == "yes":
            return True
    return any(k.startswith(LIFECYCLE_PREFIXES) for k in tags)


def classify(tags: dict[str, str], include_post_mvp: bool = False) -> str | None:
    """Map OSM tags to a ``kind`` from the contract enum, or None to skip."""
    if tags.get("access") in EXCLUDED_ACCESS:
        return None
    bunker_type = tags.get("bunker_type")

    if tags.get("building") == "bunker" or tags.get("military") == "bunker":
        if _is_lifecycle_dead(tags):
            return None
        if tags.get("building") == "bunker":
            if bunker_type is None or bunker_type in CIVIL_BUNKER_TYPES:
                return "shelter"
            return None
        if bunker_type in CIVIL_BUNKER_TYPES:  # military=bunker only
            return "shelter"
        return None

    if tags.get("amenity") == "shelter":
        if tags.get("shelter_type") in SHELTER_TYPES_CIVIL and not _is_lifecycle_dead(tags):
            return "shelter"
        return None

    if include_post_mvp:
        if tags.get("amenity") == "hospital" or tags.get("healthcare") == "hospital":
            return "hospital"
        if tags.get("amenity") == "fire_station":
            return "fire_station"
        if tags.get("amenity") == "pharmacy":
            return "pharmacy"
        if tags.get("emergency") == "defibrillator":
            return "aed"
    return None


def centroid(coords: Iterable[tuple[float, float]]) -> tuple[float, float]:
    """Mean (lat, lon) of coordinates. A closed way's repeated first node is dropped."""
    pts = list(coords)
    if not pts:
        raise ValueError("no coordinates")
    if len(pts) > 1 and pts[0] == pts[-1]:
        pts = pts[:-1]
    return (
        sum(p[0] for p in pts) / len(pts),
        sum(p[1] for p in pts) / len(pts),
    )


def build_address(tags: dict[str, str]) -> str | None:
    street = tags.get("addr:street") or tags.get("addr:place")
    number = tags.get("addr:housenumber")
    city = tags.get("addr:city")
    first = " ".join(p for p in (street, number) if p)
    parts = [p for p in (first, city) if p]
    return ", ".join(parts) if parts else None


def build_row(tags: dict[str, str], kind: str, lat: float, lon: float,
              verified_at: str, osm_type: str, osm_id: int) -> dict:
    hours = tags.get("opening_hours")
    return {
        "kind": kind,
        "name": tags.get("name") or tags.get("name:pl") or None,
        "address": build_address(tags),
        "lat": lat,
        "lon": lon,
        "availability": hours or None,
        "open_24h": 1 if hours and hours.strip() == "24/7" else None,
        "source": "OpenStreetMap",
        "verified_at": verified_at,
        "confirmed": 0,
        "osm_type": osm_type,
        "osm_id": osm_id,
    }


# --- OSM extraction -------------------------------------------------------

def check_pbf(path: Path) -> None:
    if not path.is_file():
        raise SystemExit(f"PBF not found: {path}")
    with path.open("rb") as f:
        head = f.read(16)
    if head.startswith(b"<") or len(head) < 8:
        raise SystemExit(f"{path} is not a PBF file (looks like an HTML error page); re-download it")


def extract_date(path: Path) -> str:
    """Extract date: PBF header replication timestamp, else file mtime (UTC)."""
    import osmium
    try:
        ts = osmium.io.Reader(str(path)).header().get("osmosis_replication_timestamp")
    except RuntimeError:
        ts = None
    if ts:
        return ts[:10]
    return dt.datetime.fromtimestamp(path.stat().st_mtime, dt.timezone.utc).date().isoformat()


def iter_osm_rows(path: Path, verified_at: str, include_post_mvp: bool) -> Iterator[dict]:
    import osmium
    fp = osmium.FileProcessor(path).with_locations()
    for obj in fp:
        if obj.is_node():
            kind_tags = {t.k: t.v for t in obj.tags}
            kind = classify(kind_tags, include_post_mvp)
            if kind and obj.location.valid():
                yield build_row(kind_tags, kind, obj.location.lat, obj.location.lon,
                                verified_at, "node", obj.id)
        elif obj.is_way():
            tags = {t.k: t.v for t in obj.tags}
            kind = classify(tags, include_post_mvp)
            if not kind:
                continue
            coords = [(n.lat, n.lon) for n in obj.nodes if n.location.valid()]
            if not coords:
                continue
            lat, lon = centroid(coords)
            yield build_row(tags, kind, lat, lon, verified_at, "way", obj.id)


# --- manual CSV -----------------------------------------------------------

def load_manual_csv(path: Path) -> list[dict]:
    """Read human-entered points. Missing file or header-only file -> []."""
    if not path.is_file():
        return []
    rows: list[dict] = []
    with path.open(newline="", encoding="utf-8") as f:
        reader = csv.DictReader(f)
        if reader.fieldnames is None:
            return []
        missing = set(MANUAL_COLUMNS) - set(reader.fieldnames)
        if missing:
            raise ValueError(f"{path}: missing columns {sorted(missing)}")
        for n, r in enumerate(reader, start=2):
            where = f"{path}:{n}"
            kind = (r["kind"] or "").strip()
            if kind not in KINDS:
                raise ValueError(f"{where}: invalid kind {kind!r}")
            source = (r["source"] or "").strip()
            verified_at = (r["verified_at"] or "").strip()
            if not source or not verified_at:
                raise ValueError(f"{where}: source and verified_at are required")
            try:
                dt.date.fromisoformat(verified_at)
            except ValueError:
                raise ValueError(f"{where}: verified_at must be ISO date") from None
            try:
                lat, lon = float(r["lat"]), float(r["lon"])
            except ValueError:
                raise ValueError(f"{where}: lat/lon must be numbers") from None
            if not (-90 <= lat <= 90 and -180 <= lon <= 180):
                raise ValueError(f"{where}: lat/lon out of range")
            confirmed = (r["confirmed"] or "").strip()
            if confirmed not in ("0", "1"):
                raise ValueError(f"{where}: confirmed must be 0 or 1")
            o24 = (r["open_24h"] or "").strip()
            if o24 not in ("", "0", "1"):
                raise ValueError(f"{where}: open_24h must be empty, 0 or 1")
            rows.append({
                "kind": kind,
                "name": (r["name"] or "").strip() or None,
                "address": (r["address"] or "").strip() or None,
                "lat": lat, "lon": lon,
                "availability": (r["availability"] or "").strip() or None,
                "open_24h": int(o24) if o24 else None,
                "source": source,
                "verified_at": verified_at,
                "confirmed": int(confirmed),
                "osm_type": None, "osm_id": None,
            })
    return rows


# --- database -------------------------------------------------------------

def build_db(rows: Iterable[dict], out: Path) -> int:
    """Create a fresh database at ``out``; returns number of points written."""
    out.parent.mkdir(parents=True, exist_ok=True)
    if out.exists():
        out.unlink()
    con = sqlite3.connect(out)
    try:
        con.executescript(SCHEMA)
        n = 0
        for r in rows:
            cur = con.execute(
                "INSERT INTO points (kind, name, address, lat, lon, availability,"
                " open_24h, source, verified_at, confirmed)"
                " VALUES (?,?,?,?,?,?,?,?,?,?)",
                (r["kind"], r["name"], r["address"], r["lat"], r["lon"],
                 r["availability"], r["open_24h"], r["source"], r["verified_at"],
                 r["confirmed"]),
            )
            pid = cur.lastrowid
            con.execute(
                "INSERT INTO points_rtree (id, min_lat, max_lat, min_lon, max_lon)"
                " VALUES (?,?,?,?,?)",
                (pid, r["lat"], r["lat"], r["lon"], r["lon"]),
            )
            if r.get("osm_type"):
                con.execute("INSERT INTO points_osm VALUES (?,?,?)",
                            (pid, r["osm_type"], r["osm_id"]))
            n += 1
        con.commit()
        con.execute("VACUUM")
    finally:
        con.close()
    return n


def counts_per_kind(con: sqlite3.Connection) -> dict[str, int]:
    return dict(con.execute("SELECT kind, COUNT(*) FROM points GROUP BY kind ORDER BY kind"))


def nearest(con: sqlite3.Connection, lat: float, lon: float, limit: int = 5,
            start_box_deg: float = 0.05, max_box_deg: float = 5.0) -> list[tuple]:
    """Nearest points via R*Tree box, expanded until enough hits; great-circle sorted."""
    box = start_box_deg
    rows: list[tuple] = []
    while box <= max_box_deg:
        rows = con.execute(
            "SELECT p.id, p.kind, p.name, p.lat, p.lon FROM points_rtree r"
            " JOIN points p ON p.id = r.id"
            " WHERE r.min_lat >= ? AND r.max_lat <= ? AND r.min_lon >= ? AND r.max_lon <= ?",
            (lat - box, lat + box, lon - box, lon + box),
        ).fetchall()
        if len(rows) >= limit:
            break
        box *= 2
    rows.sort(key=lambda r: haversine_m(lat, lon, r[3], r[4]))
    return [(*r, haversine_m(lat, lon, r[3], r[4])) for r in rows[:limit]]


def haversine_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    p1, p2 = math.radians(lat1), math.radians(lat2)
    a = (math.sin((p2 - p1) / 2) ** 2
         + math.cos(p1) * math.cos(p2) * math.sin(math.radians(lon2 - lon1) / 2) ** 2)
    return 2 * 6371000.0 * math.asin(math.sqrt(a))


def self_check(db: Path, center: tuple[float, float] = SZCZECIN,
               require_near: bool = True) -> list[str]:
    """Return a list of problems (empty = OK). Prints counts and nearest hit."""
    problems: list[str] = []
    con = sqlite3.connect(db)
    try:
        counts = counts_per_kind(con)
        print("Counts per kind:")
        for k in KINDS:
            print(f"  {k:<18}{counts.get(k, 0)}")
        total = sum(counts.values())
        print(f"  {'TOTAL':<18}{total}")
        rt = con.execute("SELECT COUNT(*) FROM points_rtree").fetchone()[0]
        if rt != total:
            problems.append(f"rtree count {rt} != points count {total}")
        orphans = con.execute(
            "SELECT COUNT(*) FROM points p LEFT JOIN points_rtree r ON r.id = p.id"
            " WHERE r.id IS NULL").fetchone()[0]
        if orphans:
            problems.append(f"{orphans} points missing from rtree")
        bad = con.execute(
            "SELECT COUNT(*) FROM points WHERE verified_at IS NULL OR source IS NULL"
            " OR confirmed NOT IN (0,1)").fetchone()[0]
        if bad:
            problems.append(f"{bad} points with invalid source/verified_at/confirmed")
        wrongly = con.execute(
            "SELECT COUNT(*) FROM points WHERE source = 'OpenStreetMap' AND confirmed = 1"
        ).fetchone()[0]
        if wrongly:
            problems.append(f"{wrongly} OSM points marked confirmed")
        near = nearest(con, *center)
        print(f"Nearest to {center}:")
        for pid, kind, name, lat, lon, d in near:
            print(f"  id={pid} {kind} {name!r} ({lat:.5f}, {lon:.5f}) {d / 1000:.2f} km")
        if require_near and not near:
            problems.append("nearest query around Szczecin returned no rows")
    finally:
        con.close()
    for p in problems:
        print(f"SELF-CHECK FAIL: {p}", file=sys.stderr)
    print("Self-check:", "FAILED" if problems else "OK")
    return problems


def main(argv: list[str] | None = None) -> int:
    repo = Path(__file__).resolve().parent.parent
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--pbf", type=Path,
                    default=Path.home() / "development/data/zachodniopomorskie-latest.osm.pbf")
    ap.add_argument("--out", type=Path, default=repo / "app/assets/generated/points.sqlite")
    ap.add_argument("--manual", type=Path, default=repo / "tools/data/points_manual.csv")
    ap.add_argument("--include-post-mvp", action="store_true",
                    help="also emit hospital/fire_station/pharmacy/aed (off: MVP is shelters only)")
    ap.add_argument("--check", action="store_true",
                    help="only run the self-check on an existing --out database")
    args = ap.parse_args(argv)

    if args.check:
        return 1 if self_check(args.out) else 0

    check_pbf(args.pbf)
    verified_at = extract_date(args.pbf)
    print(f"Extract: {args.pbf} (date {verified_at})")
    osm_rows = list(iter_osm_rows(args.pbf, verified_at, args.include_post_mvp))
    manual_rows = load_manual_csv(args.manual)
    print(f"OSM points: {len(osm_rows)}, manual points: {len(manual_rows)}")
    n = build_db(osm_rows + manual_rows, args.out)
    print(f"Wrote {n} points to {args.out} ({args.out.stat().st_size} bytes)")
    return 1 if self_check(args.out) else 0


if __name__ == "__main__":
    sys.exit(main())
