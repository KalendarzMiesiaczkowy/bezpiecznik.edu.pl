"""Builds app/assets/cards/*.json from anchored excerpts of content/sources.

Every excerpt is cut verbatim (after dehyphenation of line-wrap breaks) from
the cited pdf_page, so `original` is never typed from memory. Step texts are
Polish paraphrases written by hand next to the fragment they paraphrase.

Source ids are `{doc_id}-s{pdf_page}-f{n}` with n numbered from 101 per page,
so they never collide with the chunk ids of content/knowledge (f1, f2, ...).
Run: python3 -I app/assets/cards/tools/build_cards.py
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[4]  # repo root (tools -> cards -> assets -> app -> root)
SRC = ROOT / 'content/sources'
OUT = ROOT / 'app/assets/cards'

PUBLISHER = 'European Resuscitation Council; Polska Rada Resuscytacji'
DOCS = {
    'erc-2025-bls-algorytmy': dict(
        short='ERC 2025, BLS krok po kroku',
        title='Podstawowe zabiegi resuscytacyjne krok po kroku - algorytmy',
        file='erc-2025-bls-algorytmy/bls-algorytmy.pdf', issued='2025-12'),
    'erc-2025-podsumowanie': dict(
        short='ERC 2025, Podsumowanie',
        title='Wytyczne Europejskiej Rady Resuscytacji 2025 - Podsumowanie wytycznych (tłumaczenie polskie)',
        file='erc-2025-podsumowanie/podsumowanie-wytycznych-2025.pdf', issued='2025-10'),
    'erc-2025-pierwsza-pomoc': dict(
        short='ERC 2025, Pierwsza pomoc',
        title='Wytyczne ERC 2025 - pierwsza pomoc (rozdział)',
        file='erc-2025-pierwsza-pomoc/wytyczne-erc-2025-pierwsza-pomoc.pdf', issued='2025-10'),
    'erc-2025-pierwsza-pomoc-algorytmy': dict(
        short='ERC 2025, I pomoc, algorytmy',
        title='Pierwsza pomoc - algorytmy',
        file='erc-2025-pierwsza-pomoc-algorytmy/pierwsza-pomoc-algorytmy.pdf', issued='2026-04'),
    'erc-2025-bls': dict(
        short='ERC 2025, BLS (rozdział)',
        title='Wytyczne ERC 2025 - podstawowe zabiegi resuscytacyjne u dorosłych (rozdział BLS)',
        file='erc-2025-bls/wytyczne-erc-2025-bls.pdf', issued='2025-10'),
    'erc-2025-kluczowe-bls': dict(
        short='ERC 2025, BLS kluczowe',
        title='Podstawowe zabiegi resuscytacyjne u dorosłych - kluczowe informacje',
        file='erc-2025-kluczowe-bls/kluczowe-bls.pdf', issued='2025-10'),
    'erc-2025-broszura-resuscytacja-dla-kazdego': dict(
        short='ERC 2025, Resuscytacja dla każdego',
        title='Resuscytacja dla każdego (broszura ERC 2025, wersja polska)',
        file='erc-2025-broszura-resuscytacja-dla-kazdego/broszura-resuscytacja-dla-kazdego.pdf', issued='2026-04'),
}

_pages = {}
_counter = {}


def page_text(doc, n):
    if doc not in _pages:
        _pages[doc] = {}
        for line in open(SRC / doc / 'pages.jsonl', encoding='utf-8'):
            d = json.loads(line)
            _pages[doc][d['pdf_page']] = d
    return _pages[doc][n]


def clean(t):
    t = t.replace('\t', ' ')
    t = re.sub(r'[●❍•]', ' ', t)
    t = re.sub(r'(\w)-\s*\n\s*([a-ząćęłńóśźż])', r'\1\2', t)
    t = re.sub(r'\s+', ' ', t)
    # repair two obvious text-layer splits of the algorithm poster (page 3)
    t = t.replace('plecac h', 'plecach').replace('poszkodowaneg o', 'poszkodowanego')
    return t.strip()


SOURCES = {}


def frag(fid, doc, page, start, end):
    """Register a fragment: verbatim slice of cleaned page text."""
    t = clean(page_text(doc, page)['text'])
    i = t.find(start)
    assert i >= 0, f'{fid}: start not found: {start!r}'
    j = t.find(end, i)
    assert j >= 0, f'{fid}: end not found: {end!r}'
    ex = t[i:j + len(end)]
    words = len(ex.split())
    assert words <= 60, f'{fid}: {words} words'
    _counter[(doc, page)] = _counter.get((doc, page), 100) + 1
    sid = f'{doc}-s{page}-f{_counter[(doc, page)]}'
    d = DOCS[doc]
    assert sid not in SOURCES
    # printed page number == pdf_page where the page text carries it; the
    # algorithm posters carry none, so pdf_page is used.
    SOURCES[sid] = {
        'source_id': sid, 'doc_id': doc, 'doc_title': d['title'],
        'doc_short': d['short'], 'publisher': PUBLISHER, 'issued': d['issued'],
        'page_label': str(page), 'pdf_page': page,
        'pdf_file': d['file'], 'original': ex, 'rects': [],
    }
    return sid


ALG = 'erc-2025-bls-algorytmy'
SUM = 'erc-2025-podsumowanie'
FA = 'erc-2025-pierwsza-pomoc'
FAA = 'erc-2025-pierwsza-pomoc-algorytmy'
BLS = 'erc-2025-bls'
KBLS = 'erc-2025-kluczowe-bls'
BRO = 'erc-2025-broszura-resuscytacja-dla-kazdego'

# ---------------------------------------------------------------- adult BLS
a = {}
a['safe'] = frag(1, ALG, 3, 'Upewnij się, że Ty, poszkodowany i świadkowie zdarzenia', 'jesteście bezpieczni')
a['react'] = frag(2, ALG, 3, 'Delikatnie potrząśnij poszkodowanego za ramiona', '„Czy wszystko w porządku?”')
a['call'] = frag(3, ALG, 3, 'Jeśli poszkodowany nie reaguje, poproś osobę', 'rozmowy z dyspozytorem')
a['airway'] = frag(4, ALG, 3, 'połóż go na plecach', 'udrożnić drogi oddechowe')
a['breath'] = frag(5, ALG, 3, 'Przez nie dłużej niż 10 sekund', 'nie oddycha prawidłowo')
a['aed_send'] = frag(6, ALG, 3, 'Wyślij kogoś, żeby znalazł i przyniósł AED', 'natychmiast rozpocznij RKO')
a['hands'] = frag(7, ALG, 3, 'Uklęknij obok', 'Ramiona trzymaj wyprostowane')
a['depth'] = frag(8, ALG, 3, 'Przyjmij taką pozycję', 'w tempie 100–120 na minutę')
a['only'] = frag(9, ALG, 3, 'Jeśli nie masz przeszkolenia lub nie potrafisz', '100–120 na minutę)')
a['trained'] = frag(10, ALG, 3, 'Jeśli posiadasz przeszkolenie', 'odgięcia głowy i uniesienia brody')
a['breaths'] = frag(11, ALG, 3, 'Palcem wskazującym i kciukiem', 'około 1 sekundę')
a['cycle'] = frag(12, ALG, 3, 'Nie przerywaj uciśnięć klatki piersiowej na dłużej niż 10 sekund', 'w stosunku 30:2')
a['aed_on'] = frag(13, ALG, 3, 'Gdy tylko AED zostanie dostarczone', 'przyklejania elektrod do klatki piersiowej')
a['aed_follow'] = frag(14, ALG, 3, 'Postępuj zgodnie z instrukcjami głosowymi i wizualnymi AED', 'zgodnie z poleceniami AED')
a['defib_no'] = frag(16, ALG, 3, 'Jeśli defibrylacja nie jest zalecana', 'zgodnie z poleceniami AED')
a['stop'] = frag(15, ALG, 3, 'Jeśli AED jest niedostępne lub czekasz', 'zbyt zmęczony, żeby kontynuować')

# ------------------------------------------------------------ paediatric BLS
c = {}
c['safe'] = frag(1, SUM, 67, 'zapewnij bezpieczeństwo sobie i dziecku, a następnie postępuj', 'niebólowe;')
c['dispatch'] = frag(2, SUM, 67, 'jeśli dziecko nie reaguje, to natychmiast zadzwoń', 'instrukcji dyspozytora.')
c['untrained'] = frag(3, SUM, 67, 'Osoby bez przeszkolenia lub przeszkolone wyłącznie', 'oddechach ratowniczych.')
c['nobreath'] = frag(4, SUM, 67, 'Jeśli osoba udzielająca pomocy nie chce', 'uciskaniem klatki piersiowej.')
c['call'] = frag(5, SUM, 67, 'Natychmiast wezwij lub poproś kogoś', 'rozpoczęcie RKO.')
c['airway'] = frag(6, SUM, 67, 'Udrożnij drogi oddechowe za pomocą manewru', 'maksymalnie przez 10 sekund.')
c['five'] = frag(7, SUM, 67, 'Wykonaj 5 oddechów ratowniczych.', 'w przeciwnym razie z zachowaniem stosunku 30:2.')
c['aed_who'] = frag(1, SUM, 68, 'Jeśli na miejscu jest obecny drugi ratownik', 'postępuj zgodnie z jego instrukcjami.')
c['aed_one'] = frag(2, SUM, 68, 'W przypadku gdy jest tylko jeden ratownik', 'przynoszenie i podłączanie AED.')
c['keep'] = frag(3, SUM, 68, 'Nie przerywaj RKO, chyba że', 'wyda AED.')
c['airway_inf'] = frag(4, SUM, 68, 'u niemowląt trzymaj głowę w pozycji neutralnej', 'większe odgięcie głowy.')
c['breath_tech'] = frag(5, SUM, 68, 'upewnij się, że drogi oddechowe są drożne, wdmuchuj', 'do kolejnego oddechu ratowniczego')
c['site_inf'] = frag(6, SUM, 68, 'uciskaj klatkę piersiową w dolnej połowie mostka', 'obejmując dłońmi klatkę piersiową;')
c['hands_child'] = frag(7, SUM, 68, 'u dzieci powyżej 1. roku życia lub gdy nie można', 'jedną lub dwiema rękami;')
c['quality'] = frag(8, SUM, 68, 'wykonuj wysokiej jakości uciśnięcia, czyli:', 'niezależnie od wieku dziecka,')
c['recoil'] = frag(9, SUM, 68, 'unikaj opierania się na klatce piersiowej', 'wyjściowej pozycji,')
c['nostop'] = frag(10, SUM, 68, 'nie przerywaj uciśnięć klatki piersiowej poza momentami', 'na polecenie AED.')
c['aed_pad'] = frag(11, SUM, 68, 'u wszystkich niemowląt i dzieci o masie ciała poniżej 25', 'tryb dla dorosłych;')
c['change'] = frag(13, SUM, 72, 'Osobę wykonującą uciśnięcia klatki piersiowej zmieniaj co', 'zmieniaj ich częściej.')
c['aed_touch'] = frag(12, SUM, 68, 'nie dotykaj pacjenta w trakcie analizy rytmu', 'wznów uciśnięcia klatki piersiowej.')

# ------------------------------------------------------------------ choking
k = {}
k['adult_sus'] = frag(1, SUM, 93, 'Podejrzewaj zadławienie, gdy osoba nagle', 'Zachęć poszkodowanego do kaszlu.')
k['adult_back'] = frag(2, SUM, 93, 'Jeśli poszkodowany nie jest w stanie kaszleć', 'okolicę międzyłopatkową.')
k['adult_abd'] = frag(3, SUM, 93, 'Jeżeli uderzenia w okolicę międzyłopatkową są nieskuteczne', 'uciśnięć nadbrzusza.')
k['adult_alt'] = frag(4, SUM, 93, 'Jeśli niedrożność dróg oddechowych nie ustąpi', 'u poszkodowanego.')
k['adult_call'] = frag(5, SUM, 93, 'Zadzwoń pod numer ratunkowy 112/999.', 'palcem „na ślepo”.')
k['adult_loss'] = frag(6, SUM, 93, 'Gdy poszkodowany straci przytomność, rozpocznij RKO.', 'rozpocznij RKO.')
k['adult_check'] = frag(7, SUM, 93, 'Każda osoba, u której usunięto ciało obce', 'rozwoju powikłań lub urazu.')
k['adult_back_t'] = frag(1, FA, 21, 'stań za poszkodowanym,', 'na środku pleców.')
k['adult_abd_t'] = frag(2, FA, 21, 'stań za poszkodowanym i obiema rękami obejmij go', 'do siebie i do góry.')
k['ch_sus'] = frag(1, SUM, 69, 'Zadławienie ciałem obcym należy podejrzewać', 'bawiło się bez nadzoru.')
k['ch_call'] = frag(2, SUM, 69, 'Jak najszybciej wezwij pogotowie ratunkowe', 'zachęcaj do kaszlu.')
k['ch_back1'] = frag(3, SUM, 69, 'Jeśli dziecko nie może kaszleć lub kaszel', 'okolicę międzyłopatkową:')
k['inf_back'] = frag(4, SUM, 69, 'obróć niemowlę twarzą w dół', 'gdy usuniesz ciało obce;')
k['ch_back'] = frag(5, SUM, 69, 'w przypadku starszych dzieci i nastolatków pochyl', 'Powtórz do 5 razy.')
k['ch_abd_intro'] = frag(6, SUM, 69, 'Jeśli uderzenia w okolicę międzyłopatkową są nieskuteczne', 'klatki piersiowej lub nadbrzusza:')
k['inf_chest'] = frag(7, SUM, 69, 'obróć niemowlę na plecy i połóż je', 'do udrożnienia dróg oddechowych;')
k['ch_abd_a'] = frag(8, SUM, 69, 'stań za dzieckiem i obejmij je', 'wyrostkiem mieczykowatym mostka,')
k['ch_abd_b'] = frag(9, SUM, 69, 'chwyć pięść drugą ręką', 'chyba że wcześniej usuniesz przeszkodę;')
k['ch_alt'] = frag(10, SUM, 69, 'Jeśli dziecko nadal jest przytomne', 'klatki piersiowej/nadbrzusza (do 5 razy),')
k['ch_stop'] = frag(11, SUM, 69, 'Natychmiast przerwij uderzenia lub uciśnięcia', 'głośny oddech lub płacz).')
k['ch_blind'] = frag(12, SUM, 69, 'Nie próbuj usuwać ciała obcego z jamy ustnej', 'jest wyraźnie widoczna.')
k['ch_call2'] = frag(13, SUM, 69, 'Wezwij pomoc i zadzwoń po pogotowie ratunkowe', 'straci przytomność.')
k['ch_loss'] = frag(14, SUM, 69, 'Gdy dziecko straci przytomność, natychmiast rozpocznij RKO', 'pięciu oddechów ratowniczych.')

# ----------------------------------------------------------------- bleeding
b = {}
b['press'] = frag(1, FA, 12, 'Na krwawiące miejsce zastosuj silny', 'bezpośredni ucisk ręką (ryc. 9).')
b['dress'] = frag(2, FA, 12, 'Przyłóż standardowy opatrunek lub opatrunek hemostatyczny', 'bezpośredni ucisk ręką.')
b['bandage'] = frag(1, FA, 13, 'Po opanowaniu krwawienia załóż opatrunek uciskowy.', 'opatrunek uciskowy.')
b['tourniquet'] = frag(2, FA, 13, 'W przypadku zagrażającego życiu krwawienia z kończyny', 'założyć opaskę uciskową.')
b['note'] = frag(3, FA, 13, 'Zanotuj czas założenia opaski uciskowej.', 'opaski uciskowej.')

# -------------------------------------------------------------- unconscious
u = {}
u['check'] = frag(1, FAA, 3, 'Udrożnij drogi oddechowe patrz', 'Oceń oddech (maks. 10 sek)')
u['pos_who'] = frag(1, FA, 9, 'W pozycji bezpiecznej należy układać poszkodowanych', '(ryc. 3).')
u['agonal'] = frag(1, FA, 18, 'Osób z oddechem agonalnym lub po urazie', 'w pozycji leżącej na plecach.')
u['r1'] = frag(1, FA, 18, 'Upewnij się, że nogi poszkodowanego są wyprostowane.', '(ryc. 3b).')
u['r2'] = frag(1, FA, 19, 'Drugą rękę (znajdującą się dalej) skrzyżuj', '(po twojej stronie).')
u['r3'] = frag(2, FA, 19, 'Drugą ręką chwyć tuż nad kolanem', 'tak aby je zgiąć.')
u['r4'] = frag(3, FA, 19, 'Przyciskając jedną ręką dłoń do policzka', 'przetocz poszkodowanego na bok.')
u['r5'] = frag(4, FA, 19, 'Nogę leżącą na górze ułóż tak', 'zgięte pod kątem prostym.')
u['r6'] = frag(5, FA, 19, 'Ostrożnie odchyl głowę poszkodowanego do tyłu', 'z jamy ustnej.')
u['r7'] = frag(6, FA, 19, 'Regularnie sprawdzaj, czy poszkodowany prawidłowo oddycha.', 'bez nadzoru.')
u['worse'] = frag(2, FA, 18, 'Osoba ułożona w pozycji bezpiecznej powinna być stale', 'rozpocząć u niego RKO.')

# --------------------------------------------------------------------- AED
e = {}
e['anyone'] = frag(1, KBLS, 1, 'Każdy może użyć AED, nawet jeśli nie przeszedł szkolenia', 'nawet jeśli nie przeszedł szkolenia')
e['safe'] = frag(1, BRO, 27, 'AED nie wyzwoli wyładowania', 'odpowiednich warunków.')
e['now'] = frag(1, BLS, 7, 'Użyj AED natychmiast, gdy tylko jest dostępny.', 'gdy tylko jest dostępny.')
e['send'] = frag(2, BRO, 27, 'wyślij kogoś po najbliższe AED.', 'wyślij kogoś po najbliższe AED.')
e['open'] = frag(2, BLS, 7, 'Otwórz obudowę AED (jeżeli występuje).', 'włącz urządzenie.')
e['voice'] = frag(3, BLS, 7, 'Postępuj zgodnie z poleceniami głosowymi/wizualnymi AED.', 'wizualnymi AED.')
e['pads'] = frag(4, BLS, 7, 'Przyklej elektrody na odsłoniętą klatkę piersiową', '(lub na elektrodach AED)')
e['place'] = frag(1, BLS, 24, 'Jedna elektroda powinna być umieszczona poniżej prawego obojczyka', 'środkowej.')
e['breast'] = frag(2, BLS, 24, 'Należy w miarę możliwości unikać umieszczania elektrod na tkance gruczołu piersiowego.', 'gruczołu piersiowego.')
e['bra'] = frag(1, BLS, 25, 'Jeśli jednak biustonosz utrudnia', 'właściwe przyklejenie elektrod.')
e['more'] = frag(5, BLS, 7, 'Jeżeli na miejscu zdarzenia jest więcej niż jeden ratownik', 'naklejania elektrod do defibrylacji.')
e['analyse'] = frag(6, BLS, 7, 'Upewnij się, że nikt nie dotyka poszkodowanego w czasie, gdy AED analizuje', 'rytm serca.')
e['shock'] = frag(7, BLS, 7, 'Jeżeli wskazane jest wykonanie defibrylacji', 'nikt nie dotyka poszkodowanego.')
e['auto'] = frag(8, BLS, 7, 'Niektóre AED (w pełni automatyczne)', 'przycisku defibrylacji.')
e['after'] = frag(9, BLS, 7, 'Natychmiast po defibrylacji wznów', 'klatki piersiowej.')
e['noshock'] = frag(10, BLS, 7, 'Jeżeli defibrylacja nie jest wskazana', 'od uciśnięć klatki piersiowej.')
e['follow'] = frag(11, BLS, 7, 'Kontynuuj RKO, stosując się do instrukcji wydawanych przez AED.', 'ponownej analizy rytmu serca.')
e['p_follow'] = frag(1, SUM, 68, 'postępuj według instrukcji AED;', 'prowadzi RKO);')
e['p_pads_adultsize'] = frag(2, SUM, 68, 'elektrody do defibrylacji w rozmiarze dla dorosłych rozmieść', 'między łopatkami,')
e['p_pads_big'] = frag(3, SUM, 68, 'u dzieci o masie ciała powyżej 25 kg i nastolatków możliwe jest', 'pod lewą pachą.')
e['p_teen'] = frag(4, SUM, 68, 'Jeśli stosujesz ułożenie przednio-tylne u nastolatków', 'gruczole piersiowym;')


MAXLEN = 120
STEPS = []  # (card, variant, text, source_id) for the report


def I(sid, *texts, link=None):
    """One or more steps citing the same fragment; `link` goes on the last."""
    out = []
    for i, t in enumerate(texts):
        assert len(t) <= MAXLEN, f'{len(t)} chars: {t}'
        d = {'text': t, 'source_id': sid}
        if link and i == len(texts) - 1:
            d['card_link'] = link
        out.append(d)
    return out


def cat(*parts):
    r = []
    for p in parts:
        r.extend(p)
    return r


RKO_LINK = {'label': 'Nie oddycha → RKO', 'card_id': 'rko'}
RKO_LINK2 = {'label': 'RKO', 'card_id': 'rko'}

# --------------------------------------------------------------------- RKO
rko_adult = cat(
    I(a['safe'], 'Upewnij się, że Ty, poszkodowany i świadkowie jesteście bezpieczni.'),
    I(a['react'], 'Delikatnie potrząśnij poszkodowanym za ramiona i głośno zapytaj: „Czy wszystko w porządku?”'),
    I(a['call'],
      'Jeśli nie reaguje, poproś kogoś o wezwanie służb ratunkowych albo zrób to sam.',
      'Jeśli to możliwe, zostań z poszkodowanym.',
      'Włącz w telefonie tryb głośnomówiący, aby rozpocząć RKO w trakcie rozmowy z dyspozytorem.'),
    I(a['airway'],
      'Połóż poszkodowanego na plecach.',
      'Jedną rękę połóż na jego czole, opuszki palców drugiej pod brodą.',
      'Delikatnie odegnij głowę do tyłu i unieś brodę, aby udrożnić drogi oddechowe.'),
    I(a['breath'],
      'Przez nie dłużej niż 10 sekund patrz, słuchaj i wyczuwaj, czy poszkodowany oddycha.',
      'Prawie brak oddechu albo nieregularne, powolne i głośne westchnienia oznaczają brak prawidłowego oddechu.'),
    I(a['aed_send'],
      'Wyślij kogoś po AED, jeśli jest dostępne.',
      'Jeśli jesteś sam, idź po AED tylko wtedy, gdy przyniesiesz i uruchomisz je w ciągu jednej minuty.',
      'W przeciwnym razie natychmiast rozpocznij RKO.'),
    I(a['hands'],
      'Uklęknij obok poszkodowanego.',
      'Nasadę jednej dłoni połóż na środku klatki piersiowej, na dolnej połowie mostka.',
      'Nasadę drugiej dłoni połóż na pierwszej i spleć palce.',
      'Trzymaj ramiona wyprostowane.'),
    I(a['depth'],
      'Ułóż ramiona pionowo nad klatką piersiową poszkodowanego.',
      'Uciskaj mostek na głębokość co najmniej 5 cm, ale nie więcej niż 6 cm.',
      'Po każdym uciśnięciu zwolnij ucisk, nie tracąc kontaktu dłoni z klatką piersiową.',
      'Powtarzaj uciśnięcia w tempie 100–120 na minutę.'),
    I(a['only'],
      'Bez przeszkolenia lub gdy nie potrafisz wykonać oddechów ratowniczych, prowadź RKO tylko z uciskaniem.',
      'Uciskaj klatkę piersiową bez przerw, w tempie 100–120 na minutę.'),
    I(a['trained'], 'Z przeszkoleniem: po 30 uciśnięciach ponownie udrożnij drogi oddechowe (odegnij głowę, unieś brodę).'),
    I(a['breaths'],
      'Zaciśnij skrzydełka nosa palcem wskazującym i kciukiem dłoni leżącej na czole poszkodowanego.',
      'Weź normalny wdech i szczelnie obejmij ustami usta poszkodowanego.',
      'Wdmuchuj powietrze około 1 sekundę i obserwuj, czy klatka piersiowa się unosi.'),
    I(a['cycle'],
      'Wykonaj 2 oddechy ratownicze.',
      'Nie przerywaj uciśnięć na dłużej niż 10 sekund, nawet jeśli oddechy są nieskuteczne.',
      'Bez opóźnienia wróć do 30 uciśnięć klatki piersiowej.',
      'Kontynuuj uciśnięcia i oddechy w stosunku 30:2.'),
    I(a['aed_on'],
      'Gdy tylko dostarczą AED, włącz je.',
      'Przyklej elektrody na odsłoniętą klatkę piersiową poszkodowanego.',
      'Jeśli jest więcej niż jeden ratownik, kontynuuj RKO podczas przyklejania elektrod.'),
    I(a['aed_follow'],
      'Postępuj zgodnie z instrukcjami głosowymi i wizualnymi AED.',
      'Gdy AED zaleca defibrylację, upewnij się, że nikt nie dotyka poszkodowanego.',
      'Naciśnij przycisk defibrylacji zgodnie z poleceniem.',
      'Potem natychmiast wróć do RKO zgodnie z poleceniami AED.'),
    I(a['defib_no'], 'Jeśli defibrylacja nie jest zalecana, natychmiast wróć do RKO.'),
    I(a['stop'],
      'Jeśli AED jest niedostępne lub czekasz na nie, kontynuuj RKO.',
      'Nie przerywaj RKO, aż pracownik ochrony zdrowia powie Ci, żebyś przestał.',
      'Albo aż poszkodowany oczywiście odzyska przytomność, poruszy się, otworzy oczy i zacznie prawidłowo oddychać.',
      'Albo aż będziesz zbyt zmęczony, żeby kontynuować.'),
)

child_head = cat(
    I(c['safe'], 'Zapewnij bezpieczeństwo sobie i dziecku.', 'Sprawdź, czy dziecko reaguje na bodźce niebólowe.'),
    I(c['dispatch'], 'Jeśli dziecko nie reaguje, natychmiast zadzwoń po pogotowie ratunkowe.', 'Postępuj według wskazówek dyspozytora.'),
    I(c['call'], 'Użyj w telefonie funkcji głośnomówiącej, a jeśli to możliwe, także transmisji wideo.',
      'Dyspozytor może pomóc ocenić, czy trzeba rozpocząć RKO.'),
    I(c['untrained'], 'Bez przeszkolenia: rozpocznij RKO według instrukcji dyspozytora.',
      'Dyspozytor poprowadzi RKO w stosunku 30:2 po początkowych pięciu oddechach ratowniczych.'),
)


def child_tail(infant):
    who = 'niemowlęcia' if infant else 'dziecka'
    mouth = 'ust i nosa niemowlęcia' if infant else 'ust dziecka'
    out = []
    if infant:
        out += I(c['airway'], 'Udrożnij drogi oddechowe i oceń oddech oraz oznaki życia maks. 10 s.')
        out += I(c['airway_inf'],
                 'U niemowlęcia trzymaj głowę w pozycji neutralnej, lekko ją odginając.',
                 'Unieś bródkę dwoma palcami ułożonymi na elementach kostnych, unikając uciskania tkanek miękkich.')
    else:
        out += I(c['airway'],
                 'Jeśli masz przeszkolenie PBLS: udrożnij drogi oddechowe odgięciem głowy i uniesieniem bródki.',
                 'Oceń oddech oraz oznaki życia maksymalnie przez 10 sekund.')
    out += I(c['five'],
             'Wykonaj 5 oddechów ratowniczych, potem uciskaj klatkę piersiową 30 razy i wykonaj 2 oddechy (30:2).',
             'Jeśli masz przeszkolenie PBLS: po 5 oddechach wykonaj 15 uciśnięć, dalej kontynuuj w stosunku 15:2.')
    out += I(c['breath_tech'],
             'Upewnij się, że drogi oddechowe są drożne.',
             f'Wdmuchuj powietrze do {mouth} przez około 1 sekundę, aż klatka piersiowa się uniesie.',
             'Pozwól klatce piersiowej biernie opaść, gdy nabierasz powietrza do kolejnego oddechu.')
    if infant:
        out += I(c['site_inf'], 'Uciskaj klatkę piersiową w dolnej połowie mostka.',
                 'U niemowlęcia stosuj technikę uciskania dwoma kciukami, obejmując dłońmi klatkę piersiową.')
    else:
        out += I(c['site_inf'], 'Uciskaj klatkę piersiową w dolnej połowie mostka.')
        out += I(c['hands_child'], 'U dziecka powyżej 1. roku życia stosuj technikę uciskania jedną lub dwiema rękami.')
    out += I(c['quality'],
             'Uciskaj z częstością 100–120 na minutę.',
             'Uciskaj na głębokość co najmniej 1/3 przednio-tylnego wymiaru klatki piersiowej.',
             'Nie uciskaj głębiej niż 6 cm, niezależnie od wieku dziecka.')
    out += I(c['recoil'],
             'Nie opieraj się na klatce piersiowej.',
             'Całkowicie zwalniaj ucisk między uciśnięciami, aby klatka wróciła do wyjściowej pozycji.')
    out += I(c['nostop'], 'Nie przerywaj uciśnięć poza momentami oddechów ratowniczych lub poleceniem AED.')
    out += I(c['nobreath'], 'Jeśli nie chcesz lub nie możesz wykonywać oddechów, prowadź RKO tylko z uciskaniem klatki piersiowej.')
    out += I(c['aed_who'],
             'Jeśli jest drugi ratownik, niech wezwie pogotowie, gdy Ty zaczynasz RKO.',
             'Niech potem jak najszybciej przyniesie i podłączy AED.',
             'Po włączeniu AED postępuj zgodnie z jego instrukcjami.')
    out += I(c['aed_one'], 'Jeśli jesteś sam, priorytetem jest wezwanie pogotowia i rozpoczęcie RKO, a nie przynoszenie AED.')
    out += I(c['aed_pad'],
             'Niemowlętom i dzieciom poniżej 25 kg (do około 8. roku życia) włącz w AED tryb pediatryczny, jeśli jest.',
             'Większym dzieciom i nastolatkom stosuj tryb dla dorosłych.',
             'Jeśli AED nie ma trybu pediatrycznego, stosuj tryb dla dorosłych.')
    out += I(c['aed_touch'], 'Nie dotykaj dziecka, gdy AED analizuje rytm.',
             'Po defibrylacji natychmiast wznów uciśnięcia klatki piersiowej.')
    out += I(c['keep'], 'Nie przerywaj RKO, chyba że pojawią się wyraźne oznaki życia albo AED wyda takie polecenie.')
    return out


rko_child = cat(child_head, child_tail(False))
rko_infant = cat(child_head, child_tail(True))

CHANGE_NOTE = ('Wartość 120 s pochodzi ze zdania o zmianie osoby uciskającej co najmniej co 2 minuty '
               '(ERC 2025, Podsumowanie, s. 72, i s. 70). To zdanie stoi w części o zaawansowanych zabiegach '
               'resuscytacyjnych u dzieci, nie w instrukcji dla świadków zdarzenia.')
RATE_NOTE = 'Źródło podaje zakres 100–120 na minutę. rate_bpm 110 to środek tego zakresu, wybór aplikacji, nie liczba z wytycznych.'

rko = {
    'version': 1, 'id': 'rko', 'name': 'RKO', 'priority': 1, 'verify': True,
    'verify_note': 'Parafraza wytycznych ERC/PRC 2025 do sprawdzenia przez ratownika medycznego lub instruktora PRC przed publikacją.',
    'panels': [
        {'type': 'steps', 'title': 'RKO', 'read_aloud': True, 'variants': [
            {'id': 'adult', 'label': 'Dorosły', 'items': rko_adult},
            {'id': 'child', 'label': 'Dziecko', 'items': rko_child},
            {'id': 'infant', 'label': 'Niemowlę', 'items': rko_infant},
        ]},
        {'type': 'cpr', 'source_id': a['cycle'],
         'rate_bpm': 110, 'rate_bpm_min': 100, 'rate_bpm_max': 120,
         'rate_source_id': a['depth'], 'rate_note': RATE_NOTE,
         'rescuer_change_s': 120, 'rescuer_change_source_id': c['change'],
         'verify_note': CHANGE_NOTE,
         'variants': [
             {'id': 'adult', 'label': 'Dorosły', 'source_id': a['cycle'], 'compressions': 30, 'breaths': 2,
              'initial_breaths': 0, 'breath_phase_s': 10},
             {'id': 'child', 'label': 'Dziecko', 'source_id': c['five'], 'compressions': 30,
              'compressions_pbls_trained': 15, 'breaths': 2, 'initial_breaths': 5, 'breath_phase_s': None},
             {'id': 'infant', 'label': 'Niemowlę', 'source_id': c['five'], 'compressions': 30,
              'compressions_pbls_trained': 15, 'breaths': 2, 'initial_breaths': 5, 'breath_phase_s': None},
         ],
         'voice': {'compress': 'Uciskaj', 'breaths': 'Dwa oddechy',
                   'aed': 'Niech ktoś przyniesie AED', 'change': 'Zmiana ratownika'},
         'aed_card_id': 'aed'},
    ],
}

# ----------------------------------------------------------------- choking
choke_adult = cat(
    I(k['adult_sus'],
      'Podejrzewaj zadławienie, gdy osoba nagle nie może mówić, zwłaszcza podczas jedzenia.',
      'Zapytaj poszkodowanego: „Czy się zadławiłeś?”',
      'Zachęć poszkodowanego do kaszlu.'),
    I(k['adult_call'], 'Zadzwoń pod numer ratunkowy 112/999.'),
    I(k['adult_back'], 'Jeśli nie może kaszleć albo kaszel jest nieskuteczny, wykonaj do 5 uderzeń w okolicę międzyłopatkową.'),
    I(k['adult_back_t'], 'Stań za poszkodowanym i nasadą dłoni uderzaj go między łopatkami, na środku pleców.'),
    I(k['adult_abd'], 'Jeśli uderzenia są nieskuteczne, wykonaj do 5 uciśnięć nadbrzusza.'),
    I(k['adult_abd_t'],
      'Stań za poszkodowanym i obiema rękami obejmij go w górnej części brzucha.',
      'Pochyl poszkodowanego do przodu.',
      'Zaciśniętą pięść umieść między pępkiem a dolnym brzegiem klatki piersiowej.',
      'Obejmij pięść drugą dłonią i mocno pociągnij obie dłonie do siebie i do góry.'),
    I(k['adult_alt'],
      'Jeśli niedrożność nie ustąpi po 5 uciśnięciach, powtarzaj na przemian 5 uderzeń między łopatki i 5 uciśnięć nadbrzusza.',
      'Rób to do usunięcia ciała obcego albo do utraty przytomności przez poszkodowanego.'),
    I(k['adult_call'], 'Nie próbuj usuwać ciała obcego z jamy ustnej ani dróg oddechowych palcem „na ślepo”.'),
    I(k['adult_check'],
      'Po usunięciu ciała obcego uciśnięciami poproś pracownika ochrony zdrowia o ocenę poszkodowanego.',
      'Mogło dojść do powikłań lub urazu.'),
)
sus_child = I(k['ch_sus'],
              'Podejrzewaj zadławienie, gdy dziecko lub nastolatek nie może mówić.',
              'Podejrzewaj je też, gdy niemowlę lub młodsze dziecko nie może głośno płakać.',
              'Zwłaszcza podczas jedzenia lub karmienia albo gdy dziecko bawiło się bez nadzoru.')
choke_child = cat(
    sus_child,
    I(k['ch_call'], 'Jak najszybciej wezwij pogotowie ratunkowe albo poproś o to kogoś.',
      'Starsze dziecko lub nastolatkę zachęcaj do kaszlu.'),
    I(k['ch_back1'], 'Jeśli dziecko nie może kaszleć albo kaszel jest nieskuteczny, wykonaj do 5 uderzeń w okolicę międzyłopatkową.'),
    I(k['ch_back'], 'Starsze dziecko pochyl do przodu i uderz je w plecy, w okolicę międzyłopatkową.',
      'Powtórz do 5 razy.'),
    I(k['ch_abd_intro'], 'Jeśli uderzenia w okolicę międzyłopatkową są nieskuteczne, wykonaj do 5 uciśnięć nadbrzusza.'),
    I(k['ch_abd_a'],
      'Stań za dzieckiem i obejmij je ramionami wokół górnej części brzucha.',
      'Pochyl dziecko do przodu.',
      'Zaciśnij pięść i umieść ją między pępkiem a wyrostkiem mieczykowatym mostka.'),
    I(k['ch_abd_b'],
      'Chwyć pięść drugą ręką i gwałtownie pociągnij dłonie do siebie i do góry.',
      'Powtórz do 5 razy, chyba że wcześniej usuniesz przeszkodę.'),
    I(k['ch_alt'], 'Jeśli dziecko nadal jest przytomne, powtarzaj na przemian 5 uderzeń między łopatki i 5 uciśnięć nadbrzusza.'),
    I(k['ch_stop'],
      'Natychmiast przerwij uderzenia lub uciśnięcia, gdy pojawią się oznaki usunięcia przeszkody.',
      'Takie oznaki to kaszel, głośny oddech lub płacz.'),
    I(k['ch_blind'],
      'Nie próbuj usuwać ciała obcego z jamy ustnej „na ślepo”.',
      'Pojedynczą próbę usunięcia wykonaj tylko wtedy, gdy przeszkoda jest wyraźnie widoczna.'),
)
choke_infant = cat(
    sus_child,
    I(k['ch_call'], 'Jak najszybciej wezwij pogotowie ratunkowe albo poproś o to kogoś.'),
    I(k['ch_back1'], 'Jeśli niemowlę nie może kaszleć albo kaszel jest nieskuteczny, wykonaj do 5 uderzeń w okolicę międzyłopatkową.'),
    I(k['inf_back'],
      'Obróć niemowlę twarzą w dół na swoim przedramieniu, a przedramię oprzyj na nodze.',
      'Podtrzymuj głowę niemowlęcia dłonią, starając się utrzymać ją poniżej poziomu klatki piersiowej.',
      'Wykonaj energiczne uderzenie w okolicę między łopatkami.',
      'Powtórz do 5 razy lub do usunięcia ciała obcego.'),
    I(k['ch_abd_intro'], 'Jeśli uderzenia w okolicę międzyłopatkową są nieskuteczne, wykonaj do 5 uciśnięć klatki piersiowej.'),
    I(k['inf_chest'],
      'Obróć niemowlę na plecy i połóż je na swoich kolanach.',
      'Uciskaj klatkę piersiową dwoma kciukami i dłońmi obejmującymi klatkę, jak przy resuscytacji, ale z większą siłą.',
      'Powtórz do 5 razy lub do udrożnienia dróg oddechowych.'),
    I(k['ch_alt'], 'Jeśli niemowlę nadal jest przytomne, powtarzaj na przemian 5 uderzeń między łopatki i 5 uciśnięć klatki piersiowej.'),
    I(k['ch_stop'],
      'Natychmiast przerwij uderzenia lub uciśnięcia, gdy pojawią się oznaki usunięcia przeszkody.',
      'Takie oznaki to kaszel, głośny oddech lub płacz.'),
    I(k['ch_blind'],
      'Nie próbuj usuwać ciała obcego z jamy ustnej „na ślepo”.',
      'Pojedynczą próbę usunięcia wykonaj tylko wtedy, gdy przeszkoda jest wyraźnie widoczna.'),
)
choking = {
    'version': 1, 'id': 'choking', 'name': 'Zadławienie', 'priority': 2, 'verify': True,
    'verify_note': 'Parafraza wytycznych ERC/PRC 2025 do sprawdzenia przez ratownika medycznego lub instruktora PRC przed publikacją.',
    'panels': [
        {'type': 'steps', 'title': 'Zadławienie', 'read_aloud': True, 'variants': [
            {'id': 'adult', 'label': 'Dorosły', 'items': choke_adult},
            {'id': 'child', 'label': 'Dziecko', 'items': choke_child},
            {'id': 'infant', 'label': 'Niemowlę', 'items': choke_infant},
        ]},
        {'type': 'steps', 'title': 'Gdy straci przytomność', 'read_aloud': True, 'variants': [
            {'id': 'adult', 'label': 'Dorosły', 'items': I(
                k['adult_loss'], 'Gdy poszkodowany straci przytomność, rozpocznij RKO.', link=RKO_LINK2)},
            {'id': 'child', 'label': 'Dziecko', 'items': cat(
                I(k['ch_call2'], 'Wezwij pomoc i zadzwoń po pogotowie, jeśli jeszcze tego nie zrobiono.',
                  'Zrób to najpóźniej wtedy, gdy dziecko straci przytomność.'),
                I(k['ch_loss'], 'Gdy dziecko straci przytomność, natychmiast rozpocznij RKO od pięciu oddechów ratowniczych.',
                  link=RKO_LINK2))},
            {'id': 'infant', 'label': 'Niemowlę', 'items': cat(
                I(k['ch_call2'], 'Wezwij pomoc i zadzwoń po pogotowie, jeśli jeszcze tego nie zrobiono.',
                  'Zrób to najpóźniej wtedy, gdy niemowlę straci przytomność.'),
                I(k['ch_loss'], 'Gdy niemowlę straci przytomność, natychmiast rozpocznij RKO od pięciu oddechów ratowniczych.',
                  link=RKO_LINK2))},
        ]},
    ],
}

# ---------------------------------------------------------------- bleeding
bleeding = {
    'version': 1, 'id': 'bleeding', 'name': 'Krwotok', 'priority': 3, 'verify': True,
    'verify_note': 'Parafraza wytycznych pierwszej pomocy ERC 2025 do sprawdzenia przez ratownika medycznego lub instruktora PRC przed publikacją.',
    'panels': [
        {'type': 'steps', 'title': 'Tamowanie krwawienia', 'read_aloud': True, 'items': cat(
            I(b['press'], 'Na krwawiące miejsce zastosuj silny, bezpośredni ucisk ręką.'),
            I(b['dress'], 'Przyłóż opatrunek standardowy lub hemostatyczny bezpośrednio na krwawiące miejsce.',
              'Następnie zastosuj silny, bezpośredni ucisk ręką.'),
            I(b['bandage'], 'Po opanowaniu krwawienia załóż opatrunek uciskowy.'),
            I(b['tourniquet'], 'Jeśli krwawienie z kończyny zagraża życiu i trwa mimo ucisku ręką, jak najszybciej załóż opaskę uciskową.'),
            I(b['note'], 'Zanotuj czas założenia opaski uciskowej.'),
        )},
    ],
}

# ------------------------------------------------------------- unconscious
unconscious = {
    'version': 1, 'id': 'unconscious', 'name': 'Utrata przytomności', 'priority': 5, 'verify': True,
    'verify_note': 'Parafraza wytycznych ERC 2025 do sprawdzenia przez ratownika medycznego lub instruktora PRC przed publikacją.',
    'panels': [
        {'type': 'steps', 'title': 'Utrata przytomności', 'read_aloud': True, 'items': cat(
            I(u['check'], 'Udrożnij drogi oddechowe i sprawdź oddech: patrz, słuchaj, czuj do 10 s', link=RKO_LINK),
            I(a['breath'], 'Prawie brak oddechu albo nieregularne, powolne i głośne westchnienia oznaczają brak prawidłowego oddechu.'),
            I(u['pos_who'], 'Jeśli osoba oddycha prawidłowo, nie ma urazu i nie wymaga RKO, ułóż ją w pozycji bezpiecznej (na boku).'),
            I(u['agonal'], 'Przy oddechu agonalnym (nieprawidłowym) nie układaj na boku – rozpocznij RKO.', link=RKO_LINK),
            I(u['agonal'], 'Po urazie zostaw poszkodowanego leżącego na plecach.'),
            I(u['r1'], 'Upewnij się, że nogi poszkodowanego są wyprostowane.',
              'Rękę bliższą Tobie ułóż pod kątem prostym względem tułowia, wyprostowaną lub zgiętą.'),
            I(u['r2'], 'Drugą rękę (dalszą) skrzyżuj przez klatkę piersiową poszkodowanego.',
              'Przyłóż grzbiet jego dłoni do jego policzka po Twojej stronie.'),
            I(u['r3'], 'Drugą ręką chwyć dalszą nogę tuż nad kolanem i unieś kolano, zostawiając stopę na podłożu.'),
            I(u['r4'], 'Przyciskając jedną ręką dłoń do policzka, drugą pociągnij do siebie zgiętą nogę.',
              'Ostrożnie przetocz poszkodowanego na bok.'),
            I(u['r5'], 'Nogę leżącą na górze ułóż tak, aby biodro i kolano były zgięte pod kątem prostym.'),
            I(u['r6'], 'Ostrożnie odchyl głowę do tyłu, aby drogi oddechowe były drożne.',
              'W razie potrzeby popraw dłoń pod policzkiem, aby głowa była odchylona i zwrócona do podłoża.',
              'Dzięki temu wydzielina może wypływać z jamy ustnej.'),
            I(u['r7'], 'Regularnie sprawdzaj, czy poszkodowany prawidłowo oddycha.',
              'Tylko jeśli to konieczne do wezwania pomocy, możesz go zostawić bez nadzoru.'),
            I(u['worse'], 'Jeśli oddech, drożność dróg oddechowych lub przytomność się pogarszają, ułóż poszkodowanego na plecach.',
              'W razie potrzeby rozpocznij RKO.', link=RKO_LINK),
        )},
    ],
}

# --------------------------------------------------------------------- AED
aed_head = cat(
    I(e['anyone'], 'Każdy może użyć AED, nawet bez szkolenia.'),
    I(e['safe'], 'AED nie wyzwoli wyładowania, jeśli nie wykryje odpowiednich warunków.'),
    I(e['send'], 'Jeśli jest więcej świadków, wyślij kogoś po najbliższe AED.'),
    I(e['now'], 'Użyj AED natychmiast, gdy tylko je masz.'),
    I(e['open'],
      'Otwórz obudowę AED, jeśli ją ma.',
      'Niektóre AED włączają się automatycznie po otwarciu.',
      'Jeśli nie, znajdź przycisk zasilania i włącz urządzenie.'),
)
aed_tail = cat(
    I(e['analyse'], 'Upewnij się, że nikt nie dotyka poszkodowanego, gdy AED analizuje rytm serca.'),
    I(e['shock'], 'Jeśli AED wskazuje defibrylację, upewnij się, że nikt nie dotyka poszkodowanego.'),
    I(e['auto'],
      'W pełni automatyczne AED wykonają defibrylację same.',
      'W półautomatycznym AED naciśnij przycisk defibrylacji.'),
    I(e['after'], 'Natychmiast po defibrylacji wznów uciśnięcia klatki piersiowej.'),
    I(e['noshock'], 'Jeśli defibrylacja nie jest wskazana, natychmiast wznów RKO od uciśnięć klatki piersiowej.'),
    I(e['follow'],
      'Kontynuuj RKO zgodnie z instrukcjami AED.',
      'AED po określonym czasie zaleci przerwę w RKO i ponownie zanalizuje rytm serca.',
      link=RKO_LINK2),
)
aed_adult = cat(
    aed_head,
    I(e['voice'], 'Postępuj zgodnie z poleceniami głosowymi i wizualnymi AED.'),
    I(e['pads'], 'Przyklej elektrody na odsłoniętą klatkę piersiową zgodnie z instrukcją na AED lub na elektrodach.'),
    I(e['place'], 'Jedną elektrodę przyklej poniżej prawego obojczyka, przy prawym brzegu mostka, drugą poniżej lewej pachy.'),
    I(e['breast'], 'W miarę możliwości unikaj przyklejania elektrod na tkance gruczołu piersiowego.'),
    I(e['bra'], 'Jeśli biustonosz utrudnia przyklejenie elektrod, przesuń go.'),
    I(e['more'], 'Jeśli jest więcej niż jeden ratownik, kontynuuj RKO podczas naklejania elektrod.'),
    aed_tail,
)
aed_child_mid = cat(
    I(e['p_follow'], 'Postępuj według instrukcji AED.',
      'Przyklej elektrody, minimalizując przerwy w RKO.',
      'Jedna osoba nakleja elektrody, druga prowadzi RKO.'),
    I(c['aed_pad'],
      'Niemowlę lub dziecko poniżej 25 kg (do ok. 8. r.ż.): włącz tryb pediatryczny, jeśli AED go ma.',
      'Większe dziecko i nastolatek: standardowy tryb dla dorosłych.',
      'Jeśli AED nie ma trybu pediatrycznego, stosuj tryb dla dorosłych.'),
    I(e['p_pads_adultsize'],
      'Elektrody w rozmiarze dla dorosłych, dziecko poniżej 25 kg: jedna z przodu, tuż na lewo od mostka.',
      'Druga elektroda na plecach, na środku, między łopatkami.'),
    I(e['p_pads_big'],
      'Dziecko powyżej 25 kg i nastolatek: jedna elektroda poniżej prawego obojczyka, druga pod lewą pachą.'),
    I(e['p_teen'], 'U nastolatka, przy ułożeniu przednio-tylnym, unikaj elektrody na gruczole piersiowym.'),
    I(c['aed_one'], 'Jeśli jesteś sam, priorytetem jest wezwanie pogotowia i RKO, a nie przynoszenie AED.'),
)
aed_child_tail = cat(
    I(c['aed_touch'], 'Nie dotykaj dziecka, gdy AED analizuje rytm.',
      'Po defibrylacji natychmiast wznów uciśnięcia klatki piersiowej.'),
    I(e['follow'], 'Kontynuuj RKO zgodnie z instrukcjami AED.', link=RKO_LINK2),
)
aed_child = cat(aed_head, I(e['voice'], 'Postępuj zgodnie z poleceniami głosowymi i wizualnymi AED.'),
                aed_child_mid, aed_child_tail)

aed = {
    'version': 1, 'id': 'aed', 'name': 'Jak użyć AED', 'priority': 4, 'verify': True,
    'verify_note': 'Parafraza wytycznych ERC/PRC 2025 do sprawdzenia przez ratownika medycznego lub instruktora PRC przed publikacją.',
    'panels': [
        {'type': 'steps', 'title': 'Jak użyć AED', 'read_aloud': True, 'variants': [
            {'id': 'adult', 'label': 'Dorosły', 'items': aed_adult},
            {'id': 'child', 'label': 'Dziecko', 'items': aed_child},
            {'id': 'infant', 'label': 'Niemowlę', 'items': aed_child},
        ]},
    ],
}

CARDS = [rko, choking, bleeding, unconscious, aed]
IDX = json.load(open(ROOT / 'app/assets/phrases/cards_index.json', encoding='utf-8'))
idx_by_id = {x['id']: x for x in IDX['cards']}


def collect(panel, acc):
    for key in ('source_id', 'rate_source_id', 'rescuer_change_source_id'):
        if panel.get(key):
            acc.append(panel[key])
    for it in panel.get('items', []):
        acc.append(it['source_id'])
    for v in panel.get('variants', []):
        if isinstance(v, dict):
            if v.get('source_id'):
                acc.append(v['source_id'])
            for it in v.get('items', []):
                acc.append(it['source_id'])


for card in CARDS:
    ix = idx_by_id[card['id']]
    assert card['priority'] == ix['priority'], card['id']
    card['phrases'] = list(ix['phrases'])
    if ix['variants']:
        card['variant_words'] = {v: IDX['variant_words'][v] for v in ix['variants'] if v in IDX['variant_words']}
    acc = []
    for p in card['panels']:
        collect(p, acc)
    seen = []
    for s in acc:
        if s not in seen:
            seen.append(s)
    card['source_ids'] = seen
    # key order per contract; no `call` panel (the app inserts it)
    ordered = {k_: card[k_] for k_ in ('version', 'id', 'name', 'priority', 'verify', 'verify_note', 'phrases') if k_ in card}
    if 'variant_words' in card:
        ordered['variant_words'] = card['variant_words']
    ordered['panels'] = card['panels']
    ordered['source_ids'] = card['source_ids']
    (OUT / f"{card['id']}.json").write_text(json.dumps(ordered, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

used = set()
for card in CARDS:
    used.update(card['source_ids'])
unused = set(SOURCES) - used
assert not unused, unused
(OUT / 'sources.json').write_text(json.dumps(
    {'version': 1, 'sources': [SOURCES[s] for s in sorted(SOURCES, key=lambda s: (s.rsplit('-s', 1)[0], int(re.search(r'-s(\d+)-f', s).group(1)), int(s.rsplit('-f', 1)[1])))]},
    ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print('cards', len(CARDS), 'sources', len(SOURCES))
