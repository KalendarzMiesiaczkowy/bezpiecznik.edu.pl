/// Health/safety words used only to classify a question as in-domain
/// ("brak w źródłach" instead of "poza tematem" when the knowledge base has
/// nothing, BG03). Not medical content: nothing here is ever shown or used as
/// an answer. Inflected forms are listed where the 3-character-prefix rule of
/// `Retriever._isDomainWord` would not reach them. Avoid short stems that
/// prefix-match everyday words (e.g. "waz" ~ "wazny", "rana" ~ "rano").
const List<String> kSafetyVocabulary = [
  // injuries, bites, poisoning
  'ugryzienie', 'ukąszenie', 'pogryzienie', 'użądlenie', 'żmija', 'żmii',
  'zatrucie', 'zatruć', 'otrucie', 'trucizna', 'toksyczny', 'zatruł',
  'grzyb', 'grzyby', 'grzybami', 'grzybach', 'muchomor', 'sinica',
  'skaleczenie', 'zranienie', 'oparzenie', 'odmrożenie', 'złamanie',
  'zwichnięcie', 'stłuczenie', 'wstrząs', 'wstrząśnienie', 'uraz',
  'obrażenia', 'rana', 'rany', 'ranny', 'ranni', 'rannego', 'poparzony',
  'porażenie', 'rażenie', 'utonięcie', 'tonie', 'topielec',
  'wychłodzenie', 'hipotermia', 'przegrzanie', 'udar', 'zawał', 'zemdlał',
  'omdlenie', 'drgawki', 'padaczka', 'alergia', 'uczulenie', 'anafilaksja',
  'duszność', 'astma', 'cukrzyca', 'hipoglikemia', 'infekcja', 'gorączka',
  'wymioty', 'biegunka', 'odwodnienie', 'krwawienie', 'zakrztuszenie',
  // medicines and doses
  'lekarstwo', 'lekarstwa', 'leki', 'lekarz', 'tabletka', 'tabletki',
  'dawka', 'dawkę', 'dawki', 'dawkowanie', 'przedawkowanie', 'ibuprofen',
  'paracetamol', 'apteczka', 'opatrunek', 'szczepionka', 'antybiotyk',
  // disasters and hazards
  'trzęsienie', 'lawina', 'osuwisko', 'tsunami', 'huragan',
  'wichura', 'burza', 'piorun', 'gradobicie', 'susza', 'upał', 'mróz',
  'wybuch', 'wybuchowy', 'eksplozja', 'gaz', 'czad', 'tlenek', 'wyciek',
  'skażenie', 'promieniowanie', 'radioaktywny', 'chemiczny', 'atak',
  'zagrożenie', 'niebezpieczeństwo', 'niebezpieczny', 'katastrofa',
  'awaria', 'zawalenie', 'zawalony', 'uwięziony', 'zasypany', 'zaginiony',
  'napad', 'przemoc', 'molestowanie', 'samobójstwo', 'samobójcze',
  // first aid and emergency
  'pomoc', 'ratunek', 'ratować', 'uratować', 'reanimacja',
  'resuscytacja', 'defibrylator', 'karetka', 'pogotowie', 'ratownik',
  'nieprzytomny', 'oddycha', 'oddychanie', 'puls', 'tętno', 'umiera',
  'umierający', 'śmierć', 'zagrożone', 'zdrowie', 'choroba',
  'objawy', 'cierpi',
];
