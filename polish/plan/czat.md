# Czat (E1) — plan i dziennik

Zakres: `app/lib/czat/ui/**`, `app/lib/czat/drawer/**`, `app/lib/czat/templates/**` (bez `panel_card.dart`, `call/`, `map/`).
Referencja: `polish/ref/start.png`, `start-pisanie.png`, `czat-odpowiedz.png`, `czat-odpowiedz-2.png`, `czat-zrodlo.png`.
Wymiary referencji zmierzone z pikseli (skala do 390 dp), kolory porównane z `bz_tokens.g.dart`.
`polish/ref/roznice.md`, na który powołuje się brief, nie istnieje w worktree — różnice landing ↔ DS ustalałem sam.

**Po co tu jest:** użytkownik opisuje, co się dzieje, i dostaje kroki ze źródłem.

**Akcja główna:** wysłanie opisu sytuacji (pole wiadomości + strzałka; kafelki to skróty tej samej akcji).

## Plan zmian

Stan: ✔ zrobione w tym przebiegu · ○ pominięte (powód w „Świadomie pominięte”).

| Widok | Plik | Zmiana | Token | Stan |
|---|---|---|---|---|
| Pusty stan: kafelki | `ui/quick_actions.dart` `_Tile` | Wypełnienie zamiast ramki (ref: kafel `#181715`, bez obramowania); padding 16/14 → 16; wciśnięcie = jaśniejsze tło, 150 ms | `bg-100`, `bg-200` (pressed), `space-4`, `radius-lg`, `duration-fast` | ✔ |
| Pusty stan: ikony | `ui/quick_actions.dart` `defaultQuickActions` | Jak w ref: wszystkie ikony `ink-200` (serce też), `zap` zamiast `zap-off`, `footprints` zamiast `backpack`. Czerwień zostaje tylko na SOS | `ink-200` | ✔ (odstępstwo od DS, patrz niżej) |
| Pusty stan: nagłówek, notka | `ui/chat_screen.dart` `_EmptyChat` | Bez zmian — zgodne z ref (32/38 w800, notka `caption` `ink-300`, odstępy `space-5`) | — | — |
| Pole wiadomości | `ui/composer.dart` | Ramka `line-200` przy focusie (DS Composer), 150 ms; literały 16/12/4 → tokeny; stan wciśnięty Wyślij/Zatrzymaj | `line-150`/`line-200`, `space-1/3/4`, `overlay-press`, `duration-fast` | ✔ |
| Pole wiadomości: margines | `ui/chat_screen.dart` | 16 → 12 dp od krawędzi ekranu (ref: pigułka 12–377 dp, szersza niż kolumna treści) | `space-3` | ✔ |
| Dymek użytkownika | `ui/message_view.dart` | Bez zmian — `bg-200`, `radius-lg`, do prawej jak w ref | — | — |
| Kroki (`steps`) | `templates/steps_panel.dart` `_StepRow` | Numer wyrównany do lewej krawędzi tytułu karty; tło i pasek bieżącego kroku wychodzą 8 dp w padding karty (ref: tło 8 dp od krawędzi karty); przejście tła 200 ms przy odhaczeniu; literały 10/4 → tokeny | `overlay-hover`, `signal`, `space-1/2/3`, `radius-md`, `duration-base`, `ease-in-out` | ✔ |
| Lista (`bullets`) | `templates/bullets_panel.dart` | Bez zmian | — | ○ |
| Cytat (`quote`) | `templates/quote_panel.dart` | „Powiększ”: `OutlinedButton` 48 dp wysokości → `BzButton` `sm` (32 dp wizualnie, pole dotyku 48) jak w ref; okno papieru wydzielone do `QuotePaper` (wspólne z arkuszem źródła) | `paper`, `paper-ink`, `highlight`, `signal-press`, `radius-md` | ✔ |
| Arkusz źródła | `templates/source_sheet.dart` | Ta sama hierarchia co karta „Źródło” z ref: tytuł dokumentu (`step` zamiast `title` 24), jedna cicha linia „Strona N” + wydawca, fragment na papierze (`QuotePaper`, czcionka szeryfowa, bez zakreślenia) zamiast zwykłego tekstu czatu; literały → tokeny | `step`, `caption`, `ink-200/300`, `paper`, `paper-ink`, `radius-md`, `space-1…5` | ✔ |
| Brak w źródłach / poza tematem | `templates/no_source.dart` | Bez zmian — zgodne z DS NoSource | — | — |
| Tekst rozmowy | `templates/chat_text.dart` | Bez zmian (etykieta nietykalna) | — | — |
| Myślenie | `ui/thinking.dart` | Czas pulsu z tokenu zamiast `1200`; odstęp szkieletu 10 → 8 | `duration-pulse`, `space-2` | ✔ |
| Panel boczny | `drawer/chat_drawer.dart` | Wiersze 44 → 48 dp (pole dotyku ≥ 48 z briefu; DS rysował 44) | `min-touch-target` (48) | ✔ |

