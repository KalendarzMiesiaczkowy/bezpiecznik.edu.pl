import 'dart:io';

import 'package:bezpiecznik/czat/templates/panel_model.dart';
import 'package:bezpiecznik/czat/ui/answer_service.dart';
import 'package:bezpiecznik/ratunek/ui/rescue_answer.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reads assets straight from `assets/` on the host.
class _FileBundle extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async {
    final bytes = await File(key).readAsBytes();
    return ByteData.sublistView(bytes);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late RescueAnswerService service;

  setUpAll(() async {
    service = await RescueAnswerService.load(_FileBundle());
  });

  test(
    '"dziecko nie oddycha" -> rko card, child variant, call first',
    () async {
      final a = (await service.tryAnswer('dziecko nie oddycha'))!;
      expect(a.origin, AnswerOrigin.rescueCard);
      expect(a.cardId, 'rko');
      expect(a.selectedVariant, 'child');
      expect(a.verify, isTrue);
      expect(a.panels.first, isA<CallPanel>());
      expect(a.panels.whereType<CallPanel>(), hasLength(1));
      expect(a.panels.whereType<StepsPanel>(), hasLength(1));
      expect(a.panels.whereType<CprPanel>(), hasLength(1));
      final steps = a.panels.whereType<StepsPanel>().single;
      expect(
        steps.variantOptions.map((o) => o.id),
        containsAll(['adult', 'child']),
      );
      expect(steps.itemsFor('child'), isNotEmpty);
      expect(a.panels.whereType<UnknownPanel>(), isEmpty);
    },
  );

  test('every cited source resolves to a record', () async {
    final a = (await service.tryAnswer('dziecko nie oddycha'))!;
    final cited = <String?>{
      for (final s in a.panels.whereType<StepsPanel>())
        for (final v in s.variants) ...v.items.map((i) => i.sourceId),
      a.panels.whereType<CprPanel>().single.sourceId,
    };
    expect(cited, isNotEmpty);
    for (final id in cited) {
      final src = a.source(id);
      expect(src, isNotNull, reason: 'missing source $id');
      expect(src!.docShort, isNotEmpty);
      expect(src.pageLabel, isNotEmpty);
    }
  });

  test('cpr panel keeps the instructor parameters', () async {
    final a = (await service.tryAnswer('dziecko nie oddycha'))!;
    final cpr = a.panels.whereType<CprPanel>().single;
    expect(cpr.raw['rate_bpm'], isA<int>());
    expect(cpr.options.map((o) => o.id), contains('child'));
    expect(
      (cpr.raw['variants'] as List).first,
      containsPair('compressions', isA<int>()),
    );
  });

  test(
    'adult phrase selects the first variant; round-trips through JSON',
    () async {
      final a = (await service.tryAnswer('mężczyzna nie oddycha'))!;
      expect(a.selectedVariant, 'adult');
      final again = AssistantAnswer.fromJson(a.toJson());
      expect(again.panels.length, a.panels.length);
      expect(again.verify, isTrue);
    },
  );

  test(
    '"nieprzytomny" -> the card the detector names, with call first',
    () async {
      final hit = service.detector.detectCard('nieprzytomny');
      expect(hit, isNotNull);
      final a = (await service.tryAnswer('nieprzytomny'))!;
      expect(a.cardId, hit!.cardId);
      expect(a.cardId, 'unconscious');
      expect(a.panels.first, isA<CallPanel>());
    },
  );

  test('"nieprzytomny i nie oddycha" wins as rko', () async {
    expect(
      (await service.tryAnswer('nieprzytomny i nie oddycha'))!.cardId,
      'rko',
    );
  });

  test('non-risk question -> null', () async {
    expect(
      await service.tryAnswer('Jak przechować insulinę bez prądu?'),
      isNull,
    );
    expect(await service.tryAnswer(''), isNull);
  });

  test('withCallFirst prepends one call panel only', () {
    final base = fakeStepsAnswer();
    final once = RescueAnswerService.withCallFirst(base);
    expect(once.panels.first, isA<CallPanel>());
    expect(
      RescueAnswerService.withCallFirst(once).panels.length,
      once.panels.length,
    );
    expect(service.isRisk('pożar w kuchni'), isTrue);
    expect(service.isRisk('dzień dobry'), isFalse);
  });

  test(
    'RescueFirstAnswerService: card without fallback, else fallback',
    () async {
      final fake = FakeAnswerService();
      final s = RescueFirstAnswerService(
        rescue: () async => service,
        fallback: fake,
      );
      const ctx = ChatContext(chatId: 'c');
      final card = await s.answer('dziecko nie oddycha', ctx).toList();
      expect(card.single, isA<AnswerReady>());
      expect(fake.questions, isEmpty);
      final other = await s.answer('Jak przechować insulinę?', ctx).toList();
      expect(other.last, isA<AnswerReady>());
      expect(fake.questions, ['Jak przechować insulinę?']);
    },
  );

  test('timing: detection and mapping under 50 ms after load', () async {
    await service.tryAnswer('dziecko nie oddycha'); // warm up JIT
    final sw = Stopwatch()..start();
    await service.tryAnswer('dziecko nie oddycha');
    sw.stop();
    // ignore: avoid_print
    print('tryAnswer: ${sw.elapsedMicroseconds} us');
    expect(sw.elapsedMilliseconds, lessThan(50));
  });
}
