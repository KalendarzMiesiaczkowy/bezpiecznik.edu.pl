# Panel 2 · Kontakt ze służbami

`EmergencyContactPanel` (wariant `sheet`). Arkusz nad bieżącym ekranem. Ten sam komponent w wariancie `inline` to szablon [`call`](szablony-czatu.md#call). Elementy globalne: [README](README.md#elementy-globalne).

## Cel

W jednym miejscu: gdzie jestem, połączenie ze służbami i przygotowany SMS do bliskich. Jedno dotknięcie SOS otwiera ten panel, a 112 jest w nim pierwszym i największym przyciskiem. Połączenie potwierdza systemowe okno telefonu.

## Wejście / wyjście

| Wejście | |
|---|---|
| Dotknięcie SOS na dowolnym ekranie (E0–E4, PV, nad P1) | Arkusz wysuwa się od dołu |

Przytrzymanie SOS nie otwiera panelu, tylko od razu otwiera wybieranie 112 (potwierdza system).

| Wyjście | Dokąd |
|---|---|
| 112, 999, 998, 997 | Systemowe wybieranie numeru (`tel:`), system pokazuje potwierdzenie. Panel zostaje otwarty pod spodem |
| „Wyślij lokalizację SMS-em” | Systemowe okno SMS z gotową treścią. Użytkownik sam wysyła |
| „Dodaj kontakty” | E4 Profil, sekcja kontaktów alarmowych. Panel się zamyka |
| `✕`, przesunięcie w dół, systemowy Wstecz | Zamknięcie, powrót do ekranu pod spodem bez zmian |

## Układ

```
┌──────────────────────────────┐
│░░░░░░░░░░░░░░░░░░░░░░░  (SOS)│
│┌────────────────────────────┐│
││(✕)  Kontakt ze służbami    ││
││                            ││
││ Twoja pozycja   GPS ±12 m  ││
││ 52.22977, 21.01178         ││
││ 52°13'47.2"N 21°00'42.4"E  ││
││ ok. ul. Marszałkowska 10,  ││
││ Warszawa                   ││
││┌──────────────────────────┐││
│││       ZADZWOŃ 112        │││
│││     Numer alarmowy       │││
││└──────────────────────────┘││
││[  999   ][  998   ][  997 ]││
││[Pogotow.][ Straż  ][Policj]││
││ⓘ Lokalizacja przy 112 (AML)││
││ Powiedz: co, gdzie, ile    ││
││ osób, czy są przytomne.    ││
││────────────────────────────││
││ Powiadom bliskich          ││
││[✓] Dołącz dane z profilu   ││
││ niemowlę, insulina, 7. p.  ││
││[ Wyślij lokalizację SMS-em]││
││ Do: Mama, Tomek            ││
││[ Sygnał ratunkowy       ▾ ]││
│└────────────────────────────┘│
└──────────────────────────────┘
```

Pełne teksty notek: [Teksty](#teksty).

## Elementy

| Element | Zachowanie |
|---|---|
| Arkusz | Od dołu, ok. 92% wysokości, przewijany. Pod SOS w kolejności warstw (SOS widoczny). Bez animacji w motywie kryzysowym |
| `✕` Zamknij | Lewy górny róg arkusza, 48 × 48 dp |
| Twoja pozycja | Współrzędne dziesiętne (5 miejsc po przecinku) dużą czcionką, pod nimi stopnie, minuty, sekundy (`52°13'47.2"N 21°00'42.4"E`). Obok dokładność i wiek pozycji. Dotknięcie → kopiuje oba formaty i toast „Skopiowano współrzędne” |
| GPS | Po otwarciu panelu: pozycja o wysokiej dokładności, odświeżana do zamknięcia panelu. Po zamknięciu GPS wraca do zwykłego trybu (bateria) |
| Najbliższy adres | Z offline'owej bazy adresów pobranego województwa, z dopiskiem „ok.” |
| Zadzwoń 112 | Największy przycisk panelu, pełna szerokość, min. 72 dp, czerwony. `tel:112` |
| 999 · 998 · 997 | Rząd trzech przycisków, każdy min. 56 dp, z nazwą służby. `tel:999`, `tel:998`, `tel:997` |
| Notka AML | Stała, pod numerami |
| Co powiedzieć | Stała podpowiedź dla rozmowy z dyspozytorem |
| Dołącz dane z profilu | Przełącznik nad przyciskiem SMS. Domyślnie włączony (*do potwierdzenia*). Pod nim podgląd linii `{profil}`, która trafi do SMS-a (np. „niemowlę, insulina, 7. piętro bez windy”); gdy profil jest pusty, przełącznik i podgląd są ukryte. Wyłączony: SMS bez linii `{profil}`. Stan zapamiętany do zamknięcia panelu |
| Powiadom bliskich: „Wyślij lokalizację SMS-em” | Otwiera systemowe okno SMS (`url_launcher`, schemat `sms:`) z odbiorcami = numery kontaktów ICE z profilu i treścią z [szablonu SMS](#szablon-sms). Aplikacja nigdy nie wysyła SMS sama. **112 nigdy nie jest odbiorcą** (w Polsce SMS na 112 działa tylko przez oficjalną aplikację Alarm112 po rejestracji) |
| Do: {imiona} | Imiona kontaktów ICE, które dostaną SMS. Link „Zmień” → E4 |
| Sygnał ratunkowy | Rozwijana sekcja z tym samym komponentem co szablon [`signal`](szablony-czatu.md#signal) |

### Szablon SMS

Tekst bez polskich znaków, żeby mieścił się w mniejszej liczbie części SMS (*domyślne, do potwierdzenia*). Aplikacja usuwa polskie znaki także z wstawianych wartości. Linie z pustą wartością są pomijane.

```
SOS. Potrzebuje pomocy. {opis}
Pozycja: {lat}, {lon} (dokladnosc {acc} m, {HH:MM})
https://www.openstreetmap.org/?mlat={lat}&mlon={lon}#map=17/{lat}/{lon}
Adres (ok.): {adres}
{profil}
Jesli nie odpowiadam, zadzwon pod 112 i podaj te dane.
```

| Pole | Wartość |
|---|---|
| `{opis}` | Gdy w bieżącym czacie jest karta ratunkowa: `Sytuacja: {nazwa karty}.` Inaczej ostatnia wiadomość użytkownika w bieżącym czacie, do 80 znaków: `Sytuacja: {tekst}.` Bez czatu (np. z Mapy bez czatu) lub bez wiadomości: pominięte |
| `{lat}`, `{lon}` | 5 miejsc po przecinku |
| `{acc}` | Dokładność w metrach, zaokrąglona |
| `{HH:MM}` | Czas pomiaru pozycji |
| `{adres}` | Najbliższy adres z bazy offline |
| `{profil}` | Pomijane, gdy przełącznik „Dołącz dane z profilu” jest wyłączony. Inaczej tylko wypełnione pola profilu, w tej kolejności: `Dom: {domownicy wymagający uwagi}.` (niemowle, dziecko, senior, ciaza, niepelnosprawnosc, ograniczona mobilnosc) `Leki: {nazwy}{ (lodowka)}.` `Urzadzenia: {np. koncentrator tlenu}.` `Pietro {n}{, bez windy}.` Bez imion domowników i bez numerów kontaktów |

Bez świeżego GPS linia pozycji brzmi `Ostatnia pozycja: {lat}, {lon} ({HH:MM}, teraz brak GPS)`. Bez żadnej pozycji: `Pozycja: nieznana (brak GPS).`, a linie z linkiem i adresem są pominięte.

Przykład:

```
SOS. Potrzebuje pomocy. Sytuacja: RKO.
Pozycja: 52.22977, 21.01178 (dokladnosc 12 m, 14:32)
https://www.openstreetmap.org/?mlat=52.22977&mlon=21.01178#map=17/52.22977/21.01178
Adres (ok.): ul. Marszalkowska 10, Warszawa
Dom: niemowle, senior. Leki: insulina (lodowka). Pietro 7, bez windy.
Jesli nie odpowiadam, zadzwon pod 112 i podaj te dane.
```

## Stany

| Stan | Zachowanie |
|---|---|
| Ładowanie (szukanie GPS) | Zamiast współrzędnych: „Szukam pozycji GPS…”. Gdy jest ostatnia znana pozycja, pokazana szaro z czasem: „Ostatnia pozycja (14:05)”. Przyciski numerów działają od razu |
| Brak GPS (brak sygnału) | „Brak sygnału GPS. Wyjdź na otwartą przestrzeń.” + ostatnia pozycja, jeśli jest |
| Brak uprawnienia do lokalizacji | „Brak dostępu do lokalizacji.” + przycisk „Zezwól” (okno systemowe albo ustawienia systemu) |
| Brak adresu (poza pobranym województwem) | „Adres niedostępny poza pobranym województwem.” |
| Brak kontaktów ICE | Przycisk SMS działa i otwiera okno SMS z pustym odbiorcą. Pod nim: „Nie masz kontaktów alarmowych.” i link „Dodaj kontakty” → E4 |
| Telefon bez SMS (np. tablet) | Przycisk SMS nieaktywny, tekst „Ten telefon nie wysyła SMS-ów.” |
| Offline (brak internetu) | Bez zmian. Połączenia i SMS wymagają tylko sieci komórkowej |
| AI generuje, tryb bez AI | Nie dotyczy (panel nie zależy od AI) |
| Niska bateria | Bez zmian. GPS o wysokiej dokładności działa tylko, gdy panel jest otwarty |
| Błąd otwarcia `tel:` lub okna SMS | Toast „Nie mogę otworzyć {telefonu / wiadomości}. Wybierz {numer} ręcznie.” |

## Teksty

| Miejsce | Tekst |
|---|---|
| Tytuł | Kontakt ze służbami |
| Etykieta zamknięcia | Zamknij |
| Nagłówek pozycji | Twoja pozycja |
| Dokładność | GPS ±{acc} m |
| Adres | ok. {adres} |
| Przycisk 112 | ZADZWOŃ 112 |
| Podpis 112 | Numer alarmowy |
| 999 | 999 · Pogotowie |
| 998 | 998 · Straż |
| 997 | 997 · Policja |
| Notka AML | Przy połączeniu z 112 telefon sam przekazuje lokalizację, jeśli ma zasięg sieci komórkowej. |
| Co powiedzieć | Powiedz: co się stało, gdzie jesteś, ile osób potrzebuje pomocy, czy są przytomne. |
| Nagłówek SMS | Powiadom bliskich |
| Przełącznik profilu | Dołącz dane z profilu |
| Podgląd profilu | W SMS-ie: {np. niemowlę, insulina, 7. piętro bez windy} |
| Przycisk SMS | Wyślij lokalizację SMS-em |
| Podpis SMS | Przygotuję SMS do bliskich. Wyślesz go sam. |
| Odbiorcy | Do: {imiona} |
| Zmiana odbiorców | Zmień |
| Brak ICE | Nie masz kontaktów alarmowych. |
| Link ICE | Dodaj kontakty |
| Brak SMS | Ten telefon nie wysyła SMS-ów. |
| Szukanie GPS | Szukam pozycji GPS… |
| Ostatnia pozycja | Ostatnia pozycja ({HH:MM}) |
| Brak GPS | Brak sygnału GPS. Wyjdź na otwartą przestrzeń. |
| Brak uprawnienia | Brak dostępu do lokalizacji. |
| Przycisk uprawnienia | Zezwól |
| Brak adresu | Adres niedostępny poza pobranym województwem. |
| Toast kopiowania | Skopiowano współrzędne |
| Sekcja sygnału | Sygnał ratunkowy |
| Etykieta czytnika 112 | Zadzwoń pod numer alarmowy 112 |

## Kryteria akceptacji

- [ ] Dotknięcie SOS na E1, E2, E3, E4 i PV otwiera ten panel; dotknięcie „ZADZWOŃ 112” otwiera systemowe wybieranie 112 (potwierdza system).
- [ ] Przytrzymanie SOS (800 ms) otwiera wybieranie 112 bez otwierania panelu.
- [ ] 112 jest pierwszym i największym przyciskiem panelu.
- [ ] Współrzędne są w dwóch formatach i kopiują się po dotknięciu.
- [ ] W trybie samolotowym panel pokazuje pozycję GPS i adres z bazy offline.
- [ ] „Wyślij lokalizację SMS-em” otwiera systemowe okno SMS z treścią zgodną z szablonem i odbiorcami z profilu; nic nie jest wysyłane bez akcji użytkownika.
- [ ] Przełącznik „Dołącz dane z profilu” pokazuje podgląd linii profilu; po wyłączeniu SMS nie zawiera linii `{profil}` (ani leków, ani domowników, ani piętra).
- [ ] Odbiorcą SMS nigdy nie jest 112.
- [ ] Bez kontaktów ICE okno SMS otwiera się z pustym odbiorcą, a panel pokazuje „Dodaj kontakty”.
- [ ] Treść SMS nie zawiera polskich znaków, imion domowników ani numerów kontaktów.
- [ ] Bez pozycji SMS zawiera „Pozycja: nieznana (brak GPS).” i nie zawiera linku.
- [ ] Szablon `call` w czacie wywołuje te same akcje i tworzy identyczny SMS.
- [ ] Po zamknięciu panelu GPS wraca do zwykłego trybu.

## Powiązane funkcje

- [Panel alarmowy](../02-funkcje/05-alarm/panel-alarmowy.md)
- [Przycisk SOS](../02-funkcje/05-alarm/przycisk-sos.md)
- [Sygnał ratunkowy](../02-funkcje/05-alarm/sygnal-ratunkowy.md)
- [Profil domu](../02-funkcje/04-profil-i-plan/profil-domu.md)
- [Prywatność i bezpieczeństwo](../05-technologia/prywatnosc-i-bezpieczenstwo.md)
