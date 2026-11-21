# /// script
# requires-python = ">=3.11"
# dependencies = []
# ///
"""Generate ``app/lib/wspolne/theme/bz_tokens.g.dart`` from the design-system tokens.

Usage::

    uv run --script tools/gen_tokens.py [--tokens bezpiecznik/08-design-system/tokens.json] \
        [--out app/lib/wspolne/theme/bz_tokens.g.dart]

Token names become lowerCamelCase (``bg-000`` -> ``bg000``, ``on-action`` ->
``onAction``, ``space-3`` -> ``space3``, ``duration-fast`` -> ``durationFast``).
Values of the form ``{other-token}`` are resolved. ``minTouchTarget`` is not in
tokens.json (the spec fixes it at 48 dp), so it is emitted from a constant here.
"""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

MIN_TOUCH_TARGET = 48.0  # dp, spec 03-ekrany / komponenty.md (Button hit area)


def camel(name: str) -> str:
    head, *rest = name.split("-")
    return head + "".join(p[:1].upper() + p[1:] for p in rest)


def dart_num(x: float) -> str:
    return repr(float(x)) if not float(x).is_integer() else f"{float(x):.1f}"


def px(s: str) -> float:
    m = re.fullmatch(r"(-?[\d.]+)px", s.strip())
    assert m, f"not a px value: {s!r}"
    return float(m.group(1))


def ms(s: str) -> int:
    m = re.fullmatch(r"(\d+)ms", s.strip())
    assert m, f"not a ms value: {s!r}"
    return int(m.group(1))


def color(hexv: str) -> str:
    h = hexv.lstrip("#")
    if len(h) == 6:
        h = "FF" + h
    elif len(h) == 8:  # CSS #RRGGBBAA -> Flutter 0xAARRGGBB
        h = h[6:] + h[:6]
    else:
        raise ValueError(hexv)
    return f"Color(0x{h.upper()})"


def resolve(tokens: list[dict]) -> dict[str, str]:
    raw = {t["name"]: t["value"] for t in tokens}

    def go(name: str) -> str:
        v = raw[name]
        m = re.fullmatch(r"\{(.+)\}", v)
        return go(m.group(1)) if m else v

    return {n: go(n) for n in raw}


def shadow(value: str) -> str:
    m = re.fullmatch(r"(-?\d+)(?:px)? (-?\d+)px (\d+)px (#[0-9A-Fa-f]{6,8})", value.strip())
    assert m, value
    dx, dy, blur, col = m.groups()
    return (f"[BoxShadow(color: {color(col)}, offset: Offset({dx}.0, {dy}.0), "
            f"blurRadius: {blur}.0)]")


def curve(value: str) -> str:
    m = re.fullmatch(r"cubic-bezier\(([^)]*)\)", value.strip())
    assert m, value
    a, b, c, d = (x.strip() for x in m.group(1).split(","))
    return f"Cubic({a}, {b}, {c}, {d})"


