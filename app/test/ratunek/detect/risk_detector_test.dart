import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:bezpiecznik/ratunek/detect/risk_detector.dart';

Map<String, dynamic> _json(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

void main() {
  late RiskDetector d;
  setUpAll(() {
    d = RiskDetector(
      risk: _json('assets/phrases/risk.json'),
      cardsIndex: _json('assets/phrases/cards_index.json'),
    );
  });

  void card(String msg, String id, String? variant) {
    test('"$msg" -> $id/$variant', () {
      final r = d.detectCard(msg);
      expect(r, isNotNull, reason: msg);
      expect(r!.cardId, id);
      expect(r.variant, variant);
      expect(d.isRisk(msg), isTrue);
    });
  }

  void none(String msg) {
    test('"$msg" -> no card', () {
      expect(d.detectCard(msg), isNull);
    });
  }

  group('CPR (rko) and variants', () {
    card('dziecko nie oddycha', 'rko', 'child');
    card('niemowle nie oddycha', 'rko', 'infant');
    card('niemowlę nie oddycha', 'rko', 'infant');
    card('noworodek nie oddycha', 'rko', 'infant');
    card('mąż nie oddycha', 'rko', 'adult');
    card('nie oddycha', 'rko', 'adult');
    card('Ktoś nie oddycha!!!', 'rko', 'adult');
    card('NIE ODDYCHA moja córka', 'rko', 'child');
    card('syn nie oddycha', 'rko', 'child');
    card('bobas nie oddycha', 'rko', 'infant');
    card('brak oddechu u dziecka', 'rko', 'child');
    card('przestał oddychać', 'rko', 'adult');
    card('dziecko i niemowle nie oddychaja', 'rko', 'infant');
    card('dzicko nie odycha', 'rko', 'child');
    card('dziecko nie odychaa', 'rko', 'child');
    card('niemowle nie  oddyxha', 'rko', 'infant');
    card('nieprzytomny i nie oddycha', 'rko', 'adult');
    card('dzieciak nieprzytomny nie oddycha', 'rko', 'child');
  });

  group('unconscious -> check breathing', () {
    card('nieprzytomny', 'unconscious', null);
    card('nieprzytomy', 'unconscious', null);
    card('Mój tata jest nieprzytomny', 'unconscious', null);
    card('zemdlal', 'unconscious', null);
    card('nie wiem co robić, ktoś jest nieprzytomny', 'unconscious', null);
    test('nieprzytomny has nextStep check_breathing', () {
      final r = d.detectCard('nieprzytomny')!;
      expect(r.nextStep, 'check_breathing');
      expect(r.matchedPhrase, 'nieprzytomny');
    });
    test('rko beats unconscious and is listed as the only winner', () {
      final r = d.detectCard('nieprzytomny i nie oddycha')!;
      expect(r.cardId, 'rko');
      expect(r.nextStep, isNull);
      expect(r.alsoCardIds, ['unconscious']);
    });
  });

  group('choking', () {
    card('dziecko się zadławiło', 'choking', 'child');
    card('dziecko sie zadlawilo', 'choking', 'child');
    card('niemowlak się dławi', 'choking', 'infant');
    card('dławi się', 'choking', 'adult');
    card('zadlawil sie kawalkiem miesa', 'choking', 'adult');
    card('moja corka sie dusi', 'choking', 'child');
  });

  group('bleeding', () {
    card('krew leci mocno z nogi', 'bleeding', null);
    card('silny krwotok', 'bleeding', null);
    card('krwawi', 'bleeding', null);
    card('KRWAWI Z RĘKI', 'bleeding', null);
    card('mocne krwawienie po wypadku', 'bleeding', null);
    card('krfawi', 'bleeding', null);
  });

  group('negatives and negation', () {
    none('jak przygotować plecak');
    none('dziecko oddycha normalnie');
    none('gdzie jest schron');
    none('czy woda z kranu jest bezpieczna');
    none('nie krwawi już');
    none('on nie jest nieprzytomny');
    none('nie, dziecko oddycha');
    none('dziecko nie jest nieprzytomne');
    none('czas na obiad');
    none('');
    none('   ');
    test('"czas" is not risk (czad is exact-only)', () {
      expect(d.isRisk('czas na obiad'), isFalse);
      expect(d.isRisk('uwaga czad w kuchni'), isTrue);
    });
  });

  group('risk-only phrases', () {
    for (final m in [
      'pożar w kuchni',
      'czuję gaz',
      'pozary lasu',
      'zapach gazu w mieszkaniu',
      'był wypadek na drodze',
      'POWÓDŹ w miescie',
      'wybuch w sąsiedztwie',
    ]) {
      test('"$m" -> risk, no card', () {
        expect(d.isRisk(m), isTrue);
        expect(d.detectCard(m), isNull);
      });
    }
    test('plain question is not risk', () {
      expect(d.isRisk('jak przygotować plecak'), isFalse);
      expect(d.isRisk('gdzie jest schron'), isFalse);
    });
  });

  group('edit distance', () {
    test('transposition and substitution', () {
      expect(editDistanceWithin('oddycha', 'oddyhca', 1), isTrue);
      expect(editDistanceWithin('oddycha', 'odycha', 1), isTrue);
      expect(editDistanceWithin('oddycha', 'odycham', 2), isTrue);
      expect(editDistanceWithin('oddycha', 'odycham', 1), isFalse);
      expect(editDistanceWithin('abc', 'xyz', 2), isFalse);
    });
  });

  test('performance: 1000 detections average < 10 ms', () {
    final msgs = [
      'dziecko nie oddycha',
      'jak przygotować plecak na 72 godziny w mieszkaniu',
      'nieprzytomny',
      'pożar w kuchni, co robić, bardzo się boję i nie wiem gdzie uciekać',
      'krew leci mocno z nogi',
    ];
    final sw = Stopwatch()..start();
    for (var i = 0; i < 1000; i++) {
      final m = msgs[i % msgs.length];
      d.detectCard(m);
      d.isRisk(m);
    }
    sw.stop();
    final avgMs = sw.elapsedMicroseconds / 1000 / 1000;
    // ignore: avoid_print
    print('avg per detection (card + risk): ${avgMs.toStringAsFixed(4)} ms');
    expect(avgMs, lessThan(10));
  });
}
