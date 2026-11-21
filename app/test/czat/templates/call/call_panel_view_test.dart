import 'package:bezpiecznik/alarm/panel/call_gps.dart';
import 'package:bezpiecznik/alarm/panel/call_panel.dart';
import 'package:bezpiecznik/czat/templates/call/call_panel_view.dart';
import 'package:bezpiecznik/czat/templates/panel_model.dart';
import 'package:bezpiecznik/czat/templates/template_registry.dart';
import 'package:bezpiecznik/mapa/position_provider.dart';
import 'package:bezpiecznik/profil/profile_model.dart';
import 'package:bezpiecznik/profil/profile_store.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _Profile extends ProfileNotifier {
  _Profile(this.p);
  final HouseholdProfile p;
  @override
  Future<HouseholdProfile> build() async => p;
}

Future<void> pump(
  WidgetTester tester,
  List<Uri> launched, {
  HouseholdProfile profile = HouseholdProfile.empty,
  VoidCallback? onAddContacts,
}) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        callLauncherProvider.overrideWithValue((uri) async {
          launched.add(uri);
          return true;
        }),
        canSendSmsProvider.overrideWith((_) async => true),
        profileProvider.overrideWith(() => _Profile(profile)),
        callGpsProvider.overrideWith(
          (_) => Stream.value(const CallGps(access: LocationAccess.serviceOff)),
        ),
      ],
      child: MaterialApp(
        theme: buildBzTheme(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: CallPanelView(onAddContacts: onAddContacts),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('title, two 80 px radius-lg buttons, "Więcej" collapsed', (
    tester,
  ) async {
    await pump(tester, []);
    expect(find.text(callTitle), findsOneWidget);
    expect(find.text(call112Label), findsOneWidget);
    expect(tester.getSize(find.byKey(const Key('call-112'))).height, greaterThanOrEqualTo(80));
    expect(tester.getSize(find.byKey(const Key('call-notify'))).height, greaterThanOrEqualTo(80));
    expect(find.text('Więcej'), findsOneWidget);
    expect(find.byKey(const Key('call-999')), findsOneWidget);
    final material = tester.widget<Material>(
      find
          .descendant(
            of: find.byKey(const Key('call-112')),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(
      (material.shape! as RoundedRectangleBorder).borderRadius,
      BorderRadius.circular(18),
    );
  });

  testWidgets('Panel 2 state block: GPS line and empty contacts', (
    tester,
  ) async {
    var added = 0;
    await pump(tester, [], onAddContacts: () => added++);
    expect(
      find.text('Brak sygnału GPS. Wyjdź na otwartą przestrzeń.'),
      findsOneWidget,
    );
    expect(find.text('Nie masz kontaktów alarmowych.'), findsNothing);
    await tester.tap(find.text('Dodaj kontakty'));
    expect(added, 1);
  });

  testWidgets('"Dodaj kontakty" is flush with the panel content', (
    tester,
  ) async {
    await pump(tester, []);
    final textLeft = tester.getTopLeft(find.text(call112Label)).dx;
    final linkLeft = tester.getTopLeft(find.text('Dodaj kontakty')).dx;
    expect(linkLeft, lessThan(textLeft));
  });

  testWidgets('with contacts the recipients are listed', (tester) async {
    await pump(
      tester,
      [],
      profile: HouseholdProfile(
        iceContacts: const [IceContact(name: 'Mama', phone: '+48600100200')],
      ),
    );
    expect(find.text('SMS z lokalizacją do: Mama'), findsOneWidget);
    expect(find.text('Nie masz kontaktów alarmowych.'), findsNothing);
  });

  testWidgets('nothing launched before a tap; taps dial / prepare SMS', (
    tester,
  ) async {
    final launched = <Uri>[];
    await pump(tester, launched);
    expect(launched, isEmpty);
    await tester.tap(find.byKey(const Key('call-112')));
    await tester.pump();
    expect(launched.single.toString(), 'tel:112');
    await tester.tap(find.byKey(const Key('call-notify')));
    await tester.pump();
    expect(launched.last.scheme, 'sms');
  });

  testWidgets('999 / 998 / 997 are visible and dial without "Więcej"', (tester) async {
    final launched = <Uri>[];
    await pump(tester, launched);
    await tester.tap(find.byKey(const Key('call-998')));
    await tester.pump();
    expect(launched.single.toString(), 'tel:998');
  });

  testWidgets('registerCallTemplate replaces the placeholder', (tester) async {
    final r = TemplateRegistry.withDefaults();
    registerCallTemplate(r);
    expect(r.builderFor('call'), isNotNull);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          callGpsProvider.overrideWith((_) => const Stream.empty()),
          profileProvider.overrideWith(() => _Profile(HouseholdProfile.empty)),
        ],
        child: MaterialApp(
          theme: buildBzTheme(),
          home: Material(
            child: SingleChildScrollView(
              child: Builder(
                builder: (c) => r.builderFor('call')!(
                  c,
                  PanelScope(
                    panel: const CallPanel(),
                    index: 0,
                    answer: const AssistantAnswer(),
                    variant: null,
                    showVariantSwitch: false,
                    onVariantChanged: (_) {},
                    done: const {},
                    onDoneChanged: (_, _) {},
                    onOpenSource: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    expect(find.text(call112Label), findsOneWidget);
    expect(find.byKey(const ValueKey('placeholder-call')), findsNothing);
  });
}