def build(data: dict) -> str:
    fields: list[tuple[str, str, str, str]] = []  # (dart type, name, value expr, doc)

    for t, val in zip(data["color"]["tokens"], resolve(data["color"]["tokens"]).values()):
        fields.append(("Color", camel(t["name"]), color(val), t["usage"]))
    for t in data["spacing"]["tokens"]:
        fields.append(("double", camel(t["name"]), dart_num(px(t["value"])), t["usage"]))
    for t in data["radius"]["tokens"]:
        fields.append(("double", camel(t["name"]), dart_num(px(t["value"])), t["usage"]))

    family = data["type"]["fonts"][0]["family"]
    for group in data["type"]["groups"]:
        for s in group["styles"]:
            size, height = px(s["fontSize"]), px(s["lineHeight"])
            args = [
                f"fontFamily: bzFontFamily",
                f"fontSize: {dart_num(size)}",
                f"height: {dart_num(height)} / {dart_num(size)}",
                f"fontWeight: FontWeight.w{s['fontWeight']}",
            ]
            if "letterSpacing" in s:
                em = float(s["letterSpacing"].removesuffix("em"))
                args.append(f"letterSpacing: {dart_num(round(em * size, 4))}")
            if "tabular-nums" in s["usage"]:
                args.append("fontFeatures: [FontFeature.tabularFigures()]")
            fields.append(("TextStyle", camel(s["name"]),
                           "TextStyle(" + ", ".join(args) + ")", s["usage"]))

    for t in data["duration"]["tokens"]:
        fields.append(("Duration", camel(t["name"]),
                       f"Duration(milliseconds: {ms(t['value'])})", t["usage"]))
    for t in data["easing"]["tokens"]:
        fields.append(("Curve", camel(t["name"]), curve(t["value"]), t["usage"]))
    for t in data["shadow"]["tokens"]:
        fields.append(("List<BoxShadow>", camel(t["name"]), shadow(t["value"]), t["usage"]))
    fields.append(("double", "minTouchTarget", dart_num(MIN_TOUCH_TARGET),
                   "Minimum touch target in dp (spec: every control >= 48 dp)."))

    o: list[str] = []
    o.append("// GENERATED — do not edit, run tools/gen_tokens.py")
    o.append("// Source: bezpiecznik/08-design-system/tokens.json")
    o.append("// ignore_for_file: type=lint")
    o.append("")
    o.append("import 'package:material_ui/material_ui.dart';")
    o.append("")
    o.append(f"/// Font family registered in pubspec (see app/assets/fonts/README.md).")
    o.append(f"const String bzFontFamily = {json.dumps(family)};")
    o.append("")
    o.append("/// Design tokens as a [ThemeExtension]. Read via `context.bz` (bz_theme.dart).")
    o.append("@immutable")
    o.append("class BzTokens extends ThemeExtension<BzTokens> {")
    o.append("  const BzTokens({")
    for _, n, _, _ in fields:
        o.append(f"    required this.{n},")
    o.append("  });")
    o.append("")
    o.append("  /// The dark theme (the only one in the MVP).")
    o.append("  static const BzTokens dark = BzTokens(")
    for _, n, v, _ in fields:
        o.append(f"    {n}: {v},")
    o.append("  );")
    o.append("")
    for typ, n, _, doc in fields:
        o.append(f"  /// {doc}")
        o.append(f"  final {typ} {n};")
        o.append("")
    o.append("  @override")
    o.append("  BzTokens copyWith({")
    for typ, n, _, _ in fields:
        o.append(f"    {typ}? {n},")
    o.append("  }) {")
    o.append("    return BzTokens(")
    for _, n, _, _ in fields:
        o.append(f"      {n}: {n} ?? this.{n},")
    o.append("    );")
    o.append("  }")
    o.append("")
    o.append("  /// Tokens are discrete design constants: no interpolation, swap at t = 0.5.")
    o.append("  @override")
    o.append("  BzTokens lerp(ThemeExtension<BzTokens>? other, double t) {")
    o.append("    if (other is! BzTokens) return this;")
    o.append("    return t < 0.5 ? this : other;")
    o.append("  }")
    o.append("")
    o.append("  /// Colour tokens by their tokens.json name, for the gallery and tests.")
    o.append("  Map<String, Color> get colorsByName => {")
    for typ, n, _, _ in fields:
        if typ == "Color":
            kebab = re.sub(r"([a-z])([A-Z0-9])", lambda m: m.group(1) + "-" + m.group(2).lower(), n)
            # bg000 -> bg-000 ; keep digits glued: handled below
            kebab = re.sub(r"([a-z])(\d)", r"\1-\2", n)
            kebab = re.sub(r"([a-z])([A-Z])", lambda m: m.group(1) + "-" + m.group(2).lower(), kebab)
            o.append(f"    {json.dumps(kebab)}: {n},")
    o.append("  };")
    o.append("")
    o.append("  /// Text styles by their tokens.json name, for the gallery and tests.")
    o.append("  Map<String, TextStyle> get textStylesByName => {")
    for typ, n, _, _ in fields:
        if typ == "TextStyle":
            o.append(f"    {json.dumps(n)}: {n},")
    o.append("  };")
    o.append("}")
    o.append("")
    return "\n".join(o)


def main() -> None:
    root = Path(__file__).resolve().parent.parent
    ap = argparse.ArgumentParser()
    ap.add_argument("--tokens", type=Path,
                    default=root / "bezpiecznik/08-design-system/tokens.json")
    ap.add_argument("--out", type=Path,
                    default=root / "app/lib/wspolne/theme/bz_tokens.g.dart")
    args = ap.parse_args()
    data = json.loads(args.tokens.read_text(encoding="utf-8"))
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(build(data), encoding="utf-8")
    print(f"wrote {args.out}")


if __name__ == "__main__":
    main()
