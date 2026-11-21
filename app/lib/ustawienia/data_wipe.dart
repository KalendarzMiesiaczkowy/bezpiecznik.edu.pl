import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../czat/data/chat_store.dart';
import '../profil/profile_store.dart';
import 'settings_store.dart';

/// "Usuń wszystkie dane": profile + ICE, all chats, settings, onboarding flag
/// (so the router returns to E0). Packs (maps, knowledge base) stay.
/// Throws when anything fails; the caller shows `settings.privacy.deleteFailed`.
Future<void> wipeAllUserData(WidgetRef ref) async {
  final chats = ref.read(chatStoreProvider);
  for (final c in await chats.listChats()) {
    await chats.deleteChat(c.id);
  }
  ref.read(chatRevisionProvider.notifier).bump();
  await ref.read(profileProvider.notifier).clear();
  await ref.read(settingsProvider.notifier).reset();
  // Last: flips the router redirect to /onboarding.
  await ref.read(onboardingDoneProvider.notifier).reset();
}
