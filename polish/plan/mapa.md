# Plan polish: mapa + kompas + karta mapy w czacie (agent MAP)

Branch `polish/map`, emulator `emulator-5564`. Faza 1: audyt kodu + zrzuty „przed”.
Baseline `flutter analyze`: **0 problemów** (`polish/tools/analyze-baseline-map.txt`).
Zrzuty przed: `polish/before/{mapa,mapa-najblizsze,mapa-punkt,kompas}.png` (wspólne u koordynatora + moje).
Referencja: `polish/ref/kompas.png` (kompas), `polish/ref/sos.png` (wygląd arkusza). Mapa nie ma refu.

Zasady wspólne dla całego zakresu:
- Tylko tokeny (`context.bz`): odstępy `space1..7`, promienie `radius*`, typografia `display/title/step/chat/label/caption/readout`.
  Twarde liczby z kodu (16, 24, 72, `space2 + 2`, `vertical: 2`, ikona 22/18) → najbliższy token.
- Przyciski: wszędzie `BzButton` (stany pressed/hover/focus/disabled 38 %/loading już są). Usuwam lokalny
  `BzButtonLike` (`TextButton` w kolorze `signal`) i `FilledButton/OutlinedButton` z `minimumSize`.
- Etykiety przycisków nigdy nie ucinane: przy skali > 1,15 para przycisków układa się w kolumnę (wzorzec już jest w kompasie).
- Słowa z tabeli tekstów spec (`ekran-2-mapa.md`) zostają; zmieniam wygląd, nie treść. Podpis OSM nietykalny.

---

## E2 · Mapa (`app/lib/mapa/map_screen.dart`, `gps_status.dart`)

**Po co tu jest:** zobaczyć, gdzie jestem, i bez internetu znaleźć najbliższe schronienie.

**Akcja główna:** **Najbliższy schron** (pełna szerokość, na dole).

### Plan zmian

| Widget / plik | Zmiana | Token |
| --- | --- | --- |
| `build` → przycisk „Najbliższy schron” (map_screen.dart:566-572) | `FilledButton` → `BzButton(variant: primary, size: xl, fullWidth: true, icon: LucideIcons.shield)`; jedyny wypełniony element na ekranie | `action`/`onAction`, wys. 56 |
| `build` → kolumna dolna (map_screen.dart:537-579) | `left/right/bottom: 16` → `space4`; `SizedBox(height: space2 + 2)` → `space2`; odstęp nad przyciskiem głównym `space3` | `space2/3/4` |
| `build` → `Positioned` notki (map_screen.dart:529-535) | `+ 8` / `16` → `space2` / `space4` | `space2/4` |
| `RecenterButton` (map_screen.dart:636-680) | wyłączony: `Opacity 0.45` → `0.38` (jak `BzButton`); ikona 22 → 20 (`BzButtonSize.md.iconSize`); dodać stan pressed przez `overlayPress` (InkResponse `highlightColor`) | `overlayPress`, `ink100`/`info` |
| `LayersButton` (map_screen.dart:683-723) | ikona 18 → 20, padding `space4` zostaje; stan pressed `overlayPress`; drugorzędny (pigułka `bg200` + 1 px `line150`) | `bg200`, `line150`, `label` |
| `_detailIndicator` (map_screen.dart:587-606) | pokazywać **tylko** poza mapą szczegółową (stan, który coś mówi); wtedy wariant `Notice bar` jak GPS (spójny wygląd: `bg200`, 1 px `line150`, `radiusMd`) zamiast pigułki `radiusLg` | `bg200`, `line150`, `radiusMd`, `caption` |
| `MapNotice` (map_screen.dart:726-764) | dodać ikonę stanu po lewej (`LucideIcons.locateOff` brak GPS/zgody, `mapPinOff` poza mapą), 20 dp `ink200`; akcja „Otwórz ustawienia telefonu” → `BzButton(secondary, sm)` (hit 48 dp) zamiast `TextButton` w `signal` | `ink200`, `space2/3` |
| `BzButtonLike` (map_screen.dart:767-785) | **usunąć klasę**; użycia → `BzButton` | — |
| `AttributionLabel` (map_screen.dart:787-804) | tylko `vertical: 2` → `space1`/2 (bez zmiany treści i miejsca) | `space1` |
| `_Preparing` (map_screen.dart:806-842) | pasek postępu z zaokrągleniem (`borderRadius: radiusFull`), szerokość max ~240 dp; tytuł `title`, opis `chat ink200` zostają | `radiusFull`, `signal`, `bg300` |
| `_InstallError` (map_screen.dart:844-868) | brak paddingu (tekst może dotknąć krawędzi) → `EdgeInsets.all(space6)` jak `_Preparing`; „Spróbuj ponownie” → `BzButton(primary, lg)` (jedyna akcja tego stanu) | `space6`, `action` |
| `_showNearest` / `_showPoint` / `_showLayers` (map_screen.dart:364-449) | usunąć nadpisania `backgroundColor: bg200/bg100` → motyw arkusza (`bg100`, 1 px `line150`, `radiusXl`, uchwyt) jak `sos.png`; wszystkie trzy arkusze jednakowe | `bg100`, `line150`, `radiusXl` |
| Arkusz `layers` (map_screen.dart:425-447) | nagłówek jak w `sos.png`: [X Zamknij 48 dp] + tytuł „Warstwy” (`title`); wiersz `ShelterLayerToggle` z paddingiem `space4` | `title`, `space4` |

