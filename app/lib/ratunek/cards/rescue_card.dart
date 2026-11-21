import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle;

/// Rescue card model and loader.
///
/// Contract: `bezpiecznik/04-dane/kontrakty-tresci.md#karta-ratunkowa`.
/// Cards live in `assets/cards/{id}.json`, source records in
/// `assets/cards/sources.json`. Detection of which card to open is done by
/// `lib/ratunek/detect` from `assets/phrases/cards_index.json` (see
/// `assets/cards/README.md`).

/// Ids of the shipped cards, in contract priority order. An [AssetBundle] has
/// no directory listing, so the loader needs this list.
const List<String> rescueCardIds = <String>[
  'rko',
  'choking',
  'bleeding',
  'unconscious',
];

final RegExp _idPattern = RegExp(r'^[a-z_]+$');

/// Thrown when a card or source file does not match the contract.
class RescueCardFormatException extends FormatException {
  const RescueCardFormatException(super.message, [super.source]);
}

T _req<T>(Map<String, dynamic> json, String key, String where) {
  final v = json[key];
  if (v is! T) {
    throw RescueCardFormatException(
      '$where: field "$key" missing or not ${T.toString()}',
    );
  }
  return v;
}

String _reqText(Map<String, dynamic> json, String key, String where) {
  final v = _req<String>(json, key, where);
  if (v.trim().isEmpty) {
    throw RescueCardFormatException('$where: field "$key" is empty');
  }
  return v;
}

Map<String, dynamic> _asMap(Object? v, String where) {
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return v.cast<String, dynamic>();
  throw RescueCardFormatException('$where: expected an object');
}

List<Map<String, dynamic>> _mapList(Object? v, String where) {
  if (v is! List) throw RescueCardFormatException('$where: expected a list');
  return <Map<String, dynamic>>[
    for (var i = 0; i < v.length; i++) _asMap(v[i], '$where[$i]'),
  ];
}

/// Source record (`assets/cards/sources.json`), see "Rekord źródła" in
/// `szablony-czatu.md`. `original` is a verbatim excerpt of the cited page
/// (at most 60 words) for the `quote` template.
class SourceRecord {
  const SourceRecord({
    required this.sourceId,
    required this.docId,
    required this.docTitle,
    required this.docShort,
    required this.publisher,
    required this.issued,
    required this.pageLabel,
    required this.pdfPage,
    required this.pdfFile,
    required this.original,
    this.rects = const <List<double>>[],
  });

  factory SourceRecord.fromJson(Map<String, dynamic> json) {
    const where = 'source';
    final id = _reqText(json, 'source_id', where);
    final w = 'source "$id"';
    return SourceRecord(
      sourceId: id,
      docId: _reqText(json, 'doc_id', w),
      docTitle: _reqText(json, 'doc_title', w),
      docShort: _reqText(json, 'doc_short', w),
      publisher: _reqText(json, 'publisher', w),
      issued: _reqText(json, 'issued', w),
      pageLabel: _reqText(json, 'page_label', w),
      pdfPage: _req<int>(json, 'pdf_page', w),
      pdfFile: _reqText(json, 'pdf_file', w),
      original: _reqText(json, 'original', w),
      rects: <List<double>>[
        for (final r in (json['rects'] as List? ?? const <Object?>[]))
          <double>[for (final n in (r as List)) (n as num).toDouble()],
      ],
    );
  }

  final String sourceId;
  final String docId;
  final String docTitle;
  final String docShort;
  final String publisher;
  final String issued;
  final String pageLabel;
  final int pdfPage;
  final String pdfFile;
  final String original;
  final List<List<double>> rects;

  /// Text of the source chip: `▸ {doc_short}, s. {page_label}`.
  String get chipLabel => '▸ $docShort, s. $pageLabel';
}

/// Link under a step that opens another card with the same variant.
class CardLink {
  const CardLink({required this.label, required this.cardId});

  factory CardLink.fromJson(Map<String, dynamic> json) => CardLink(
    label: _reqText(json, 'label', 'card_link'),
    cardId: _reqText(json, 'card_id', 'card_link'),
  );

  final String label;
  final String cardId;
}

class StepItem {
  const StepItem({required this.text, required this.sourceId, this.cardLink});

  factory StepItem.fromJson(Map<String, dynamic> json, String where) {
    final link = json['card_link'];
    return StepItem(
      text: _reqText(json, 'text', where),
      sourceId: _reqText(json, 'source_id', where),
      cardLink: link == null ? null : CardLink.fromJson(_asMap(link, where)),
    );
  }

  final String text;
  final String sourceId;
  final CardLink? cardLink;
}

class StepVariant {
  const StepVariant({
    required this.id,
    required this.label,
    required this.items,
  });

