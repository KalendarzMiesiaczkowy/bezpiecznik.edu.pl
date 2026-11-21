import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../alarm/panel/call_panel.dart'
    show ContactCallPanel, ContactPanelVariant;
import '../../../wspolne/shell/sos_button.dart'
    show UriLauncher, defaultSosLauncher;
import '../panel_card.dart';
import '../template_registry.dart';

export '../../../alarm/panel/call_panel.dart' show call112Label;

/// Card title of the `call` template.
const String callTitle = 'Wezwij pomoc';

/// Opens `tel:` / `sms:` links. The default is `url_launcher`; tests and the
/// shell override it. Dialling and sending always need the user's tap.
final callLauncherProvider = Provider<UriLauncher>((ref) => defaultSosLauncher);

/// `call` template (DS `CallPanel`, `inline`): the same component as Panel 2
/// (`ContactCallPanel`) inside a `PanelCard`, so the buttons, the GPS line, the
/// contacts state ("Nie masz kontaktów alarmowych" / "Dodaj kontakty") and the
/// "Więcej" row behave identically.
class CallPanelView extends StatelessWidget {
  const CallPanelView({super.key, this.situation, this.onAddContacts});

  /// SMS `{opis}`, when known.
  final String? situation;

  /// Defaults to the profile screen.
  final VoidCallback? onAddContacts;

  @override
  Widget build(BuildContext context) => PanelCard(
    title: callTitle,
    child: ContactCallPanel(
      variant: ContactPanelVariant.inline,
      situation: situation,
      onAddContacts: onAddContacts,
    ),
  );
}

/// Registers the real `call` template (replaces the placeholder).
void registerCallTemplate(TemplateRegistry r) =>
    r.register('call', (context, scope) => const CallPanelView());