### Arkusz `nearest` (`punkty/point_sheet.dart`, `NearestList`)

| Widget | Zmiana | Token |
| --- | --- | --- |
| `NearestList.build` (point_sheet.dart:295-311) | nagłówek [X] + „Najbliższe schronienie” jak `sos.png`; padding `space4`, dół `space5` + SafeArea | `title`, `space4/5` |
| `_row` symbol (point_sheet.dart:326-329) | tekst `'S'` / `'s?'` → mały `PointMarker` 32 dp w języku markerów mapy (`shelter_layer.dart`: pełny `verified` z literą S/U/M; pusty przerywany pierścień `ink300` z „?”). Jeden widżet, używany też w karcie czatu | `verified`, `ink300`, `ink200`, `bg000` |
| `_row` (point_sheet.dart:313-353) | `InkWell` z `radiusMd` i poziomym paddingiem `space2`; wys. min 56 zostaje; odległość `label` z cyframi tabelarycznymi, strzałka `BearingArrow` `ink200`; separator 1 px `line100` między wierszami | `radiusMd`, `line100` |
| pusto (point_sheet.dart:305-306) | `chat` → `chat ink200` | `ink200` |

### Arkusz `point` (`punkty/point_sheet.dart`, `PointSheet`)

| Widget | Zmiana | Token |
| --- | --- | --- |
| hierarchia (point_sheet.dart:208-268) | 3 grupy: **tożsamość** (rodzaj `caption ink200`, nazwa `title`, adres `chat ink200`) → `space4` → **dojście** (odległość duża `readout` 28 tabelaryczne + kierunek świata `label ink200` + `BearingArrow`; dostępność `label`) → `space4` → **pochodzenie** (status, źródło, ostrzeżenie o wieku) → `space5` → przyciski | `readout`, `title`, `space4/5` |
| status (point_sheet.dart:232-239) | „✓ Potwierdzony” jako chip (`verifiedTint` tło, `verified` tekst, `radiusFull`, 28 dp) jak chipy źródeł w refie; „? Niepotwierdzony…” zostaje pełnym zdaniem `label ink100` (to informacja bezpieczeństwa) | `verifiedTint`, `verified`, `source` |
| ostrzeżenie wieku (point_sheet.dart:244-248) | kolor `highlight` (ochra 40 % alfa, słaby kontrast na `bg100`) → `signal` (AA) | `signal` |
| przyciski (point_sheet.dart:250-268) | `FilledButton`/`OutlinedButton` → `BzButton(primary, lg)` „Prowadź” + `BzButton(secondary, lg, icon: compass)` „Kompas”; kolumna przy skali > 1,15 | `action`, `line150` |
| padding (point_sheet.dart:207) | `24` → `space5` | `space5` |

