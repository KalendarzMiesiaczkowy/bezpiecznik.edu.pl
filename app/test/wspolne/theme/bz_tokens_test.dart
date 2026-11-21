import 'dart:convert';
import 'dart:io';

import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

Map<String, dynamic> _json() => jsonDecode(
  File('../bezpiecznik/08-design-system/tokens.json').readAsStringSync(),
) as Map<String, dynamic>;

String _camel(String name) {
  final p = name.split('-');
  return p.first +
      p.skip(1).map((s) => s[0].toUpperCase() + s.substring(1)).join();
}

double _px(String s) => double.parse(s.replaceAll('px', ''));

void main() {
  final data = _json();
  const t = BzTokens.dark;

  test('every colour token matches tokens.json (refs resolved)', () {
    final toks = (data['color']['tokens'] as List).cast<Map<String, dynamic>>();
    final raw = {
      for (final e in toks) e['name'] as String: e['value'] as String,
    };
    String resolve(String n) {
      final v = raw[n]!;
      return v.startsWith('{') ? resolve(v.substring(1, v.length - 1)) : v;
    }

    expect(t.colorsByName.length, toks.length);
    for (final name in raw.keys) {
      final hex = resolve(name).substring(1);
      final rgb = int.parse(hex.substring(0, 6), radix: 16);
      final a = hex.length == 8 ? int.parse(hex.substring(6), radix: 16) : 255;
      final expected = Color((a << 24) | rgb);
      expect(t.colorsByName[name], expected, reason: name);
    }
    expect(t.action, t.ink100);
    expect(t.danger, t.sosText);
    expect(t.overlayHover, const Color(0x14EEECE6));
  });

  test('spacing and radius match tokens.json', () {
    final all = [
      ...(data['spacing']['tokens'] as List),
      ...(data['radius']['tokens'] as List),
    ];
    final map = <String, double>{
      'space1': t.space1,
      'space2': t.space2,
      'space3': t.space3,
      'space4': t.space4,
      'space5': t.space5,
      'space6': t.space6,
      'space7': t.space7,
      'radiusSm': t.radiusSm,
      'radiusMd': t.radiusMd,
      'radiusLg': t.radiusLg,
      'radiusXl': t.radiusXl,
      'radiusFull': t.radiusFull,
    };
    expect(all.length, map.length);
    for (final e in all) {
      expect(map[_camel(e['name'])], _px(e['value']), reason: e['name']);
    }
    // 4 px grid
    for (final s in [
      t.space1,
      t.space2,
      t.space3,
      t.space4,
      t.space5,
      t.space6,
      t.space7,
    ]) {
      expect(s % 4, 0);
    }
  });

  test('typography roles match tokens.json', () {
    final styles = [
      for (final g in data['type']['groups'] as List)
        ...(g['styles'] as List).cast<Map<String, dynamic>>(),
    ];
    expect(t.textStylesByName.length, styles.length);
    for (final s in styles) {
      final ts = t.textStylesByName[s['name']]!;
      final size = _px(s['fontSize']);
      expect(ts.fontFamily, 'Atkinson Hyperlegible Next');
      expect(ts.fontSize, size, reason: s['name']);
      expect(ts.height! * ts.fontSize!, closeTo(_px(s['lineHeight']), 1e-9));
      expect(
        ts.fontWeight,
        FontWeight.values[(s['fontWeight'] as int) ~/ 100 - 1],
      );
    }
    expect(t.display.letterSpacing, closeTo(-0.8, 1e-9));
    expect(
      t.readout.fontFeatures,
      contains(const FontFeature.tabularFigures()),
    );
  });

  test('durations, easing and touch target', () {
    final d = {
      for (final e in (data['duration']['tokens'] as List))
        _camel(e['name']): e['value'],
    };
    final actual = {
      'durationFast': t.durationFast,
      'durationBase': t.durationBase,
      'durationSlow': t.durationSlow,
      'durationStream': t.durationStream,
      'durationPulse': t.durationPulse,
      'durationShimmer': t.durationShimmer,
    };
    expect(actual.length, d.length);
    d.forEach((k, v) {
      expect(
        actual[k],
        Duration(milliseconds: int.parse(v.replaceAll('ms', ''))),
      );
    });
    expect(t.easeOut, const Cubic(0.2, 0, 0, 1));
    expect(t.easeSheet, const Cubic(0.32, 0.72, 0, 1));
    expect(t.minTouchTarget, 48);
    expect(t.shadowFloat.single.blurRadius, 12);
    expect(t.shadowFloat.single.offset, const Offset(0, 2));
  });

  test('copyWith and lerp', () {
    final c = t.copyWith(space1: 5);
    expect(c.space1, 5);
    expect(c.space2, t.space2);
    expect(t.lerp(c, 0.2), same(t));
    expect(t.lerp(c, 0.8), same(c));
    expect(t.lerp(null, 0.8), same(t));
  });
}
