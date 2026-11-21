import '../../alarm/signal/signal_panel.dart';
import '../../ratunek/cpr/cpr_view.dart';
import 'call/call_panel_view.dart';
import 'map/map_card_view.dart';
import 'panel_model.dart';
import 'template_registry.dart';

/// The registry the app uses: defaults plus the templates of other modules
/// (`call` D03, `map` B06, `cpr` D04, `signal` D05).
TemplateRegistry buildAppTemplateRegistry() {
  final r = TemplateRegistry.withDefaults();
  registerCallTemplate(r);
  registerMapTemplate(r);
  r.register('signal', (c, s) => SignalPanelView(panel: s.panel as SignalPanel));
  registerCprTemplate(r, inlinePinned: false);
  return r;
}
