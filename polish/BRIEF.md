# Polish UX/UI aplikacji (Flutter) — brief zespołu

Brief właściciela (bez zmian) + zasady koordynacji równoległych agentów.

## Kontekst
- Pracujesz WYŁĄCZNIE w swoim worktree (podanym w zadaniu). Aplikacja: `app/`.
- Design system: `bezpiecznik/08-design-system/` (komponenty.md, motion.md, tokens.json).
  Tokeny we Flutterze: `app/lib/wspolne/theme/bz_tokens.g.dart` — generowane, nie edytuj ręcznie.
- Referencja stylu: `polish/ref/` — zrzuty landingu (390 px) + `roznice.md` (co landing robi inaczej niż DS).
  Landing jest w budowie: NIE otwieraj, nie edytuj i nie importuj niczego z `../Bezpiecznik-landing`
  ani z brancha `landing-page`.
- Tylko ciemny motyw (MVP).

## Cel
Każdy ekran ma wyglądać jak jego odpowiednik z referencji: ten sam układ, mniej szumu, dopracowane komponenty.
Ekrany: onboarding, czat (z kartami ratunkowymi), mapa, ratunek/RKO, alarm/SOS, profil, ustawienia.

## Na czym polega polish
1. Teksty (anti-slop). Usuń zdania, których brak niczego nie odbiera użytkownikowi: ogólniki
   („Twoje bezpieczeństwo jest najważniejsze"), podtytuły powtarzające tytuł, opisy oczywistości
   przy przyciskach, dekoracyjne emoji. Test: czy po usunięciu użytkownik wie mniej albo nie wie, co zrobić?
   Jeśli nie — usuń.
2. Hierarchia. Dla każdego ekranu zapisz jednym zdaniem „po co użytkownik tu jest" i wskaż JEDNĄ akcję główną.
   Ona jest najwyraźniejsza; reszta cichsza, zgrupowana albo schowana.
3. Komponenty. Odstępy, promienie, typografia wyłącznie z tokenów. Głębia przez tło i 1 px obramowanie,
   nie cienie (najwyżej 1 poziom elevation). Bez nowych kolorów i gradientów. Dopracowane stany
   pressed / disabled / focus / loading / pusty.

## Nietykalne
- Layout i przeznaczenie widoków, struktura kart, nawigacja (wyspa lewy-górny, SOS prawy-górny).
- Treści bezpieczeństwa: numery 112/999/998/997, „nie zastępuje 112", odznaka „Do weryfikacji",
  źródła i cytaty, etykieta „Rozmowa – nie z poradników", treść kart ratunkowych i instrukcji RKO
  (zmieniasz wygląd, nie słowa).
- Logika, routing, dane, `content/`.
- `tokens.json`. Brakuje wartości → użyj najbliższego tokenu i dopisz propozycję do swojego pliku planu
  („Propozycje tokenów"). Decyzję podejmuje człowiek.
- Dostępność: cele dotykowe ≥ 48 dp, kontrast WCAG AA, czcionka 200% (`test/font_scale_2_test.dart`) bez ucięć.

## Zasady koordynacji (zespół równoległy)
- Każdy agent ma swój worktree, swój branch i swój emulator (`-d emulator-XXXX` z zadania).
  Nigdy nie instaluj na urządzeniu fizycznym `47270DLAQ00421` ani na cudzym emulatorze.
- Edytujesz TYLKO pliki ze swojego zakresu (lista w zadaniu). Potrzebujesz zmiany poza zakresem
  (np. we wspólnym komponencie) → nie rób jej; opisz w sekcji „Prośby do innych zakresów” swojego planu.
- Plan i dziennik piszesz w `polish/plan/<zakres>.md` (nie w POLISH.md — koordynator scala).
  Format: per ekran: **Po co tu jest** (1 zdanie), **Akcja główna**, **Plan zmian**, **Usunięte teksty**
  (dosłownie, z plikiem i linią przed zmianą), **Świadomie pominięte**, **Propozycje tokenów**,
  **Prośby do innych zakresów**.
- Zrzuty: `polish/tools/shots.sh <katalog> [nazwa testu] ` robi zrzuty z `app/integration_test/polish_shots_test.dart`
  (domyślnie emulator-5554 — w swoim worktree ustaw `DEV=emulator-XXXX` w zmiennej środowiskowej, skrypt ją respektuje).
  „Przed” są w `polish/before/` (wspólne). Twoje „po” → `polish/after/<nazwa>.png`.
- Jeden ekran = jeden commit (angielski komunikat, końcówka
  `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`). Bez push — koordynator scala.
- Po każdym ekranie: `flutter analyze` (0 nowych problemów) i `flutter test` zielone. Gorzej niż przed → revert.
- Flutter: `~/development/flutter/bin/flutter`, adb: `~/Android/Sdk/platform-tools/adb`.
  LLM hosta (llama-server :8080) — nie zatrzymuj go. Pliki tymczasowe tylko w worktree (`polish/tools/`), nigdy w /tmp.
- Raport końcowy: lista commitów, ścieżki zrzutów po, wynik analyze/test (liczby), czego nie zrobiłeś i dlaczego.
  Raport bez dowodów = nie zrobione.
