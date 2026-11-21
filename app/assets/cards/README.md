# Rescue cards

`rko.json`, `choking.json`, `bleeding.json`, `unconscious.json` follow
`bezpiecznik/04-dane/kontrakty-tresci.md#karta-ratunkowa`. `sources.json` holds
the source records the cards cite. Loader: `lib/ratunek/cards/rescue_card.dart`
(`RescueCardRepository`). Add `- assets/cards/` to `pubspec.yaml` assets.

## Status: every card is `verify: true`

Step texts are Polish paraphrases of the ERC 2025 guidelines (Polish
translation by PRC), each step tied to one source fragment. They were not
signed off by a paramedic or PRC instructor. The UI shows the `VerifyBadge`
("Do weryfikacji", `lib/ratunek/cards/verify_badge.dart`) on every card with
`verify: true`.

## Detection: which file is the source of truth

- **Detection (phrases, variant words, priority):** the app uses
  `assets/phrases/cards_index.json` (read by `lib/ratunek/detect`).
- The `phrases`, `variant_words` and `priority` inside each card are kept for
  contract compliance. They are copied from `cards_index.json`, and
  `test/ratunek/cards/card_files_test.dart` fails when the two differ. Change
  the index first, then the cards.

## Format notes

- `panels` starts with `{ "type": "call" }`. The contract says the app adds it
  when missing; `RescueCard.fromJson` inserts it if absent and never
  duplicates it.
- `steps` panels use `variants` (adult, child, infant) where the sources
  differ by age. `choking` has a second `steps` panel "Gdy straci
  przytomność" with its own variants; its last step links to `rko`.
  `unconscious` starts with "Sprawdź oddech" and the link "Nie oddycha → RKO".
- `source_id` is `{doc_id}-s{pdf_page}-f{n}`; `n` numbers the fragments cited
  on that page. `page_label` equals `pdf_page`: the Polish ERC PDFs print the
  page number equal to the PDF page, and the algorithm posters print none.
- `sources.json` record = contract record without `text`. `original` is the
  verbatim excerpt (at most 60 words, line-wrap hyphenation removed; two
  text-layer splits of the poster, "plecac h" and "poszkodowaneg o", repaired)
  that the `quote` template shows. `rects` is empty, so `quote` shows the
  excerpt below the page.
- `cpr` panel:
  - `rate_bpm` is `null`: the sources give a range (100-120), not one tempo.
    `rate_bpm_min`/`rate_bpm_max` carry it; `CprPanel.effectiveRateBpm` gives
    the derived midpoint 110 for the metronome. The owner may set `rate_bpm`.
  - `rescuer_change_s` is `null`, `voice.change` is `null`: none of the
    downloaded lay-person documents gives a rescuer-change interval.
  - child/infant `breath_phase_s` is `null`: not stated for children.
  - `compressions` is the layperson ratio (30:2); `compressions_pbls_trained`
    is 15 (15:2 for rescuers with a PBLS course).
  - adult `initial_breaths: 0`: the adult sequence starts with compressions
    (page 3 of the BLS algorithm), unlike the 5 initial breaths of children.
- Not shipped: `animation` panel (no GIF assets), `quote` panels (the source
  chip opens the quote from `sources.json`).
