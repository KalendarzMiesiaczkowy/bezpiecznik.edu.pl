# /// script
# requires-python = ">=3.11"
# dependencies = ["fonttools", "brotli"]
# ///
"""Convert the design-system variable woff2 fonts into static TTFs for Flutter.

Flutter cannot load woff2 and ignores variable-font axes on Android, so we
instantiate one static TTF per weight used by the tokens and merge the latin and
latin-ext subsets (the latter carries the Polish letters).

Usage::

    uv run --script tools/build_fonts.py [--ds bezpiecznik/08-design-system] \
        [--out app/assets/fonts]
"""
from __future__ import annotations

import argparse
from pathlib import Path

from fontTools.merge import Merger
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

FAMILY = "Atkinson Hyperlegible Next"
# weight value -> style name (weights used in tokens.json: 400/500/600/700/800)
WEIGHTS = {
    400: "Regular",
    500: "Medium",
    600: "SemiBold",
    700: "Bold",
    800: "ExtraBold",
}
SUBSETS = (
    "atkinson-hyperlegible-next-latin-wght-normal.woff2",
    "atkinson-hyperlegible-next-latin-ext-wght-normal.woff2",
)


def _load(path: Path, weight: int, tmp: Path) -> Path:
    font = TTFont(path)
    font.flavor = None  # decompress woff2
    inst = instancer.instantiateVariableFont(font, {"wght": weight})
    out = tmp / f"{path.stem}-{weight}.ttf"
    inst.save(out)
    return out


def build(ds: Path, out: Path) -> list[Path]:
    out.mkdir(parents=True, exist_ok=True)
    tmp = out / ".build"
    tmp.mkdir(exist_ok=True)
    written: list[Path] = []
    try:
        for weight, style in WEIGHTS.items():
            parts = [_load(ds / "fonts" / s, weight, tmp) for s in SUBSETS]
            merged = Merger().merge([str(p) for p in parts])
            name = merged["name"]
            for rec in list(name.names):
                if rec.nameID in (1, 16):
                    rec.string = FAMILY
                elif rec.nameID in (2, 17):
                    rec.string = style
                elif rec.nameID == 4:
                    rec.string = f"{FAMILY} {style}"
                elif rec.nameID == 6:
                    rec.string = f"AtkinsonHyperlegibleNext-{style}"
            merged["OS/2"].usWeightClass = weight
            target = out / f"AtkinsonHyperlegibleNext-{style}.ttf"
            merged.save(target)
            written.append(target)
            print(f"{target} ({target.stat().st_size} B, {len(merged.getGlyphOrder())} glyphs)")
    finally:
        for p in tmp.glob("*.ttf"):
            p.unlink()
        tmp.rmdir()
    return written


def main() -> None:
    root = Path(__file__).resolve().parent.parent
    ap = argparse.ArgumentParser()
    ap.add_argument("--ds", type=Path, default=root / "bezpiecznik/08-design-system")
    ap.add_argument("--out", type=Path, default=root / "app/assets/fonts")
    args = ap.parse_args()
    build(args.ds, args.out)


if __name__ == "__main__":
    main()
