import '../../ratunek/cpr/cpr_view.dart';
import 'call/call_panel_view.dart';
import 'map/map_card_view.dart';
import 'template_registry.dart';

/// The registry the app uses: defaults plus the templates of other modules
/// (`call` D03, `map` B06, `cpr` D04).
TemplateRegistry buildAppTemplateRegistry() {
  final r = TemplateRegistry.withDefaults();
  registerCallTemplate(r);
  registerMapTemplate(r);
  registerCprTemplate(r);
  return r;
}
