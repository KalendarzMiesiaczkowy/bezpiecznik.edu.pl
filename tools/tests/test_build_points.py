"""Tests for tools/build_points.py (synthetic input only, no real PBF)."""
import sqlite3
import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import build_points as bp  # noqa: E402


@pytest.mark.parametrize("tags,expected", [
    ({"building": "bunker"}, "shelter"),
    ({"building": "bunker", "bunker_type": "bomb_shelter"}, "shelter"),
    ({"building": "bunker", "bunker_type": "pillbox"}, None),
    ({"building": "bunker", "historic": "bunker"}, None),
    ({"building": "bunker", "ruins": "yes"}, None),
    ({"building": "bunker", "disused:building": "bunker"}, None),
    ({"building": "bunker", "access": "private"}, None),
    ({"military": "bunker"}, None),
    ({"military": "bunker", "bunker_type": "munitions"}, None),
    ({"military": "bunker", "bunker_type": "air_raid_shelter"}, "shelter"),
    ({"amenity": "shelter", "shelter_type": "bomb_shelter"}, "shelter"),
    ({"amenity": "shelter", "shelter_type": "public_transport"}, None),
    ({"amenity": "shelter", "shelter_type": "picnic_shelter"}, None),
    ({"amenity": "shelter"}, None),
    ({"emergency": "assembly_point"}, None),
    ({"amenity": "hospital"}, None),
    ({}, None),
])
def test_classify_mvp(tags, expected):
    assert bp.classify(tags) == expected


@pytest.mark.parametrize("tags,expected", [
    ({"amenity": "hospital"}, "hospital"),
    ({"healthcare": "hospital"}, "hospital"),
    ({"amenity": "fire_station"}, "fire_station"),
    ({"amenity": "pharmacy"}, "pharmacy"),
    ({"emergency": "defibrillator"}, "aed"),
    ({"building": "bunker"}, "shelter"),
])
def test_classify_post_mvp(tags, expected):
    assert bp.classify(tags, include_post_mvp=True) == expected


def test_classify_outputs_are_in_contract_enum():
    for tags in ({"building": "bunker"}, {"amenity": "pharmacy"}, {"emergency": "defibrillator"}):
        assert bp.classify(tags, True) in bp.KINDS


def test_centroid_square_closed_ring():
    ring = [(0.0, 0.0), (0.0, 2.0), (2.0, 2.0), (2.0, 0.0), (0.0, 0.0)]
    assert bp.centroid(ring) == (1.0, 1.0)


def test_centroid_single_and_empty():
    assert bp.centroid([(53.0, 14.0)]) == (53.0, 14.0)
    with pytest.raises(ValueError):
        bp.centroid([])


def test_address():
    assert bp.build_address({"addr:street": "Wojska Polskiego", "addr:housenumber": "1",
                             "addr:city": "Szczecin"}) == "Wojska Polskiego 1, Szczecin"
    assert bp.build_address({"addr:city": "Szczecin"}) == "Szczecin"
    assert bp.build_address({}) is None


def test_build_row_osm_fields():
    r = bp.build_row({"name": "Schron", "opening_hours": "24/7"}, "shelter",
                     53.4, 14.5, "2026-11-19", "way", 7)
    assert r["confirmed"] == 0 and r["source"] == "OpenStreetMap"
    assert r["verified_at"] == "2026-11-19" and r["open_24h"] == 1
    r2 = bp.build_row({}, "shelter", 53.4, 14.5, "2026-11-19", "node", 8)
    assert r2["name"] is None and r2["open_24h"] is None and r2["availability"] is None


def _rows():
    return [
        bp.build_row({"name": "A"}, "shelter", 53.4285, 14.5528, "2026-11-19", "node", 1),
        bp.build_row({"name": "B"}, "shelter", 53.5, 14.6, "2026-11-19", "way", 2),
        {**bp.build_row({}, "hiding_place", 53.43, 14.55, "2026-03-01", "node", 0),
         "source": "KG PSP", "confirmed": 1, "osm_type": None, "osm_id": None},
    ]


