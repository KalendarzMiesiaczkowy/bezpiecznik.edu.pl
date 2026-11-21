# POLISH — UX/UI aplikacji (branch `polish/ui`)

Stan: 2026-11-21, ~13:00. Bazą jest `night/mvp` 5bf3218. Pięć zakresów robiło zmiany równolegle, każdy na swoim worktree i emulatorze, potem wszystko scalono w `polish/ui`.
Weryfikacja po scaleniu: `flutter analyze` daje 0 problemów (przed też 0). `flutter test`: 772 zaliczone, 2 pominięte, 0 błędów (przed: 768 / 2 / 0), łącznie z `font_scale_2_test`.
Zrzuty: `polish/before/`, `polish/after/` (emulator, Pixel 7, 1080×2400). Porównania przed|po: `polish/compare/*.png`. Minutowe demo: `polish/compare/demo.mp4`. Referencja: `polish/ref/`.

Szczegółowe plany (po co jest ekran, akcja główna, plan zmian, usunięte teksty z plikiem i linią, propozycje tokenów) są w `polish/plan/`:
- `wspolne.md`: przyciski, chip źródła, arkusze, wyspa, przełącznik segmentowy
- `czat.md`: czat E1
- `ratunek-sos.md`: karta ratunkowa, RKO, alarm/SOS
- `mapa.md`: mapa, arkusz punktu, kompas, karta mapy
- `formularze.md`: onboarding, profil, ustawienia

## Ekrany: cel i akcja główna

| Ekran | Po co tu jest | Akcja główna |
|---|---|---|
| Onboarding | Raz poznać zasady i zgody, zanim aplikacja będzie potrzebna | „Dalej” (jeden `primary` na krok) |
| Czat | Opisać sytuację i dostać kroki ze źródłem | Pole „Opisz sytuację…” / kafelek |
| Karta ratunkowa | Natychmiast wezwać pomoc i działać | „Zadzwoń 112” |
| RKO | Utrzymać rytm uciśnięć | Uciskanie (licznik + metronom) |
| SOS | Połączyć się ze służbami | „Zadzwoń 112” |
| Mapa | Znaleźć najbliższy schron | „Najbliższy schron” |
| Kompas | Dojść do punktu bez mapy | Kierunek + odległość |
| Profil | Uzupełnić dane domu do SMS-a i porad | Pola (autozapis) |
| Ustawienia | Zmienić profil, wygląd, prywatność | „Profil domu” |

## Usunięte teksty (dosłownie; plik:linia przed zmianą)

- `czat/templates/panel_card.dart:97`: „▸ ” (prefiks chipa źródła; zastąpiony ikoną książki)
- `onboarding/onboarding_screen.dart:222`: „Zostaje w telefonie. Wysyłasz go tylko ty.” (krok wcześniej, l. 196, mówi to samo)
- `profil/profile_form.dart:317`: „Pomoże dopasować porady.”
- `profil/profile_form.dart:266`: „Np. insulina.” (przeniesione do placeholdera)
- `profil/profile_form.dart:316`: etykieta „Np. choroby, diety” (stała się placeholderem)
- `profil/profile_form.dart:283`, `:377`: „+ ” w etykietach przycisków (zastąpione ikoną)
- `ustawienia/settings_screen.dart:136`: „Tak będzie wyglądał tekst instrukcji.”
- `ustawienia/settings_screen.dart:73`: nagłówek „Profil” (powtarzał „Profil domu”)
- `mapa/map_screen.dart:40`: „Kopiuję mapę na telefon. ” (powtarzał tytuł „Przygotowuję mapę…”)
- `mapa/map_screen.dart:601`: „● Mapa szczegółowa” (wskaźnik zostaje tylko poza obszarem szczegółowym)
- `czat/templates/map/map_card_view.dart:24`: „Odległości nieznane. ”
- `alarm/panel/call_panel.dart:241`: osobny wiersz „Do: …” (odbiorcy przeniesieni do podpisu przycisku SMS)
- `alarm/panel/call_panel.dart:301`: separator „ · ” w „999 · Pogotowie”
- `ratunek/cpr/cpr_view.dart:510`: „Czas ” przed stoperem
- `ratunek/cpr/cpr_view.dart:431`: osobny wiersz „RKO · Dorosły” (ten sam tekst otwiera linię meta)

