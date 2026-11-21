# Zakres: formularze (onboarding E0, profil E4, ustawienia E3)

Agent: FORMS · worktree `Bezpiecznik-polish-forms` · branch `polish/forms` · emulator `emulator-5558`.

Baseline (przed zmianami, commit `be157b0`+polish base): `flutter analyze` → **No issues found**.
Zrzuty „przed”: `polish/before/onboarding-1..5.png`, `profil.png`, `profil-2.png`, `profil-3.png`,
`ustawienia.png`, `ustawienia-2.png` (zrobione na emulator-5558, bo wspólny katalog był pusty).

Wspólny język dla trzech ekranów (z `polish/ref/profil.png`): tytuł `title`, pod nim jedno zdanie
`caption`/`ink-200`; treść pogrupowana w karty `bg-100` + 1 px `line-100` + `radius-lg`, padding `space-4`,
odstęp między kartami `space-4`; nagłówek karty = ikona Lucide 20 dp `ink-200` + tytuł 16/700 `ink-100`
(jak `PanelCard`); etykiety pól NAD polem (`label`/`ink-200`), pole `bg-100`, 1 px `line-150`, `radius-md`;
helper pod polem `caption`/`ink-300`. Ikony wyłącznie Lucide (dziś profil miesza Material `Icons.*`).
Bez cieni, bez nowych kolorów. Wszystkie stałe liczbowe → tokeny `space*`/`radius*`/`duration*`.

---

## E0 · Onboarding (`app/lib/onboarding/onboarding_screen.dart`)

**Po co tu jest:** w minutę dowiedzieć się, czym jest aplikacja (i że nie zastępuje 112), zgodzić się na
lokalizację i opcjonalnie uzupełnić profil domu.

**Akcja główna:** przycisk `primary` xl na dole każdego kroku (Dalej / Zezwól / Uzupełnij / Dalej) —
jedna na krok; drugi przycisk zawsze `ghost`.

**Plan zmian**
1. Intro (`_body` case intro, l. 103–153): nad tytułem `BzLogo(size: 48)` (już jest w
   `czat/drawer/bz_logo.dart`, używa go ustawienia) — znak marki zamiast gołego słowa; odstęp `space4`.
2. Notice „Nie zastępuje 112” (l. 116–140): stałe → tokeny: `EdgeInsets.all(16)` → `space4`,
   `circular(12)` → `radiusMd`, `SizedBox(width: 12)` → `space3`; dodać 1 px obramowanie
   `signal` @ ~24 % alfa? **Nie** — nowy kolor; zostaje `signalTint` bez obramowania. Treść i styl
   `step` bez zmian (treść bezpieczeństwa ma zostać wyraźna).
3. `_title` (l. 66–81): `SizedBox(8/16)` → `space2`/`space4`; tytuł ma odstęp `space5` od paska
   postępu zamiast 8 (dziś „Krok 2 z 3”, pasek i tytuł są ściśnięte).
4. Krok formularza (l. 218–296): między „Dalej” a „Pomiń” brak odstępu (w innych krokach 8) →
   `SizedBox(height: space2)` jak w pozostałych krokach. Formularz dostaje karty z `ProfileForm`
   (patrz E4) — onboarding i profil wyglądają identycznie.
5. Potwierdzenie „Dodano profil domu” (l. 300–315): `Duration(milliseconds: 400)` → `durationSlow`
   (motion.md: maks. 300 ms) + `easeOut`; ikona check w kółku `verifiedTint` 64 dp zamiast gołej
   ikony 48 dp (głębia przez tło, nie cień). Opóźnienie 1200 ms przed przejściem — logika, nie ruszam.
6. Padding ekranu `fromLTRB(16, 80, 16, 16)` (l. 334) → `space4` + 80 zostaje (rezerwa na Back/SOS,
   spójna z `TopFade`); bez zmian układu.
7. Stany: przyciski już mają pressed/disabled z `BzButton`; „Dalej” w formularzu disabled przy błędzie
   — zostaje.

**Teksty do usunięcia** (test briefu: czy bez tego użytkownik wie mniej / nie wie, co zrobić?)

