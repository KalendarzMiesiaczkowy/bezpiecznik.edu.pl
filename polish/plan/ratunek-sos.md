# Plan polish — ratunek / RKO / alarm-SOS (agent RESCUE)

Worktree `Bezpiecznik-polish-rescue`, branch `polish/rescue`, emulator `emulator-5562`.
Faza 1: audyt + plan, bez zmian w `app/lib`. Baseline `flutter analyze`: **0 issues** (2026-11-21).
Zrzuty „przed”: wspólne, `Bezpiecznik-polish/polish/before/` (generuje koordynator).

Źródła prawdy (kolejność): brief → testy kodujące decyzje właściciela → spec `03-ekrany` → DS (`bundle.css`,
`components/*/README.md`) → referencja `polish/ref/*.png`. Gdzie ref i decyzja zapisana w testach się
różnią, wygrywa decyzja (opisane w „Świadomie pominięte”).

Zasada przekrojowa: zmieniam wygląd, nie słowa. Wielkość liter traktuję jako typografię, ale dla
przycisku 112 zostawiam decyzję człowiekowi (spec „Teksty” wymienia „ZADZWOŃ 112” dosłownie) — patrz D1.

---

## 1. Karta ratunkowa (czat: `call` + kroki)

**Po co tu jest:** osoba w nagłej sytuacji ma od razu wezwać pomoc i wiedzieć, co robić krok po kroku.

**Akcja główna:** „Zadzwoń 112” (wypełniony `sos`). Reszta cichsza: „Powiadom bliskich” obrysowany,
999/998/997 jako cichy wiersz tekstowy, kroki w zwykłych kartach.

### Plan zmian

| Widget / plik | Zmiana | Tokeny |
| --- | --- | --- |
| `VerifyBadge` — `ratunek/cards/verify_badge.dart` | Pigułka jak w ref: `radiusFull`, bez ramki, tło `signalTint`, ikona `LucideIcons.triangleAlert` 16 dp w `signal`, tekst `label` w `ink100` (kontrast ink100/signalTint ≫ 4.5:1). Tekst „Do weryfikacji” i etykieta semantyczna bez zmian. Fallback bez `BzTokens` zostaje. | `radiusFull`, `space2`/`space1`, `signal`, `signalTint`, `ink100`, `label` |
| `CallPanelView` — `czat/templates/call/call_panel_view.dart` | Grupa „Wezwij pomoc” w czerwonej ramce (DS `.bz-panel--sos`: ramka `sos`, tło `sosTint`, tytuł `sosText`) obejmuje tylko tytuł, dwa przyciski i linię GPS/kontaktów. Wiersz 999/998/997 + „Więcej” **pod** grupą, poza ramką (jak w ref). Wymaga `PanelCard(tone: sos)` od agenta wspólnego (prośba P1); gdy nie będzie gotowe, lokalny `DecoratedBox` z tymi samymi tokenami. | `sos`, `sosTint`, `sosText`, `radiusLg`, `space4` |
| `_BigButton` — `alarm/panel/call_panel.dart` | Wg DS `.bz-call__btn`: promień `radiusLg` (zamiast pigułki), treść wyrównana do lewej, padding 12×20, odstęp ikona–tekst 16, etykieta 20/26 w800 (najbliższy token `step` 20/28 w700 + w800 — propozycja T1), podpis 14/18 w500 (`label` w500). Obrys „Powiadom bliskich” `line200` (DS), ikona `LucideIcons.users` zamiast `messageSquare`. Min. 80 dp i zawijanie przy 200% bez zmian. Stany pressed: `overlayPress` na obrysowanym, `alphaBlend(overlayPress, sos)` na 112 (jak `BzButton.sos`); disabled 38% zostaje. | `radiusLg`, `step`, `label`, `line200`, `sos`, `onSos`, `overlayPress` |
| Podpis SMS — `call_panel.dart` | Odbiorcy wchodzą do podpisu przycisku: „SMS z lokalizacją do: Mama” (jak DS/ref). Osobny wiersz „Do: …” znika (informacja zostaje, tylko w innym miejscu). Bez kontaktów: podpis „SMS z lokalizacją” + link „Dodaj kontakty” pod przyciskiem (bez zmian). | `label` |
| Wiersz 999/998/997 — `_SmallDial` | Zamiast trzech obrysowanych pudełek 56 dp: cichy wiersz tekstowy jak w ref — numer `label` w700 `ink200`, nazwa `label` w500 `ink300`, bez ramek, każdy cel ≥ 48 dp (`minTouchTarget`), `Wrap` przy 200%. Etykiety semantyczne „Zadzwoń: 999 Pogotowie” bez zmian. Inline: „Więcej ⌄” na końcu tego wiersza (ref). | `minTouchTarget`, `label`, `ink200`, `ink300`, `space2`/`space4` |
| Notka (toast) w panelu | Promień `12` → `radiusMd`, padding → `space3`, odstępy `SizedBox(12/8/4)` → `space3/space2/space1`. | `radiusMd`, `space*` |
| „Więcej” (rozwinięcie) | Tylko odstępy i hierarchia: nagłówki sekcji `label` `ink200`, treść `chat`/`caption`; bez zmian treści. | `space*` |

