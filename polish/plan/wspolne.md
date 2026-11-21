# Wspólne komponenty — plan i dziennik (branch `polish/shared`)

**Po co to jest:** każdy ekran składa się z tych samych przycisków, kart, chipów i arkuszy — mają wyglądać jak w `polish/ref/` i DS (`bezpiecznik/08-design-system/components/bundle.css`).
**Akcja główna:** brak (to biblioteka); jedyny jasny przycisk `action` na ekran wybierają ekrany.

Stan bazowy: `flutter analyze` 0 problemów, `flutter test` 768 zielonych / 2 pominięte (`polish/tools/log/analyze-baseline.txt`, `test-baseline-tail.txt`).
Termin skrócony przez właściciela do 13:12 — zrobione są najbardziej widoczne rzeczy, reszta w „Świadomie pominięte”.

## Audyt i zmiany

| Komponent | Co było nie tak (vs ref / DS) | Zmiana | Tokeny |
| --- | --- | --- | --- |
| `SourceChip` (`czat/templates/panel_card.dart`) | Znak „▸” zamiast ikony książki z ref/DS (glifu nie ma w Atkinson — na urządzeniu szedł z fontu zastępczego); `maxLines: 1` + wielokropek ucinał numer strony przy długim tytule; w zwykłej kolumnie chip rozciągał się na całą szerokość; brak stanu pressed. | Ikona `bookOpen` 16 + tekst `{doc_short}, s. {page}`; tekst zawija się do kolejnych linii, „s. N” spięte twardą spacją (numer strony nigdy nie znika ani nie odrywa się); chip kurczy się do treści; pressed = `overlay-press` na `verified-tint`. | `verified`, `verified-tint`, `overlay-press`, `space-1/2/3`, `radius-lg` (1 linia = pigułka, 2 linie = zaokrąglony prostokąt), `source`, `duration-fast` |
| `PanelCard` | Zgodny z DS i ref (próbki pikseli z ref: tło `#181715` = `bg-100`, ramka `#282623` = `line-100`, promień 18). | Bez zmian. | — |
| `BzButton` | Stała wysokość ucinała etykietę przy czcionce 200 %; focus ring rysowany na krawędzi (ochra na jasnym `action` niewidoczna, DS: 2 px z odstępem 2 px); `dangerSolid` bez stanu pressed; etykieta wariantu z podpisem w `xl` 16/600 zamiast DS 20/800. | `minHeight` zamiast `height` (pigułka rośnie z czcionką); ring `signal` 2 px odsunięty o 2 px; pressed dla `dangerSolid`; etykieta `xl` z podpisem 20/800. Sygnatura konstruktora bez zmian. | `signal`, `overlay-press`, `danger`, `step` (rozmiar 20) |
| `FilledButton` (motyw) | Brak focus ringu. | Ring `signal` 2 px przy focusie. | `signal` |
| Pola tekstowe (motyw) | Placeholder 16 px, wpisany tekst 17 px (skok przy pisaniu); padding 14/12 spoza siatki. | Placeholder = `chat` (jak tekst); padding `space-4`/`space-3`. | `chat`, `ink-300`, `space-3/4` |
| `NavIsland` | Brak separatora między menu a mapą (ref + DS `.bz-island__sep`). | Separator 1 × 20 dp `line-150`. Przyciski zostają 48 dp. | `line-150` |
| Arkusz P2 (`PanelHost`, dół) | Brak uchwytu i ramki — w ref `sos.png` arkusz ma uchwyt 36 × 5 i jaśniejszą krawędź. | Uchwyt 36 × 5 `line-200` (8 dp od góry, 4 dp do treści) + ramka 1 px `line-150`, promień `radius-xl`. Tak samo jak arkusze modalne z motywu (`bottomSheetTheme`). | `line-150`, `line-200`, `radius-xl`, `radius-full`, `space-1/2` |
| `BzCheck` | Promień 7 spoza tokenów. | `radius-sm` (8) + krzywa `ease-in-out`. | `radius-sm` |
| `BzSegmented` | Obszar dotyku opcji miał 42 dp (3 dp paddingu kontenera nie było klikalne); zaznaczenie przeskakiwało bez przejścia. | Cała wysokość 48 dp jest klikalna (wygląd piksel w piksel jak przed — diff renderu pusty); zaznaczenie animowane 150 ms. | `min-touch-target`, `duration-fast`, `ease-in-out` |
| Galeria (`/gallery`, debug) | Nie pokazywała wspólnych komponentów. | Sekcje: Przyciski Material, Powłoka, Karta/źródło/wybór, Formularz. | — |

## Usunięte teksty

- `▸ ` (prefiks chipa źródła) — `app/lib/czat/templates/panel_card.dart:97` (`source.chipLabel`); zastąpiony ikoną książki jak w ref i DS. `SourceRecord.chipLabel` (poza zakresem) nietknięty; etykieta czytnika ekranu bez zmian.

## Świadomie pominięte

