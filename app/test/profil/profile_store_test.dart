import 'dart:io';

import 'package:bezpiecznik/profil/profile_model.dart';
import 'package:bezpiecznik/profil/profile_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory dir;
  setUp(() async {
    final base = Directory('.dart_tool/test_tmp');
    await base.create(recursive: true);
    dir = await base.createTemp('profile_');
  });
  tearDown(() => dir.delete(recursive: true));

  test('profile and onboarding flag persist across store instances', () async {
    final a = ProfileStore(() async => dir);
    expect(await a.loadProfile(), isNull);
    expect(await a.isOnboardingDone(), isFalse);
    await a.saveProfile(const HouseholdProfile(medications: [Medication(name: 'Insulina')]));
    await a.setOnboardingDone(true);
    a.close();

    final b = ProfileStore(() async => dir);
    expect((await b.loadProfile())!.medications.single.name, 'Insulina');
    expect(await b.isOnboardingDone(), isTrue);
    expect(File('${dir.path}/profile.sqlite').existsSync(), isTrue);
    await b.clearProfile();
    expect(await b.loadProfile(), isNull);
    b.close();
  });

  test('providers load, save and clear', () async {
    final store = ProfileStore.inMemory();
    final c = ProviderContainer(overrides: [profileStoreProvider.overrideWithValue(store)]);
    addTearDown(c.dispose);
    expect(await c.read(onboardingDoneProvider.future), isFalse);
    expect((await c.read(profileProvider.future)).isEmpty, isTrue);
    await c.read(profileProvider.notifier).save(const HouseholdProfile(home: Home(floor: 2)));
    expect(c.read(profileProvider).value!.home.floor, 2);
    expect((await store.loadProfile())!.home.floor, 2);
    await c.read(onboardingDoneProvider.notifier).complete();
    expect(await store.isOnboardingDone(), isTrue);
    await c.read(profileProvider.notifier).clear();
    expect(c.read(profileProvider).value!.isEmpty, isTrue);
  });
}
