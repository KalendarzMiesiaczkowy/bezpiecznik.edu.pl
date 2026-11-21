import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

/// Text size steps (spec: `settings.textScale` = 1.0 / 1.25 / 1.5).
enum TextSizeOption {
  standard('Standardowy', 1.0),
  large('Duży', 1.25),
  extraLarge('Bardzo duży', 1.5);

  const TextSizeOption(this.label, this.factor);
  final String label;
  final double factor;
}

/// All MVP settings. Defaults: standard text, AI on (always on by default),
/// voice on.
class AppSettings {
  const AppSettings({
    this.textSize = TextSizeOption.standard,
    this.noAiMode = false,
    this.voiceEnabled = true,
  });

  final TextSizeOption textSize;

  /// "Tryb bez AI": chat shows only source quotes. Off by default.
  final bool noAiMode;
  final bool voiceEnabled;

  AppSettings copyWith({TextSizeOption? textSize, bool? noAiMode, bool? voiceEnabled}) => AppSettings(
    textSize: textSize ?? this.textSize,
    noAiMode: noAiMode ?? this.noAiMode,
    voiceEnabled: voiceEnabled ?? this.voiceEnabled,
  );
}

/// Key-value store in `settings.sqlite` (table `settings(key, value)`), keys
/// `settings.*`. Not encrypted (MVP).
class SettingsStore {
  SettingsStore(this._dir) : _memory = false;

  /// In-memory store for tests.
  SettingsStore.inMemory() : _dir = null, _memory = true;

  final Future<Directory> Function()? _dir;
  final bool _memory;
  Database? _db;

  Future<Database> _open() async {
    if (_db != null) return _db!;
    final Database db;
    if (_memory) {
      db = sqlite3.openInMemory();
    } else {
      final dir = await _dir!();
      await dir.create(recursive: true);
      db = sqlite3.open(p.join(dir.path, 'settings.sqlite'));
    }
    db.execute('CREATE TABLE IF NOT EXISTS settings(key TEXT PRIMARY KEY, value TEXT NOT NULL)');
    return _db = db;
  }

  Future<AppSettings> load() async {
    final rows = (await _open()).select('SELECT key, value FROM settings');
    final m = {for (final r in rows) r['key'] as String: r['value'] as String};
    return AppSettings(
      textSize: TextSizeOption.values.firstWhere(
        (o) => o.name == m['settings.textScale'],
        orElse: () => TextSizeOption.standard,
      ),
      noAiMode: m['settings.noAiMode'] == 'true',
      voiceEnabled: m['settings.voiceEnabled'] != 'false',
    );
  }

  Future<void> save(AppSettings s) async {
    final db = await _open();
    void put(String k, String v) => db.execute('INSERT OR REPLACE INTO settings(key, value) VALUES (?, ?)', [k, v]);
    put('settings.textScale', s.textSize.name);
    put('settings.noAiMode', '${s.noAiMode}');
    put('settings.voiceEnabled', '${s.voiceEnabled}');
  }

  Future<void> clear() async => (await _open()).execute('DELETE FROM settings');

  void close() {
    _db?.close();
    _db = null;
  }
}

final settingsStoreProvider = Provider<SettingsStore>((ref) {
  final store = SettingsStore(getApplicationSupportDirectory);
  ref.onDispose(store.close);
  return store;
});

class SettingsNotifier extends AsyncNotifier<AppSettings> {
  @override
  Future<AppSettings> build() => ref.read(settingsStoreProvider).load();

  Future<void> _update(AppSettings next) async {
    await ref.read(settingsStoreProvider).save(next);
    state = AsyncData(next);
  }

  AppSettings get _current => state.value ?? const AppSettings();

  Future<void> setTextSize(TextSizeOption o) => _update(_current.copyWith(textSize: o));
  Future<void> setNoAiMode(bool v) => _update(_current.copyWith(noAiMode: v));
  Future<void> setVoiceEnabled(bool v) => _update(_current.copyWith(voiceEnabled: v));

  /// Wipes stored settings and returns to defaults.
  Future<void> reset() async {
    await ref.read(settingsStoreProvider).clear();
    state = const AsyncData(AppSettings());
  }
}

final settingsProvider = AsyncNotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

/// Text scale factor applied app-wide (defaults to 1.0 while loading).
final textScaleFactorProvider = Provider<double>(
  (ref) => ref.watch(settingsProvider).value?.textSize.factor ?? 1.0,
);

/// True when the user turned "Tryb bez AI" on. Chat wiring: when true the LLM
/// mode must be [LlmMode.off] (see report WIRING).
final noAiModeProvider = Provider<bool>((ref) => ref.watch(settingsProvider).value?.noAiMode ?? false);

/// Whether spoken instructions are enabled (cards, CPR instructor).
final voiceEnabledProvider = Provider<bool>((ref) => ref.watch(settingsProvider).value?.voiceEnabled ?? true);