Uwaga: nagłówek „Karta ratunkowa” + odznaka, stopka „Ta instrukcja nie zastępuje połączenia z 112.” i kroki
(`steps_panel.dart`) są w `czat/templates/template_renderer.dart` / `steps_panel.dart` — poza moim zakresem
(prośba P3).

### Teksty do usunięcia (kandydaci)

| Tekst (dosłownie) | Plik:linia | Test z briefu | Dlaczego to NIE jest tekst bezpieczeństwa |
| --- | --- | --- | --- |
| `'Do: ${names…}'` (wiersz „Do: Mama”) | `alarm/panel/call_panel.dart:241` | Nie wie mniej — odbiorcy są w podpisie przycisku („SMS z lokalizacją do: Mama”) | Lista odbiorców SMS; nie numer służb, nie instrukcja. To przeniesienie, nie utrata informacji. |
| `'Zmień'` (link obok odbiorców) | `alarm/panel/call_panel.dart:245` | Nie wie mniej — kontakty edytuje się w Profilu (wyspa → menu). W panelu alarmowym to cel do pomyłkowego dotknięcia tuż pod „Powiadom bliskich”, który zamyka panel i przenosi do profilu. | Nawigacja pomocnicza do ustawień, nie wezwanie pomocy. **Do akceptacji** (patrz D3); bez akceptacji zostaje jako cichy link. |
| Separator `' · '` w `'$n · $name'` | `alarm/panel/call_panel.dart:301` | Typografia — numer i nazwa rozdziela waga/kolor jak w ref („999 Pogotowie”) | Numery 999/998/997 i nazwy służb zostają dosłownie. |

---

## 2. RKO (`CprCard`, `CprPinned`, podsumowanie)

**Po co tu jest:** prowadzić laika przez uciśnięcia w dobrym tempie, dopóki nie przyjedzie pomoc.

**Akcja główna:** przed startem „Zacznij uciskanie”; w trakcie — sam rytm (kropka + „Uciskaj 17 z 30”),
przyciski Pauza/Zakończ ciche. 112 zostaje w przypiętym widoku (D2).

### Plan zmian

