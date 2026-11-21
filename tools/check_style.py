# /// script
# requires-python = ">=3.10"
# dependencies = []
# ///
"""Validates app/assets/map/style.json against the generated MBTiles and local glyphs.

Usage: uv run --script tools/check_style.py [--style PATH] [--mbtiles PATH] [--glyphs DIR]

Checks: valid JSON; no http(s) URLs anywhere; only the known placeholders; every
source-layer exists in the mbtiles `json` metadata row; every font stack used has
glyph ranges 0-255 and 256-511 (Polish diacritics) in the glyphs directory.
"""
import argparse
import json
import re
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PLACEHOLDERS = {"MBTILES_PATH", "GLYPHS_DIR"}
REQUIRED_RANGES = ("0-255", "256-511")


def walk(node):
    """Yield every string in a JSON tree."""
    if isinstance(node, str):
        yield node
    elif isinstance(node, dict):
        for v in node.values():
            yield from walk(v)
    elif isinstance(node, list):
        for v in node:
            yield from walk(v)


def fontstacks(style):
    stacks = set()
    for layer in style.get("layers", []):
        font = layer.get("layout", {}).get("text-font")
        if font is None:
            continue
        if isinstance(font, list) and font and isinstance(font[0], str) and font[0] not in ("literal", "step", "case", "match", "get"):
            stacks.add(tuple(font))
        else:
            print(f"  ! layer {layer['id']}: text-font is an expression, cannot verify", file=sys.stderr)
    return stacks


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--style", default=ROOT / "app/assets/map/style.json")
    ap.add_argument("--mbtiles", default=ROOT / "app/assets/generated/zachodniopomorskie.mbtiles")
    ap.add_argument("--glyphs", default=ROOT / "app/assets/map/glyphs")
    args = ap.parse_args()
    errors = []

    try:
        style = json.loads(Path(args.style).read_text(encoding="utf-8"))
    except (OSError, ValueError) as e:
        print(f"FAIL: style is not valid JSON: {e}")
        return 1
    print(f"ok: valid JSON, {len(style.get('layers', []))} layers")

    for s in walk(style):
        if re.search(r"https?://", s, re.I):
            errors.append(f"network URL in style: {s}")
        for ph in re.findall(r"\{([A-Z_]+)\}", s):
            if ph not in PLACEHOLDERS:
                errors.append(f"unknown placeholder {{{ph}}} in: {s}")
    if "sprite" in style:
        errors.append("style has a sprite key, but sprites are not bundled")
    if not errors:
        print("ok: no http(s) URLs, placeholders known")

    # Source layers vs mbtiles metadata.
    used = {l["source-layer"] for l in style["layers"] if "source-layer" in l}
    mb = Path(args.mbtiles)
    if not mb.exists():
        errors.append(f"mbtiles not found: {mb}")
    else:
        con = sqlite3.connect(f"file:{mb}?mode=ro", uri=True)
        row = con.execute("select value from metadata where name='json'").fetchone()
        if not row:
            errors.append("mbtiles metadata has no `json` row")
        else:
            have = {v["id"] for v in json.loads(row[0]).get("vector_layers", [])}
            missing = sorted(used - have)
            if missing:
                errors.append(f"source-layers missing from mbtiles: {missing}")
            else:
                print(f"ok: {len(used)} source-layers all present ({len(have)} in mbtiles)")
        con.close()

    # Glyph ranges.
    stacks = fontstacks(style)
    gdir = Path(args.glyphs)
    for stack in sorted(stacks):
        for name in stack:
            for rng in REQUIRED_RANGES:
                f = gdir / name / f"{rng}.pbf"
                if not f.is_file() or f.stat().st_size < 100:
                    errors.append(f"missing/empty glyph range: {f}")
    if stacks and not any(e.startswith("missing/empty glyph") for e in errors):
        print(f"ok: glyph ranges {', '.join(REQUIRED_RANGES)} present for {len(stacks)} font stacks")

    if errors:
        print("FAIL")
        for e in errors:
            print("  -", e)
        return 1
    print("PASS")
    return 0


if __name__ == "__main__":
    sys.exit(main())
