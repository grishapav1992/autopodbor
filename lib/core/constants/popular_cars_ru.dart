String _normalizeKey(String value) {
  return value
      .toLowerCase()
      .trim()
      .replaceAll(RegExp(r'[^a-z0-9\u0400-\u04FF]+'), '');
}

const List<String> kPopularMakesRu = [
  'Lada',
  'Toyota',
  'Hyundai',
  'Kia',
  'Renault',
  'Volkswagen',
  'Skoda',
  'Nissan',
  'BMW',
  'Mercedes-Benz',
  'Audi',
  'Ford',
  'Chevrolet',
  'Honda',
  'Geely',
  'Haval',
  'Chery',
  'Mazda',
  'Mitsubishi',
  'Subaru',
];

const Map<String, List<String>> kPopularModelsRu = {
  'Lada': [
    'Granta',
    'Vesta',
    'Niva',
    'Niva Travel',
    'Niva Legend',
    'Largus',
    'XRAY',
    'Priora',
    'Kalina',
  ],
  'Toyota': [
    'Camry',
    'Corolla',
    'RAV4',
    'Land Cruiser',
    'Land Cruiser Prado',
    'Highlander',
    'Hilux',
  ],
  'Hyundai': [
    'Solaris',
    'Creta',
    'Tucson',
    'Santa Fe',
    'Elantra',
  ],
  'Kia': [
    'Rio',
    'Sportage',
    'Ceed',
    'K5',
    'Seltos',
    'Sorento',
  ],
  'Renault': [
    'Duster',
    'Logan',
    'Sandero',
    'Kaptur',
    'Arkana',
  ],
  'Volkswagen': [
    'Polo',
    'Tiguan',
    'Passat',
    'Golf',
    'Jetta',
  ],
  'Skoda': [
    'Octavia',
    'Rapid',
    'Kodiaq',
    'Karoq',
    'Superb',
  ],
  'Nissan': [
    'Qashqai',
    'X-Trail',
    'Juke',
    'Almera',
    'Terrano',
  ],
  'BMW': [
    '3 Series',
    '5 Series',
    'X5',
    'X3',
  ],
  'Mercedes-Benz': [
    'E-Class',
    'C-Class',
    'GLC',
    'GLE',
  ],
  'Audi': [
    'A4',
    'A6',
    'Q5',
    'Q7',
  ],
  'Honda': [
    'CR-V',
    'Civic',
    'Accord',
  ],
  'Geely': [
    'Coolray',
    'Atlas',
    'Emgrand',
  ],
  'Haval': [
    'Jolion',
    'F7',
    'F7x',
  ],
  'Chery': [
    'Tiggo 7',
    'Tiggo 4',
    'Tiggo 8',
  ],
  'Mazda': [
    'CX-5',
    'Mazda 3',
    'Mazda 6',
  ],
  'Mitsubishi': [
    'Outlander',
    'ASX',
    'Pajero',
  ],
  'Subaru': [
    'Forester',
    'Outback',
    'Impreza',
  ],
};

const List<String> kPopularModelsGlobalRu = [
  'Granta',
  'Vesta',
  'Rio',
  'Solaris',
  'Polo',
  'Camry',
  'Duster',
  'RAV4',
  'Creta',
  'Sportage',
  'Logan',
  'Octavia',
  'Kaptur',
  'Qashqai',
  'Tiguan',
  'Rapid',
  'Corolla',
  'Largus',
  'Niva',
  'X-Trail',
];

int _rankFor(String value, Map<String, int> rankMap) {
  return rankMap[_normalizeKey(value)] ?? 9999;
}

List<String> _popularModelsForMake(String make) {
  if (make.trim().isEmpty) return kPopularModelsGlobalRu;
  final target = _normalizeKey(make);
  for (final entry in kPopularModelsRu.entries) {
    if (_normalizeKey(entry.key) == target) {
      return entry.value;
    }
  }
  return kPopularModelsGlobalRu;
}

int compareMakesByPopularity(String a, String b) {
  final rank = {
    for (int i = 0; i < kPopularMakesRu.length; i++)
      _normalizeKey(kPopularMakesRu[i]): i,
  };
  final ra = _rankFor(a, rank);
  final rb = _rankFor(b, rank);
  if (ra != rb) return ra.compareTo(rb);
  return a.toLowerCase().compareTo(b.toLowerCase());
}

int compareModelsByPopularity(String make, String a, String b) {
  final popular = _popularModelsForMake(make);
  final rank = {
    for (int i = 0; i < popular.length; i++) _normalizeKey(popular[i]): i,
  };
  final ra = _rankFor(a, rank);
  final rb = _rankFor(b, rank);
  if (ra != rb) return ra.compareTo(rb);
  return a.toLowerCase().compareTo(b.toLowerCase());
}

List<String> sortMakesByPopularity(List<String> makes) {
  final sorted = List<String>.from(makes);
  sorted.sort(compareMakesByPopularity);
  return sorted;
}

List<String> sortModelsByPopularity(String make, List<String> models) {
  final sorted = List<String>.from(models);
  sorted.sort((a, b) => compareModelsByPopularity(make, a, b));
  return sorted;
}

List<String> sortModelsByPopularityForMakes(
  List<String> makes,
  List<String> models,
) {
  if (makes.length == 1) {
    return sortModelsByPopularity(makes.first, models);
  }
  return sortModelsByPopularity('', models);
}