| Plik:linia | Tekst (dosłownie) | Decyzja |
| --- | --- | --- |
| `onboarding_screen.dart:222` | „Zostaje w telefonie. Wysyłasz go tylko ty. Każde pole możesz pominąć.” | **Skrócić do „Każde pole możesz pominąć.”** Pierwsze dwa zdania powtarzają to, co użytkownik przeczytał sekundę wcześniej na kroku 3 („Profil zostaje tylko w telefonie.”, l. 196) — do formularza nie da się wejść inaczej. Nie wie mniej. „Każde pole możesz pominąć” zostaje (to inna informacja niż przycisk „Pomiń” = cały profil). |
| `onboarding_screen.dart:112` | „Podpowiada, co zrobić w sytuacji kryzysowej, według oficjalnych poradników. Działa bez internetu. Prowadzi do najbliższego schronu.” | **Zostaje.** Trzy konkretne fakty (źródła, offline, schron) — to jedyny opis produktu. |
| `onboarding_screen.dart:134` | „Nie zastępuje 112. W zagrożeniu życia dzwoń pod 112.” | **Nietykalne** (bezpieczeństwo). |
| `onboarding_screen.dart:159` | „Pokażę najbliższy schron. Tylko gdy używasz aplikacji. Lokalizacja zostaje w telefonie. Wysyłasz ją tylko ty, np. SMS-em do bliskich.” | **Zostaje.** Uzasadnienie zgody na uprawnienie — każde zdanie zmienia decyzję użytkownika. |
| `onboarding_screen.dart:190` | „Bez lokalizacji nie pokażę najbliższego schronu. Możesz to zmienić w ustawieniach telefonu.” | **Zostaje** (konsekwencja odmowy + jak cofnąć). |
| `onboarding_screen.dart:196` | „Odpowiedz na kilka pytań o domowników i mieszkanie (ok. 2 min). Dzięki temu porady dotyczą twojej rodziny. Profil zostaje tylko w telefonie.” | **Zostaje** (koszt, korzyść, prywatność). |

**Świadomie pominięte:** krok pobierania paczek (nie ma w MVP); zmiana kolejności/liczby kroków;
zmiana treści przycisków; gradientowe zanikania nad/pod formularzem (l. 239–275) zostają — są
funkcjonalne (krawędź przewijania), nie dekoracyjne; opóźnienie 1200 ms potwierdzenia (logika).

**Propozycje tokenów:** brak (wszystko mieści się w `space*`, `radius*`, `durationSlow`).

---

## E4 · Profil domu (`app/lib/profil/profile_screen.dart`, `profile_form.dart`)

**Po co tu jest:** zapisać zawczasu domowników, leki, mieszkanie i kontakty, żeby porady i SMS do bliskich
dotyczyły tej rodziny.

**Akcja główna:** wypełnianie pól (autozapis, brak przycisku „Zapisz”). Wizualnie najwyraźniejsza jest
pierwsza karta „Kto mieszka w domu?”; akcje drugorzędne („Dodaj lek”, „Dodaj kontakt”) ciche (`ghost`).

**Plan zmian** (wzorzec: `polish/ref/profil.png`)
1. `ProfileForm._section` (l. 156–166) → karta sekcji: `bg-100`, 1 px `line-100`, `radius-lg`,
   padding `space4`, odstęp między kartami `space4`; nagłówek = ikona 20 dp `ink-200` + tytuł
   (styl tytułu `PanelCard`: `label` 16/700 `ink-100`), `Semantics(header: true)`. Każda sekcja
   (`Kto mieszka w domu?`, `Zwierzęta`, `Leki`, `Twoje mieszkanie`, `Dodatkowe informacje`,
   `Kogo powiadomić…`) staje się osobną kartą. Implementacja: wspólny `BzSectionCard` (prośba niżej);
   fallback — prywatny `_SectionCard` w `profile_form.dart`.
2. Ikony Material → Lucide (spójnie z resztą aplikacji i ref): `group_outlined`→`users`,
   `pets_outlined`→`pawPrint`, `medication_outlined`→`pill`, `home_outlined`→`house`,
   `notes_outlined`→`notebookPen`, `contact_phone_outlined`→`bookUser`; `Icons.remove/add/close`
   → `LucideIcons.minus/plus/x`.
3. Licznik domowników (l. 207–239): liczba `step`-wagą (bold) `ink-100`, przy 0 → `ink-300` (jak ref);
   szerokość kolumny liczby 24 → `space5`/32 przy 2× czcionce bez ucięcia; przyciski −/+ zostają
   `IconButton` 48 dp (cel dotyku), disabled = `ink-300` @ 38 %.
4. Pola tekstowe: etykieta NAD polem zamiast pływającej w ramce (ref: „Nazwa leku”, „Piętro”):
   `Text(label, style: label/ink-200)` + `space2` + `TextField`, całość w `MergeSemantics`, żeby
   czytnik ekranu nadal czytał etykietę razem z polem. Dotyczy: Nazwa leku, Piętro, Imię, Numer.
   Dla „Dodatkowe informacje” etykietą jest nagłówek karty, a „Np. choroby, diety” → `hintText`.
