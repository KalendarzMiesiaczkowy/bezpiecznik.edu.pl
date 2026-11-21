import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'profile_model.dart';

/// Local store in `profile.sqlite` (table `profile(key, json)`), kept in the
/// private app-support directory. Not encrypted (MVP).
class ProfileStore {
  ProfileStore(this._dir);

  /// In-memory store for tests.
  ProfileStore.inMemory() : _dir = null, _memory = true;

  final Future<Directory> Function()? _dir;
  bool _memory = false;
  Database? _db;

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final Database db;
    if (_memory) {
      db = sqlite3.openInMemory();
    } else {
      final dir = await _dir!();
      await dir.create(recursive: true);
      db = sqlite3.open(p.join(dir.path, 'profile.sqlite'));
    }
    db.execute('CREATE TABLE IF NOT EXISTS profile(key TEXT PRIMARY KEY, json TEXT)');
    return _db = db;
  }

  Future<Map<String, dynamic>?> _get(String key) async {
    final rows = (await _open()).select('SELECT json FROM profile WHERE key = ?', [key]);
    if (rows.isEmpty) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(rows.first['json'] as String) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> _put(String key, Map<String, dynamic> value) async {
    (await _open()).execute('INSERT OR REPLACE INTO profile(key, json) VALUES (?, ?)', [key, jsonEncode(value)]);
  }

  Future<HouseholdProfile?> loadProfile() async {
    final j = await _get('household');
    return j == null ? null : HouseholdProfile.fromJson(j);
  }

  Future<void> saveProfile(HouseholdProfile profile) => _put('household', profile.toJson());

  Future<void> clearProfile() async =>
      (await _open()).execute("DELETE FROM profile WHERE key = 'household'");

  Future<bool> isOnboardingDone() async => (await _get('onboarding'))?['completed'] == true;

  Future<void> setOnboardingDone(bool done) => _put('onboarding', {'completed': done});

  void close() {
    _db?.close();
    _db = null;
  }
}

final profileStoreProvider = Provider<ProfileStore>((ref) {
  final store = ProfileStore(getApplicationSupportDirectory);
  ref.onDispose(store.close);
  return store;
});

class OnboardingDoneNotifier extends AsyncNotifier<bool> {
  @override
  Future<bool> build() => ref.read(profileStoreProvider).isOnboardingDone();

  Future<void> complete() async {
    await ref.read(profileStoreProvider).setOnboardingDone(true);
    state = const AsyncData(true);
  }

  Future<void> reset() async {
    await ref.read(profileStoreProvider).setOnboardingDone(false);
    state = const AsyncData(false);
  }
}

/// Resolves to whether onboarding was completed. While loading (or on a
/// storage error) the router does not redirect.
final onboardingDoneProvider = AsyncNotifierProvider<OnboardingDoneNotifier, bool>(OnboardingDoneNotifier.new);

class ProfileNotifier extends AsyncNotifier<HouseholdProfile> {
  @override
  Future<HouseholdProfile> build() async =>
      await ref.read(profileStoreProvider).loadProfile() ?? HouseholdProfile.empty;

  Future<void> save(HouseholdProfile profile) async {
    await ref.read(profileStoreProvider).saveProfile(profile);
    state = AsyncData(profile);
  }

  Future<void> clear() async {
    await ref.read(profileStoreProvider).clearProfile();
    state = const AsyncData(HouseholdProfile.empty);
  }
}

final profileProvider = AsyncNotifierProvider<ProfileNotifier, HouseholdProfile>(ProfileNotifier.new);