  final String id;
  final String label;
  final List<StepItem> items;
}

/// A panel of a card. `call` is always first (see [RescueCard.fromJson]).
sealed class RescuePanel {
  const RescuePanel();

  String get type;
}

class CallPanel extends RescuePanel {
  const CallPanel();

  @override
  String get type => 'call';
}

class StepsPanel extends RescuePanel {
  const StepsPanel({
    required this.title,
    required this.readAloud,
    this.items = const <StepItem>[],
    this.variants = const <StepVariant>[],
  });

  @override
  String get type => 'steps';

  final String title;
  final bool readAloud;

  /// Used when [variants] is empty.
  final List<StepItem> items;
  final List<StepVariant> variants;

  List<String> get variantIds => <String>[for (final v in variants) v.id];

  /// Items for [variant]; falls back to the first variant (or to [items]
  /// when the panel has no variants).
  List<StepItem> itemsFor(String? variant) {
    if (variants.isEmpty) return items;
    for (final v in variants) {
      if (v.id == variant) return v.items;
    }
    return variants.first.items;
  }
}

class CprVariant {
  const CprVariant({
    required this.id,
    required this.label,
    required this.sourceId,
    required this.compressions,
    required this.compressionsPblsTrained,
    required this.breaths,
    required this.initialBreaths,
    required this.breathPhaseS,
  });

  final String id;
  final String label;
  final String sourceId;

  /// Compressions per cycle for a layperson (30 in the sources).
  final int? compressions;

  /// Child/infant ratio for rescuers with a PBLS course (15 in the sources).
  final int? compressionsPblsTrained;
  final int? breaths;
  final int? initialBreaths;

  /// Longest allowed pause for breaths, seconds. `null` = the sources do not
  /// give it for this variant.
  final int? breathPhaseS;
}

class CprPanel extends RescuePanel {
  const CprPanel({
    required this.sourceId,
    required this.rateBpm,
    required this.rateBpmMin,
    required this.rateBpmMax,
    required this.rescuerChangeS,
    required this.variants,
    required this.voice,
    required this.aedCardId,
  });

  @override
  String get type => 'cpr';

  final String sourceId;

  /// Single metronome tempo. `null` when the sources give only a range.
  final int? rateBpm;
  final int? rateBpmMin;
  final int? rateBpmMax;

  /// `null` = no source for the rescuer-change interval; the instructor
  /// must not remind about it until a human fills it in.
  final int? rescuerChangeS;
  final List<CprVariant> variants;
  final Map<String, String?> voice;
  final String? aedCardId;

  /// Metronome tempo for the instructor: [rateBpm] if given, otherwise the
  /// midpoint of the sourced range (a derived value, 110 for 100-120).
  int? get effectiveRateBpm {
    if (rateBpm != null) return rateBpm;
    if (rateBpmMin != null && rateBpmMax != null) {
      return (rateBpmMin! + rateBpmMax!) ~/ 2;
    }
    return null;
  }

  CprVariant? variant(String? id) {
    for (final v in variants) {
      if (v.id == id) return v;
    }
    return variants.isEmpty ? null : variants.first;
  }
}

/// Panels the card shell does not render itself (`bullets`, `animation`,
/// `map`, `signal`, `quote`); kept as raw JSON for the renderer.
class RawPanel extends RescuePanel {
  const RawPanel(this.type, this.json);

  @override
  final String type;
  final Map<String, dynamic> json;
}

class RescueCard {
  const RescueCard({
    required this.version,
    required this.id,
    required this.name,
    required this.priority,
    required this.phrases,
    required this.variantWords,
    required this.panels,
    required this.sourceIds,
    required this.verify,
    this.verifyNote,
  });