def test_build_db_schema_and_rtree(tmp_path):
    out = tmp_path / "sub" / "points.sqlite"
    assert bp.build_db(_rows(), out) == 3
    con = sqlite3.connect(out)
    cols = [r[1] for r in con.execute("PRAGMA table_info(points)")]
    assert cols == ["id", "kind", "name", "address", "lat", "lon", "availability",
                    "open_24h", "source", "verified_at", "confirmed"]
    assert con.execute("SELECT COUNT(*) FROM points_rtree").fetchone()[0] == 3
    assert con.execute("SELECT COUNT(*) FROM points_osm").fetchone()[0] == 2
    hit = con.execute("SELECT id FROM points_rtree WHERE min_lat >= 53.42 AND max_lat <= 53.44"
                      " AND min_lon >= 14.54 AND max_lon <= 14.56").fetchall()
    assert len(hit) == 2
    with pytest.raises(sqlite3.IntegrityError):
        con.execute("INSERT INTO points (kind, lat, lon, source, verified_at, confirmed)"
                    " VALUES ('bogus', 1, 1, 's', '2026-01-01', 0)")
    with pytest.raises(sqlite3.IntegrityError):
        con.execute("INSERT INTO points (kind, lat, lon, source, verified_at, confirmed)"
                    " VALUES ('shelter', 1, 1, 's', '2026-01-01', 2)")


def test_build_db_overwrites(tmp_path):
    out = tmp_path / "p.sqlite"
    bp.build_db(_rows(), out)
    bp.build_db(_rows()[:1], out)
    con = sqlite3.connect(out)
    assert con.execute("SELECT COUNT(*) FROM points").fetchone()[0] == 1


def test_nearest_and_self_check(tmp_path, capsys):
    out = tmp_path / "p.sqlite"
    bp.build_db(_rows(), out)
    con = sqlite3.connect(out)
    near = bp.nearest(con, *bp.SZCZECIN, limit=2)
    assert near[0][2] == "A" and near[0][5] < 10
    assert bp.self_check(out) == []
    assert "shelter" in capsys.readouterr().out


def test_self_check_detects_missing_rtree(tmp_path, capsys):
    out = tmp_path / "p.sqlite"
    bp.build_db(_rows(), out)
    con = sqlite3.connect(out)
    con.execute("DELETE FROM points_rtree WHERE id = 1")
    con.commit()
    con.close()
    assert bp.self_check(out)


def test_self_check_empty_db_fails(tmp_path):
    out = tmp_path / "p.sqlite"
    bp.build_db([], out)
    assert bp.self_check(out)


HEADER = ",".join(bp.MANUAL_COLUMNS)


def test_manual_csv_default_file_is_header_only():
    path = Path(__file__).resolve().parent.parent / "data" / "points_manual.csv"
    assert bp.load_manual_csv(path) == []


def test_manual_csv_valid_and_invalid(tmp_path):
    p = tmp_path / "m.csv"
    p.write_text(f"{HEADER}\nshelter,Name,Addr 1,53.4,14.5,,1,KG PSP,2026-03-01,1\n")
    rows = bp.load_manual_csv(p)
    assert rows[0]["confirmed"] == 1 and rows[0]["open_24h"] == 1 and rows[0]["availability"] is None
    for bad in (
        "bogus,N,A,53.4,14.5,,,KG PSP,2026-03-01,1",
        "shelter,N,A,53.4,14.5,,,,2026-03-01,1",
        "shelter,N,A,53.4,14.5,,,KG PSP,not-a-date,1",
        "shelter,N,A,abc,14.5,,,KG PSP,2026-03-01,1",
        "shelter,N,A,53.4,14.5,,,KG PSP,2026-03-01,2",
    ):
        p.write_text(f"{HEADER}\n{bad}\n")
        with pytest.raises(ValueError):
            bp.load_manual_csv(p)


def test_manual_csv_missing_file(tmp_path):
    assert bp.load_manual_csv(tmp_path / "nope.csv") == []


def test_check_pbf_rejects_html(tmp_path):
    f = tmp_path / "x.pbf"
    f.write_text("<!DOCTYPE HTML><html>404</html>")
    with pytest.raises(SystemExit):
        bp.check_pbf(f)