### Odstępstwo od DS do potwierdzenia przez człowieka
DS (`components/QuickActions/README.md`): „Ktoś nie oddycha” ma ikonę w `sos-text`. Referencja `start.png`: wszystkie cztery ikony `#a9a59d` (`ink-200`).
Poszedłem za referencją (brief: ekran ma wyglądać jak referencja). Powrót do DS to jedna linia w `quick_actions.dart`.

## Usunięte teksty

Żaden tekst nie został usunięty. Każdy kandydat przeszedł test z briefu („czy po usunięciu użytkownik wie mniej albo nie wie, co zrobić?”) — wszystkie zostają:

| Tekst (dosłownie) | Plik:linia (przed zmianą) | Wynik testu |
|---|---|---|
| „Rozmowy są zapisane tylko na tym telefonie.” | `drawer/chat_drawer.dart:18` | Zostaje: jedyna informacja o prywatności rozmów |
| „„{tytuł}” zniknie z telefonu na zawsze.” | `drawer/chat_drawer.dart:281` | Zostaje: mówi, że usunięcie jest trwałe |
| „Strona {n}” | `templates/source_sheet.dart:52` | Zostaje (źródło — nietykalne); zmiana tylko stylu: z osobnej linii `chat` na linię `caption` obok wydawcy |
| „Zamknij” | `templates/source_sheet.dart:64` | Zostaje: jawny przycisk zamknięcia (uchwyt arkusza nie jest przyciskiem) |
| „Uruchamiam model. Pierwsza odpowiedź trwa dłużej.” | `ui/answer_service.dart:28` | Zostaje: tłumaczy opóźnienie |
| „{tytuł}: Wszystko zrobione” | `templates/steps_panel.dart:39` | Zostaje: stan panelu |
| „Coś poszło nie tak. Spróbuj ponownie.” | `ui/chat_controller.dart:192`, `:195` | Zostaje: jedyny komunikat błędu; ogólnik, ale plik to logika |
| „Karta ratunkowa”, „Z twojego profilu”, „Tryb bez AI: fragmenty źródeł” | `templates/template_renderer.dart:15–17` | Zostają: pochodzenie odpowiedzi |

Zmienione znaki (nie teksty): ikony kafelków `zapOff` → `zap`, `backpack` → `footprints` (`ui/quick_actions.dart:19`, `:21`).

## Świadomie pominięte

- **Chip źródła** (`SourceChip` w `panel_card.dart`, zakres wspólny): w „przed” chip rozciąga się na całą szerokość wiersza i ma znak „▸”; w ref jest na szerokość treści i ma ikonę książki. Nie mój plik — prośba niżej.
- **Promień karty odpowiedzi**: ref ≈ 12 dp, `PanelCard` ma `radius-lg` (18). Zakres wspólny.
- **Pole wyboru kroku** stoi 12 dp od prawej krawędzi paddingu karty (ref: równo z nią). Wymaga zmiany `PanelCard`/`BzCheck` — przesunięcie poza rodzica odcięłoby pole dotyku.
- **Zakreślenie tylko cytowanego zdania** (ref: szary kontekst przed/po): `SourceRecord` ma jedno pole `text`. W karcie `quote` zakreślony jest cały fragment (jak dotąd); w arkuszu źródła fragment jest bez zakreślenia, bo zakreślenie całej strony tekstu niczego nie wskazuje (sprawdzone na emulatorze). Wskazanie zdania wymaga danych/logiki.
- **`bullets`, dymek, `NoSource`, pigułka „Nowa odpowiedź”, dialog „Usunąć czat?”**: zgodne z DS, bez odpowiednika w ref; zostały literały 10/14/6/20 dp.
- **Połysk tekstu statusu** (`bz-shimmer` z `motion.md`) w `Thinking`: nie dodany, zostaje kropka + szkielet.
- **Kolejność dołu panelu bocznego** (notka / Poradniki i źródła / Ustawienia): bez zmian — layout.
- **Zrzuty „po” na emulatorze**: koordynator robi centralnie.