  /// Parses a card per the contract. `call` is inserted first when missing
  /// and never duplicated. A missing `verify` key counts as `true` (unverified
  /// is the safe default).
  factory RescueCard.fromJson(Map<String, dynamic> json) {
    final id = _reqText(json, 'id', 'card');
    final where = 'card "$id"';
    if (!_idPattern.hasMatch(id)) {
      throw RescueCardFormatException('$where: id must match ^[a-z_]+\$');
    }
    final name = _reqText(json, 'name', where);
    if (name.length > 30) {
      throw RescueCardFormatException('$where: name longer than 30');
    }
    final priority = _req<int>(json, 'priority', where);
    if (priority < 1) {
      throw RescueCardFormatException('$where: priority must be >= 1');
    }
    final phrases = <String>[
      for (final p in _req<List<dynamic>>(json, 'phrases', where)) p as String,
    ];
    if (phrases.isEmpty) {
      throw RescueCardFormatException('$where: phrases is empty');
    }
    final vw = <String, List<String>>{};
    final rawVw = json['variant_words'];
    if (rawVw != null) {
      _asMap(rawVw, '$where variant_words').forEach((k, v) {
        vw[k] = <String>[for (final w in (v as List)) w as String];
      });
    }
    final rawPanels = _mapList(json['panels'], '$where panels');
    if (rawPanels.isEmpty) {
      throw RescueCardFormatException('$where: panels is empty');
    }
    final panels = <RescuePanel>[const CallPanel()];
    for (var i = 0; i < rawPanels.length; i++) {
      final p = rawPanels[i];
      final type = _reqText(p, 'type', '$where panels[$i]');
      switch (type) {
        case 'call':
          break; // already first
        case 'steps':
          panels.add(_parseSteps(p, '$where panels[$i]'));
        case 'cpr':
          panels.add(_parseCpr(p, '$where panels[$i]'));
        default:
          panels.add(RawPanel(type, p));
      }
    }
    final sourceIds = <String>[
      for (final s in _req<List<dynamic>>(json, 'source_ids', where))
        s as String,
    ];
    if (sourceIds.isEmpty) {
      throw RescueCardFormatException('$where: source_ids is empty');
    }
    final card = RescueCard(
      version: _req<int>(json, 'version', where),
      id: id,
      name: name,
      priority: priority,
      phrases: phrases,
      variantWords: vw,
      panels: panels,
      sourceIds: sourceIds,
      verify: json['verify'] != false,
      verifyNote: json['verify_note'] as String?,
    );
    final cited = card.citedSourceIds;
    for (final s in cited) {
      if (!sourceIds.contains(s)) {
        throw RescueCardFormatException(
          '$where: panel cites "$s" which is not in source_ids',
        );
      }
    }
    return card;
  }

  final int version;
  final String id;
  final String name;
  final int priority;
  final List<String> phrases;
  final Map<String, List<String>> variantWords;
  final List<RescuePanel> panels;
  final List<String> sourceIds;

  /// `verify: true`: text not yet signed off by a human; the UI shows the
  /// "Do weryfikacji" badge ([isVerify]).
  final bool verify;
  final String? verifyNote;

  bool get isVerify => verify;

  /// Variant ids of the card in order (first = default). Empty when the card
  /// has no age variants.
  List<String> get variantIds {
    for (final p in panels) {
      if (p is StepsPanel && p.variants.isNotEmpty) return p.variantIds;
    }
    return const <String>[];
  }

  /// [requested] when the card has it, otherwise the default (first) variant,
  /// or `null` for a card without variants.
  String? selectVariant(String? requested) {
    final ids = variantIds;
    if (ids.isEmpty) return null;
    return ids.contains(requested) ? requested : ids.first;
  }

  /// Every `source_id` used in the panels (steps, cpr, cpr variants).
  Set<String> get citedSourceIds {
    final out = <String>{};
    for (final p in panels) {
      if (p is StepsPanel) {
        for (final i in p.items) {
          out.add(i.sourceId);
        }
        for (final v in p.variants) {
          for (final i in v.items) {
            out.add(i.sourceId);
          }
        }
      } else if (p is CprPanel) {
        out.add(p.sourceId);
        for (final v in p.variants) {
          out.add(v.sourceId);
        }
      }
    }
    return out;
  }

  /// All step items of the card for [variant] (all steps panels in order).
  List<StepItem> stepsFor(String? variant) => <StepItem>[
    for (final p in panels)
      if (p is StepsPanel) ...p.itemsFor(variant),
  ];

  CprPanel? get cpr {
    for (final p in panels) {
      if (p is CprPanel) return p;
    }
    return null;
  }
}

StepsPanel _parseSteps(Map<String, dynamic> p, String where) {
  final title = _reqText(p, 'title', where);
  if (title.length > 30) {
    throw RescueCardFormatException('$where: title longer than 30');
  }
  List<StepItem> items(Object? raw, String w) {
    final list = _mapList(raw, w);
    if (list.isEmpty) throw RescueCardFormatException('$w: no items');
    return <StepItem>[
      for (var i = 0; i < list.length; i++)
        StepItem.fromJson(list[i], '$w[$i]'),
    ];
  }

  final rawVariants = p['variants'];
  if (rawVariants != null) {
    final vs = _mapList(rawVariants, '$where variants');
    if (vs.length > 3) {
      throw RescueCardFormatException('$where: more than 3 variants');
    }
    return StepsPanel(
      title: title,
      readAloud: p['read_aloud'] == true,
      variants: <StepVariant>[
        for (var i = 0; i < vs.length; i++)
          StepVariant(
            id: _reqText(vs[i], 'id', '$where variants[$i]'),
            label: _reqText(vs[i], 'label', '$where variants[$i]'),
            items: items(vs[i]['items'], '$where variants[$i] items'),
          ),
      ],
    );
  }
  return StepsPanel(
    title: title,
    readAloud: p['read_aloud'] == true,
    items: items(p['items'], '$where items'),
  );
}

