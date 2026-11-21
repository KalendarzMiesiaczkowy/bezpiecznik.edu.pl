"""Regenerate SOURCES.md from the manifest below (sha256, pages and size are computed).

Usage: python3 -I content/sources/build_sources_md.py
"""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
DL = "2026-11-21"
GOV = "https://www.gov.pl/attachment/"
PRC = "https://www.prc.krakow.pl/wp-content/uploads/"
PL_OFFICIAL = ("Polish official material, copyright act art. 4 (public domain); "
               "stored as original, rewrite later with link to original page")
PL_OFFICIAL_DOUBT = (PL_OFFICIAL + "; art. 4 applicability for this publisher is not certain, "
                     "treat as copyrighted: paraphrase with citation, verify: true")
ERC = ("Copyrighted (c) ERC 2025, Polish translation PRC; stored as original for reference, "
       "paraphrase with citation, verify: true")

# doc_id, file, title, publisher, date, url, licence, covers
ROWS = [
    ("rcb-poradnik-2025", "poradnik-bezpieczenstwa-pl.pdf",
     "Poradnik bezpieczeństwa (pion, wersja PL), publ. 1/2025",
     "RCB, MON, MSWiA", "2025-08-28 (PDF built 2025-08-27)",
     GOV + "fa491036-8872-457c-95e4-d1292e4a8203 (page: https://www.gov.pl/web/poradnikbezpieczenstwa)",
     PL_OFFICIAL,
     "Alarm signals, shelter, evacuation, 3-day stock, power outage, flood, fire, first aid, hygiene, family plan"),
    ("rcb-safety-handbook-2025-en", "safety-handbook-en.pdf",
     "Safety handbook 2025 (English version of the Poradnik)",
     "RCB, MON, MSWiA", "2025-08-27",
     GOV + "4d6947da-a6b2-4890-83ef-b2c8eb4a11df (page: https://www.gov.pl/web/rcb-en/crisis-and-war-guide)",
     PL_OFFICIAL, "English counterpart of rcb-poradnik-2025 (same chapters)"),
    ("akademia-nim-nadejdzie-dzien", "nim-nadejdzie-dzien.pdf",
     "Nim nadejdzie dzień. Poradnik podstaw bezpieczeństwa",
     "Akademia Pożarnicza (Warszawa)", "2025-11",
     GOV + "7f230c0f-6800-42d9-b5c8-2dca7a496a94 (page: https://www.gov.pl/web/kmpsp-szczecin/nim-nadejdzie-dzien--poradniki-ktore-pomagaja-przygotowac-sie-na-czas-kryzysu; author site: ochronaludnosci.edu.pl)",
     PL_OFFICIAL_DOUBT,
     "Crisis preparation: budget, documents, stock and food storage, evacuation planning, crowd, first aid, checklists"),
    ("psp-kompendium-poradnik-2025", "psp-poradnik-kompendium.pdf",
     "Poradnik bezpieczeństwa - kompendium wiedzy (based on the RCB Poradnik)",
     "Państwowa Straż Pożarna, Wydział Prewencji Społecznej", "2025-09-18",
     GOV + "96de2351-75d8-442d-b1fc-a717bad7ab3e (found on gov.pl; source page not identified)",
     PL_OFFICIAL, "PSP compendium of the RCB Poradnik: fire, flood, evacuation, backpack, shelter"),
    ("psp-plecak-ewakuacyjny-lista", "plecak-ewakuacyjny-lista.pdf",
     "Plecak ewakuacyjny - lista kontrolna",
     "Państwowa Straż Pożarna (KW PSP Poznań page)", "2025-11-10 (PDF date)",
     GOV + "14cdc2e5-2ceb-4913-b270-209c58dd1d7c (page: https://www.gov.pl/web/kwpsp-poznan/plecak-ewakuacyjny--bezpieczenstwa)",
     PL_OFFICIAL, "Evacuation backpack checklist (first aid kit, tools, documents)"),
    ("psp-powodz-ulotka", "w-obliczu-powodzi-ulotka.pdf",
     "W obliczu powodzi - ulotka",
     "Komenda Główna PSP (leaflet; PDF creation date 2010)", "undated (PDF metadata 2010-02-25)",
     GOV + "19f873aa-b3d2-4b53-b1d5-82b9a499d356 (page: https://www.gov.pl/web/kwpsp-poznan/powodz)",
     PL_OFFICIAL, "Flood: before, during, after; evacuation, utilities. Old leaflet, check currency"),
    ("rcb-powodz-poradnik-2024", "powodz-poradnik.pdf",
     "Powódź. Poradnik na wypadek powodzi, wydanie II",
     "Rządowe Centrum Bezpieczeństwa", "2024",
     GOV + "ecbf8957-a00d-4af8-81af-34f79f9dd954 (found on gov.pl; source page not identified)",
     PL_OFFICIAL, "Flood: causes, warning, preparation, evacuation, after the flood"),
    ("erc-2025-podsumowanie", "podsumowanie-wytycznych-2025.pdf",
     "Wytyczne Europejskiej Rady Resuscytacji 2025 - Podsumowanie wytycznych (tłumaczenie polskie)",
     "European Resuscitation Council; Polska Rada Resuscytacji", "ERC 2025-10; PL PDF 2026-07-10",
     PRC + "2026/09/Podsumowanie_2025.pdf (page: https://www.prc.krakow.pl/wytyczne-2025/)",
     ERC, "Executive summary: BLS adult, paediatric and newborn, first aid, choking, bleeding, ALS, systems"),
    ("erc-2025-bls", "wytyczne-erc-2025-bls.pdf",
     "Wytyczne ERC 2025 - podstawowe zabiegi resuscytacyjne u dorosłych (rozdział BLS)",
     "European Resuscitation Council; Polska Rada Resuscytacji", "ERC 2025-10; PL PDF 2026-07-22",
     PRC + "2026/07/wytyczne-ERC-2025_BLS_final.pdf (page: https://www.prc.krakow.pl/wytyczne-2025/)",
     ERC, "Adult BLS step by step, AED, compressions, choking, recovery position"),
    ("erc-2025-pierwsza-pomoc", "wytyczne-erc-2025-pierwsza-pomoc.pdf",
     "Wytyczne ERC 2025 - pierwsza pomoc (rozdział)",
     "European Resuscitation Council; Polska Rada Resuscytacji", "ERC 2025-10; PL PDF 2026-10-22",
     PRC + "2026/10/wytyczne-ERC-2025_pierwsza-pomoc_i_C.pdf (page: https://www.prc.krakow.pl/wytyczne-2025/)",
     ERC, "First aid: bleeding, choking, burns, heat stroke, fractures, poisoning"),
    ("erc-2025-bls-algorytmy", "bls-algorytmy.pdf",
     "Podstawowe zabiegi resuscytacyjne krok po kroku - algorytmy",
     "European Resuscitation Council; Polska Rada Resuscytacji", "PL PDF 2025-12",
     PRC + "2025/12/BLS_Algorytmy.pdf (page: https://www.prc.krakow.pl/wytyczne-2025/)",
     ERC, "BLS algorithm tables (adult and child)"),
    ("erc-2025-pierwsza-pomoc-algorytmy", "pierwsza-pomoc-algorytmy.pdf",
     "Pierwsza pomoc - algorytmy",
     "European Resuscitation Council; Polska Rada Resuscytacji", "PL PDF 2026-04",
     PRC + "2026/04/Algorytmy_I_Pomoc-1.pdf (page: https://www.prc.krakow.pl/wytyczne-2025/)",
     ERC, "First aid algorithms (ABCDE, bleeding, choking, recovery position)"),
    ("erc-2025-kluczowe-bls", "kluczowe-bls.pdf",
     "Podstawowe zabiegi resuscytacyjne u dorosłych - kluczowe informacje",
     "European Resuscitation Council; Polska Rada Resuscytacji", "ERC 2025-10",
     PRC + "2025/10/Kluczowe_BLS.pdf (page: https://www.prc.krakow.pl/wytyczne-2025/)",
     ERC, "One-page key points: adult BLS"),
    ("erc-2025-kluczowe-dzieci", "kluczowe-resuscytacja-dzieci.pdf",
     "Zabiegi resuscytacyjne u dzieci - kluczowe informacje",
     "European Resuscitation Council; Polska Rada Resuscytacji", "ERC 2025-10",
     PRC + "2025/10/Kluczowe_EPALS.pdf (page: https://www.prc.krakow.pl/wytyczne-2025/)",
     ERC, "One-page key points: paediatric resuscitation (child and infant)"),
    ("erc-2025-kluczowe-pierwsza-pomoc", "kluczowe-pierwsza-pomoc.pdf",
     "Pierwsza pomoc - kluczowe informacje",
     "European Resuscitation Council; Polska Rada Resuscytacji", "ERC 2025-10",
     PRC + "2025/10/Kluczowe_I_Pomoc.pdf (page: https://www.prc.krakow.pl/wytyczne-2025/)",
     ERC, "One-page key points: first aid training"),
    ("erc-2025-broszura-resuscytacja-dla-kazdego", "broszura-resuscytacja-dla-kazdego.pdf",
     "Resuscytacja dla każdego (broszura ERC 2025, wersja polska)",
     "European Resuscitation Council; Polska Rada Resuscytacji", "ERC 2025; PL PDF 2026-04-09",
     PRC + "2026/04/Broszura-ERC-2025-i.pdf (page: https://www.prc.krakow.pl/wytyczne-2025/)",
     ERC, "Lay-person overview: recognise arrest, call, compressions, AED, child/infant, choking"),
]

