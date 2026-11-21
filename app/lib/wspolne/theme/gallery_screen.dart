import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import 'bz_buttons.dart';
import 'bz_theme.dart';

/// Route path of the design gallery.
///
/// DEBUG ONLY: the router must register [GalleryScreen] under this path only
/// when `kDebugMode` is true (e.g. `if (kDebugMode) GoRoute(path: galleryRoutePath, ...)`).
/// As a second line of defence [GalleryScreen] renders an empty page in
/// release/profile builds.
const galleryRoutePath = '/gallery';

/// Debug-only showcase: type scale, colours, buttons, icons, Polish glyphs.
class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    if (!kDebugMode) {
      return Scaffold(backgroundColor: t.bg000, body: const SizedBox.shrink());
    }
    return Scaffold(
      backgroundColor: t.bg000,
      appBar: AppBar(title: const Text('Galeria')),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(t.space4, t.space2, t.space4, t.space6),
          children: [
            const _Section('Typografia'),
            for (final e in t.textStylesByName.entries)
              _TypeRow(name: e.key, style: e.value),
            const _Section('Polskie znaki'),
            Text(
              'Zażółć gęślą jaźń. ĄĆĘŁŃÓŚŹŻ ąćęłńóśźż',
              key: const Key('gallery-polish'),
              style: t.chat,
            ),
            const _Section('Kolory'),
            for (final e in t.colorsByName.entries)
              _Swatch(name: e.key, color: e.value),
            const _Section('Przyciski'),
            const _Buttons(),
            const _Section('Ikony Lucide'),
            const _Icons(),
            const _Section('Odstępy i zaokrąglenia'),
            const _Spacing(),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    return Padding(
      padding: EdgeInsets.only(top: t.space6, bottom: t.space3),
      child: Text(title, style: t.title),
    );
  }
}

class _TypeRow extends StatelessWidget {
  const _TypeRow({required this.name, required this.style});
  final String name;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    final meta =
        '$name · ${style.fontSize!.round()}/${(style.fontSize! * style.height!).round()} '
        '· w${style.fontWeight!.value}';
    return Padding(
      padding: EdgeInsets.only(bottom: t.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(meta, style: t.caption.copyWith(color: t.ink300)),
          Text('Bezpiecznik 047° 12 m', style: style.copyWith(color: t.ink100)),
        ],
      ),
    );
  }
}

String _hex(Color c) {
  String two(double v) => (v * 255).round().toRadixString(16).padLeft(2, '0');
  final rgb = '${two(c.r)}${two(c.g)}${two(c.b)}'.toUpperCase();
  return c.a < 1 ? '#$rgb${two(c.a).toUpperCase()}' : '#$rgb';
}

class _Swatch extends StatelessWidget {
  const _Swatch({required this.name, required this.color});
  final String name;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    return Padding(
      padding: EdgeInsets.only(bottom: t.space2),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(t.radiusSm),
              border: Border.all(color: t.line200),
            ),
          ),
          SizedBox(width: t.space3),
          Expanded(child: Text(name, style: t.label)),
          Text(_hex(color), style: t.caption.copyWith(color: t.ink200)),
        ],
      ),
    );
  }
}

class _Buttons extends StatelessWidget {
  const _Buttons();

  static String _name(BzButtonVariant v) => v.name;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final v in BzButtonVariant.values) ...[
          Text(_name(v), style: t.caption.copyWith(color: t.ink300)),
          SizedBox(height: t.space1),
          Wrap(
            spacing: t.space2,
            runSpacing: t.space1,
            children: [
              for (final s in BzButtonSize.values)
                BzButton(
                  label: s.name,
                  variant: v,
                  size: s,
                  icon: LucideIcons.shield,
                  onPressed: () {},
                ),
              BzButton(
                semanticLabel: 'Wyślij',
                icon: LucideIcons.arrowUp,
                variant: v,
                onPressed: () {},
              ),
              BzButton(label: 'Wyłączony', variant: v, onPressed: null),
              BzButton(
                label: 'Ładuję',
                variant: v,
                loading: true,
                onPressed: () {},
              ),
            ],
          ),
          SizedBox(height: t.space3),
        ],
        Text(
          'z podpisem, pełna szerokość',
          style: t.caption.copyWith(color: t.ink300),
        ),
        SizedBox(height: t.space1),
        BzButton(
          label: 'Zadzwoń 112',
          sub: 'Numer alarmowy',
          icon: LucideIcons.phone,
          variant: BzButtonVariant.sos,
          size: BzButtonSize.xl,
          fullWidth: true,
          onPressed: () {},
        ),
      ],
    );
  }
}

class _Icons extends StatelessWidget {
  const _Icons();

  static const _icons = <String, IconData>{
    'shield': LucideIcons.shield,
    'phone': LucideIcons.phone,
    'map': LucideIcons.map,
    'compass': LucideIcons.compass,
    'navigation': LucideIcons.navigation,
    'heartPulse': LucideIcons.heartPulse,
    'triangleAlert': LucideIcons.triangleAlert,
    'menu': LucideIcons.menu,
    'share': LucideIcons.share,
    'trash': LucideIcons.trash,
  };

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    return Wrap(
      spacing: t.space4,
      runSpacing: t.space3,
      children: [
        for (final e in _icons.entries)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(e.value, size: 24, color: t.ink100),
              SizedBox(height: t.space1),
              Text(e.key, style: t.caption.copyWith(color: t.ink300)),
            ],
          ),
      ],
    );
  }
}

class _Spacing extends StatelessWidget {
  const _Spacing();

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    final spaces = {
      'space1': t.space1,
      'space2': t.space2,
      'space3': t.space3,
      'space4': t.space4,
      'space5': t.space5,
      'space6': t.space6,
      'space7': t.space7,
    };
    final radii = {
      'radiusSm': t.radiusSm,
      'radiusMd': t.radiusMd,
      'radiusLg': t.radiusLg,
      'radiusXl': t.radiusXl,
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final e in spaces.entries)
          Padding(
            padding: EdgeInsets.only(bottom: t.space1),
            child: Row(
              children: [
                SizedBox(
                  width: 72,
                  child: Text('${e.key} ${e.value.round()}', style: t.caption),
                ),
                Container(width: e.value, height: 12, color: t.signal),
              ],
            ),
          ),
        SizedBox(height: t.space3),
        Wrap(
          spacing: t.space3,
          runSpacing: t.space3,
          children: [
            for (final e in radii.entries)
              Container(
                width: 72,
                height: 56,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: t.bg200,
                  border: Border.all(color: t.line150),
                  borderRadius: BorderRadius.circular(e.value),
                ),
                child: Text(e.key, style: t.caption),
              ),
          ],
        ),
      ],
    );
  }
}
