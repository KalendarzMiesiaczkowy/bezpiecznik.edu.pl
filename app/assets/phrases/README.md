# Phrase files

Trigger phrases only, no medical content. All phrases are stored in the
normalised form (see `lib/ratunek/detect/normalize.dart`: lowercase, ł->l, no
diacritics, punctuation stripped). The detector normalises them again on load,
so a non-normalised phrase also works.

Consumed by `lib/ratunek/detect/risk_detector.dart`. Matching runs on the
user's message only, never on retrieved chunks or model output
(szablony-czatu.md, reguła 2).

## `risk.json`

Contract: `kontrakty-tresci.md#frazy-ryzyka`.
`{ "version": 1, "phrases": [ ... ] }`. A hit makes the app prepend the `call`
template. Card phrases need not be repeated here: `RiskDetector.isRisk` is
also true when any rescue card matches.

## `cards_index.json`

Phrase to rescue-card index so detection works without loading every card.

```json
{
  "version": 1,
  "cards": [
    { "id": "rko", "priority": 1, "variants": ["adult","child","infant"],
      "phrases": ["nie oddycha", "..."], "next_step": "check_breathing" }
  ],
  "variant_words": { "child": ["dziecko", "..."], "infant": ["niemowle", "..."] }
}
```

- `id`: card id = file name `assets/cards/{id}.json` (D01). Ids follow the
  spec: `rko`, `choking`, `bleeding`, `unconscious` (kontrakty-tresci.md names
  `rko` and `unconscious`; `choking` and `bleeding` appear in the spec's
  feature list, so they are used here).
- `priority`: lower wins when several cards match (same rule as the card
  contract); the other matched ids are returned as `alsoCardIds`
  ("Też: {name}" buttons). `rko` < `unconscious`, so "nieprzytomny i nie
  oddycha" opens RKO.
- `variants`: empty means the card has no age variants (result variant `null`).
  The first entry is the default (`adult`).
- `next_step` (optional): hint for the UI; `check_breathing` on `unconscious`
  means the card opens with "Sprawdź oddech" and the "Nie oddycha -> RKO" link.
- `variant_words`: global for the MVP; infant wins when both match
  (szablony-czatu.md#warianty).

Phrase syntax: tokens are matched in order, with up to 2 other words allowed
between them, except directly after `nie` (no gap, so "nie, dziecko oddycha"
does not match "nie oddycha"). A token prefixed with `=` is matched exactly
(no typo tolerance), used for short words that collide with common ones
(`=czad` vs "czas", `=tonie` vs "tanie"). Typo tolerance otherwise: tokens of
length 4-7 allow Damerau-Levenshtein distance 1, 8+ allow 2, shorter exact.
A phrase that is directly preceded by "nie" in the message (e.g. "nie krwawi")
does not match.

## Reconciliation with D01

The card contract also puts `phrases` and `variant_words` inside each
`assets/cards/{id}.json`. This index is kept in addition for MVP; D01 should
either keep both in sync (a build-time check is advisable) or drop the index
and have the detector read the phrases from the cards. `unconscious` is
marked "po MVP" in the card contract; if its card file is not shipped, the
coordinator should drop that entry or redirect it to `rko`.