### Teksty do usunięcia (kandydaci)

| Tekst (dosłownie) | Plik:linia | Test briefu |
| --- | --- | --- |
| `● Mapa szczegółowa` (`'● $detailedMapText'`, stała `detailedMapText`) | map_screen.dart:601 (stała: punkty/points_db.dart:210) | W normalnym stanie (w zasięgu) nic nie mówi i nie wymaga działania; po usunięciu użytkownik nie wie mniej. Wariant „Poza mapą szczegółową…” **zostaje** (uczciwa informacja o zasięgu). Stała w `points_db.dart` (poza zakresem) zostaje nieużywana w UI; nie ruszam pliku. |
| `Kopiuję mapę na telefon. ` (pierwsze zdanie `preparingBody`) | map_screen.dart:40 | Powtarza tytuł „Przygotowuję mapę…”. Zostaje: „Dzieje się to tylko raz. Potem mapa działa bez internetu.” (mówi, że czekanie jest jednorazowe). Tekst roboczy (`verify:true`), nie ze spec. |

Nie usuwam: komunikatów GPS, zgody, „Brak sygnału GPS.”, „Ostatnia pozycja…”, statusu potwierdzenia, „Źródło…”, ostrzeżenia o wieku danych, podpisu OSM, tekstu braku miejsca.

### Świadomie pominięte (mapa)
- **Prowadź i Kompas robią to samo** (w MVP Prowadź = kompas, map_screen.dart:372). Dwa przyciski na jedną akcję to szum, ale oba są w spec (`map.point.guide`, `map.point.compass`) i Prowadź dostanie trasy po MVP. Zostawiam, flaguję człowiekowi.
- „Najbliższy schron” bez GPS powinien być nieaktywny z podpowiedzią (spec, Stany: Brak GPS) — to logika, nie polish.
- Style mapy / kafelki / kolory markerów na mapie (`renderMarkerPng`) — dane/wygląd mapy poza zakresem.
- `shadowFloat` na pływających przyciskach (wspólne `shellFloatDecoration`) — 1 poziom elevation, dozwolone.
- Nieaktualny komentarz w `shelter_layer.dart:hitTest` („circles are only 18 dp”, marker ma 36 dp) — zostawiam, plik to logika trafień.

---

## Kompas (`app/lib/mapa/kompas/compass_screen.dart`)

**Po co tu jest:** iść w linii prostej do wybranego punktu, gdy mapa nic nie da (brak trasy, słaby GPS, oszczędzanie baterii).

**Akcja główna:** brak przycisku — główną „akcją” jest odczyt strzałki i odległości; oba przyciski (Pokaż mapę, Zakończ) są drugorzędne i równorzędne (jak w refie: dwa obrysowane).

### Plan zmian (do `ref/kompas.png`)

| Widget | Zmiana | Token |
| --- | --- | --- |
| tytuł „Do: …” (compass_screen.dart:641-647) | wyśrodkowany, `title` 24/700 → `step` 20/700 (ref: mniejszy, spokojny nagłówek); maks. 2 linie bez ucięcia przy 200 % (zawija się) | `step`, `ink100` |
| górny odstęp `72` (compass_screen.dart:638) | → `space7 + space5` (48 + 24; pod wyspą/SOS) | `space5/7` |
| strzałka (compass_screen.dart:708-716) | `Icon(arrowUp, 200, ink100)` → **tarcza**: `CustomPainter` — okrąg 2 dp `line150`, 4 kreski N/E/S/W 3 dp `line200`, wypełniona strzałka-latawiec w `signal` (ochra) obracana o `angleDeg`; średnica `min(260, szer. × 0,66)`, mniejsza, gdy brak miejsca (200 %). Bez czujnika i w miejscu: sama tarcza bez strzałki | `line150`, `line200`, `signal` |
| odległość (compass_screen.dart:718) | `display` + `FontFeature.tabularFigures()`, kolor `ink100`; ref ma ok. 64 dp → patrz Propozycje tokenów | `display` |
| kierunek świata (compass_screen.dart:720) | `title ink100` → `step ink200` (ref: szary, drugi poziom) | `step`, `ink200` |
| współrzędne (compass_screen.dart:727-731) | `caption ink200` + cyfry tabelaryczne (ref) | `caption`, `ink200` |
| notka (kalibracja / ostatni fix) (compass_screen.dart:648-652) | tekst `chat signal` → `MapNotice` (DS `Notice bar`, jak na mapie; DS wymienia kalibrację jako `Notice`) | `bg200`, `line150`, `radiusMd` |
| przyciski (compass_screen.dart:668-695) | `BzButton(secondary, xl)` → `BzButton(secondary, lg)` jak ref (44 dp wizualnie, hit 48); „Pokaż mapę” z ikoną `LucideIcons.map` (ref) | `line150`, `ink100` |
| rytm pionowy | tarcza → `space6` → odległość → `space3` → kierunek → `space5` → współrzędne | `space3/5/6` |

