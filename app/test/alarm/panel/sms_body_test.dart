import 'package:bezpiecznik/alarm/panel/sms_body.dart';
import 'package:bezpiecznik/profil/profile_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final profile = HouseholdProfile(
    members: const [
      Member(ageGroup: AgeGroup.infant, label: 'Zosia'),
      Member(ageGroup: AgeGroup.senior, label: 'Babcia Ela'),
    ],
    medications: const [Medication(name: 'insulina', needsFridge: true)],
    home: const Home(floor: 7, elevator: false),
    iceContacts: const [IceContact(name: 'Mama', phone: '+48600100200')],
  );
  final t = DateTime(2026, 11, 21, 14, 32);

  test('full example matches the spec template', () {
    final body = buildSosSms(
      SosSmsInput(
        lat: 52.22977,
        lon: 21.01178,
        accuracyM: 12.4,
        positionTime: t,
        situation: 'RKO',
        address: 'ul. Marszałkowska 10, Warszawa',
        profile: profileSmsFacts(profile),
      ),
    );
    expect(
      body,
      'SOS. Potrzebuje pomocy. Sytuacja: RKO.\n'
      'Pozycja: 52.22977, 21.01178 (dokladnosc 12 m, 14:32)\n'
      'https://www.openstreetmap.org/?mlat=52.22977&mlon=21.01178#map=17/52.22977/21.01178\n'
      'Adres (ok.): ul. Marszalkowska 10, Warszawa\n'
      'Dom: niemowle, senior. Leki: insulina (lodowka). Pietro 7, bez windy.\n'
      'Jesli nie odpowiadam, zadzwon pod 112 i podaj te dane.',
    );
  });

  test('without profile: no profile line, no names, no phones', () {
    final body = buildSosSms(SosSmsInput(lat: 1, lon: 2, accuracyM: 5, positionTime: t));
    expect(body, contains('openstreetmap.org/?mlat=1.00000&mlon=2.00000'));
    expect(body, isNot(contains('Dom:')));
    expect(body, isNot(contains('Leki')));
    expect(body, isNot(contains('Zosia')));
    expect(body, isNot(contains('+48')));
    expect(body, isNot(contains('Sytuacja')));
  });

  test('profile facts: never names or phone numbers; ASCII only', () {
    final line = profileSmsFacts(profile).smsLine;
    expect(line, isNot(contains('Zosia')));
    expect(line, isNot(contains('Ela')));
    expect(line, isNot(contains('600')));
    expect(RegExp(r'^[\x00-\x7F]*$').hasMatch(line), isTrue);
    expect(profileSmsFacts(profile).preview, 'niemowlę, senior, insulina (lodówka), 7. piętro bez windy');
    expect(profileSmsFacts(HouseholdProfile.empty).isEmpty, isTrue);
  });

  test('no position: unknown line and no link', () {
    final body = buildSosSms(const SosSmsInput());
    expect(body, contains('Pozycja: nieznana (brak GPS).'));
    expect(body, isNot(contains('http')));
  });

  test('stale position uses the last-position wording', () {
    final body = buildSosSms(SosSmsInput(lat: 1, lon: 2, positionTime: t, fresh: false));
    expect(body, contains('Ostatnia pozycja: 1.00000, 2.00000 (14:32, teraz brak GPS)'));
  });

  test('body is ASCII, situation clipped to 80', () {
    final body = buildSosSms(SosSmsInput(situation: clipSituation('Źle się czuję ' * 20)));
    expect(RegExp(r'^[\x00-\x7F]*$').hasMatch(body), isTrue);
    expect(clipSituation('a' * 200).length, 80);
  });

  test('recipients never include 112 and sms uri encodes the body', () {
    final r = smsRecipients(const [
      IceContact(name: 'A', phone: '+48600100200'),
      IceContact(name: 'B', phone: '112'),
      IceContact(name: 'C', phone: 'abc'),
    ]);
    expect(r, ['+48600100200']);
    final uri = smsUri(['+48600100200', '+48600100201'], 'SOS a\nb');
    expect(uri.toString(), 'sms:+48600100200,+48600100201?body=SOS%20a%0Ab');
    expect(smsUri([], 'x').toString(), 'sms:?body=x');
    expect(telUri('112').toString(), 'tel:112');
  });

  test('DMS format', () {
    expect(formatDms(52.22977, 21.01178), '52°13\'47.2"N 21°00\'42.4"E');
  });
}
