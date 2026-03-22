import 'dart:convert';

enum SparkJoyRole { company, specialist }

String sparkJoyRoleLabel(SparkJoyRole role) {
  switch (role) {
    case SparkJoyRole.company:
      return 'Компания';
    case SparkJoyRole.specialist:
      return 'Специалист';
  }
}

String sparkJoyRoleKey(SparkJoyRole role) {
  return role == SparkJoyRole.company ? 'company' : 'specialist';
}

SparkJoyRole sparkJoyRoleFromKey(String? key) {
  return key == 'company' ? SparkJoyRole.company : SparkJoyRole.specialist;
}

const String kSparkCompanyId = 'comp-1';
const String kSparkSpecialistId = 'spec-7';

const List<Map<String, dynamic>> sparkCompanies = [
  {
    'id': 'comp-1',
    'name': 'АвтоЭксперт Москва',
    'city': 'Москва',
    'description':
        'Профессиональная проверка автомобилей перед покупкой. Работаем с 2018 года.',
    'contactEmail': 'info@autoexpert-msk.ru',
    'contactPhone': '+7 (495) 123-45-67',
    'cities': ['Москва', 'Подольск', 'Химки', 'Мытищи'],
    'specialistCount': 8,
    'reportCount': 347,
    'status': 'active',
    'registeredAt': '2023-01-15',
  },
  {
    'id': 'comp-2',
    'name': 'CheckCar SPb',
    'city': 'Санкт-Петербург',
    'description':
        'Независимая экспертиза автомобилей в Санкт-Петербурге и области.',
    'contactEmail': 'hello@checkcar-spb.ru',
    'contactPhone': '+7 (812) 987-65-43',
    'cities': ['Санкт-Петербург', 'Пушкин', 'Кронштадт'],
    'specialistCount': 5,
    'reportCount': 189,
    'status': 'active',
    'registeredAt': '2023-06-20',
  },
];

const List<Map<String, dynamic>> sparkSpecialists = [
  {
    'id': 'spec-1',
    'name': 'Иван Сидоров',
    'city': 'Москва',
    'phone': '+7 (926) 111-22-33',
    'email': 'sidorov@mail.ru',
    'status': 'active',
    'format': 'staff',
    'companyId': 'comp-1',
    'companyName': 'АвтоЭксперт Москва',
    'reportCount': 78,
    'activeInspections': 2,
    'lastActive': '2026-03-15',
    'specialization': 'Кузовной осмотр',
    'experience': '5 лет',
    'rating': 4.8,
  },
  {
    'id': 'spec-2',
    'name': 'Пётр Волков',
    'city': 'Москва',
    'phone': '+7 (903) 444-55-66',
    'email': 'volkov@mail.ru',
    'status': 'active',
    'format': 'staff',
    'companyId': 'comp-1',
    'companyName': 'АвтоЭксперт Москва',
    'reportCount': 62,
    'activeInspections': 1,
    'lastActive': '2026-03-14',
    'specialization': 'Полная диагностика',
    'experience': '7 лет',
    'rating': 4.9,
  },
  {
    'id': 'spec-3',
    'name': 'Андрей Кузнецов',
    'city': 'Москва',
    'phone': '+7 (915) 777-88-99',
    'email': 'kuznetsov@mail.ru',
    'status': 'active',
    'format': 'guest',
    'companyId': 'comp-1',
    'companyName': 'АвтоЭксперт Москва',
    'reportCount': 12,
    'activeInspections': 1,
    'lastActive': '2026-03-13',
    'specialization': 'Электрика и диагностика',
    'experience': '3 года',
    'rating': 4.5,
  },
  {
    'id': 'spec-7',
    'name': 'Максим Егоров',
    'city': 'Москва',
    'phone': '+7 (925) 111-00-22',
    'email': 'egorov@mail.ru',
    'status': 'active',
    'format': 'private',
    'reportCount': 156,
    'activeInspections': 0,
    'lastActive': '2026-03-12',
    'specialization': 'Подбор и осмотр',
    'experience': '10 лет',
    'rating': 4.9,
  },
];

