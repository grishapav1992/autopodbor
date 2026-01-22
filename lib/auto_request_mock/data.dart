import 'package:flutter/material.dart';

import 'models.dart';

const uiTokens = UiTokens(
  gray900: Color(0xFF111827),
  gray700: Color(0xFF334155),
  gray600: Color(0xFF6B7280),
  gray400: Color(0xFF9CA3AF),
  gray300: Color(0xFFE5E7EB),
  gray100: Color(0xFFF1F5F9),
  gray50: Color(0xFFF8FAFC),
  blue600: Color(0xFF2563EB),
  red600: Color(0xFFDC2626),
  red100: Color(0xFFFEE2E2),
  red200: Color(0xFFFECACA),
);

const Map<RequestType, String> requestTypeLabel = {
  RequestType.byCar: 'По авто (можно несколько автомобилей)',
  RequestType.turnkey: 'Под ключ',
};

const Map<RequestStatus, String> statusLabel = {
  RequestStatus.draft: 'Черновик',
  RequestStatus.published: 'Создана',
  RequestStatus.hasOffers: 'Есть предложения',
  RequestStatus.proSelected: 'Исполнитель выбран',
  RequestStatus.inProgress: 'В работе',
  RequestStatus.completed: 'Завершена',
  RequestStatus.cancelled: 'Отменена',
  RequestStatus.dispute: 'Спор',
};

const Map<RequestStatus, Color> statusColor = {
  RequestStatus.draft: Color(0xFF475569),
  RequestStatus.published: Color(0xFF334155),
  RequestStatus.hasOffers: Color(0xFF2563EB),
  RequestStatus.proSelected: Color(0xFF4F46E5),
  RequestStatus.inProgress: Color(0xFFF59E0B),
  RequestStatus.completed: Color(0xFF16A34A),
  RequestStatus.cancelled: Color(0xFFDC2626),
  RequestStatus.dispute: Color(0xFF7C3AED),
};

const Map<String, Map<String, List<String>>> carCatalog = {
  'Toyota': {
    'Camry': ['XV40', 'XV50', 'XV70'],
    'Corolla': ['E150', 'E170', 'E210'],
    'RAV4': ['XA30', 'XA40', 'XA50'],
  },
  'Ford': {
    'Focus': ['Mk1', 'Mk2', 'Mk3', 'Mk4'],
    'Mondeo': ['Mk3', 'Mk4', 'Mk5'],
    'Kuga': ['I', 'II', 'III'],
  },
  'Volkswagen': {
    'Golf': ['Mk5', 'Mk6', 'Mk7', 'Mk8'],
    'Passat': ['B6', 'B7', 'B8'],
    'Tiguan': ['I', 'II'],
  },
};

const Map<String, Map<String, Map<String, List<int>>>> yearCatalog = {
  'Toyota': {
    'Camry': {
      'XV40': [2006, 2007, 2008, 2009, 2010, 2011],
      'XV50': [2012, 2013, 2014, 2015, 2016, 2017],
      'XV70': [2018, 2019, 2020, 2021, 2022, 2023, 2024],
    },
    'Corolla': {
      'E150': [2007, 2008, 2009, 2010, 2011, 2012, 2013],
      'E170': [2014, 2015, 2016, 2017, 2018],
      'E210': [2019, 2020, 2021, 2022, 2023, 2024],
    },
    'RAV4': {
      'XA30': [2006, 2007, 2008, 2009, 2010, 2011, 2012],
      'XA40': [2013, 2014, 2015, 2016, 2017, 2018],
      'XA50': [2019, 2020, 2021, 2022, 2023, 2024],
    },
  },
  'Ford': {
    'Focus': {
      'Mk1': [1998, 1999, 2000, 2001, 2002, 2003, 2004],
      'Mk2': [2005, 2006, 2007, 2008, 2009, 2010, 2011],
      'Mk3': [2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018],
      'Mk4': [2018, 2019, 2020, 2021, 2022, 2023, 2024],
    },
    'Mondeo': {
      'Mk3': [2000, 2001, 2002, 2003, 2004, 2005, 2006, 2007],
      'Mk4': [2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014],
      'Mk5': [2014, 2015, 2016, 2017, 2018, 2019, 2020, 2021],
    },
    'Kuga': {
      'I': [2008, 2009, 2010, 2011, 2012],
      'II': [2013, 2014, 2015, 2016, 2017, 2018, 2019],
      'III': [2020, 2021, 2022, 2023, 2024],
    },
  },
  'Volkswagen': {
    'Golf': {
      'Mk5': [2003, 2004, 2005, 2006, 2007, 2008, 2009],
      'Mk6': [2008, 2009, 2010, 2011, 2012, 2013],
      'Mk7': [2012, 2013, 2014, 2015, 2016, 2017, 2018, 2019],
      'Mk8': [2020, 2021, 2022, 2023, 2024],
    },
    'Passat': {
      'B6': [2005, 2006, 2007, 2008, 2009, 2010],
      'B7': [2010, 2011, 2012, 2013, 2014, 2015],
      'B8': [2015, 2016, 2017, 2018, 2019, 2020, 2021, 2022, 2023, 2024],
    },
    'Tiguan': {
      'I': [2007, 2008, 2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016],
      'II': [2016, 2017, 2018, 2019, 2020, 2021, 2022, 2023, 2024],
    },
  },
};

