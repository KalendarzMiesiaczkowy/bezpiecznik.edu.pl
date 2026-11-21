import 'package:bezpiecznik/profil/profile_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const full = HouseholdProfile(
    members: [
      Member(ageGroup: AgeGroup.adult),
      Member(ageGroup: AgeGroup.adult, limitedMobility: true),
      Member(ageGroup: AgeGroup.child, label: 'Ola'),
    ],
    medications: [Medication(name: 'Insulina', needsFridge: true), Medication(name: 'Euthyrox')],
    powerDevices: {'oxygen_concentrator', 'other'},
    powerOtherText: 'Inhalator',
    home: Home(floor: 7, elevator: false),
    iceContacts: [IceContact(name: 'Anna Kowalska', phone: '+48600100200')],
  );

  test('JSON round trip', () {
    final back = HouseholdProfile.fromJson(full.toJson());
    expect(back.toJson(), full.toJson());
    expect(back.members.length, 3);
    expect(back.home.floor, 7);
    expect(back.home.elevator, false);
    expect(back.iceContacts.single.phone, '+48600100200');
  });

  test('empty profile: null fields stay absent, empty context', () {
    final j = HouseholdProfile.empty.toJson();
    expect((j['home'] as Map), isEmpty);
    expect(HouseholdProfile.fromJson(j).isEmpty, isTrue);
    expect(HouseholdProfile.empty.toPromptContext(), '');
  });

  test('prompt context is compact and has no ICE names or phones', () {
    final c = full.toPromptContext();
    expect(c.length, lessThanOrEqualTo(maxPromptContext));
    expect(c, contains('2 dorosły'));
    expect(c, contains('1 dziecko'));
    expect(c, contains('Insulina (lodówka)'));
    expect(c, contains('koncentrator tlenu'));
    expect(c, contains('Inhalator'));
    expect(c, contains('7. piętro'));
    expect(c, contains('brak windy'));
    expect(c, isNot(contains('Anna')));
    expect(c, isNot(contains('Kowalska')));
    expect(c, isNot(contains('600')));
  });

  test('prompt context never exceeds the limit', () {
    final p = HouseholdProfile(
      medications: [for (var i = 0; i < 20; i++) Medication(name: 'Lek numer $i bardzo długa nazwa')],
      home: const Home(floor: 3),
    );
    expect(p.toPromptContext().length, lessThanOrEqualTo(maxPromptContext));
  });

  test('phone normalisation and emergency numbers', () {
    expect(normalizePhone('600 100 200'), '+48600100200');
    expect(normalizePhone('+48 600-100-200'), '+48600100200');
    expect(normalizePhone('+4915112345678'), '+4915112345678');
    expect(normalizePhone('12345'), isNull);
    expect(isEmergencyNumber('112'), isTrue);
    expect(isEmergencyNumber('997'), isTrue);
    expect(isEmergencyNumber('600100200'), isFalse);
  });
}