## Propozycje tokenów

| Propozycja | Wartość | Gdzie dziś literał |
|---|---|---|
| `text-display-sm` | 32/38 w800 | nagłówek „Co się dzieje?” (`chat_screen.dart`) |
| `text-body-sm` | 15/22 | wiersze panelu bocznego, `NoSource`, etykieta `Thinking`, tytuł dokumentu w `quote` |
| `text-input` | 16/24 (i 16/22 w700 dla etykiet kafelków, tytułu karty) | `composer.dart`, `quick_actions.dart` |
| `radius-row` | 10 | wiersze panelu bocznego (DS README podaje 10 px, w tokenach jest 8 i 12) |
| `size-control-md` | 36 | okrągłe Wyślij/Zatrzymaj, pigułka „Nowa odpowiedź” |
| `size-tile-min` | 88 | min. wysokość kafelka |
| `space-2-5` | 10 | padding pionowy dymka, punktor listy |

## Prośby do innych zakresów

- **`SourceChip`** (`templates/panel_card.dart`): (1) chip na szerokość treści, nie wiersza — `Container(alignment:)` rozpycha go na całą szerokość; (2) ikona `book-open` 16 dp w `verified` zamiast znaku „▸” (ref). Punkt 2 rusza `chipLabel` i ok. 12 asercji z „▸ ” — decyzja człowieka.
- **`PanelCard`**: promień `radius-md` (ref ≈ 12 dp) i opcjonalne poziome wcięcie treści, żeby pole wyboru kroku stanęło równo z paddingiem karty.
- **Arkusze** (`bottomSheetTheme` w `bz_theme.dart`): bez próśb — arkusz źródła używa motywu bez zmian.
- **`integration_test/polish_shots_test.dart`** (koordynator): przy dłuższej odpowiedzi modelu po przewinięciu o 500 dp pierwszy `SourceChip` jest poza ekranem, dotknięcie nie trafia i zrzut `czat-zrodlo` nie pokazuje arkusza (tak wyszło w moim przebiegu „po”). Arkusz zweryfikowałem osobnym przebiegiem bez przewijania.
- **Logika odpowiedzi** (poza zakresem UI): pytanie „przepis na pierogi” w zrzucie „przed” dostaje od modelu pogawędkę („To wspaniałe danie!…”) z etykietą „Rozmowa – nie z poradników”, a nie odmowę „Pomagam tylko w sytuacjach kryzysowych…”. Zrzut `czat-poza-zakresem` nie pokazuje więc odmowy.

## Dziennik (2026-11-21)

- `flutter analyze`: 0 problemów przed i po.
- `flutter test`: przed 768 zaliczonych, 2 pominięte; po 769 zaliczonych (1 nowy test), 2 pominięte.
  `test/mapa/map_screen_test.dart` (poza zakresem) padł w 3 pełnych przebiegach „po” (raz „permission denied shows notice…”, dwa razy „shows attribution, map and searching notice…”); sam plik przechodzi 8/8, a ostatnie trzy pełne przebiegi „po” są zielone. Przebiegi szły przy sześciu pracujących emulatorach.
- Nowy test: `test/czat/templates/source_sheet_test.dart` — karta cytatu i arkusz źródła przy czcionce 200% na ekranie 360 dp bez przepełnień.
- Zmienione testy: `test/czat/templates/quote_panel_test.dart` („Powiększ” to teraz `BzButton`), `test/czat/drawer/chat_drawer_test.dart` (wiersze 48 dp).
- Zrzuty własne z emulator-5560 (niecommitowane): „przed” `polish/before/czat-*.png`, „po” `polish/tools/after-own/` oraz arkusz źródła `polish/tools/after-own2/czat-zrodlo.png`.