HEAD = ["doc_id", "file", "title", "publisher", "date", "url", "downloaded", "licence basis",
        "sha256", "pages", "size", "covers"]


def main() -> None:
    lines = ["# Knowledge sources",
             "",
             "Originals (PDF) and extracted text (`pages.jsonl`, one JSON per page: `pdf_page`, "
             "`page_label`, `text`) of the sources listed in `bezpiecznik/04-dane/zrodla-wiedzy.md`. "
             f"Downloaded {DL} from the official publisher URLs below. Generated by "
             "`build_sources_md.py`; verified by `check_sources.py`. Extraction: `extract_text.py`.",
             "",
             "Rules: files larger than 50 MB stay out of git (see `.gitignore`), only URL + sha256 "
             "are recorded (none at the moment). Medical and safety content is never invented: "
             "everything downstream cites these pages.",
             "",
             "| " + " | ".join(HEAD) + " |",
             "|" + "---|" * len(HEAD)]
    for doc_id, fname, title, pub, date, url, lic, covers in ROWS:
        path = ROOT / doc_id / fname
        data = path.read_bytes()
        pages = sum(1 for _ in (ROOT / doc_id / "pages.jsonl").open(encoding="utf-8"))
        size = f"{len(data) / 1e6:.2f} MB"
        cells = [doc_id, f"`{doc_id}/{fname}`", title, pub, date, url, DL, lic,
                 hashlib.sha256(data).hexdigest(), str(pages), size, covers]
        lines.append("| " + " | ".join(c.replace("|", "/") for c in cells) + " |")
    lines += ["", "## Missing / not downloaded", "",
              "| item | tried | status |", "|---|---|---|",
              "| ERC 2025 Polish full summary `WytResusc_net.pdf` / `WytResusc2025_20a.pdf` | "
              "prc.krakow.pl upload URLs surfaced by search | missing: 404; replaced by the "
              "`erc-2025-podsumowanie` file linked from https://www.prc.krakow.pl/wytyczne-2025/ |",
              "| PSP procedure on house fire (stand-alone PDF) | gov.pl/web/kgpsp, KW PSP Poznan pages | "
              "missing: only web pages (no PDF) found; fire content is in `rcb-poradnik-2025` and "
              "`psp-kompendium-poradnik-2025`. Web pages https://www.gov.pl/web/kgpsp/bezpieczna-ewakuacja "
              "are HTML only and not stored |",
              "| ERC 2025 paediatric life support full chapter | prc.krakow.pl/wytyczne-2025/ list | "
              "missing: only key-points page (`erc-2025-kluczowe-dzieci`), the summary and the brochure "
              "cover children |",
              "",
              "## Notes", "",
              "- `rcb-poradnik-2025`: two gov.pl attachments (`fa491036...`, `66632d1d...`) are byte-identical; "
              "a third (`726ed2d0...`, 1447673 B, same 54 pages) differs and is not stored.",
              "- Extraction notes: `akademia-nim-nadejdzie-dzien` has duplicated heading lines and words "
              "split without hyphen (layout artefact of the PDF); `erc-2025-*` Polish PDFs have two columns "
              "(native text order kept, which follows columns).",
              "- Pages without a text layer: akademia p. 2 (graphic), rcb-powodz-poradnik-2024 p. 34 (back cover).",
              ""]
    (ROOT / "SOURCES.md").write_text("\n".join(lines), encoding="utf-8")
    print(f"wrote SOURCES.md with {len(ROWS)} rows")


if __name__ == "__main__":
    main()