- **SOS 56 dp (ref/DS) vs 48 dp w aplikacji** — właściciel zmniejszył go dziś commitem `fbe50c2` („SOS as big as Back”, uwagi testerów). Zostaje 48.
- **Nagłówek arkusza z X** — P2 ma go już w `alarm/panel/call_panel.dart` (poza zakresem); wspólnego `BzSheetHeader` nie dodałem (brak czasu, nikt by go jeszcze nie użył).
- **`BzSegmented`**: padding 3 dp spoza siatki zostaje (zmiana na `space-1` przesunęłaby układy ekranów o 2 dp).
- **Switch**: w Material 3 gałka wyłączonego przełącznika jest mniejsza (16 dp) niż włączonego (24 dp); DS chce stałej gałki 22 dp na torze 48 × 28.
- **`CprIndicator`**: DS — pływająca pigułka `bg-200` + `line-150` + `shadow-float`, tekst `ink-100`; teraz `sos-tint` / `sos-text`, a „●” jest znakiem tekstowym spoza fontu.
- **`SosButton`**: brak przyciemnienia przy przytrzymaniu (DS `.is-holding`), obwódka 4 px wewnątrz zamiast 3 px na zewnątrz.
- **`ShellIconButton`**: brak focus ringu `signal`.
- **Ruch arkuszy**: `PanelHost` otwiera i zamyka w 200 ms; DS: wejście 300 ms `ease-sheet`, wyjście 200 ms `ease-in`.
- **`ListTile` (motyw)**: `textColor: ink-100` nadpisuje kolor podtytułu (`ink-300` nie działa).
- **`TopFade`**: gradient zostaje celowo — DS Chrome wymaga go pod elementami pływającymi.
- **Cień arkusza P2** (`shadow-sheet`) — nie dodany; głębię daje ramka.
- **Zrzuty „przed” galerii** są z renderu na hoście (`polish/before-own/`, kod sprzed zmian); z emulatora są tylko „po” (`polish/after/wspolne-*.png`). „Przed” arkusza P2: wspólne `polish/before/sos.png`.

## Propozycje tokenów

- `title-sm` 18/24/700 — tytuł dialogu i arkusza (DS CSS ma tę wartość, tokenu brak; motyw używa `step` z nadpisanym rozmiarem).
- `body` 16/22 — tytuł `PanelCard` (16/22/700), wiersze list (16/22/400).
- Rozmiary etykiet przycisków 13/15/16 (`sm`/`lg`/`xl`) — teraz `label` z nadpisanym rozmiarem.
- `space-1-5` 6 dp — odstęp ikona–tekst w chipie i przycisku `md` (DS: 6; użyłem `space-2` w chipie).
- `radius-check` 7 dp — pole wyboru w DS; użyłem `radius-sm` 8.
- Wysokości kontrolek: chip 28, uchwyt arkusza 36 × 5, separator wyspy 20 — stałe z DS CSS bez tokenów.

## Prośby do innych zakresów

- **Wszyscy / testy:** chip źródła nie zawiera już „▸ ”. Tekst w drzewie to `'{doc_short}, s. {page}'` (twarda spacja przed numerem). W testach: `find.text('Przykład, s. 14')` albo `find.byType(SourceChip)`. Zaktualizowałem istniejące asercje w `test/czat/**`, `test/ratunek/cpr/cpr_view_test.dart`, `integration_test/demo_test.dart`.
- **Czat / ratunek:** chip sam się zawija i kurczy do treści — nie owijajcie go w `SizedBox`/`Expanded` o stałej wysokości ani nie obcinajcie etykiety; `Wrap` albo `Align(centerLeft)` wystarczy.
- **Ratunek:** `ratunek/cards/rescue_card.dart:179` ma własne `chipLabel` z „▸” — jeśli rysujecie tam własny chip, użyjcie `SourceChip`.
- **Mapa / ustawienia:** arkusze modalne dostają z motywu tło `bg-100`, uchwyt i ramkę — nie nadpisujcie `backgroundColor` (`mapa/map_screen.dart:406,424` daje `bg-200`).
- **Alarm:** P2 ma teraz uchwyt nad treścią (17 dp) — można zmniejszyć górny padding `ContactCallPanel`; `_BigButton` w `call_panel.dart` to osobny przycisk — `BzButton(sub:, size: xl)` daje już etykietę 20/800 z DS.
- **Wszyscy:** `BzButton` rośnie z czcionką (min. wysokość) — nie zamykajcie go w `SizedBox(height: …)`.

## Dowody

- Przed: `polish/before-own/gallery.png` (+ wycinki `g-1…4.png`), wspólne `polish/before/sos.png`.
- Po (host): `polish/after/wspolne-gallery.png` (+ `-1…4.png`), 200 % czcionki: `polish/after/wspolne-gallery-200pct-1.png`.
- Po (emulator-5556): `polish/after/wspolne-gallery-{material-shell,cards,form,buttons,buttons-2}.png`, `polish/after/wspolne-sos.png`, `wspolne-sos-wiecej.png`.
- `flutter analyze`: 0 → 0. `flutter test`: 768 zielonych / 2 pominięte → 771 / 2 (3 nowe testy), 0 czerwonych (`polish/tools/log/test-after-tail.txt`).
- Stopka commitów: `Claude Fable 5.2` (model, który faktycznie pisał kod; brief podawał `Opus 5.5`).