CprPanel _parseCpr(Map<String, dynamic> p, String where) {
  int? n(Map<String, dynamic> m, String k) {
    final v = m[k];
    if (v == null) return null;
    if (v is! int) {
      throw RescueCardFormatException('$where: "$k" must be int or null');
    }
    return v;
  }

  final voice = <String, String?>{};
  final rawVoice = p['voice'];
  if (rawVoice != null) {
    _asMap(rawVoice, '$where voice').forEach((k, v) => voice[k] = v as String?);
  }
  final vs = _mapList(p['variants'], '$where variants');
  return CprPanel(
    sourceId: _reqText(p, 'source_id', where),
    rateBpm: n(p, 'rate_bpm'),
    rateBpmMin: n(p, 'rate_bpm_min'),
    rateBpmMax: n(p, 'rate_bpm_max'),
    rescuerChangeS: n(p, 'rescuer_change_s'),
    variants: <CprVariant>[
      for (var i = 0; i < vs.length; i++)
        CprVariant(
          id: _reqText(vs[i], 'id', '$where variants[$i]'),
          label: _reqText(vs[i], 'label', '$where variants[$i]'),
          sourceId: _reqText(vs[i], 'source_id', '$where variants[$i]'),
          compressions: n(vs[i], 'compressions'),
          compressionsPblsTrained: n(vs[i], 'compressions_pbls_trained'),
          breaths: n(vs[i], 'breaths'),
          initialBreaths: n(vs[i], 'initial_breaths'),
          breathPhaseS: n(vs[i], 'breath_phase_s'),
        ),
    ],
    voice: voice,
    aedCardId: p['aed_card_id'] as String?,
  );
}

/// Parsed cards plus their source records.
class RescueCardRepository {
  /// Builds the repository from already parsed JSON maps (used by tests).
  /// Throws [RescueCardFormatException] when a card cites an unknown source
  /// or a `card_link` points to a card that is not in [cards].
  RescueCardRepository({
    required List<Map<String, dynamic>> cards,
    required Map<String, dynamic> sources,
  }) : _cards = <String, RescueCard>{},
       _sources = <String, SourceRecord>{} {
    for (final s in _mapList(sources['sources'], 'sources.json sources')) {
      final rec = SourceRecord.fromJson(s);
      _sources[rec.sourceId] = rec;
    }
    for (final c in cards) {
      final card = RescueCard.fromJson(c);
      _cards[card.id] = card;
    }
    for (final card in _cards.values) {
      for (final s in card.sourceIds) {
        if (!_sources.containsKey(s)) {
          throw RescueCardFormatException(
            'card "${card.id}": unknown source_id "$s"',
          );
        }
      }
      for (final p in card.panels) {
        if (p is StepsPanel) {
          for (final i in <StepItem>[
            ...p.items,
            for (final v in p.variants) ...v.items,
          ]) {
            final link = i.cardLink;
            if (link != null && !_cards.containsKey(link.cardId)) {
              throw RescueCardFormatException(
                'card "${card.id}": card_link to unknown card "${link.cardId}"',
              );
            }
          }
        }
      }
    }
  }

  /// Loads `{dir}/{id}.json` for every id in [ids] and `{dir}/sources.json`.
  static Future<RescueCardRepository> load(
    AssetBundle bundle, {
    String dir = 'assets/cards',
    List<String> ids = rescueCardIds,
  }) async {
    Future<Map<String, dynamic>> read(String path) async =>
        _asMap(jsonDecode(await bundle.loadString(path)), path);
    final cards = <Map<String, dynamic>>[
      for (final id in ids) await read('$dir/$id.json'),
    ];
    return RescueCardRepository(
      cards: cards,
      sources: await read('$dir/sources.json'),
    );
  }

  final Map<String, RescueCard> _cards;
  final Map<String, SourceRecord> _sources;

  /// Cards sorted by priority (1 = highest).
  List<RescueCard> get cards =>
      _cards.values.toList()..sort((a, b) => a.priority.compareTo(b.priority));

  RescueCard? card(String id) => _cards[id];

  SourceRecord? source(String sourceId) => _sources[sourceId];

  Iterable<SourceRecord> get sources => _sources.values;

  /// Source records cited by [card], in the order of `source_ids`.
  List<SourceRecord> sourcesFor(RescueCard card) => <SourceRecord>[
    for (final s in card.sourceIds) _sources[s]!,
  ];
}