### Teksty do usunięcia
Brak. Wszystkie teksty kompasu są w tabeli spec (`map.compass.*`) i niosą informację (kalibracja, brak GPS, brak czujnika). Uwaga: ref pokazuje „Do: najbliższy schron”; spec mówi „Do: {rodzaj}, {nazwa}” — zostaje spec.

### Świadomie pominięte (kompas)
- Rozmiar cyfr 64 dp z refu — brak tokenu; używam `display` (40) do decyzji człowieka.
- Kreski tarczy są stałe względem ekranu (jak w refie), nie róża wiatrów obracana z północą — to byłaby nowa funkcja.

---

## Karta mapy w czacie (`app/lib/czat/templates/map/map_card_view.dart`)

**Po co tu jest:** w rozmowie pokazać najbliższe schronienie (gdzie, jak daleko, czy potwierdzone) i przenieść na mapę.

**Akcja główna:** **Prowadź** (z pozycją) / **Pokaż na mapie** (bez pozycji).

### Plan zmian

| Widget | Zmiana | Token |
| --- | --- | --- |
| `_KindMarker` (map_card_view.dart:287-311) | koło `ink100` z tarczą-ikoną → wspólny `PointMarker` z `point_sheet.dart` (ten sam język co marker na mapie i w liście `nearest`: litera S/U/M na `verified`, „?” w przerywanym pierścieniu). Klasa `_KindMarker` znika | `verified`, `ink300` |
| strzałka kierunku (map_card_view.dart:254-263) | `navigation2` 24 → `BearingArrow` (jak w arkuszach), `ink200` | `ink200` |
| wiersz punktu (map_card_view.dart:222-266) | tekst: nazwa `label` → `step`? nie — zostaje `label` 600; odległość `label ink100` z cyframi tabelarycznymi; „niepotwierdzony” i „Dane sprzed …” w jednej linii `caption ink200` rozdzielone „ · ” (mniej wierszy, te same słowa) | `caption`, `ink200` |
| `_SourceChip` (map_card_view.dart:314-373) | szary chip z tarczą → wygląd DS `SourceChip` (28 dp, `radiusFull`, padding `space3`): potwierdzony = `verifiedTint`/`verified`, niepotwierdzony = `bg200`/`ink200` (nie udaje weryfikacji). Treść i dialog bez zmian | `verifiedTint`, `verified`, `bg200`, `source` |
| przycisk (map_card_view.dart:274-281) | `FilledButton` → `BzButton(primary, lg, fullWidth, icon: navigation2)` | `action` |
| mini mapa (map_card_view.dart:187-214) | bez zmian rysunku; ramka 1 px `line100` dla odcięcia od `bg100` karty | `line100` |

### Teksty do usunięcia (kandydaci)

| Tekst (dosłownie) | Plik:linia | Test briefu |
| --- | --- | --- |
| `Odległości nieznane. ` (początek `mapUnknownDistancesText`) | map_card_view.dart:24 | Wynika z linii wyżej „Nie znam twojej pozycji.”; po usunięciu użytkownik nie wie mniej. Zostaje „Poniżej schrony najbliżej centrum Szczecina.” (kluczowe: punkt NIE jest koło niego). Tekst roboczy `verify:true`. Test `test/czat/templates/map/map_card_view_test.dart:264` używa stałej, więc przejdzie. |