Treści bezpieczeństwa są bez zmian: 112/999/998/997, „nie zastępuje 112”, „Do weryfikacji”, źródła i cytaty, treść kart i instrukcji RKO. Wielkość liter zmieniła się tylko w fazach RKO („UCISKAJ” → „Uciskaj”, „PAUZA” → „Pauza”).

## Decyzje dla człowieka

1. „ZADZWOŃ 112” i „POWIADOM BLISKICH” zostają wersalikami, bo tak dosłownie podaje spec P2. Referencja i DS mają „Zadzwoń 112”. Podpis 112 to „Numer alarmowy”, a referencja ma „Pogotowie, straż, policja”.
2. Ikona kafelka „Ktoś nie oddycha” jest szara, jak w referencji. DS (QuickActions) chce `sos-text`. Powrót to jedna linia.
3. Wiersze panelu bocznego mają 48 dp (wymóg briefu), a DS z 21.11 mówi 44.
4. Przycisk 112 w przypiętym RKO zostaje, choć w referencji go nie ma.
5. W SOS nie ma przełącznika „Dołącz dane z profilu”, a numery 999/998/997 są widoczne bez rozwijania. Tak kodują obecne testy i logika SMS, a referencja pokazuje inaczej.
6. Na mapie „Prowadź” i „Kompas” w MVP robią to samo. Oba zostały.
7. „Sieć służy tylko do pobierania paczek.” (ustawienia) to deklaracja prywatności. Zostawiona, choć paczki są w APK.
8. SOS ma 48 dp, a nie 56 jak w DS, bo dziś zmniejszono go commitem `fbe50c2`.

## Propozycje tokenów (`tokens.json` nietknięty)

- `display-xl` (~64): odległość w kompasie. Dziś 40 dp.
- `title-sm` 18/24/700: tytuły arkuszy i dialogów.
- `body` 16/22 i `type.cardTitle` 16/22/700: tytuły kart, wiersze list.
- Etykiety dużych przycisków 20/26/800 z podpisem; etykiety przycisków 13/15/16.
- Faza RKO 28/34; kropka metronomu 10 dp.
- `space-1-5` = 6 dp; `radius-check` = 7 dp; `size.icon.md` = 20.
- Stałe z CSS DS bez tokenów: chip 28, uchwyt arkusza 36×5, separator wyspy 20.

## Świadomie pominięte

- **Wspólny nagłówek arkusza z X.** Mapa i źródło zamykają się gestem albo przyciskiem „Zamknij”. X ma tylko SOS.
- **`PanelCard`:** wariant `sos` jest zrobiony lokalnie w `call_panel.dart`. Nie ma wariantu z ikoną: profil i ustawienia mają lokalny `SectionCard`. Promień 18 zamiast ~12 z referencji.
- **Szczegóły czatu:**
  - podświetlenie cytowanego zdania w arkuszu źródła (wymaga danych);
  - lista punktowana, dymek, NoSource i pigułka „Nowa odpowiedź” są bez polishu;
  - checkbox kroku odsunięty o 12 dp.
- **Formularze:**
  - etykiety nad polami (zostały wewnątrz ramki);
  - Piętro i Winda w jednym wierszu;
  - `BzChip` ma cel dotyku 40 dp, bo tego wymaga obecny test.
- **Detale komponentów:**
  - `SosButton` bez przyciemnienia przy przytrzymaniu;
  - `ShellIconButton` bez focus ringu;
  - ruch arkuszy 200/200 zamiast 300/200 ms;
  - wygląd Switch jak w Material 3;
  - kolor podtytułu `ListTile`.
- **Zachowanie, nie wygląd** (poza zakresem polishu):
  - „przepis na pierogi” dostaje od modelu pogawędkę zamiast odmowy;
  - „Najbliższy schron” bez GPS nie jest wyłączony.
- **`polish/ref/roznice.md` nie powstał.** Referencją są same zrzuty, bo brief zabrania czytać kod landingu.
- **Niestabilny `test/mapa/map_screen_test.dart`** pod obciążeniem. Agent mapy poprawił czekanie w helperze testu.
