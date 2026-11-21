import 'dart:convert';
import 'dart:io';

import 'package:bezpiecznik/poradniki/guide.dart';
import 'package:bezpiecznik/poradniki/guide_reader_screen.dart';
import 'package:bezpiecznik/poradniki/guides_screen.dart';
import 'package:bezpiecznik/ustawienia/sources.dart';
import 'package:bezpiecznik/wspolne/theme/bz_theme.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

const _manifest = '''
{"version": 1, "guides": [
  {"id": "rcb", "title": "Poradnik bezpieczeństwa", "publisher": "RCB, MON, MSWiA",
   "year": "2025", "pages": 54, "bytes": 1501142, "file": "guide-rcb.pdf"},
  {"id": "ulotka", "title": "W obliczu powodzi (ulotka)", "publisher": "Komenda Główna PSP",
   "year": null, "pages": 2, "bytes": 512933, "file": "guide-ulotka.pdf"}
]}
''';

// 1x1 transparent PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

class _Bundle extends CachingAssetBundle {
  final loaded = <String>[];

  @override
  Future<ByteData> load(String key) async {
    loaded.add(key);
    if (key == 'assets/generated/guide-rcb.pdf') {
      return ByteData.sublistView(Uint8List.fromList(List.filled(1501142, 7)));
    }
    throw FlutterError('missing asset $key');
  }
}

class _Pdf implements PdfPages {
  _Pdf({this.fail = false});

  final bool fail;
  final rendered = <int>[];

  @override
  Future<List<Size>> pageSizes(String path) async {
    if (fail) throw PlatformException(code: 'pdf');
    return const [Size(420, 595), Size(420, 595), Size(595, 420)];
  }

  @override
  Future<Uint8List> renderPage(String path, int index, int width) async {
    rendered.add(index);
    return _png;
  }
}

void main() {
  late Directory base;
  final guides = parseGuides(_manifest);

  setUp(() async {
    final root = Directory(p.join(Directory.current.path, '.dart_tool', 'test_tmp'));
    await root.create(recursive: true);
    base = await root.createTemp('guides_');
  });

  tearDown(() async {
    if (await base.exists()) await base.delete(recursive: true);
  });

  group('manifest and texts', () {
    test('guides keep the manifest order; an undated guide has no year', () {
      expect([for (final g in guides) g.id], ['rcb', 'ulotka']);
      expect(guides.first.assetKey, 'assets/generated/guide-rcb.pdf');
      expect(guides.last.year, isNull);
    });

    test('Polish plural of "strona"', () {
      expect(pagesText(1), '1 strona');
      expect(pagesText(2), '2 strony');
      expect(pagesText(5), '5 stron');
      expect(pagesText(12), '12 stron');
      expect(pagesText(22), '22 strony');
      expect(pagesText(54), '54 strony');
      expect(pagesText(112), '112 stron');
      expect(pagesText(172), '172 strony');
    });

    test('size and meta line', () {
      expect(guideSizeText(1501142), '1,5 MB');
      expect(guideSizeText(11503509), '12 MB');
      expect(guideSizeText(20000), '0,1 MB');
      expect(guideMetaText(guides.first), 'RCB, MON, MSWiA · 2025 · 54 strony · 1,5 MB');
      expect(guideMetaText(guides.last), 'Komenda Główna PSP · 2 strony · 0,5 MB');
    });
  });

  test('a guide is copied to disk once and reused', () async {
    final bundle = _Bundle();
    final files = GuideFiles(bundle: bundle, baseDir: () async => base);
    final first = await files.ensureOnDisk(guides.first);
    expect(await first.length(), 1501142);
    expect(p.basename(first.path), 'guide-rcb.pdf');
    await files.ensureOnDisk(guides.first);
    expect(bundle.loaded, hasLength(1));
    expect(File('${first.path}.part').existsSync(), isFalse);
  });

  group('screens', () {
    Future<_Pdf> pump(
      WidgetTester tester, {
      List<Guide>? list,
      String location = '/poradniki',
      bool pdfFails = false,
    }) async {
      tester.view.physicalSize = const Size(360, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final pdf = _Pdf(fail: pdfFails);
      final router = GoRouter(
        initialLocation: location,
        routes: [
          GoRoute(
            path: '/poradniki',
            builder: (_, _) => const GuidesScreen(),
            routes: [
              GoRoute(path: ':id', builder: (_, s) => GuideReaderScreen(guideId: s.pathParameters['id']!)),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            guidesProvider.overrideWith((ref) async => list ?? guides),
            guideFilesProvider.overrideWithValue(GuideFiles(bundle: _Bundle(), baseDir: () async => base)),
            pdfPagesProvider.overrideWithValue(pdf),
          ],
          child: MaterialApp.router(theme: buildBzTheme(), routerConfig: router),
        ),
      );
      // Real file IO (the copy to disk) needs real time.
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      return pdf;
    }

    testWidgets('the list shows every guide with publisher, pages and size', (tester) async {
      await pump(tester);
      expect(find.text(guidesTitle), findsOneWidget);
      expect(find.text('Poradnik bezpieczeństwa'), findsWidgets);
      expect(find.text('RCB, MON, MSWiA · 2025 · 54 strony · 1,5 MB'), findsOneWidget);
      expect(find.text('W obliczu powodzi (ulotka)'), findsOneWidget);
    });

    testWidgets('sources and the OSM attribution stay reachable', (tester) async {
      await pump(tester);
      expect(find.text(guidesSourcesTitle), findsOneWidget);
      expect(find.text(osmAttribution), findsOneWidget);
    });

    testWidgets('a build without guides says so', (tester) async {
      await pump(tester, list: const []);
      expect(find.byKey(const Key('guides-empty')), findsOneWidget);
    });

    testWidgets('tapping a guide opens its pages', (tester) async {
      final pdf = await pump(tester);
      await tester.tap(find.byKey(const Key('guide-rcb')));
      for (var i = 0; i < 20; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
        await tester.pump();
      }
      expect(find.byKey(const Key('guide-pages')), findsOneWidget);
      expect(find.text('1 / 3'), findsOneWidget);
      expect(pdf.rendered, contains(0));
    });

    testWidgets('only pages near the viewport are rendered', (tester) async {
      final pdf = await pump(tester, location: '/poradniki/rcb');
      expect(find.text('1 / 3'), findsOneWidget);
      expect(pdf.rendered.toSet().length, lessThanOrEqualTo(3));
      expect(pdf.rendered.length, pdf.rendered.toSet().length, reason: 'no page rendered twice');
    });

    testWidgets('an unknown guide id shows a calm message', (tester) async {
      await pump(tester, location: '/poradniki/nie-ma');
      expect(find.text(guideMissing), findsOneWidget);
    });

    testWidgets('a phone that cannot render the PDF says so instead of crashing', (tester) async {
      await pump(tester, location: '/poradniki/rcb', pdfFails: true);
      expect(find.text(guideUnreadable), findsOneWidget);
    });

    testWidgets('a guide whose file is not bundled says so', (tester) async {
      await pump(tester, location: '/poradniki/ulotka');
      expect(find.text(guideUnreadable), findsOneWidget);
    });
  });
}