const List<String> segmentOptionsEU = [
  'A (мини)',
  'B',
  'C',
  'D',
  'E',
  'F',
  'J (SUV)',
  'M (минивэн)',
  'S (спорт)',
];

const List<String> segmentOptionsTaxi = [
  'Эконом',
  'Комфорт',
  'Комфорт+',
  'Бизнес',
  'Премиум',
  'Минивэн',
  'SUV',
];

const List<String> bodyTypeOptions = [
  'Седан',
  'Хэтчбек',
  'Универсал',
  'Кроссовер/SUV',
  'Минивэн',
  'Купе',
  'Пикап',
];

const List<String> fuelOptions = ['Бензин', 'Дизель', 'Гибрид', 'Электро'];
const List<String> transmissionOptions = ['AT', 'MT', 'CVT', 'Робот'];
const List<String> driveOptions = ['Передний', 'Задний', 'Полный'];
const List<String> colorOptions = [
  'Белый',
  'Черный',
  'Серый',
  'Синий',
  'Красный',
  'Зеленый',
  'Бежевый',
  'Любой',
];

const List<String> allowedListingDomains = [
  'avito.ru',
  'www.avito.ru',
  'drom.ru',
  'www.drom.ru',
  'auto.ru',
  'www.auto.ru',
];

const List<String> locationSuggestions = [
  'Алматы, Бостандыкский район',
  'Алматы, Медеуский район',
  'Алматы, Алатауский район',
  'Алматы, Ауэзовский район',
  'Алматинская область, Каскелен',
  'Алматинская область, Талгар',
  'Алматинская область, Илийский район',
  'Алматы, Турксибский район',
];

const Map<String, Map<String, String>> plateLookup = {
  'A123BC77': {
    'make': 'Toyota',
    'model': 'Camry',
    'restyling': 'XV70',
    'year': '2019',
    'vin': 'JTNB11HK1K3000001',
  },
  'K777KK77': {
    'make': 'Volkswagen',
    'model': 'Golf',
    'restyling': 'Mk7',
    'year': '2016',
    'vin': 'WVWZZZ1KZGW000002',
  },
  'M555MM77': {
    'make': 'Ford',
    'model': 'Focus',
    'restyling': 'Mk3',
    'year': '2015',
    'vin': 'WF0AXXWPMAP000003',
  },
};

const Map<String, String> brandCountryByMake = {
  'Toyota': 'Япония',
  'Ford': 'Иномарки',
  'Volkswagen': 'Иномарки',
  'BMW': 'Иномарки',
  'Audi': 'Иномарки',
  'Changan': 'Китай',
  'Chery': 'Китай',
  'Hyundai': 'Корея',
  'Kia': 'Корея',
  'Lada': 'Отечественные',
};

const List<String> brandCountries = [
  'Отечественные',
  'Иномарки',
  'Китай',
  'Корея',
  'Япония',
];