5. „Twoje mieszkanie” (l. 289–306): Piętro i Winda w jednym wierszu (ref) — `Piętro` pole po lewej,
   `Winda` jako `Segmented` Tak/Nie po prawej (ref: pigułka `bg-200`, zaznaczona `bg-300` + 1 px
   `line-150`, ten sam wzór co rozmiar tekstu w ustawieniach). Przy skali czcionki ≥ 1,5 → kolumna
   (bez ucięć przy 200 %). Trójstan zostaje: ponowne dotknięcie zaznaczonego → `null` (dziś BzChip
   tak działa; logika bez zmian).
6. „+ Dodaj lek” / „+ Dodaj kontakt” (l. 283, 377): znak „+” w tekście → `BzButton(icon: LucideIcons.plus,
   label: 'Dodaj lek')` (ikona zamiast glifu w etykiecie), nadal `ghost`, nadal wyrównane do lewej
   krawędzi treści karty.
7. Kontakt ICE (l. 329–372): Imię + Numer jako para w karcie; przycisk usuń `x` wyrównany do pierwszego
   pola; między kolejnymi kontaktami 1 px `line-100` separator zamiast samego odstępu.
8. `ProfileScreen` (l. 76–93): padding `fromLTRB(16, 96, 16, 32)` → `space4`/`space6` (96 zostaje,
   rezerwa na Back/SOS); tytuł → podtytuł `space2`, podtytuł → pierwsza karta `space5`.
   Pusty stan: tekst „Profil jest pusty…” z `chat` (17 px, większy niż podtytuł) → `caption`/`ink-200`
   pod podtytułem — dziś stan pusty krzyczy głośniej niż tytuł. Stan ładowania: `CircularProgressIndicator`
   → `BzSpinner` (już jest w `bz_buttons.dart`). Stan błędu: tekst `caption` wyśrodkowany z paddingiem
   `space4` (dziś bez paddingu i stylu).
9. Toast „Zapisano” — bez zmian (motyw SnackBar jest wspólny).

**Teksty do usunięcia**

| Plik:linia | Tekst (dosłownie) | Decyzja |
| --- | --- | --- |
| `profile_form.dart:266` | helperText „Np. insulina.” | **Usunąć jako helper → przenieść do `hintText: 'Np. insulina'`** (placeholder w pustym polu). Linia pod polem znika; przykład zostaje tam, gdzie się pisze. Nie wie mniej. |
| `profile_form.dart:317` | helperText „Pomoże dopasować porady.” | **Usunąć.** Uzasadnienie „po co” jest już w karcie profilu na onboardingu (l. 196) i w podtytule; pole jest opcjonalne. Bez niego użytkownik wie tyle samo i wie, co wpisać (hint „Np. choroby, diety”). |
| `profile_form.dart:316` | labelText „Np. choroby, diety” | **Etykieta → `hintText`** (to przykład, nie etykieta; etykietą jest nagłówek karty „Dodatkowe informacje”). Tekst zostaje. |
| `profile_form.dart:283`, `:377` | „+ Dodaj lek”, „+ Dodaj kontakt” | **„+ ” z etykiety → ikona `plus`.** Słowa zostają. |
| `profile_screen.dart:82` | „Zostaje w telefonie. Wysyłasz go tylko ty, np. SMS-em do bliskich. Nie ma konta ani serwera.” | **Zostaje** (dokładnie ten tekst jest w ref; informacja o prywatności danych zdrowotnych). |
| `profile_screen.dart:88` | „Profil jest pusty. Uzupełnij go, żeby odpowiedzi dotyczyły twojej rodziny.” | **Zostaje, ciszej** (`caption`). Stan pusty mówi, po co wypełniać — bez niego użytkownik wie mniej. |
| `profile_form.dart:326` | „Do tych osób przygotujemy SMS z twoją pozycją. Wyślesz go sam.” | **Zostaje** (wyjaśnia, co się stanie z kontaktami — powiązane z SOS / „Powiadom bliskich”). |
| `profile_form.dart:296` | helperText „0 to parter” | **Zostaje** (jest w ref; bez niego niejasne, jak wpisać parter). |
| komunikaty błędów (l. 84–106) | „Wpisz liczbę od -2 do 100.” itd. | **Zostają** (walidacja). |

