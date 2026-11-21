import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../ratunek/ui/rescue_situation.dart';
import '../signal/signal_panel.dart';
import 'call_panel.dart';

/// Panel 2 content (spec `panel-2-kontakt-ze-sluzbami.md`), hosted by the
/// shell's bottom `PanelHost`. Thin wrapper over [ContactCallPanel] (`sheet`):
/// "Zamknij" closes the panel through `shellPanelsProvider`, the signal section
/// embeds the D05 `SignalPanelView` without its card.
class ContactPanel extends ConsumerWidget {
  const ContactPanel({super.key, this.situation});

  /// SMS `{opis}` (rescue card name or last user message), when known.
  final String? situation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ContactCallPanel(
      situation: situation ?? ref.watch(chatSituationProvider),
      signalBuilder: (_) => const SignalPanelView(bare: true),
    );
  }
}
