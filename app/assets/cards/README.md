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

- Card files have no `call` panel (contract: the app adds it).
  `RescueCard.fromJson` inserts it first and never duplicates it.
- One step = one action, at most 120 characters (`szablony-czatu.md`, rule 5);
  a test enforces it. Several steps may cite the same fragment.
- All panels with variants (`steps`, `cpr`) have the same variant id set; the
  parser rejects the card otherwise, and rejects `variants: []`.
- `steps` panels use `variants` (adult, child, infant) where the sources
  differ by age. `choking` has a second `steps` panel "Gdy straci
  przytomność" with its own variants; its last step links to `rko`.
  `unconscious` starts with "Sprawdź oddech" and the link "Nie oddycha → RKO".
- `source_id` is `{doc_id}-s{pdf_page}-f{n}`; `n` numbers the fragments cited
  on that page **from 101**, so a card source id never equals a chunk id of
  `content/knowledge` (f1, f2, ...); a test enforces it. `page_label` equals `pdf_page`: the Polish ERC PDFs print the
  page number equal to the PDF page, and the algorithm posters print none.
- `sources.json` record = contract record without `text`. `original` is the
  verbatim excerpt (at most 60 words, line-wrap hyphenation removed; two
  text-layer splits of the poster, "plecac h" and "poszkodowaneg o", repaired)
  that the `quote` template shows. `rects` is empty, so `quote` shows the
  excerpt below the page.
- `cpr` panel: no value is `null` except child/infant `breath_phase_s`.
  - `rate_bpm` is 110, the midpoint of the cited 100-120/min
    (`rate_bpm_min`/`rate_bpm_max`, `rate_source_id`, `rate_note`). 110 is a
    choice of the app, not a number from the guidelines.
  - `rescuer_change_s` is 120 (`rescuer_change_source_id`: ERC 2025 Podsumowanie,
    p. 72, "zmieniaj co najmniej co 2 minuty"). `verify_note` on the panel says
    that this sentence comes from the advanced paediatric section, not from the
    lay-rescuer instructions. `voice.change` is "Zmiana ratownika".
  - `compressions` is the layperson ratio (30:2); `compressions_pbls_trained`
    is 15 (15:2 for rescuers with a PBLS course). The lay child/infant sequence
    is 5 rescue breaths, then 30:2 (Podsumowanie p. 67); the card has the PBLS
    15:2 as a separate step.
  - adult `initial_breaths: 0`: the adult sequence starts with compressions
    (page 3 of the BLS algorithm), unlike the 5 initial breaths of children.
  - `aed_card_id: "aed"` names a card that is not shipped; the repository
    exposes it as `null`, so the UI hides "Jak użyć AED".
- Not shipped: `animation` panel (no GIF assets), `quote` panels (the source
  chip opens the quote from `sources.json`).

## Odstępstwa od kontraktu

- **`breath_phase_s` child/infant is `null`.** The downloaded sources give no
  time for the breath phase in children. The contract says a card with `null`
  in `cpr` fails the build test; the test allows exactly these two nulls. The
  instructor (task D04) must handle `null` as "wait for the user's tap"
  ("Dalej"), with no countdown.
- **`rate_bpm` 110** is derived (midpoint), see above.
- **`cpr` has extra fields** the contract does not list: `rate_source_id`,
  `rate_note`, `rescuer_change_source_id`, `verify_note`,
  `compressions_pbls_trained`. The parser reads them, the renderer may ignore
  them.
- **`unconscious` starts with** "Udrożnij drogi oddechowe i sprawdź oddech:
  patrz, słuchaj, czuj do 10 s" (algorithm poster, FA p. 3) instead of the
  spec's "Sprawdź oddech: patrz, słuchaj, czuj do 10 s"; `szablony-czatu.md`
  (Warianty) still names the old text.

## Regenerating

`python3 -I app/assets/cards/tools/build_cards.py` cuts every `original` from
`content/sources/*/pages.jsonl` by anchor strings and writes the card files and
`sources.json`. Edit the script, not the JSON. `assets/cards/tools/` is not
bundled (the pubspec lists `assets/cards/` without subdirectories).

## Loading

`RescueCardRepository.load` reads every card on its own: a missing or invalid
card file is logged (`dart:developer`, name `bezpiecznik.rescue_cards`) and
skipped; the other cards load. A missing `sources.json` throws. A card that
cites an unknown source is skipped. A `card_link` to a card that is not loaded
is kept; `RescueCardRepository.linkTarget(link)` returns `null`, so the UI
hides the button. A requested variant the card does not have is not replaced
by the first one: `selectVariant`, `StepsPanel.itemsFor` and `CprPanel.variant`
return `null` (`stepsFor` throws `ArgumentError`); `null` requested means the
declared default (first variant).