**Świadomie pominięte:** spec E4 przewiduje tryb kreatora (`StepHeader`, `QuestionStep`, podsumowania
sekcji `ListRow`, Toast „Cofnij”) — to zmiana układu i logiki, poza polishem. Etykiety/mobilność
pojedynczych członków — brak w MVP UI. `BzChip` (wysokość 40 dp wizualnie; test pilnuje 40) zostaje —
cel dotyku: chip ma 40 dp, poniżej 48 → **zgłaszam** w prośbach (nie zmieniam, bo test i DS mówią 40).

**Propozycje tokenów**
- `type.cardTitle` (16/22, 700) — dziś `PanelCard` robi `label.copyWith(fontSize: 16, …)`; ten sam styl
  potrzebny w kartach profilu i ustawień. Do decyzji człowieka; do tego czasu `copyWith` jak w `PanelCard`.
- `size.icon.md` = 20 (ikony nagłówków kart) — dziś liczba w kodzie w kilku miejscach.

---

## E3 · Ustawienia (`app/lib/ustawienia/settings_screen.dart`, `sources.dart`)

**Po co tu jest:** zmienić to, co dotyczy wygody (rozmiar tekstu, tryb bez AI, głos), wejść do profilu
i w razie potrzeby usunąć dane.

**Akcja główna:** brak jednej akcji „wykonaj” — ekran to lista. Najwyraźniejszy element: wiersz
**Profil domu** (pierwsza karta, ikona + chevron). Akcja niszcząca „Usuń wszystkie dane” zostaje
`danger` (obramowana, nie wypełniona) — wyraźna, ale nie dominuje.

**Plan zmian**
1. Nagłówki sekcji WERSALIKAMI `label`/`ink-300` (l. 53–59) → karty z nagłówkiem ikona + tytuł
   (ten sam `BzSectionCard` co w profilu): `Wygląd` (`type`), `AI i bateria` (`sparkles`),
   `Prywatność` (`shieldCheck`), `O aplikacji` (`info`). Wiersze `ListTile`/`SwitchListTile` w karcie
   z `contentPadding: 0` (padding daje karta), separator 1 px `line-100` między wierszami.
2. Sekcja „Profil” z jednym wierszem „Profil domu” → sama karta-wiersz (ikona `house` w kółku
   `bg-200`, tytuł, chevron), bez nagłówka „Profil” (dublował „Profil domu”). Cel dotyku 56 dp.
3. Rozmiar tekstu (l. 82–139): istniejący segmented → wspólny `BzSegmented` (jeśli powstanie) albo
   zostaje lokalny; stałe `EdgeInsets.all(3)`, `margin 1`, `horizontal: 4` → `space1`; stan pressed:
   dziś `GestureDetector` bez żadnego feedbacku → `InkWell` z `overlayPress` w kształcie pigułki;
   zmiana zaznaczenia animowana `durationFast` + `easeInOut` (`AnimatedContainer`).
4. Dialog „Usuń wszystkie dane” (l. 21–45): `TextButton('Anuluj')` (Material, niespójny) →
   `BzButton(variant: ghost)`; tytuł i treść bez zmian.
5. „O aplikacji” (l. 177–201): wiersz „Źródła” dostaje ikonę `bookOpen` (dziś jako jedyny wiersz bez
   ikony); blok logo + opis i disclaimer w tej samej karcie, odstępy z tokenów (`space2`/`space3`).
   Disclaimer „Bezpiecznik nie zastępuje 112 ani służb.” — treść i waga `step` bez zmian.
6. Arkusz „Źródła” (`sources.dart` l. 29–56): odstępy 12 → `space3`, wiersze rozdzielone 1 px
   `line-100`; treść bez zmian.
7. Padding listy (l. 67) `fromLTRB(0, 96, 0, 32)` → karty z marginesem `space4`, dół `space6`.

**Teksty do usunięcia**