### Świadomie pominięte (karta)
- „{d} w linii prostej · ok. {n} min” — „w linii prostej” to uczciwość (brak trasy), zostaje.
- Etykieta semantyczna „Mini mapa. Pokaż punkt na mapie” — tylko dla czytnika, zostaje.

---

## Propozycje tokenów
1. **`display-xl`**: 64 / 68, 800, `tabularFigures`, `letterSpacing −1.2` — odczyt odległości w kompasie (ref „810 m”). Do tego czasu `display` 40.
2. **`readout` z cyframi tabelarycznymi już jest** (28) — użyję go w arkuszu punktu; nic nowego.
3. (Do rozważenia) **`opacity-disabled = 0.38`** jako token — dziś zaszyte w `BzButton`, a `RecenterButton` miał 0.45.

## Prośby do innych zakresów
1. **Wspólne (`wspolne/**`)**: komponent nagłówka arkusza `BzSheetHeader` ([X Zamknij 48 dp] + tytuł `title`) — dziś osobno w `call_panel.dart:200-207`; mapa ma 3 arkusze z tym samym wzorcem. Jeśli nie powstanie, zrobię lokalną kopię w `point_sheet.dart` 1:1 z `call_panel.dart`.
2. **Wspólne (`czat/templates/panel_card.dart`)**: `SourceChip` przyjmuje tylko `SourceRecord` (PDF). Prośba o wariant z gołą etykietą i tonem `neutral` (`bg200`/`ink200`) — wtedy karta mapy użyje wspólnego chipa zamiast lokalnego `_SourceChip`.
3. **Wspólne (`shell_icon_button.dart`)**: `shellFloatDecoration` — bez zmian; tylko informacyjnie: mapa nadal korzysta z niego dla „Warstwy” i ◎.
4. **Właściciel / spec**: decyzja, czy w MVP zostawić oba przyciski Prowadź + Kompas (robią to samo).

---

## Dziennik realizacji (faza 2, skrócona do 1 h decyzją właściciela)

Commity: `8ee827b` kompas, mapa+karta (ten plik dołączony do commitu mapy).
`flutter analyze`: 0 problemów (baseline 0). `flutter test`: 768 passed, 2 skipped, 0 failed.
Zrzuty po: `polish/after/{mapa,mapa-najblizsze,mapa-punkt,kompas}.png` (emulator-5564).

### Usunięte teksty (dosłownie, plik:linia przed zmianą)
1. `Kopiuję mapę na telefon. ` — `app/lib/mapa/map_screen.dart:40` (`preparingBody`); zostało „Dzieje się to tylko raz. Potem mapa działa bez internetu.”
2. `● Mapa szczegółowa` — `app/lib/mapa/map_screen.dart:601` (`'● $detailedMapText'`); wskaźnik pokazuje się już tylko poza mapą szczegółową (`outsideRegionText` bez zmian).
3. `Odległości nieznane. ` — `app/lib/czat/templates/map/map_card_view.dart:24` (`mapUnknownDistancesText`); zostało „Poniżej schrony najbliżej centrum Szczecina.”

### Odstępstwa od planu
- Arkusz punktu: odległość w `step` (20), nie `readout` (28) — linia zawiera też kierunek świata i przy 28 zawijała się.
- Nagłówek arkuszy z [X] (jak `sos.png`) — nie zrobiony: brak wspólnego komponentu, a lokalna kopia to dublowanie `call_panel.dart`; arkusze mają uchwyt i zamykają się gestem/scrimem. Prośba 1 aktualna.
- `_SourceChip` karty mapy przestylowany lokalnie (wygląd DS `SourceChip`), bo wspólny przyjmuje tylko `SourceRecord`. Prośba 2 aktualna.
- `test/mapa/map_screen_test.dart`: helper `pump` czekał stałe 0,4 s na instalator plików — flaky przy równoległym `flutter test` (padało też przed moimi zmianami); teraz czeka do zniknięcia „Przygotowuję mapę…” (maks. ~2 s).