const List<Map<String, dynamic>> sparkAssignments = [
  {
    'id': 'asgn-1',
    'title': 'Осмотр Toyota Camry',
    'vehicle': 'Toyota Camry 2021',
    'vin': 'XW7BF4FK60S123456',
    'listingUrl': 'https://auto.ru/cars/used/sale/toyota/camry/111222333',
    'contactPhone': '+79261112233',
    'city': 'Москва',
    'specialistId': 'spec-1',
    'specialistName': 'Иван Сидоров',
    'companyId': 'comp-1',
    'companyName': 'АвтоЭксперт Москва',
    'date': '2026-03-16',
    'address': 'ул. Ленина, д. 15',
    'comment': 'Клиент просит утренний осмотр',
    'status': 'in_progress',
    'reportId': 'rpt-1',
    'createdAt': '2026-03-10',
  },
  {
    'id': 'asgn-2',
    'title': 'Проверка BMW X5',
    'vehicle': 'BMW X5 2020',
    'vin': 'WBAJB9C54KB789012',
    'listingUrl': 'https://auto.ru/cars/used/sale/bmw/x5/444555666',
    'contactPhone': '+79034445566',
    'city': 'Москва',
    'specialistId': 'spec-2',
    'specialistName': 'Пётр Волков',
    'companyId': 'comp-1',
    'companyName': 'АвтоЭксперт Москва',
    'date': '2026-03-17',
    'address': 'Ярославское ш., д. 120',
    'status': 'assigned',
    'createdAt': '2026-03-12',
  },
  {
    'id': 'asgn-3',
    'title': 'Электрика Kia Sportage',
    'vehicle': 'Kia Sportage 2022',
    'vin': 'XWEPH81ABN0345678',
    'listingUrl': 'https://auto.ru/cars/used/sale/kia/sportage/777888999',
    'contactPhone': '+79157778899',
    'city': 'Москва',
    'specialistId': 'spec-3',
    'specialistName': 'Андрей Кузнецов',
    'companyId': 'comp-1',
    'companyName': 'АвтоЭксперт Москва',
    'date': '2026-03-18',
    'address': 'ул. Мира, д. 45',
    'comment': 'Проверка электрики — приоритет',
    'status': 'assigned',
    'createdAt': '2026-03-11',
  },
  {
    'id': 'asgn-4',
    'title': 'Осмотр Hyundai Tucson',
    'vehicle': 'Hyundai Tucson 2023',
    'vin': 'TMAJ381APNJ901234',
    'listingUrl': 'https://auto.ru/cars/used/sale/hyundai/tucson/123987456',
    'contactPhone': '+79261239874',
    'city': 'Москва',
    'specialistId': 'spec-1',
    'specialistName': 'Иван Сидоров',
    'companyId': 'comp-1',
    'companyName': 'АвтоЭксперт Москва',
    'date': '2026-03-14',
    'status': 'completed',
    'reportId': 'rpt-2',
    'createdAt': '2026-03-08',
  },
  {
    'id': 'asgn-9',
    'title': 'Audi A4 — срочный осмотр',
    'vehicle': 'Audi A4 2022',
    'vin': 'WAUZZZ8K9NA123456',
    'listingUrl': 'https://auto.ru/cars/used/sale/audi/a4/123456789',
    'contactPhone': '+79031234567',
    'city': 'Москва',
    'specialistId': 'spec-7',
    'specialistName': 'Максим Егоров',
    'companyId': 'comp-1',
    'companyName': 'АвтоЭксперт Москва',
    'date': '2026-03-20',
    'address': 'ул. Тверская, д. 10',
    'comment': 'Клиент ждёт на паркинге, белый цвет',
    'status': 'assigned',
    'createdAt': '2026-03-16',
  },
  {
    'id': 'asgn-10',
    'title': 'Genesis G70 полная диагностика',
    'vehicle': 'Genesis G70 2023',
    'vin': 'KMTG341ABNP567890',
    'listingUrl': 'https://auto.ru/cars/used/sale/genesis/g70/987654321',
    'contactPhone': '+79157654321',
    'city': 'Москва',
    'specialistId': 'spec-7',
    'specialistName': 'Максим Егоров',
    'companyId': 'comp-1',
    'companyName': 'АвтоЭксперт Москва',
    'date': '2026-03-22',
    'comment': 'Полная диагностика + тест-драйв',
    'status': 'assigned',
    'createdAt': '2026-03-16',
  },
];

const List<Map<String, dynamic>> sparkPlatformReports = [
  {
    'id': 'rpt-1',
    'vehicle': 'Toyota Camry 2021',
    'vin': 'XW7BF4FK60S123456',
    'city': 'Москва',
    'specialistId': 'spec-1',
    'specialistName': 'Иван Сидоров',
    'companyId': 'comp-1',
    'companyName': 'АвтоЭксперт Москва',
    'assignmentId': 'asgn-1',
    'format': 'staff',
    'status': 'draft',
    'createdAt': '2026-03-16',
  },
  {
    'id': 'rpt-2',
    'vehicle': 'Hyundai Tucson 2023',
    'vin': 'TMAJ381APNJ901234',
    'city': 'Москва',
    'specialistId': 'spec-1',
    'specialistName': 'Иван Сидоров',
    'companyId': 'comp-1',
    'companyName': 'АвтоЭксперт Москва',
    'assignmentId': 'asgn-4',
    'format': 'staff',
    'status': 'completed',
    'score': 7.2,
    'createdAt': '2026-03-14',
  },
  {
    'id': 'rpt-4',
    'vehicle': 'Mazda CX-5 2022',
    'vin': 'JMZKE2BE7N0112233',
    'city': 'Москва',
    'specialistId': 'spec-7',
    'specialistName': 'Максим Егоров',
    'format': 'private',
    'status': 'completed',
    'score': 6.8,
    'createdAt': '2026-03-11',
  },
];

const Map<String, String> sparkFormatLabels = {
  'private': 'Частный',
  'staff': 'В штате',
  'guest': 'Внештат',
};

const Map<String, String> sparkAssignmentStatusLabels = {
  'new': 'Новая',
  'assigned': 'Передано спецу',
  'in_progress': 'В работе',
  'completed': 'Завершено',
};

Map<String, dynamic> cloneMap(Map<String, dynamic> map) {
  return jsonDecode(jsonEncode(map)) as Map<String, dynamic>;
}

List<Map<String, dynamic>> cloneMapList(List<Map<String, dynamic>> list) {
  return list.map(cloneMap).toList();
}