| Plik:linia | Tekst (dosłownie) | Decyzja |
| --- | --- | --- |
| `settings_screen.dart:136` | „Tak będzie wyglądał tekst instrukcji.” | **Usunąć.** `AppTextScale` skaluje cały interfejs natychmiast po wyborze — każdy tekst na ekranie (także „Rozmiar tekstu” nad przełącznikiem) jest podglądem. Zdanie nie daje nowej informacji. (Spec ma klucz `settings.textScale.preview` — do odnotowania w spec przez koordynatora.) |
| `settings_screen.dart:73` | nagłówek „Profil” (`section('Profil')`) | **Usunąć** — sekcja ma jeden wiersz „Profil domu”, nagłówek go powtarza. |
| `settings_screen.dart:159` | „Sieć służy tylko do pobierania paczek.” (część `settings.privacy.info`) | **Proponuję usunąć — do akceptacji człowieka.** W MVP paczki są w APK (brak kroku pobierania), więc zdanie odnosi się do funkcji, której użytkownik nie widzi. Reszta notki prywatności zostaje: „Profil, czaty i lokalizacja zostają w telefonie. Wysyłasz je tylko ty, np. SMS-em do bliskich. Nie ma konta ani serwera.” Jeśli człowiek uzna to za deklarację prywatności — zostawiam. |
| `settings_screen.dart:144` | „Czat pokazuje tylko fragmenty źródeł, bez generowania odpowiedzi.” | **Zostaje** — bez niego nie wiadomo, co robi „Tryb bez AI”. |
| `settings_screen.dart:193` | „Bezpiecznik: poradniki kryzysowe offline, w twoim telefonie.” | **Zostaje** — to jest treść „O aplikacji”; bez niej blok to samo logo. |
| `settings_screen.dart:200` | „Bezpiecznik nie zastępuje 112 ani służb.” | **Nietykalne.** |
| `settings_screen.dart:27` | „Usunąć profil, wszystkie czaty i ustawienia? Pobrane mapy i baza wiedzy zostaną.” | **Zostaje** (konsekwencje nieodwracalnej akcji). |

**Świadomie pominięte:** wiersze ze spec poza MVP (Czaty, Paczki danych, Motyw, Wersja, eksport profilu,
„Posłuchaj” przy głosie) — nie dodaję; `noAiMode` jako przełącznik (spec: Automatycznie/Zawsze/Nigdy) —
logika; kolejność sekcji bez zmian.

**Propozycje tokenów:** `size.icon.md` = 20 i `type.cardTitle` (jak w E4).

---

## Prośby do innych zakresów (shared components, `app/lib/wspolne/**`, `panel_card.dart`)

1. **`BzSectionCard`** (nowy, `wspolne/theme/`): karta `bg-100` + 1 px `line-100` + `radius-lg`, padding
   `space4`; opcjonalny nagłówek = `IconData? icon` (Lucide 20 dp `ink-200`) + `String title`
   (styl tytułu `PanelCard`), `Semantics(header: true)`; `child`. Alternatywa: rozszerzyć `PanelCard`
   o parametr `IconData? icon` (leading przed tytułem) — wtedy użyję `PanelCard`. Potrzebne w E3 i E4
   (i zapewne w innych zakresach). Fallback, jeśli nie będzie: prywatna karta w `profile_form.dart`,
   reużyta przez ustawienia.
2. **`BzSegmented<T>`** (nowy): pigułka `bg-200`, padding `space1`, opcja zaznaczona `bg-300` + 1 px
   `line-150` + `ink-100`, niezaznaczona `ink-200`; każda opcja ≥ 48 dp, `Semantics(button, selected)`,
   pressed = `overlayPress`, animacja `durationFast`; opcjonalnie `allowDeselect` (trójstan Tak/Nie/brak).
   DS wymienia `Segmented` w E3 i E4 — dziś istnieje tylko jako kod inline w `settings_screen.dart`
   (l. 89–134), który mogę oddać jako wzorzec. Fallback: lokalny widget w `ustawienia/`.
3. **`BzChip` → do `wspolne/`?** Dziś leży w `profil/profile_form.dart`, a jest komponentem DS
   (`ChoiceChips`). Zgłaszam tylko: wizualnie 40 dp, a cel dotyku nie jest powiększony do 48 dp
   (`BzButton` to robi, `BzChip` nie) — naruszenie zasady ≥ 48 dp. Proponuję: wizual 40, hit area 48
   (jak `BzButton`). Mogę to zrobić sam (plik w moim zakresie), jeśli shared nie przejmuje chipa —
   potrzebuję tylko decyzji, gdzie ma żyć.
4. **Motyw pól (`bz_theme.dart` `inputDecorationTheme`)**: ref ma pole z promieniem `radius-md` i
   obramowaniem `line-150` na `bg-100` w karcie `bg-100` — pole zlewa się z kartą. Prośba: `fillColor`
   pola w karcie = `bg-000` albo `bg-200`? (ref wygląda na `bg-000`/ciemniejsze niż karta). Do decyzji
   shared; ja ustawię etykiety nad polem lokalnie.
5. **`TextButton` w dialogach**: motyw `textButtonTheme` — jeśli shared ustawi go na wygląd `BzButton ghost`,
   nie muszę zamieniać ręcznie (dotyczy też innych dialogów w aplikacji).
