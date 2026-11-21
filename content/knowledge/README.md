# Knowledge chunks (rewritten, linked to the original page)

Task A02 of the night build. Input: `content/sources/<doc_id>/pages.jsonl`. Output: one Markdown file per chunk in `content/knowledge/<doc_id>/<chunk_id>.md`. Task A03 loads these files into `kb.sqlite` together with `synonyms.tsv`.

## Format

```
---
id: rcb-poradnik-2025-s31-f1        # <doc_id>-s<pdf_page>-f<n>; n counts chunks on that page from 1
doc_id, doc_short, title, publisher, date
pdf_page: 31                        # page in the PDF file, from 1
page_label: "31"                    # printed page number; pdf_page as string when unknown
section: "Reagowanie: Pożar"
topics: [pozar]                     # slugs from TOPICS.md
keywords: ["pożar", "dym", ...]     # 5-12 Polish search words incl. colloquial ones
verify: true                        # always true: human review still pending
original: |                         # verbatim words of the passage, only bullet glyphs, line breaks and split words cleaned
  ...
---
<rewritten plain-Polish body>
```

- The body is a faithful rewrite of the `original` passage: no facts, numbers or advice beyond the cited page.
- The `original:` block is cut automatically from `pages.jsonl` by `tools/build_chunks.py` (start/end markers in the spec), so it cannot drift from the source. Bodies are hand-written in `tools/specs/<doc_id>.py`.
- Layout artefacts are visible in some originals (tables on RCB p. 30, two-column ERC pages, running headers). Words split by the PDF layout were rejoined (list `FIXES` in `build_chunks.py`).
- ERC/PRC and Akademia texts are copyrighted: `original` is kept short (max 140 words, enforced), the body is a paraphrase with citation.
- Body length: 150-450 words when the original is long enough; shorter bodies are allowed when the cited passage is short (allowed minimum is 70 % of the original words, at least 15). A short page cannot be padded without inventing content.
- `page_label` for `rcb-powodz-poradnik-2024` is the printed `str.N` number (pdf page minus 2).

## Tools (`tools/`)

| Script | Purpose | Run |
|---|---|---|
| `dump_pages.py` | print page text of a document | `uv run python -I content/knowledge/tools/dump_pages.py <doc_id> [first] [last]` |
| `build_chunks.py` | regenerate all chunk files from `tools/specs/*.py` (deletes old chunk files of those docs) | `uv run python -I content/knowledge/tools/build_chunks.py [doc_id ...]` |
| `check_markers.py` | diagnose start/end markers in a spec | `uv run python -I content/knowledge/tools/check_markers.py <doc_id>` |
| `check_chunks.py` | validate every chunk (front matter, ids, page exists, original found on page >= 80 %, body length, no invented numbers, topics, keyword count), prints counts per document and topic | `uv run --with pyyaml python -I content/knowledge/tools/check_chunks.py` |

## Synonyms

`synonyms.tsv`: two columns (term, synonym), candidates for the `synonyms` table. Not normalised: A03 applies the shared normalisation to both columns.

## Coverage (topic to chunk ids)