| Widget / plik | Zmiana | Tokeny |
| --- | --- | --- |
| `CprCard` przed startem — `ratunek/cpr/cpr_view.dart` | Linia meta (`'${label} · ${rate}/min · c:b'`) w `chat` `ink200` z cyframi tabelarycznymi (bez zmian słów). „Zacznij uciskanie”: `primary`, rozmiar `lg` (DS: 44 px, ref), ikona `LucideIcons.play` zamiast `heartPulse`, pełna szerokość; cel ≥ 48 dp zapewnia `BzButton`. Chip źródła pod spodem bez zmian (styl chipa — prośba P2). | `chat`, `ink200`, `space3` |
| `CprCard` w trakcie | Zamiast samego tekstu: linia meta + wiersz „● Instruktor RKO działa ↓” (kropka 10 dp `sosText`, tekst `chat` w600 `ink100`, DS `.bz-cprcard__running`) + chip źródła — jak w ref. Tekst `cprRunningNotice` bez zmian. | `sosText`, `ink100`, `space2` |
| `CprCard` po zakończeniu | Tekst podsumowania bez zmian; „Zacznij od nowa” `secondary` `lg`, nie na całą szerokość (DS `.bz-cprcard__done`: justify-start). | `space2` |
| `CprPinned` — kontener | Promień `radiusLg` na wszystkich rogach (host w `chat_screen` już daje marginesy), tło `bg200`, 1 px `line150`, zostaje 1 poziom `shadowFloat`. Padding `space4` (DS `.bz-cpr`), odstępy `space3`. | `bg200`, `line150`, `radiusLg`, `space4`, `space3` |
| `CprPinned` — wiersz fazy | `_Dots` (4 kropki) → jedna kropka „beat” 10 dp `sosText`, puls skali 1.35→0.85 przy każdym `beatInCycle` (DS `.bz-beat`; ≤ 2 Hz przy 110/min, zgodne z motion.md p.5). Pauza: `ink300`, bez ruchu. Oddechy: `signal` jak dziś. Faza 28/34 w700 (`readout` bez zmiany liter, propozycja T2). Licznik „17 z 30”: liczba `readout` `ink100`, „z 30” `chat` `ink200` (DS `.bz-cpr__count`). | `readout`, `chat`, `sosText`, `signal`, `ink300`, `durationFast`, `easeOut` |
| `CprPinned` — meta | Nagłówek „RKO · Dorosły” scalony z linią meta: „RKO · Dorosły · 01:28 · zmiana za 0:32” (`label` 14/20 `ink300`, DS `.bz-cpr__meta`). Pigułka **112** (`sos`, `sm`, cel 48 dp) przechodzi na prawy koniec linii meta — zostaje widoczna. Klucze `cpr-time`, `cpr-change` zostają. | `label`, `ink300` |
| `CprPinned` — akcje | Dwie kolumny jak DS `.bz-cpr__actions`: „Pauza/Wznów” `secondary` z ikoną `pause`/`play`, „Zakończ” `ghost`, obie `lg` (44 px). „Dalej” (oddechy) osobno nad nimi, `secondary`, do lewej. | `space2` |
| `CprPinned` — baner zmiany ratownika | **Błąd kontrastu:** dziś `signalInk` (#1A1408) na `signalTint` (#241F16) — tekst praktycznie niewidoczny. Wg DS `.bz-cpr__alert`: tło `sosTint`, tekst `sosText` w700, a karta na czas banera dostaje 1 px ramkę `sos` („jedyny moment, gdy karta jest czerwona”). Tekst `cfg.voice.change` z treści karty bez zmian. | `sosTint`, `sosText`, `sos` |
| `CprPinned` compact (klawiatura) | Tylko tokeny (padding `space2`/`space4`, `radiusLg`). Treść linii bez zmian poza D1. | — |
| Wiersz AED | Bez zmian treści; promień `radiusMd` i `overlayHover` już zgodne z DS. | — |
| Dialog „Zakończyć RKO?” | Bez zmian (motyw dialogu jest wspólny). | — |

### Teksty do usunięcia (kandydaci)

| Tekst (dosłownie) | Plik:linia | Test z briefu | Dlaczego to NIE jest tekst bezpieczeństwa |
| --- | --- | --- | --- |
| `'Czas '` (prefiks w „Czas 01:28”) | `ratunek/cpr/cpr_view.dart:510` | Nie wie mniej — stoper „01:28” w linii „RKO · Dorosły · 01:28 · zmiana za 0:32” jest jednoznaczny (DS/ref). | Etykieta stopera, nie instrukcja RKO. Liczba zostaje. |
| Osobny wiersz `'$cprShortTitle · ${v.label}'` | `ratunek/cpr/cpr_view.dart:431` | Nie znika — treść „RKO · Dorosły” przechodzi na początek linii meta. | Nagłówek kontekstu, nie instrukcja. |

Zmiana wielkości liter (nie słów): `cprCompressLabel 'UCISKAJ'` → „Uciskaj” (`cpr_view.dart:56`),
`cprPausedLabel 'PAUZA'` → „Pauza” (`cpr_view.dart:61`); licznik `'17 / 30'` → „17 z 30” (`cpr_view.dart:353`,
typografia DS). Spec głosu (`szablony-czatu.md:385`) i DS mają „Uciskaj”. Patrz D1.

---

## 3. Alarm / SOS (Panel 2 `sheet` + `SignalPanel`)

**Po co tu jest:** jednym ruchem wezwać pomoc albo zawiadomić bliskich, gdy coś się dzieje.

**Akcja główna:** „Zadzwoń 112”.

### Plan zmian

| Widget / plik | Zmiana | Tokeny |
| --- | --- | --- |
| Nagłówek — `call_panel.dart` | X (48 dp) + „Kontakt ze służbami” w `step` (20/28 w700) zamiast `title` 24 (ref: mniejszy, spokojny). Odstęp `space3`. | `step`, `space2`, `space3` |
| Przyciski | Jak w karcie (wspólny `_BigButton`). | j.w. |
| Wiersz 999/998/997 | Ten sam cichy wiersz co inline; w `sheet` pod nim separator `line100` i pełny wiersz „Więcej ⌄” (ref sos.png). | `line100`, `minTouchTarget` |
| Linia GPS | `caption` `ink300` → zostaje `ink200` (kontrast AA na `bg200`); tylko odstępy z tokenów. | `caption`, `space1` |
| „Więcej” → „Sygnał ratunkowy” | Akordeon jak „Więcej” (te same tokeny). | — |
| `SignalPanelView` — `alarm/signal/signal_panel.dart` | Praktycznie bez zmian — odstępy już z tokenów, układ zgodny z DS (`Switch` per tryb, `Segmented` przerwy, licznik). Ewentualnie tylko wyrównanie do lewej krawędzi treści panelu w trybie `bare`. | — |
| `ContactPanel` — `contact_panel.dart` | Bez zmian (cienki wrapper). | — |

### Teksty do usunięcia (kandydaci)

Te same co w karcie (`Do: …`, `Zmień`, separator `·`) — wspólny komponent. Innych kandydatów brak: notka AML,
„Co powiedzieć dyspozytorowi”, współrzędne, „Brak sygnału GPS…”, „Ten telefon nie wysyła SMS-ów.”,
„Latarka niedostępna.” niosą informację potrzebną w kryzysie.

---

## Świadomie pominięte

1. **Podpis 112 „Numer alarmowy” → „Pogotowie, straż, policja”** (ref, DS CallPanel). Zmiana słów na przycisku 112;
   spec P2 „Teksty” mówi „Numer alarmowy”. Zostawiam. Decyzja człowieka (D1).
2. **Przełącznik „Dołącz dane z profilu” z podglądem** (ref sos.png, spec P2). Test `call_panel_test.dart`
   „no switch/hints; SMS always includes profile data” koduje późniejszą decyzję: bez przełącznika. Poza tym
   to logika SMS, nie polish.
3. **999/998/997 schowane w „Więcej”** (ref sos.png, DS decyzja 4). Testy `call_panel_test.dart` i
   `call_panel_view_test.dart` („999 / 998 / 997 are visible and dial without "Więcej"”) kodują decyzję: widoczne
   bez rozwijania. Zostają widoczne, tylko ciszej.
4. **Usunięcie pigułki 112 z przypiętego RKO** (ref rko.png jej nie ma). 112 jest nietykalne — zostaje, przeniesione
   do linii meta.
5. **Meta „110 uciśnięć na minutę”** zamiast „110/min” (ref). To dopisanie słów do instrukcji RKO; zostaje „110/min”.
6. **Format stopera „1:28”** (ref) zamiast „01:28” — `formatCprElapsed` jest w `wspolne/shell/cpr_state.dart`
   (wspólny, używa go też `CprIndicator`). Nie ruszam.
7. Dialog „Zakończyć RKO?”, `Switch` w `SignalPanel`, arkusz P2 (uchwyt, promień, tło) — wygląd z motywu/hosta
   wspólnego.
8. Logika: `detect/`, `cpr_engine/session/config/ports`, `sms_body`, `sos_pattern`, `call_gps`, `content/` — bez zmian.

## Do decyzji (koordynator / właściciel)

- **D1 — wielkość liter.** DS i ref: „Zadzwoń 112”, „Powiadom bliskich”, „Uciskaj”. Spec P2 („Teksty”, kryteria
  akceptacji) i testy integracyjne: „ZADZWOŃ 112”, „POWIADOM BLISKICH”. Słowa te same, inna typografia.
  Domyślnie w fazie 2: **112 i SMS zostają WERSALIKAMI** (spec dosłownie), „UCISKAJ”/„PAUZA” → „Uciskaj”/„Pauza”
  (spec głosu i DS). Jeśli właściciel zgodzi się na „Zadzwoń 112” — zmieniam stałe + 2 testy integracyjne.
- **D2 — 112 w przypiętym RKO.** Zostaje (nietykalne), na końcu linii meta. Ref go nie ma.
- **D3 — link „Zmień” przy odbiorcach.** Rekomenduję usunąć (cel pomyłki w panelu alarmowym; edycja w Profilu).
  Bez zgody: zostaje jako cichy link pod przyciskiem SMS.

## Propozycje tokenów

- **T1 `call-label`** 20/26 w800 — etykieta dużych przycisków `CallPanel` (DS `.bz-call__btn .bz-btn__label`).
  Dziś najbliższy `step` 20/28 w700; użyję `step.copyWith(fontWeight: w800, height: 26/20)`.
- **T2 `phase`** 28/34 w700 bez cyfr tabelarycznych — faza RKO (DS `.bz-cpr__phase`). Dziś najbliższy `readout` 28/32.
- **T3 `call-sub`** 14/18 w500 — podpis dużych przycisków. Najbliższy `label` 14/20 w600 → `copyWith(w500)`.
- **T4 `beat-size` 10 dp** — kropka metronomu (DS `.bz-beat`). Dziś literal 10, jak w obecnym `_Dots`.

## Prośby do innych zakresów

- **P1 (wspólny — `czat/templates/panel_card.dart`):** `PanelCard` z wariantem `sos` wg DS `.bz-panel--sos`
  (ramka `sos`, tło `sosTint`, tytuł `sosText`). Potrzebne dla grupy „Wezwij pomoc”. Bez tego zrobię lokalny
  `DecoratedBox` w `call_panel_view.dart` z tymi samymi tokenami.
- **P2 (wspólny — `SourceChip`):** w ref chip ma ikonę książki (`LucideIcons.bookOpen`) zamiast prefiksu „▸”
  („ERC 2025, BLS krok po kroku, s. 3”). Treść źródła bez zmian. Dotyczy `panel_model.dart` `chipLabel` i
  `panel_card.dart` `SourceChip` (oraz bliźniaczy `chipLabel` w `ratunek/cards/rescue_card.dart:179`, jeśli
  wspólny agent chce spójności — mogę go zmienić sam).
- **P3 (czat — `czat/templates/template_renderer.dart`):** etykieta „Karta ratunkowa” z ikoną `heartPulse` 16 dp
  `ink300`, tekst `label` `ink300` (ref); odstęp etykieta–odznaka `space2`. Stopka „nie zastępuje 112” bez zmian.
- **P4 (wspólny — `wspolne/shell/panel_host.dart`):** arkusz P2 jak w ref: uchwyt 36×4 `line200`, górne rogi
  `radiusXl`, tło `bg200`. Sprawdzę na zrzucie „przed” i potwierdzę w fazie 2.
- **P5 (wspólny — `CprIndicator`):** spójność z `CprPinned` (kropka beat `sosText` zamiast innej sygnalizacji),
  jeśli wspólny agent ją rusza.

---

## Dziennik wykonania (faza 2 przyspieszona, decyzja właściciela: limit 1 h)

Bez czekania na wspólne komponenty. Decyzje domyślne: D1 — „ZADZWOŃ 112” / „POWIADOM BLISKICH” zostają
wersalikami, „UCISKAJ”/„PAUZA” → „Uciskaj”/„Pauza”; D2 — 112 zostaje w przypiętym RKO; D3 — „Zmień” zostaje
(cichy link w wierszu GPS). P1 (PanelCard `sos`) zrobione lokalnie w `call_panel.dart` (`DecoratedBox` z tokenami).

| Commit | Ekran | Zakres |
| --- | --- | --- |
| `bc44b41` | karta ratunkowa | grupa „Wezwij pomoc” (ramka `sos`, tło `sosTint`, tytuł `sosText`), przyciski DS (`radiusLg`, do lewej, 20/26 w800, obrys `line200`, ikona `users`), odbiorcy w podpisie SMS, cichy wiersz 999/998/997 + „Więcej”, odznaka-pigułka |
| `010efc2` | RKO | jedna kropka-metronom, „Uciskaj 17 z 30”, linia meta z 112, Pauza/Zakończ w 2 kolumnach, baner zmiany `sosTint/sosText` + czerwona ramka, karta w trakcie z meta i chipem, „Zacznij uciskanie” 44 px |
| `b6cdbaa` | SOS | wiersz GPS + „Zmień”, współrzędne `step` zamiast `readout`, nagłówki sekcji `ink200` (nagłówek `step` i wiersz numerów weszły w `bc44b41`, bo komponent jest wspólny) |
| `a9643d2` | RKO | licznik przy prawej krawędzi |
| `844a5f5` | karta ratunkowa | dolny padding grupy |

### Usunięte teksty (dosłownie, przed zmianą)

- `alarm/panel/call_panel.dart:241` — `'Do: ${…}'` jako osobny wiersz → treść przeniesiona do podpisu „SMS z lokalizacją do: Mama”.
- `alarm/panel/call_panel.dart:301` — separator `' · '` w `'$n · $name'` → „999 Pogotowie” (waga/kolor).
- `ratunek/cpr/cpr_view.dart:510` — prefiks `'Czas '` przed stoperem.
- `ratunek/cpr/cpr_view.dart:431` — osobny wiersz `'RKO · Dorosły'` → początek linii meta (tekst zostaje).
- `ratunek/cpr/cpr_view.dart:516` — `'Zmiana za'` → `'zmiana za'` (środek zdania, wielka litera tylko).

Testy zaktualizowane: `test/ratunek/cards/verify_badge_test.dart`, `test/ratunek/cpr/cpr_view_test.dart`,
`test/alarm/panel/call_panel_test.dart`, `test/czat/templates/call/call_panel_view_test.dart`.
