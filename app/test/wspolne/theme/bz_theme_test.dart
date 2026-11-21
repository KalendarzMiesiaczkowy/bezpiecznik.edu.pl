import 'package:bezpiecznik/wspolne/theme/bz_buttons.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'test_fonts.dart';

Widget _app(Widget child) => MaterialApp(
  theme: buildBzTheme(),
  home: Scaffold(body: Center(child: child)),
);

void main() {
  setUpAll(loadBzFonts);

  test('theme builds from tokens', () {
    final theme = buildBzTheme();
    expect(theme.brightness, Brightness.dark);
    expect(theme.useMaterial3, isTrue);
    expect(theme.extension<BzTokens>(), isNotNull);
    expect(theme.scaffoldBackgroundColor, BzTokens.dark.bg000);
    expect(theme.colorScheme.primary, BzTokens.dark.action);
    expect(theme.colorScheme.onPrimary, BzTokens.dark.onAction);
    expect(theme.textTheme.bodyLarge!.fontFamily, bzFontFamily);
    expect(theme.textTheme.bodyLarge!.fontSize, 17);
  });

  test('component themes enforce 48 dp targets', () {
    final theme = buildBzTheme();
    for (final style in [
      theme.filledButtonTheme.style!,
      theme.outlinedButtonTheme.style!,
      theme.textButtonTheme.style!,
      theme.iconButtonTheme.style!,
    ]) {
      expect(style.minimumSize!.resolve({}), const Size(48, 48));
    }
    expect(theme.listTileTheme.minTileHeight, greaterThanOrEqualTo(48));
  });

  testWidgets('context.bz resolves and Material buttons are >= 48 dp', (
    tester,
  ) async {
    late BzTokens tokens;
    await tester.pumpWidget(
      _app(
        Builder(
          builder: (c) {
            tokens = c.bz;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton(onPressed: () {}, child: const Text('Zapisz')),
                OutlinedButton(onPressed: () {}, child: const Text('Anuluj')),
                TextButton(onPressed: () {}, child: const Text('Więcej')),
                IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
                Switch(value: true, onChanged: (_) {}),
                const ListTile(title: Text('Wiersz')),
                const TextField(decoration: InputDecoration(labelText: 'Imię')),
              ],
            );
          },
        ),
      ),
    );
    expect(tokens, same(BzTokens.dark));
    for (final type in [FilledButton, OutlinedButton, TextButton, IconButton]) {
      final s = tester.getSize(find.byType(type));
      expect(s.height, greaterThanOrEqualTo(48), reason: '$type');
      expect(s.width, greaterThanOrEqualTo(48), reason: '$type');
    }
    expect(tester.takeException(), isNull);
  });

  group('BzButton', () {
    for (final v in BzButtonVariant.values) {
      for (final s in BzButtonSize.values) {
        testWidgets('${v.name}/${s.name} hit area >= 48 dp', (tester) async {
          await tester.pumpWidget(
            _app(
              BzButton(
                label: 'Pokaż plan',
                variant: v,
                size: s,
                onPressed: () {},
              ),
            ),
          );
          final size = tester.getSize(find.byType(BzButton));
          expect(size.height, greaterThanOrEqualTo(48));
          expect(size.width, greaterThanOrEqualTo(48));
        });
      }
    }

    testWidgets('icon-only button is a >= 48 dp circle with semantics', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _app(
          BzButton(
            icon: Icons.add,
            semanticLabel: 'Dodaj',
            size: BzButtonSize.sm,
            onPressed: () {},
          ),
        ),
      );
      final size = tester.getSize(find.byType(BzButton));
      expect(size, const Size(48, 48));
      expect(find.bySemanticsLabel('Dodaj'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('taps call onPressed; disabled and loading do not', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _app(BzButton(label: 'OK', onPressed: () => taps++)),
      );
      await tester.tap(find.byType(BzButton));
      expect(taps, 1);

      await tester.pumpWidget(_app(const BzButton(label: 'OK')));
      await tester.tap(find.byType(BzButton));
      expect(taps, 1);

      await tester.pumpWidget(
        _app(BzButton(label: 'OK', loading: true, onPressed: () => taps++)),
      );
      await tester.tap(find.byType(BzButton));
      expect(taps, 1);
    });

    testWidgets('primary uses action fill, sos uses sos fill', (tester) async {
      Color? fillOf() {
        final box = tester.widget<AnimatedContainer>(
          find.byType(AnimatedContainer),
        );
        return (box.decoration! as ShapeDecoration).color;
      }

      await tester.pumpWidget(
        _app(
          BzButton(
            label: 'A',
            variant: BzButtonVariant.primary,
            onPressed: () {},
          ),
        ),
      );
      expect(fillOf(), BzTokens.dark.action);
      await tester.pumpWidget(
        _app(
          BzButton(label: 'B', variant: BzButtonVariant.sos, onPressed: () {}),
        ),
      );
      expect(fillOf(), BzTokens.dark.sos);
    });

    testWidgets('full width stretches, sub line renders', (tester) async {
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 300,
            child: BzButton(
              label: 'Zadzwoń 112',
              sub: 'Numer alarmowy',
              variant: BzButtonVariant.sos,
              size: BzButtonSize.xl,
              fullWidth: true,
              onPressed: () {},
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(BzButton)).width, 300);
      expect(find.text('Numer alarmowy'), findsOneWidget);
      expect(tester.getSize(find.byType(AnimatedContainer)).height, 72);
    });
  });
}