| topic | chunks | ids |
|---|---|---|
| `brak-pradu` | 2 | `rcb-poradnik-2025-s22-f1`, `rcb-poradnik-2025-s33-f1` |
| `ewakuacja` | 8 | `rcb-poradnik-2025-s25-f1`, `rcb-poradnik-2025-s26-f1`, `rcb-poradnik-2025-s27-f1`, `rcb-powodz-poradnik-2024-s12-f1`, `rcb-powodz-poradnik-2024-s20-f1`, `rcb-powodz-poradnik-2024-s24-f1`, `rcb-powodz-poradnik-2024-s25-f1`, `rcb-powodz-poradnik-2024-s26-f1` |
| `higiena` | 1 | `rcb-poradnik-2025-s45-f1` |
| `krwotok` | 4 | `erc-2025-kluczowe-pierwsza-pomoc-s1-f1`, `erc-2025-pierwsza-pomoc-s12-f1`, `erc-2025-pierwsza-pomoc-s13-f1`, `rcb-poradnik-2025-s44-f1` |
| `numery-alarmowe` | 4 | `erc-2025-broszura-resuscytacja-dla-kazdego-s24-f2`, `erc-2025-broszura-resuscytacja-dla-kazdego-s25-f1`, `erc-2025-broszura-resuscytacja-dla-kazdego-s36-f2`, `rcb-poradnik-2025-s3-f1` |
| `oparzenia` | 1 | `akademia-nim-nadejdzie-dzien-s135-f1` |
| `osoby-szczegolnej-troski` | 1 | `rcb-poradnik-2025-s12-f1` |
| `pierwsza-pomoc` | 15 | `akademia-nim-nadejdzie-dzien-s135-f1`, `erc-2025-broszura-resuscytacja-dla-kazdego-s29-f1`, `erc-2025-broszura-resuscytacja-dla-kazdego-s56-f1`, `erc-2025-broszura-resuscytacja-dla-kazdego-s56-f2`, `erc-2025-broszura-resuscytacja-dla-kazdego-s57-f1`, `erc-2025-broszura-resuscytacja-dla-kazdego-s58-f1`, `erc-2025-broszura-resuscytacja-dla-kazdego-s58-f2`, `erc-2025-broszura-resuscytacja-dla-kazdego-s58-f3`, `erc-2025-broszura-resuscytacja-dla-kazdego-s60-f1`, `erc-2025-kluczowe-pierwsza-pomoc-s1-f1`, `erc-2025-pierwsza-pomoc-s7-f1`, `rcb-poradnik-2025-s41-f1`, `rcb-poradnik-2025-s42-f1`, `rcb-poradnik-2025-s43-f1`, `rcb-poradnik-2025-s44-f1` |
| `plan-rodzinny` | 3 | `rcb-poradnik-2025-s47-f1`, `rcb-poradnik-2025-s52-f1`, `rcb-powodz-poradnik-2024-s11-f1` |
| `plecak-ewakuacyjny` | 6 | `psp-plecak-ewakuacyjny-lista-s1-f1`, `psp-plecak-ewakuacyjny-lista-s2-f1`, `psp-plecak-ewakuacyjny-lista-s2-f2`, `rcb-poradnik-2025-s26-f1`, `rcb-poradnik-2025-s27-f1`, `rcb-powodz-poradnik-2024-s20-f1` |
| `powodz` | 18 | `rcb-poradnik-2025-s32-f1`, `rcb-powodz-poradnik-2024-s11-f1`, `rcb-powodz-poradnik-2024-s12-f1`, `rcb-powodz-poradnik-2024-s15-f1`, `rcb-powodz-poradnik-2024-s17-f1`, `rcb-powodz-poradnik-2024-s19-f1`, `rcb-powodz-poradnik-2024-s20-f1`, `rcb-powodz-poradnik-2024-s21-f1`, `rcb-powodz-poradnik-2024-s23-f1`, `rcb-powodz-poradnik-2024-s24-f1`, `rcb-powodz-poradnik-2024-s25-f1`, `rcb-powodz-poradnik-2024-s26-f1`, `rcb-powodz-poradnik-2024-s27-f1`, `rcb-powodz-poradnik-2024-s28-f1`, `rcb-powodz-poradnik-2024-s29-f1`, `rcb-powodz-poradnik-2024-s30-f1`, `rcb-powodz-poradnik-2024-s31-f1`, `rcb-powodz-poradnik-2024-s9-f1` |
| `pozar` | 3 | `rcb-poradnik-2025-s18-f1`, `rcb-poradnik-2025-s30-f1`, `rcb-poradnik-2025-s31-f1` |
| `pozycja-boczna` | 3 | `erc-2025-broszura-resuscytacja-dla-kazdego-s57-f1`, `erc-2025-pierwsza-pomoc-s7-f1`, `rcb-poradnik-2025-s42-f1` |
| `przygotowanie-domu` | 3 | `rcb-poradnik-2025-s17-f1`, `rcb-poradnik-2025-s18-f1`, `rcb-powodz-poradnik-2024-s17-f1` |
| `przygotowanie-osobiste` | 2 | `rcb-poradnik-2025-s11-f1`, `rcb-poradnik-2025-s52-f1` |
| `rko-aed` | 21 | `erc-2025-broszura-resuscytacja-dla-kazdego-s24-f1`, `erc-2025-broszura-resuscytacja-dla-kazdego-s24-f2`, `erc-2025-broszura-resuscytacja-dla-kazdego-s25-f1`, `erc-2025-broszura-resuscytacja-dla-kazdego-s25-f2`, `erc-2025-broszura-resuscytacja-dla-kazdego-s26-f1`, `erc-2025-broszura-resuscytacja-dla-kazdego-s26-f2`, `erc-2025-broszura-resuscytacja-dla-kazdego-s26-f3`, `erc-2025-broszura-resuscytacja-dla-kazdego-s27-f1`, `erc-2025-broszura-resuscytacja-dla-kazdego-s27-f2`, `erc-2025-broszura-resuscytacja-dla-kazdego-s28-f1`, `erc-2025-broszura-resuscytacja-dla-kazdego-s29-f1`, `erc-2025-broszura-resuscytacja-dla-kazdego-s29-f2`, `erc-2025-broszura-resuscytacja-dla-kazdego-s29-f3`, `erc-2025-broszura-resuscytacja-dla-kazdego-s38-f1`, `erc-2025-broszura-resuscytacja-dla-kazdego-s38-f2`, `erc-2025-broszura-resuscytacja-dla-kazdego-s38-f3`, `erc-2025-broszura-resuscytacja-dla-kazdego-s61-f1`, `erc-2025-kluczowe-bls-s1-f1`, `rcb-poradnik-2025-s42-f1`, `rcb-poradnik-2025-s43-f1`, `rcb-poradnik-2025-s43-f2` |
| `rko-dzieci` | 10 | `erc-2025-broszura-resuscytacja-dla-kazdego-s36-f1`, `erc-2025-broszura-resuscytacja-dla-kazdego-s36-f2`, `erc-2025-broszura-resuscytacja-dla-kazdego-s36-f3`, `erc-2025-broszura-resuscytacja-dla-kazdego-s36-f4`, `erc-2025-broszura-resuscytacja-dla-kazdego-s37-f1`, `erc-2025-broszura-resuscytacja-dla-kazdego-s38-f1`, `erc-2025-broszura-resuscytacja-dla-kazdego-s38-f2`, `erc-2025-broszura-resuscytacja-dla-kazdego-s38-f3`, `erc-2025-broszura-resuscytacja-dla-kazdego-s39-f1`, `erc-2025-kluczowe-dzieci-s1-f1` |
| `schron-schronienie` | 2 | `rcb-poradnik-2025-s29-f1`, `rcb-poradnik-2025-s34-f1` |
| `sygnaly-alarmowe` | 3 | `rcb-poradnik-2025-s24-f1`, `rcb-poradnik-2025-s34-f1`, `rcb-poradnik-2025-s53-f1` |
| `tlum` | 1 | `rcb-poradnik-2025-s28-f1` |
| `transport-samochod` | 3 | `rcb-poradnik-2025-s16-f1`, `rcb-powodz-poradnik-2024-s21-f1`, `rcb-powodz-poradnik-2024-s28-f1` |
| `utoniecie` | 3 | `erc-2025-broszura-resuscytacja-dla-kazdego-s61-f1`, `erc-2025-broszura-resuscytacja-dla-kazdego-s61-f2`, `erc-2025-kluczowe-pierwsza-pomoc-s1-f1` |
| `woda-jedzenie` | 1 | `rcb-poradnik-2025-s21-f1` |
| `zadlawienie` | 4 | `erc-2025-broszura-resuscytacja-dla-kazdego-s60-f2`, `erc-2025-kluczowe-pierwsza-pomoc-s1-f1`, `erc-2025-pierwsza-pomoc-s10-f1`, `erc-2025-pierwsza-pomoc-s9-f1` |
| `zagrozenia-cbrn` | 1 | `rcb-poradnik-2025-s35-f1` |
| `zagrozenie-atak` | 1 | `rcb-poradnik-2025-s38-f1` |
| `zapasy-72h` | 6 | `rcb-poradnik-2025-s17-f1`, `rcb-poradnik-2025-s20-f1`, `rcb-poradnik-2025-s21-f1`, `rcb-poradnik-2025-s22-f1`, `rcb-poradnik-2025-s52-f1`, `rcb-powodz-poradnik-2024-s15-f1` |
| `zwierzeta` | 2 | `rcb-poradnik-2025-s14-f1`, `rcb-poradnik-2025-s15-f1` |

