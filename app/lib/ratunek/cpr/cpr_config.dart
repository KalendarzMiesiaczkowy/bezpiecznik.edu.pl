/// Parameters of the CPR instructor, parsed from the `cpr` panel JSON of the
/// reviewed rescue card (`app/assets/cards/rko.json`). Nothing is defaulted:
/// a panel with missing or out-of-range values yields no config and the UI
/// shows no instructor (medical numbers are never invented).
library;

/// Voice command texts (Polish, from the card).
class CprVoiceTexts {
  const CprVoiceTexts({
    required this.compress,
    required this.breaths,
    required this.aed,
    required this.change,
  });

  final String compress;
  final String breaths;
  final String aed;
  final String change;
}

/// One variant (adult / child / infant).
class CprVariantConfig {
  const CprVariantConfig({
    required this.id,
    required this.label,
    required this.compressions,
    required this.breaths,
    required this.initialBreaths,
    required this.breathPhase,
  });

  final String id;
  final String label;

  /// Compressions per cycle (30 in "30:2").
  final int compressions;

  /// Breaths per cycle (2 in "30:2").
  final int breaths;

  /// Rescue breaths before the first compressions (0 for adults).
  final int initialBreaths;

  /// Length of the breath phase; null = wait for the rescuer's tap.
  final Duration? breathPhase;
}

class CprConfig {
  const CprConfig({
    required this.rateBpm,
    required this.rescuerChange,
    required this.variants,
    required this.voice,
    this.aedCardId,
  });

  final int rateBpm;
  final Duration rescuerChange;
  final List<CprVariantConfig> variants;
  final CprVoiceTexts voice;
  final String? aedCardId;

  /// Time between two compressions.
  Duration get beatInterval => Duration(microseconds: 60000000 ~/ rateBpm);

  CprVariantConfig? variant(String? id) {
    for (final v in variants) {
      if (v.id == id) return v;
    }
    return variants.isEmpty ? null : variants.first;
  }

  /// Parses the raw `cpr` panel map; null when anything required is missing
  /// or `rate_bpm` is outside 100-120.
  static CprConfig? tryParse(Map<String, Object?> raw) {
    try {
      final rate = _int(raw['rate_bpm']);
      final change = _int(raw['rescuer_change_s']);
      final voiceRaw = raw['voice'];
      final variantsRaw = raw['variants'];
      if (rate == null || rate < 100 || rate > 120) return null;
      if (change == null || change <= 0) return null;
      if (voiceRaw is! Map || variantsRaw is! List) return null;
      final voice = CprVoiceTexts(
        compress: _str(voiceRaw['compress']) ?? '',
        breaths: _str(voiceRaw['breaths']) ?? '',
        aed: _str(voiceRaw['aed']) ?? '',
        change: _str(voiceRaw['change']) ?? '',
      );
      if (voice.compress.isEmpty || voice.breaths.isEmpty) return null;
      final variants = <CprVariantConfig>[];
      for (final e in variantsRaw) {
        if (e is! Map) continue;
        final id = _str(e['id']);
        final comp = _int(e['compressions']);
        final br = _int(e['breaths']);
        final init = _int(e['initial_breaths']);
        if (id == null || comp == null || comp <= 0 || br == null || br < 0 || init == null || init < 0) {
          continue;
        }
        final phase = _int(e['breath_phase_s']);
        variants.add(
          CprVariantConfig(
            id: id,
            label: _str(e['label']) ?? id,
            compressions: comp,
            breaths: br,
            initialBreaths: init,
            breathPhase: phase == null || phase <= 0 ? null : Duration(seconds: phase),
          ),
        );
      }
      if (variants.isEmpty) return null;
      return CprConfig(
        rateBpm: rate,
        rescuerChange: Duration(seconds: change),
        variants: variants,
        voice: voice,
        aedCardId: _str(raw['aed_card_id']),
      );
    } on Object {
      return null;
    }
  }

  static int? _int(Object? v) => v is num ? v.toInt() : null;
  static String? _str(Object? v) => v is String && v.trim().isNotEmpty ? v : null;
}
