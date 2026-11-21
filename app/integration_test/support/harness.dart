import 'package:bezpiecznik/profil/profile_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory profile store with onboarding already completed, so E2E tests
/// that are not about onboarding start on the chat screen (no async redirect).
Future<ProfileStore> onboardedProfileStore() async {
  final store = ProfileStore.inMemory();
  await store.setOnboardingDone(true);
  return store;
}

/// Pumps frames until [finder] matches or [timeout] passes. Use instead of
/// `pumpAndSettle` while spinners or the thinking animation run.
Future<bool> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
  Duration step = const Duration(milliseconds: 100),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    await tester.pump(step);
    if (finder.evaluate().isNotEmpty) return true;
  }
  return finder.evaluate().isNotEmpty;
}
