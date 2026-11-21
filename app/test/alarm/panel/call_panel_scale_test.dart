import 'package:bezpiecznik/alarm/panel/call_gps.dart';
import 'package:bezpiecznik/alarm/panel/call_panel.dart';
import 'package:bezpiecznik/mapa/position_provider.dart';
import 'package:bezpiecznik/profil/profile_model.dart';
import 'package:bezpiecznik/profil/profile_store.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _Profile extends ProfileNotifier {
  @override
  Future<HouseholdProfile> build() async => const HouseholdProfile();
}

void main() {
  testWidgets('call panel at 2.0 text scale: no overflow, labels present', (tester) async {
    tester.view.physicalSize = const Size(412 * 2.625, 915 * 2.625);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          callLauncherProvider.overrideWithValue((_) async => true),
          canSendSmsProvider.overrideWith((_) async => true),
          profileProvider.overrideWith(_Profile.new),
          callGpsProvider.overrideWith((_) => Stream.value(const CallGps(access: LocationAccess.serviceOff))),
        ],
        child: MaterialApp(
          theme: buildBzTheme(),
          builder: (c, w) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: const TextScaler.linear(2.0)), child: w!),
          home: const Scaffold(body: ContactCallPanel(situation: 'RKO')),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text(call112Label), findsOneWidget);
    expect(find.text(callSmsLabel), findsOneWidget);
    expect(find.byKey(const Key('call-997')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
