import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:material_ui/material_ui.dart';

import '../../wspolne/theme/bz_theme.dart';
import 'panel_model.dart';

/// Refusal "brak w zrodlach" (spec ekran-1-czat.md, "Teksty"). No 112.
const String noSourceText =
    'Nie wiem. Moje źródła tego nie opisują. Zapytaj lekarza, farmaceutę albo właściwą instytucję.';

/// Refusal "poza tematem" (spec ekran-1-czat.md, "Teksty"). No 112.
const String offTopicText =
    'Pomagam tylko w sytuacjach kryzysowych i bezpieczeństwie. Tego nie opisują moje źródła.';

String noSourceTextFor(NoSourceKind kind) =>
    kind == NoSourceKind.offTopic ? offTopicText : noSourceText;

/// DS `NoSource`: calm refusal, `bg-100` card, `book-open` icon, no red.
class NoSourceView extends StatelessWidget {
  const NoSourceView({super.key, required this.kind});

  final NoSourceKind kind;

  @override
  Widget build(BuildContext context) {
    final t = context.bz;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: t.bg100,
        border: Border.all(color: t.line150),
        borderRadius: BorderRadius.circular(t.radiusLg),
      ),
      child: Padding(
        padding: EdgeInsets.all(t.space4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(LucideIcons.bookOpen, size: 20, color: t.ink200),
            ),
            SizedBox(width: t.space2),
            Expanded(
              child: Text(
                noSourceTextFor(kind),
                style: t.chat.copyWith(fontSize: 15, height: 22 / 15, color: t.ink100),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