## Coverage vs the acceptance list

alarm signals, shelter/evacuation, 72 h kit and water/food, power outage, flood, fire, first aid basics (recognising cardiac arrest, calling 112, CPR adult/child/infant, choking, severe bleeding, recovery position, burns): all have chunks, see the table.

Known gaps and weak spots:
- Water and food: the RCB guide only gives "minimum 3 litres of water per person per day" and "ready-to-eat food"; there is nothing more in the sources (no storage advice), so none was written.
- Fire: RCB p. 30 is a table whose extinguisher-class column (A, B, C, D, F) is graphic; the extracted text does not show which class belongs to which row. The chunk says so and sends the reader to the original.
- Burns: only one source page (Akademia "Nim nadejdzie dzień", p. 135). ERC chapters only list burns in a change table.
- Infant/child choking is not covered (ERC chapter only refers to other guidelines).
- Skipped content: covers, tables of contents, imprint, blank pages, RCB pp. 4-9 (state, army, defence duties), 13 (talking to children), 19 (school and work), 36-37 (suspicious behaviour), 39-40 (digital threats), 46-51 and 54 (forms and back cover), the English handbook, `psp-kompendium-poradnik-2025` (duplicates the RCB guide), `psp-powodz-ulotka`, ERC summary/BLS chapter/algorithm tables (the lay brochure and key-points pages were used instead), most of the Akademia handbook, flood guide pp. 1-8, 10, 13, 16, 18, 22 (farm), 32-34.
- ERC pages were cut into passages of at most ~140 words, so some pages have several chunks (f1, f2, ...).
