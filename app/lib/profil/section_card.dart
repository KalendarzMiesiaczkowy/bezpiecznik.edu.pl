import 'package:material_ui/material_ui.dart';

import '../wspolne/theme/bz_theme.dart';

/// Grouped card used by the profile form and settings (ref `profil.png`):
/// `bg-100`, 1 px `line-100`, `radius-lg`, optional icon + title header
/// styled like `PanelCard`. Without a title it only wraps rows.
// ponytail: local until a shared BzSectionCard lands in wspolne/ (requested).
class SectionCard extends StatelessWidget {
  const SectionCard({super.key, this.title, this.icon, required this.children});

  final String? title;
  final IconData? icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final bz = context.bz;
    // Material (not DecoratedBox) so ListTile ink shows inside the card.
    return Material(
      color: bz.bg100,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: bz.line100),
        borderRadius: BorderRadius.circular(bz.radiusLg),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: title == null
            ? EdgeInsets.symmetric(horizontal: bz.space4, vertical: bz.space1)
            : EdgeInsets.all(bz.space4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Semantics(
                header: true,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 20, color: bz.ink200),
                      SizedBox(width: bz.space2),
                    ],
                    Expanded(
                      child: Text(
                        title!,
                        style: bz.label.copyWith(
                          fontSize: 16,
                          height: 22 / 16,
                          fontWeight: FontWeight.w700,
                          color: bz.ink100,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: bz.space3),
            ],
            ...children,
          ],
        ),
      ),
    );
  }
}
