import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:camera/camera.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/ui/common/widgets/my_button_widget.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_storage.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/vin_ocr_service.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SparkJoyCreateReportScreen extends StatefulWidget {
  const SparkJoyCreateReportScreen({
    super.key,
    this.initialReportName,
    this.draft,
    this.assignment,
  });

  final String? initialReportName;
  final Map<String, dynamic>? draft;
  final Map<String, dynamic>? assignment;

  @override
  State<SparkJoyCreateReportScreen> createState() =>
      _SparkJoyCreateReportScreenState();
}

class _SparkJoyCreateReportScreenState
    extends State<SparkJoyCreateReportScreen> {
  static const List<String> _engineTypes = [
    'Бензин',
    'Дизель',
    'Гибрид',
    'Электро',
    'Газ/Бензин',
  ];
  static const List<String> _gearboxTypes = [
    'АКПП',
    'МКПП',
    'Робот',
    'Вариатор',
  ];
  static const List<String> _driveTypes = ['Передний', 'Задний', 'Полный'];
  static const List<String> _colors = [
    'Белый',
    'Чёрный',
    'Серый',
    'Серебристый',
    'Синий',
    'Голубой',
    'Красный',
    'Бордовый',
    'Зелёный',
    'Жёлтый',
    'Оранжевый',
    'Коричневый',
    'Бежевый',
    'Фиолетовый',
    'Золотистый',
  ];
  static const List<String> _ownersCounts = ['1', '2', '3', '4+'];
  static const List<_CarCatalogBrand> _carCatalog = [
    _CarCatalogBrand(
      name: 'Toyota',
      models: [
        _CarCatalogModel(
          name: 'Camry',
          generations: [
            _CarCatalogGeneration(
              name: 'XV70',
              restylings: [
                _CarCatalogRestyling(
                  label: '2018-2021 · рест. 0',
                  frames: 'XV70 дорест',
                  photoUrl:
                      'https://images.unsplash.com/photo-1493238792000-8113da705763?w=1200&q=80&auto=format&fit=crop',
                ),
                _CarCatalogRestyling(
                  label: '2021-н.в. · рест. 1',
                  frames: 'XV70 рест',
                  photoUrl:
                      'https://images.unsplash.com/photo-1503376780353-7e6692767b70?w=1200&q=80&auto=format&fit=crop',
                ),
              ],
            ),
          ],
        ),
        _CarCatalogModel(
          name: 'RAV4',
          generations: [
            _CarCatalogGeneration(
              name: 'XA50',
              restylings: [
                _CarCatalogRestyling(
                  label: '2019-н.в. · рест. 0',
                  frames: 'XA50',
                  photoUrl:
                      'https://images.unsplash.com/photo-1549924231-f129b911e442?w=1200&q=80&auto=format&fit=crop',
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    _CarCatalogBrand(
      name: 'BMW',
      models: [
        _CarCatalogModel(
          name: 'X5',
          generations: [
            _CarCatalogGeneration(
              name: 'G05',
              restylings: [
                _CarCatalogRestyling(
                  label: '2018-2023 · рест. 0',
                  frames: 'G05 дорест',
                  photoUrl:
                      'https://images.unsplash.com/photo-1552519507-da3b142c6e3d?w=1200&q=80&auto=format&fit=crop',
                ),
                _CarCatalogRestyling(
                  label: '2023-н.в. · рест. 1',
                  frames: 'G05 LCI',
                  photoUrl:
                      'https://images.unsplash.com/photo-1553440569-bcc63803a83d?w=1200&q=80&auto=format&fit=crop',
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    _CarCatalogBrand(
      name: 'Kia',
      models: [
        _CarCatalogModel(
          name: 'Sportage',
          generations: [
            _CarCatalogGeneration(
              name: 'NQ5',
              restylings: [
                _CarCatalogRestyling(
                  label: '2021-н.в. · рест. 0',
                  frames: 'NQ5',
                  photoUrl:
                      'https://images.unsplash.com/photo-1619405399517-d7fce0f13302?w=1200&q=80&auto=format&fit=crop',
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    _CarCatalogBrand(
      name: 'Hyundai',
      models: [
        _CarCatalogModel(
          name: 'Tucson',
          generations: [
            _CarCatalogGeneration(
              name: 'NX4',
              restylings: [
                _CarCatalogRestyling(
                  label: '2020-н.в. · рест. 0',
                  frames: 'NX4',
                  photoUrl:
                      'https://images.unsplash.com/photo-1609521263047-f8f205293f24?w=1200&q=80&auto=format&fit=crop',
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    _CarCatalogBrand(
      name: 'Audi',
      models: [
        _CarCatalogModel(
          name: 'A4',
          generations: [
            _CarCatalogGeneration(
              name: 'B9',
              restylings: [
                _CarCatalogRestyling(
                  label: '2015-2019 · рест. 0',
                  frames: 'B9 дорест',
                  photoUrl:
                      'https://images.unsplash.com/photo-1613214150388-5607da5f5f59?w=1200&q=80&auto=format&fit=crop',
                ),
                _CarCatalogRestyling(
                  label: '2019-н.в. · рест. 1',
                  frames: 'B9 рест',
                  photoUrl:
                      'https://images.unsplash.com/photo-1549399542-7e82138e7f9b?w=1200&q=80&auto=format&fit=crop',
                ),
              ],
            ),
          ],
        ),
      ],
    ),
    _CarCatalogBrand(
      name: 'Genesis',
      models: [
        _CarCatalogModel(
          name: 'G70',
          generations: [
            _CarCatalogGeneration(
              name: 'IK',
              restylings: [
                _CarCatalogRestyling(
                  label: '2017-2020 · рест. 0',
                  frames: 'IK дорест',
                  photoUrl:
                      'https://images.unsplash.com/photo-1619767886558-efdc259cde1a?w=1200&q=80&auto=format&fit=crop',
                ),
                _CarCatalogRestyling(
                  label: '2020-н.в. · рест. 1',
                  frames: 'IK рест',
                  photoUrl:
                      'https://images.unsplash.com/photo-1563720223185-11003d516935?w=1200&q=80&auto=format&fit=crop',
                ),
              ],
            ),
          ],
        ),
      ],
    ),
  ];

  static const List<String> _tdEngineTagOptions = [
    'Вибрация двигателя',
    'Посторонний стук',
    'Потеря мощности',
    'Пропуски зажигания',
    'Дым из выхлопной',
    'Перегрев',
    'Нестабильный холостой ход',
  ];
  static const List<String> _tdGearboxTagOptions = [
    'Тугое переключение',
    'Задержка переключения',
    'Толчки / пинки',
    'Пробуксовка',
    'Посторонний шум КПП',
    'Вибрация на ходу',
  ];
  static const List<String> _tdSteeringTagOptions = [
    'Люфт руля',
    'Увод в сторону',
    'Шум при повороте',
    'Тяжёлый руль',
    'Вибрация руля',
  ];
  static const List<String> _tdRideTagOptions = [
    'Стук подвески на ходу',
    'Раскачка кузова',
    'Снос оси',
    'Пробой подвески',
  ];
  static const List<String> _tdBrakeTagOptions = [
    'Увод при торможении',
    'Вибрация при торможении',
    'Длинный ход педали',
    'Скрип тормозов',
    'Срабатывание ABS на ровной',
  ];
  static const String _tdModeAllGood = 'all_good';
  static const String _tdModeProblems = 'problems';
  static const String _tdModeNotConducted = 'not_conducted';
  static const Map<String, String> _summaryTitleToGroupKey = {
    'Кузов': 'body',
    'Остекление': 'glass',
    'Силовые элементы кузова': 'structural',
    'Светотехника': 'lighting',
    'Подкапотное пространство': 'underhood',
    'Салон': 'interior',
    'Колёса и шины': 'wheels',
    'Колёса и тормозные механизмы': 'wheels',
    'Компьютерная диагностика': 'diagnostics',
    'Диагностика': 'diagnostics',
  };
  static const Map<String, String> _mediaGroupLabelByKey = {
    'body': 'Кузов',
    'glass': 'Остекление',
    'lighting': 'Светотехника',
    'underhood': 'Подкапотное пространство',
    'interior': 'Салон',
    'diagnostics': 'Компьютерная диагностика',
    'structural': 'Силовые элементы кузова',
    'wheels': 'Колёса и тормозные механизмы',
  };
  static const Set<String> _interiorDashboardElementIds = {
    'dashboard_top',
    'instrument_cluster',
    'center_display',
    'climate_panel',
    'center_console',
    'gear_selector_area',
    'dashboard_buttons_left',
  };
  static const Map<String, List<_MediaOption>> _mediaElementOptionsByGroup = {
    'body': [
      _MediaOption(id: 'hood', label: 'Капот'),
      _MediaOption(id: 'front_bumper', label: 'Передний бампер'),
      _MediaOption(id: 'roof', label: 'Крыша'),
      _MediaOption(id: 'trunk', label: 'Багажник'),
      _MediaOption(id: 'rear_bumper', label: 'Задний бампер'),
      _MediaOption(id: 'left_front_fender', label: 'Левое переднее крыло'),
      _MediaOption(id: 'left_front_door', label: 'Левая передняя дверь'),
      _MediaOption(id: 'left_rear_door', label: 'Левая задняя дверь'),
      _MediaOption(id: 'left_rear_fender', label: 'Левое заднее крыло'),
      _MediaOption(id: 'right_front_fender', label: 'Правое переднее крыло'),
      _MediaOption(id: 'right_front_door', label: 'Правая передняя дверь'),
      _MediaOption(id: 'right_rear_door', label: 'Правая задняя дверь'),
      _MediaOption(id: 'right_rear_fender', label: 'Правое заднее крыло'),
      _MediaOption(
        id: 'uh_body_elements',
        label: 'Кузовные элементы под капотом',
      ),
      _MediaOption(
        id: 'inner_trunk_lid',
        label: 'Внутренняя сторона крышки багажника',
      ),
      _MediaOption(id: 'body_general', label: 'Общее состояние'),
    ],
    'structural': [
      _MediaOption(id: 'a_pillar_left', label: 'Передняя стойка левая (A)'),
      _MediaOption(id: 'a_pillar_right', label: 'Передняя стойка правая (A)'),
      _MediaOption(id: 'b_pillar_left', label: 'Центральная стойка левая (B)'),
      _MediaOption(
        id: 'b_pillar_right',
        label: 'Центральная стойка правая (B)',
      ),
      _MediaOption(id: 'c_pillar_left', label: 'Задняя стойка левая (C)'),
      _MediaOption(id: 'c_pillar_right', label: 'Задняя стойка правая (C)'),
      _MediaOption(id: 'rail_left', label: 'Лонжерон левый'),
      _MediaOption(id: 'rail_right', label: 'Лонжерон правый'),
      _MediaOption(id: 'sill_left', label: 'Порог левый'),
      _MediaOption(id: 'sill_right', label: 'Порог правый'),
      _MediaOption(
        id: 'fender_liner_left_front',
        label: 'Брызговик левый передний',
      ),
      _MediaOption(
        id: 'fender_liner_right_front',
        label: 'Брызговик правый передний',
      ),
      _MediaOption(
        id: 'fender_liner_left_rear',
        label: 'Брызговик левый задний',
      ),
      _MediaOption(
        id: 'fender_liner_right_rear',
        label: 'Брызговик правый задний',
      ),
      _MediaOption(id: 'structural_general', label: 'Общее состояние'),
    ],
    'glass': [
      _MediaOption(id: 'windshield', label: 'Лобовое стекло'),
      _MediaOption(id: 'rear_glass', label: 'Заднее стекло'),
      _MediaOption(id: 'glass_front_left', label: 'Переднее левое стекло'),
      _MediaOption(id: 'glass_front_right', label: 'Переднее правое стекло'),
      _MediaOption(id: 'glass_rear_left', label: 'Заднее левое стекло'),
      _MediaOption(id: 'glass_rear_right', label: 'Заднее правое стекло'),
      _MediaOption(id: 'mirror_left', label: 'Зеркало левое'),
      _MediaOption(id: 'mirror_right', label: 'Зеркало правое'),
      _MediaOption(id: 'glass_general', label: 'Общее состояние'),
    ],
    'lighting': [
      _MediaOption(id: 'headlights_front', label: 'Передние фары'),
      _MediaOption(id: 'taillights_rear', label: 'Задние фонари'),
      _MediaOption(id: 'drl', label: 'ДХО'),
      _MediaOption(id: 'fog_lights', label: 'Противотуманки'),
      _MediaOption(id: 'turn_signals', label: 'Поворотники'),
      _MediaOption(id: 'brake_lights', label: 'Стоп-сигналы'),
      _MediaOption(id: 'plate_light', label: 'Подсветка номера'),
      _MediaOption(id: 'lighting_general', label: 'Общее состояние'),
    ],
    'underhood': [
      _MediaOption(id: 'uh_engine', label: 'Двигатель'),
      _MediaOption(id: 'uh_accessories', label: 'Навесное оборудование'),
      _MediaOption(id: 'uh_cooling', label: 'Система охлаждения'),
      _MediaOption(id: 'uh_fuel', label: 'Топливная система'),
      _MediaOption(id: 'uh_intake_turbo', label: 'Впуск / турбина'),
      _MediaOption(id: 'uh_exhaust_ecology', label: 'Выпуск / экология'),
      _MediaOption(id: 'uh_electrical', label: 'Электрика'),
      _MediaOption(id: 'uh_brakes', label: 'Тормозная система'),
      _MediaOption(id: 'uh_steering', label: 'Рулевое управление'),
      _MediaOption(id: 'uh_fluids', label: 'Жидкости и бачки'),
      _MediaOption(id: 'uh_general', label: 'Общее состояние'),
    ],
    'wheels': [
      _MediaOption(id: 'front_left_wheel', label: 'Переднее левое колесо'),
      _MediaOption(id: 'front_right_wheel', label: 'Переднее правое колесо'),
      _MediaOption(id: 'rear_left_wheel', label: 'Заднее левое колесо'),
      _MediaOption(id: 'rear_right_wheel', label: 'Заднее правое колесо'),
      _MediaOption(id: 'spare_wheel', label: 'Запасное колесо / докатка'),
      _MediaOption(
        id: 'front_left_brake',
        label: 'Передний левый тормозной механизм',
      ),
      _MediaOption(
        id: 'front_right_brake',
        label: 'Передний правый тормозной механизм',
      ),
      _MediaOption(
        id: 'rear_left_brake',
        label: 'Задний левый тормозной механизм',
      ),
      _MediaOption(
        id: 'rear_right_brake',
        label: 'Задний правый тормозной механизм',
      ),
      _MediaOption(id: 'wheels_general', label: 'Общее состояние'),
    ],
    'interior': [
      _MediaOption(id: 'front_seats', label: 'Передние сиденья'),
      _MediaOption(id: 'rear_seats', label: 'Задние сиденья'),
      _MediaOption(id: 'door_cards', label: 'Дверные карты'),
      _MediaOption(id: 'headliner', label: 'Потолок'),
      _MediaOption(id: 'trunk_interior', label: 'Багажное отделение'),
      _MediaOption(id: 'steering_wheel', label: 'Рулевое колесо'),
      _MediaOption(id: 'dashboard_top', label: 'Торпедо'),
      _MediaOption(id: 'instrument_cluster', label: 'Комбинация приборов'),
      _MediaOption(id: 'center_display', label: 'Центральный экран'),
      _MediaOption(id: 'climate_panel', label: 'Блок климата'),
      _MediaOption(id: 'center_console', label: 'Центральная консоль'),
      _MediaOption(id: 'gear_selector_area', label: 'Зона селектора КПП'),
      _MediaOption(id: 'dashboard_buttons_left', label: 'Кнопки слева от руля'),
      _MediaOption(id: 'interior_general', label: 'Общее состояние'),
    ],
    'diagnostics': [
      _MediaOption(id: 'diag_engine', label: 'Двигатель'),
      _MediaOption(id: 'diag_transmission', label: 'Трансмиссия / АКПП / КПП'),
      _MediaOption(id: 'diag_abs_esp', label: 'ABS / ESP / тормозные системы'),
      _MediaOption(id: 'diag_srs_airbag', label: 'SRS / Airbag / подушки'),
      _MediaOption(id: 'diag_electric', label: 'Электрика / бортовая сеть'),
      _MediaOption(
        id: 'diag_ecology',
        label: 'Экология / катализатор / EGR / лямбда',
      ),
      _MediaOption(
        id: 'diag_body_comfort',
        label: 'Кузовная электроника / комфорт',
      ),
      _MediaOption(
        id: 'diag_steering_suspension',
        label: 'Рулевое управление / подвеска',
      ),
      _MediaOption(id: 'diag_awd', label: 'Полный привод / AWD / 4WD'),
      _MediaOption(id: 'diag_climate', label: 'Климат / кондиционер'),
      _MediaOption(id: 'diag_immobilizer', label: 'Иммобилайзер / запуск'),
      _MediaOption(id: 'diag_general', label: 'Общее состояние'),
    ],
  };
  static const Map<String, List<String>> _mediaTagOptionsByGroup = {
    'body': [
      'Полный окрас',
      'Окрас большей части',
      'Глубокая деформация',
      'Шпатлёвка от 400мкм',
      'Царапина от 10см',
      'Замена элемента',
      'Царапина до 5 см',
      'Царапина до 10 см',
      'Шпатлёвка до 400мкм',
      'Частичный окрас 1/4',
      'Вмятина без повр. ЛКП',
      'Скол',
    ],
    'glass': [
      'Трещина',
      'Замена (не оригинал)',
      'Расслоение',
      'Скол',
      'Царапина',
      'Тонировка',
      'Повреждение уплотнителя',
      'Запотевание / влага',
    ],
    'structural': [
      'Деформация',
      'Трещина',
      'Коррозия',
      'Замена элемента',
      'Следы сварки',
      'Нештатный герметик',
      'Подкрас / шпатлёвка',
    ],
    'lighting': [
      'Не работает',
      'Трещина / разрушение',
      'Не оригинал',
      'Помутнение',
      'Запотевание / влага',
      'Царапина',
      'Скол',
    ],
    'underhood': [
      'Течь / подтёк',
      'Механическое повреждение',
      'Не оригинал',
      'Коррозия',
      'Сильное загрязнение',
      'Нештатная проводка',
    ],
    'wheels': [
      'Повреждение шины',
      'Повреждение диска',
      'Люфт ступицы',
      'Неравномерный износ',
      'Коррозия диска',
      'Износ тормозов',
      'Скрип / биение',
    ],
    'interior': [
      'Разрыв обивки',
      'Прожог',
      'Трещина элемента',
      'Сломанный элемент',
      'Не работает функция',
      'Износ',
      'Потёртость',
      'Царапины',
      'Пятна',
      'Повреждение обшивки',
      'Посторонний запах',
    ],
    'interior_dashboard': [
      'Трещина панели',
      'Экран не работает',
      'Приборная панель неисправна',
      'Блок климата неисправен',
      'Кнопки не работают',
      'Нештатная установка',
      'Царапины',
      'Потёртость',
      'Битые пиксели / засветы',
      'Неисправна подсветка',
      'Следы разбора',
      'Стёрты пиктограммы',
    ],
    'diagnostics': [
      'Ошибка двигателя',
      'Ошибка АКПП/КПП',
      'Ошибка подушек безопасности',
      'Ошибка ABS/ESP',
      'Ошибка электрики',
      'Ошибка экологии/катализатора',
      'Ошибка кузовных систем',
      'Замороженная ошибка',
      'Предупреждение двигателя',
      'Предупреждение АКПП/КПП',
      'Предупреждение ABS/ESP',
      'Предупреждение электрики',
      'Предупреждение кузовных систем',
    ],
  };
  static const Map<String, Set<String>> _mediaSeriousTagsByGroup = {
    'body': {
      'Полный окрас',
      'Окрас большей части',
      'Глубокая деформация',
      'Шпатлёвка от 400мкм',
      'Царапина от 10см',
      'Замена элемента',
    },
    'glass': {'Трещина', 'Замена (не оригинал)', 'Расслоение'},
    'structural': {'Деформация', 'Трещина', 'Коррозия', 'Замена элемента'},
    'lighting': {'Не работает', 'Трещина / разрушение', 'Не оригинал'},
    'underhood': {'Течь / подтёк', 'Механическое повреждение', 'Не оригинал'},
    'wheels': {'Повреждение шины', 'Повреждение диска', 'Люфт ступицы'},
    'interior': {
      'Разрыв обивки',
      'Прожог',
      'Трещина элемента',
      'Сломанный элемент',
      'Не работает функция',
    },
    'interior_dashboard': {
      'Трещина панели',
      'Экран не работает',
      'Приборная панель неисправна',
      'Блок климата неисправен',
      'Кнопки не работают',
      'Нештатная установка',
    },
    'diagnostics': {
      'Ошибка двигателя',
      'Ошибка АКПП/КПП',
      'Ошибка подушек безопасности',
      'Ошибка ABS/ESP',
      'Ошибка электрики',
      'Ошибка экологии/катализатора',
      'Ошибка кузовных систем',
    },
  };
  static const Map<String, List<String>> _diagnosticTagOptionsByElement = {
    'diag_engine': [
      'Ошибки двигателя',
      'Пропуски зажигания',
      'Ошибка датчика',
      'Неровная работа',
      'Ошибка по смеси',
      'Низкое давление топлива',
      'Ошибка турбины',
      'Передув',
      'Недодув',
      'Ошибка фаз',
      'Ошибка ГРМ',
      'Предупреждение по двигателю',
      'Нестабильная работа',
      'Подозрение на пропуски',
      'Ошибка по датчику',
      'Требуется проверка топливной системы',
      'Требуется проверка наддува',
      'Подозрение на подсос воздуха',
    ],
    'diag_transmission': [
      'Ошибки АКПП',
      'Аварийный режим АКПП',
      'Пробуксовка',
      'Ошибка мехатроника',
      'Ошибка сцепления',
      'Ошибка DSG',
      'Ошибка вариатора',
      'Предупреждение по АКПП',
      'Требуется проверка АКПП',
      'Есть замечания по переключениям',
      'Подозрение на износ сцепления',
      'Рекомендована диагностика трансмиссии',
    ],
    'diag_abs_esp': [
      'Ошибка ABS',
      'Ошибка ESP',
      'Ошибка датчика колеса',
      'Ошибка EPB',
      'Неисправность тормозной системы',
      'Предупреждение ABS/ESP',
      'Требуется проверка датчика колеса',
      'Требуется проверка тормозной системы',
    ],
    'diag_srs_airbag': [
      'Ошибка SRS',
      'Ошибка Airbag',
      'Неисправность подушек безопасности',
      'Ошибка преднатяжителей',
      'Ошибка датчика удара',
      'Предупреждение SRS',
      'Требуется проверка системы безопасности',
    ],
    'diag_electric': [
      'Ошибка электрики',
      'Низкое напряжение',
      'Ошибка генератора',
      'Короткое замыкание',
      'Обрыв цепи',
      'Ошибка CAN',
      'Потеря связи',
      'Ошибка блока управления',
      'Предупреждение по электрике',
      'Нестабильное питание',
      'Требуется проверка аккумулятора',
      'Требуется проверка генератора',
      'Периодическая потеря связи',
    ],
    'diag_ecology': [
      'Ошибка катализатора',
      'Ошибка лямбда-зонда',
      'Ошибка EGR',
      'Ошибка DPF',
      'Ошибка AdBlue',
      'Предупреждение по экологии',
      'Требуется проверка катализатора',
      'Требуется проверка лямбда-зонда',
      'Рекомендована проверка DPF',
    ],
    'diag_body_comfort': [
      'Ошибка системы',
      'Неисправность',
      'Требуется проверка',
      'Есть замечания',
    ],
    'diag_steering_suspension': [
      'Ошибка системы',
      'Неисправность',
      'Требуется проверка',
      'Есть замечания',
    ],
    'diag_awd': [
      'Ошибка системы',
      'Неисправность',
      'Требуется проверка',
      'Есть замечания',
    ],
    'diag_climate': [
      'Ошибка системы',
      'Неисправность',
      'Требуется проверка',
      'Есть замечания',
    ],
    'diag_immobilizer': [
      'Ошибка системы',
      'Неисправность',
      'Требуется проверка',
      'Есть замечания',
    ],
  };
  static const Map<String, Set<String>> _diagnosticSeriousTagsByElement = {
    'diag_engine': {
      'Ошибки двигателя',
      'Пропуски зажигания',
      'Ошибка датчика',
      'Неровная работа',
      'Ошибка по смеси',
      'Низкое давление топлива',
      'Ошибка турбины',
      'Передув',
      'Недодув',
      'Ошибка фаз',
      'Ошибка ГРМ',
    },
    'diag_transmission': {
      'Ошибки АКПП',
      'Аварийный режим АКПП',
      'Пробуксовка',
      'Ошибка мехатроника',
      'Ошибка сцепления',
      'Ошибка DSG',
      'Ошибка вариатора',
    },
    'diag_abs_esp': {
      'Ошибка ABS',
      'Ошибка ESP',
      'Ошибка датчика колеса',
      'Ошибка EPB',
      'Неисправность тормозной системы',
    },
    'diag_srs_airbag': {
      'Ошибка SRS',
      'Ошибка Airbag',
      'Неисправность подушек безопасности',
      'Ошибка преднатяжителей',
      'Ошибка датчика удара',
    },
    'diag_electric': {
      'Ошибка электрики',
      'Низкое напряжение',
      'Ошибка генератора',
      'Короткое замыкание',
      'Обрыв цепи',
      'Ошибка CAN',
      'Потеря связи',
      'Ошибка блока управления',
    },
    'diag_ecology': {
      'Ошибка катализатора',
      'Ошибка лямбда-зонда',
      'Ошибка EGR',
      'Ошибка DPF',
      'Ошибка AdBlue',
    },
    'diag_body_comfort': {'Ошибка системы', 'Неисправность'},
    'diag_steering_suspension': {'Ошибка системы', 'Неисправность'},
    'diag_awd': {'Ошибка системы', 'Неисправность'},
    'diag_climate': {'Ошибка системы', 'Неисправность'},
    'diag_immobilizer': {'Ошибка системы', 'Неисправность'},
  };

  static const List<_StepConfig> _steps = [
    _StepConfig(
      id: 'vehicle',
      title: 'Автомобиль',
      description: 'VIN, госномер, марка/модель, ссылка на объявление',
    ),
    _StepConfig(
      id: 'params',
      title: 'Параметры',
      description: 'Пробег, двигатель, КПП, привод, цвет, город осмотра',
    ),
    _StepConfig(
      id: 'docs_check',
      title: 'Сверка документов',
      description: 'Проверка совпадения владельца, VIN и модели двигателя',
    ),
    _StepConfig(
      id: 'legal',
      title: 'Юр. проверка',
      description: 'Зафиксируйте статус юридической проверки автомобиля',
    ),
    _StepConfig(
      id: 'media',
      title: 'Осмотр',
      description: 'Заполните группы осмотра, заметки и ссылки на фото/видео',
    ),
    _StepConfig(
      id: 'test_drive',
      title: 'Тест-драйв',
      description: 'Проверка автомобиля на ходу',
    ),
    _StepConfig(
      id: 'summary',
      title: 'Итог',
      description: 'Итоговый вердикт, чеклист и заключение специалиста',
    ),
  ];

  static const List<_MediaGroupConfig> _mediaGroupsConfig = [
    _MediaGroupConfig(
      key: 'body',
      title: 'Кузов',
      description: 'ЛКП, вмятины, царапины, дефекты элементов',
      required: true,
      severeIfIssue: false,
    ),
    _MediaGroupConfig(
      key: 'structural',
      title: 'Силовые элементы кузова',
      description: 'Лонжероны, стойки, пороги, геометрия',
      required: false,
      severeIfIssue: true,
    ),
    _MediaGroupConfig(
      key: 'glass',
      title: 'Остекление',
      description: 'Лобовое, боковые, заднее стекло',
      required: true,
      severeIfIssue: false,
    ),
    _MediaGroupConfig(
      key: 'lighting',
      title: 'Светотехника',
      description: 'Фары, фонари, ПТФ, корректоры',
      required: false,
      severeIfIssue: false,
    ),
    _MediaGroupConfig(
      key: 'underhood',
      title: 'Подкапотное пространство',
      description: 'Течи, крепеж, ремни, агрегаты',
      required: true,
      severeIfIssue: true,
    ),
    _MediaGroupConfig(
      key: 'interior',
      title: 'Салон',
      description: 'Износ, электроника, функции и опции',
      required: true,
      severeIfIssue: false,
    ),
    _MediaGroupConfig(
      key: 'wheels',
      title: 'Колёса и тормозные механизмы',
      description: 'Резина, диски, тормоза, подвеска',
      required: false,
      severeIfIssue: false,
    ),
    _MediaGroupConfig(
      key: 'diagnostics',
      title: 'Компьютерная диагностика',
      description: 'Ошибки блоков, коды, комментарии',
      required: false,
      severeIfIssue: true,
    ),
  ];

  late final TextEditingController _reportNameController;
  late final TextEditingController _vinController;
  late final TextEditingController _plateController;
  late final TextEditingController _brandController;
  late final TextEditingController _modelController;
  late final TextEditingController _generationController;
  late final TextEditingController _adLinkController;
  late String _restylingLabel;
  late String _carPhotoUrl;
  late String _carFrames;

  late final TextEditingController _mileageController;
  late final TextEditingController _engineVolumeController;
  late final TextEditingController _engineTypeController;
  late final TextEditingController _gearboxTypeController;
  late final TextEditingController _driveTypeController;
  late final TextEditingController _colorController;
  late final TextEditingController _trimController;
  late final TextEditingController _ownersCountController;
  late final TextEditingController _inspectionCityController;
  late final TextEditingController _inspectionDateController;

  late final TextEditingController _legalNoteController;
  late final TextEditingController _tdNoteController;
  late final TextEditingController _summaryController;
  late final TextEditingController _expertController;
  late final TextEditingController _inspectorController;

  late final String _draftId;
  late final String _reportCode;
  late final String _createdAt;
  late final String _assignmentId;

  late Map<String, _MediaGroupState> _mediaState;
  Map<String, List<String>> _mediaCustomTagsByScope = {};

  int _stepIndex = 0;
  bool _editingSection = false;

  bool _mileageMismatch = false;
  bool _vinUnreadable = false;

  bool? _docsOwnerMatch;
  bool? _docsVinMatch;
  bool? _docsEngineMatch;

  bool _legalLoading = false;
  bool _legalLoaded = false;
  bool _legalSkipped = false;
  bool _legalTimedOut = false;
  bool _legalPurchased = false;
  int _legalLoadToken = 0;
  List<_UploadedItem> _legalFiles = const [];

  double _bodyPaintFrom = 80;
  double _bodyPaintTo = 200;
  double _structPaintFrom = 80;
  double _structPaintTo = 200;
  bool _bodyPaintEditing = false;
  bool _structPaintEditing = false;

  String? _tdMode;
  bool _tdEngineOk = false;
  bool _tdGearboxOk = false;
  bool _tdSteeringOk = false;
  bool _tdRideOk = false;
  bool _tdBrakeOk = false;
  List<String> _tdEngineTags = const [];
  List<String> _tdGearboxTags = const [];
  List<String> _tdSteeringTags = const [];
  List<String> _tdRideTags = const [];
  List<String> _tdBrakeTags = const [];

  List<_UploadedItem> _expertAudioFiles = const [];

  @override
  void initState() {
    super.initState();
    final draft = widget.draft ?? <String, dynamic>{};
    final assignment = widget.assignment ?? <String, dynamic>{};
    final now = DateTime.now();

    _draftId = _read(
      draft,
      'id',
      fallback: 'spark_draft_${now.microsecondsSinceEpoch}',
    );

    _createdAt = _read(draft, 'createdAt', fallback: _dateLabel(now));

    _reportCode = _read(draft, 'reportCode', fallback: _buildReportCode(now));

    _assignmentId = _read(
      draft,
      'assignmentId',
      fallback: _read(assignment, 'id'),
    );

    _stepIndex = _readInt(draft, 'currentStep', fallback: 1) - 1;
    if (_stepIndex < 0 || _stepIndex >= _steps.length) {
      _stepIndex = 0;
    }

    final fallbackCar = _read(
      draft,
      'car',
      fallback: _read(assignment, 'vehicle'),
    );
    final fallbackCarParts = fallbackCar.trim().split(RegExp(r'\s+'));

    _reportNameController = TextEditingController(
      text: _read(
        draft,
        'reportName',
        fallback:
            widget.initialReportName?.trim() ?? _read(assignment, 'title'),
      ),
    );
    _vinController = TextEditingController(
      text: _read(draft, 'vin', fallback: _read(assignment, 'vin')),
    );
    _plateController = TextEditingController(text: _read(draft, 'plate'));
    final initialPlate = _sanitizePlate(_plateController.text);
    if (initialPlate.isNotEmpty) {
      _plateController.text = _formatPlate(initialPlate);
    }
    _brandController = TextEditingController(
      text: _read(
        draft,
        'brand',
        fallback: fallbackCarParts.isNotEmpty ? fallbackCarParts.first : '',
      ),
    );
    _modelController = TextEditingController(
      text: _read(
        draft,
        'model',
        fallback: fallbackCarParts.length > 1
            ? fallbackCarParts.sublist(1).join(' ')
            : '',
      ),
    );
    _generationController = TextEditingController(
      text: _read(draft, 'generation'),
    );
    _restylingLabel = _read(draft, 'restyling');
    _carPhotoUrl = _read(draft, 'carPhotoUrl');
    _carFrames = _read(draft, 'carFrames');
    _adLinkController = TextEditingController(
      text: _read(draft, 'adLink', fallback: _read(assignment, 'listingUrl')),
    );

    _mileageController = TextEditingController(text: _read(draft, 'mileage'));
    _engineVolumeController = TextEditingController(
      text: _read(draft, 'engineVolume', fallback: _read(draft, 'engine')),
    );
    _engineTypeController = TextEditingController(
      text: _read(draft, 'engineType'),
    );
    _gearboxTypeController = TextEditingController(
      text: _read(draft, 'gearboxType', fallback: _read(draft, 'transmission')),
    );
    _driveTypeController = TextEditingController(
      text: _read(draft, 'driveType', fallback: _read(draft, 'drive')),
    );
    _colorController = TextEditingController(text: _read(draft, 'color'));
    _trimController = TextEditingController(text: _read(draft, 'trim'));
    _ownersCountController = TextEditingController(
      text: _read(draft, 'ownersCount', fallback: _read(draft, 'owners')),
    );
    _inspectionCityController = TextEditingController(
      text: _read(draft, 'inspectionCity', fallback: _read(assignment, 'city')),
    );
    _inspectionDateController = TextEditingController(
      text: _read(draft, 'inspectionDate', fallback: _dateLabel(now)),
    );

    _legalNoteController = TextEditingController(
      text: _read(draft, 'legalNote'),
    );
    _tdNoteController = TextEditingController(text: _read(draft, 'tdNote'));
    _summaryController = TextEditingController(
      text: _read(draft, 'summaryNote', fallback: _read(draft, 'summary')),
    );
    _expertController = TextEditingController(
      text: _read(draft, 'expertConclusion'),
    );
    _inspectorController = TextEditingController(
      text: _read(draft, 'inspector', fallback: 'Специалист'),
    );

    _mileageMismatch = _readBool(
      draft,
      'mileageMismatch',
      fallback: _readBool(draft, 'mileageMatchesClaimed'),
    );
    _vinUnreadable = _readBool(draft, 'vinUnreadable');

    _docsOwnerMatch = _readTriState(draft['docsOwnerMatch']);
    _docsVinMatch = _readTriState(draft['docsVinMatch']);
    _docsEngineMatch = _readTriState(draft['docsEngineMatch']);

    _legalLoading = _readBool(draft, 'legalLoading');
    _legalLoaded = _readBool(draft, 'legalLoaded');
    _legalSkipped = _readBool(draft, 'legalSkipped');
    _legalTimedOut = _readBool(draft, 'legalTimedOut');
    _legalPurchased = _readBool(draft, 'legalPurchased');
    _legalFiles = _readUploadedList(draft['legalFiles']);
    _bodyPaintFrom = _readDouble(draft, 'bodyPaintFrom', fallback: 80);
    _bodyPaintTo = _readDouble(draft, 'bodyPaintTo', fallback: 200);
    _structPaintFrom = _readDouble(draft, 'structPaintFrom', fallback: 80);
    _structPaintTo = _readDouble(draft, 'structPaintTo', fallback: 200);

    final legacyTdConducted = _readTriState(draft['tdConducted']);
    _tdEngineOk = _readBool(
      draft,
      'tdEngineOk',
      fallback: !_readBool(draft, 'tdEngineIssue'),
    );
    _tdGearboxOk = _readBool(
      draft,
      'tdGearboxOk',
      fallback: !_readBool(draft, 'tdGearboxIssue'),
    );
    _tdSteeringOk = _readBool(
      draft,
      'tdSteeringOk',
      fallback: !_readBool(draft, 'tdSteeringIssue'),
    );
    _tdRideOk = _readBool(
      draft,
      'tdRideOk',
      fallback: !_readBool(draft, 'tdRideIssue'),
    );
    _tdBrakeOk = _readBool(
      draft,
      'tdBrakeOk',
      fallback: !_readBool(draft, 'tdBrakeIssue'),
    );
    _tdEngineTags = _readStringList(draft['tdEngineTags']);
    _tdGearboxTags = _readStringList(draft['tdGearboxTags']);
    _tdSteeringTags = _readStringList(draft['tdSteeringTags']);
    _tdRideTags = _readStringList(draft['tdRideTags']);
    _tdBrakeTags = _readStringList(draft['tdBrakeTags']);
    _tdMode = _normalizeTdMode(_read(draft, 'tdConductedMode'));
    if (_tdMode == null && legacyTdConducted != null) {
      if (legacyTdConducted == false) {
        _tdMode = _tdModeNotConducted;
      } else if (_areAllTdSectionsClean()) {
        _tdMode = _tdModeAllGood;
      } else {
        _tdMode = _tdModeProblems;
      }
    }
    _expertAudioFiles = _readUploadedList(draft['expertAudioFiles']);

    _mediaState = _initMediaState(draft);
    _mediaCustomTagsByScope = _readStringListMap(draft['mediaCustomTags']);

    if (_stepIndex == _steps.length - 1) {
      _ensureSummaryAutofill();
    }
  }

  @override
  void dispose() {
    _reportNameController.dispose();
    _vinController.dispose();
    _plateController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _generationController.dispose();
    _adLinkController.dispose();

    _mileageController.dispose();
    _engineVolumeController.dispose();
    _engineTypeController.dispose();
    _gearboxTypeController.dispose();
    _driveTypeController.dispose();
    _colorController.dispose();
    _trimController.dispose();
    _ownersCountController.dispose();
    _inspectionCityController.dispose();
    _inspectionDateController.dispose();

    _legalNoteController.dispose();
    _tdNoteController.dispose();
    _summaryController.dispose();
    _expertController.dispose();
    _inspectorController.dispose();

    super.dispose();
  }

  Map<String, _MediaGroupState> _initMediaState(Map<String, dynamic> draft) {
    final byKey = <String, _MediaGroupState>{};
    final raw = draft['mediaGroupsState'];

    for (final config in _mediaGroupsConfig) {
      String note = '';
      String rawUrls = '';
      bool hasIssue = false;
      var files = const <_UploadedItem>[];

      if (raw is Map && raw[config.key] is Map) {
        final group = Map<String, dynamic>.from(raw[config.key] as Map);
        note = _read(group, 'note');
        rawUrls = _read(group, 'rawUrls');
        hasIssue = _readBool(group, 'hasIssue');
        files = _readUploadedList(group['files']);
        if (!hasIssue && files.any(_mediaItemHasIssue)) {
          hasIssue = true;
        }
      }

      byKey[config.key] = _MediaGroupState(
        config: config,
        hasIssue: hasIssue,
        note: note,
        rawUrls: rawUrls,
        files: files,
      );
    }

    return byKey;
  }

  String _read(Map<String, dynamic> map, String key, {String fallback = ''}) {
    final value = map[key];
    if (value == null) return fallback;
    final text = value.toString().trim();
    return text.isEmpty ? fallback : text;
  }

  int _readInt(Map<String, dynamic> map, String key, {int fallback = 0}) {
    final value = map[key];
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  double _readDouble(
    Map<String, dynamic> map,
    String key, {
    double fallback = 0,
  }) {
    final value = map[key];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  bool _readBool(
    Map<String, dynamic> map,
    String key, {
    bool fallback = false,
  }) {
    final value = map[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      if (value.toLowerCase() == 'true') return true;
      if (value.toLowerCase() == 'false') return false;
    }
    return fallback;
  }

  bool? _readTriState(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final lower = value.toLowerCase();
      if (lower == 'true') return true;
      if (lower == 'false') return false;
    }
    return null;
  }

  List<String> _readStringList(dynamic value) {
    if (value is List) {
      return value
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  Map<String, List<String>> _readStringListMap(dynamic value) {
    if (value is! Map) return <String, List<String>>{};

    final result = <String, List<String>>{};
    for (final entry in value.entries) {
      final key = entry.key.toString().trim();
      if (key.isEmpty) continue;
      final tags = _readStringList(entry.value);
      if (tags.isEmpty) continue;

      final dedup = <String>{};
      final clean = <String>[];
      for (final tag in tags) {
        final value = tag.trim();
        if (value.isEmpty) continue;
        final marker = value.toLowerCase();
        if (dedup.add(marker)) clean.add(value);
      }
      if (clean.isNotEmpty) {
        result[key] = clean;
      }
    }
    return result;
  }

  List<_UploadedItem> _readUploadedList(dynamic value) {
    if (value is! List) return const [];
    final items = <_UploadedItem>[];
    for (final entry in value) {
      if (entry is! Map) continue;
      final map = Map<String, dynamic>.from(entry);
      final name = _read(map, 'name');
      final dataUrl = _read(map, 'dataUrl');
      if (name.isEmpty || dataUrl.isEmpty) continue;
      items.add(
        _UploadedItem(
          name: name,
          mimeType: _read(
            map,
            'mimeType',
            fallback: 'application/octet-stream',
          ),
          dataUrl: dataUrl,
          inspection: _readMediaInspection(map['inspection']),
        ),
      );
    }
    return items;
  }

  _MediaInspection _readMediaInspection(dynamic value) {
    if (value is! Map) return const _MediaInspection();
    final map = Map<String, dynamic>.from(value);
    return _MediaInspection(
      noDamage: _readBool(map, 'noDamage'),
      tags: _readStringList(map['tags']),
      note: _read(map, 'note'),
      elementType: _read(map, 'elementType'),
      audioRecordings: _readStringList(map['audioRecordings']),
      isDraft: _readBool(map, 'isDraft', fallback: true),
    );
  }

  List<Map<String, dynamic>> _uploadedToJson(List<_UploadedItem> items) {
    return items.map((e) {
      return {
        'name': e.name,
        'mimeType': e.mimeType,
        'dataUrl': e.dataUrl,
        'inspection': e.inspection.toJson(),
      };
    }).toList();
  }

  String _guessMimeType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.webm')) return 'video/webm';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.m4a')) return 'audio/mp4';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.ogg') || lower.endsWith('.oga')) return 'audio/ogg';
    if (lower.endsWith('.aac')) return 'audio/aac';
    return 'application/octet-stream';
  }

  Uint8List _pcm16ToWav(
    Uint8List pcmBytes, {
    required int sampleRate,
    int channels = 1,
  }) {
    final dataLength = pcmBytes.length;
    final output = Uint8List(44 + dataLength);
    final view = ByteData.sublistView(output);
    final byteRate = sampleRate * channels * 2;
    final blockAlign = channels * 2;

    void writeAscii(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        view.setUint8(offset + i, value.codeUnitAt(i));
      }
    }

    writeAscii(0, 'RIFF');
    view.setUint32(4, 36 + dataLength, Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    view.setUint32(16, 16, Endian.little);
    view.setUint16(20, 1, Endian.little);
    view.setUint16(22, channels, Endian.little);
    view.setUint32(24, sampleRate, Endian.little);
    view.setUint32(28, byteRate, Endian.little);
    view.setUint16(32, blockAlign, Endian.little);
    view.setUint16(34, 16, Endian.little);
    writeAscii(36, 'data');
    view.setUint32(40, dataLength, Endian.little);
    output.setRange(44, 44 + dataLength, pcmBytes);
    return output;
  }

  Future<List<_UploadedItem>> _pickFiles({
    required FileType type,
    List<String>? allowedExtensions,
    bool allowMultiple = true,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: type,
      allowedExtensions: allowedExtensions,
      allowMultiple: allowMultiple,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return const [];

    final items = <_UploadedItem>[];
    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) continue;
      final mimeType = _guessMimeType(file.name);
      final data = base64Encode(bytes);
      items.add(
        _UploadedItem(
          name: file.name,
          mimeType: mimeType,
          dataUrl: 'data:$mimeType;base64,$data',
        ),
      );
    }
    return items;
  }

  Future<void> _pickMediaFiles(String groupKey) async {
    final items = await _pickFiles(
      type: FileType.custom,
      allowedExtensions: const [
        'png',
        'jpg',
        'jpeg',
        'webp',
        'heic',
        'heif',
        'mp4',
        'mov',
        'webm',
      ],
    );
    if (items.isEmpty || !mounted) return;
    setState(() {
      final state = _mediaState[groupKey];
      if (state == null) return;
      _mediaState[groupKey] = state.copyWith(files: [...state.files, ...items]);
    });
  }

  void _scheduleLegalTimeout(int token) {
    Future<void>.delayed(const Duration(seconds: 5), () {
      if (!mounted) return;
      if (!_legalLoading || token != _legalLoadToken) return;
      setState(() {
        _legalTimedOut = true;
        _legalLoading = false;
      });
    });
  }

  Future<void> _startLegalLoading() async {
    if (_legalLoading) return;
    final token = _legalLoadToken + 1;
    setState(() {
      _legalLoadToken = token;
      _legalPurchased = true;
      _legalSkipped = false;
      _legalTimedOut = false;
      _legalLoading = true;
      _legalLoaded = false;
    });
    _scheduleLegalTimeout(token);
  }

  String _dateLabel(DateTime value) {
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    return '$d.$m.${value.year}';
  }

  String _buildReportCode(DateTime now) {
    final random = 100000 + now.millisecondsSinceEpoch % 900000;
    return 'A$random';
  }

  InputDecoration _fieldDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: kWhiteColor,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kBorderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kBorderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kSecondaryColor),
      ),
    );
  }

  String _carName() {
    final brand = _brandController.text.trim();
    final model = _modelController.text.trim();
    final generation = _generationController.text.trim();
    return [brand, model, generation].where((e) => e.isNotEmpty).join(' ');
  }

  String _carButtonName() {
    final brand = _brandController.text.trim();
    final model = _modelController.text.trim();
    return [brand, model].where((e) => e.isNotEmpty).join(' ');
  }

  String _carMetaLabel() {
    final generation = _generationController.text.trim();
    final restyling = _restylingLabel.trim();
    final frames = _carFrames.trim();
    final parts = <String>[
      if (generation.isNotEmpty) 'Поколение $generation',
      if (restyling.isNotEmpty) restyling,
      if (frames.isNotEmpty) frames,
    ];
    return parts.join(' · ');
  }

  String _sanitizeVin(String value) {
    final cleaned = value
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]'), '')
        .replaceAll(RegExp(r'[IOQ]'), '');
    return cleaned.length > 17 ? cleaned.substring(0, 17) : cleaned;
  }

  bool _isStrictVin(String value) {
    final vin = value.trim().toUpperCase();
    if (vin.length != 17) return false;
    if (RegExp(r'[IOQ]').hasMatch(vin)) return false;
    if (!RegExp(r'^[A-HJ-NPR-Z0-9]{17}$').hasMatch(vin)) return false;
    if (!RegExp(r'[A-Z]').hasMatch(vin) || !RegExp(r'\d').hasMatch(vin)) {
      return false;
    }
    return true;
  }

  static const String _plateCyr = 'АВЕКМНОРСТУХ';
  static const Map<String, String> _plateLatToCyr = {
    'A': 'А',
    'B': 'В',
    'E': 'Е',
    'K': 'К',
    'M': 'М',
    'H': 'Н',
    'O': 'О',
    'P': 'Р',
    'C': 'С',
    'T': 'Т',
    'Y': 'У',
    'X': 'Х',
  };

  String _sanitizePlate(String value) {
    var cleaned = value.toUpperCase().replaceAll(RegExp(r'\s+'), '');
    cleaned = cleaned.split('').map((ch) => _plateLatToCyr[ch] ?? ch).join('');
    cleaned = cleaned.replaceAll(RegExp('[^${_plateCyr}0-9]'), '');
    return cleaned.length > 9 ? cleaned.substring(0, 9) : cleaned;
  }

  String _formatPlate(String sanitized) {
    if (sanitized.length <= 1) return sanitized;
    var result = sanitized[0];
    final rest = sanitized.substring(1);
    final digits = rest.substring(0, rest.length < 3 ? rest.length : 3);
    if (digits.isNotEmpty) result += ' $digits';
    final letters = rest.length > 3
        ? rest.substring(3, rest.length < 5 ? rest.length : 5)
        : '';
    if (letters.isNotEmpty) result += ' $letters';
    final region = rest.length > 5 ? rest.substring(5) : '';
    if (region.isNotEmpty) result += ' $region';
    return result;
  }

  String? _vinError() {
    if (_vinUnreadable) return null;
    final vin = _vinController.text.trim().toUpperCase();
    if (vin.isEmpty) return null;
    if (vin.length < 17) return 'Введено ${vin.length} из 17 символов';
    if (RegExp(r'[IOQ]').hasMatch(vin)) {
      return 'VIN не может содержать буквы I, O, Q';
    }
    if (!RegExp(r'^[A-HJ-NPR-Z0-9]{17}$').hasMatch(vin)) {
      return 'Некорректный формат VIN';
    }
    if (!RegExp(r'[A-Z]').hasMatch(vin) || !RegExp(r'\d').hasMatch(vin)) {
      return 'VIN должен содержать буквы и цифры';
    }
    return null;
  }

  String? _plateError() {
    final value = _plateController.text.trim();
    if (value.isEmpty) return null;
    final clean = _sanitizePlate(value);
    if (clean.length < 8) return 'Введено ${clean.length} из 8-9 символов';
    if (!RegExp(
      '^[$_plateCyr]\\d{3}[$_plateCyr]{2}\\d{2,3}\$',
    ).hasMatch(clean)) {
      return 'Некорректный формат госномера';
    }
    return null;
  }

  List<String> _parseUrls(String value) {
    return value
        .split(RegExp(r'[\n,]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  List<_MediaOption> _mediaElementOptions(String groupKey) {
    return _mediaElementOptionsByGroup[groupKey] ?? const <_MediaOption>[];
  }

  String _mediaTagSourceGroup(String groupKey, {String? elementType}) {
    return groupKey == 'interior' &&
            elementType != null &&
            _interiorDashboardElementIds.contains(elementType)
        ? 'interior_dashboard'
        : groupKey;
  }

  String _mediaTagScopeKey(String groupKey, {String? elementType}) {
    final sourceGroup = _mediaTagSourceGroup(
      groupKey,
      elementType: elementType,
    );
    final normalizedElement = (elementType ?? '').trim();

    if (normalizedElement.isNotEmpty &&
        (sourceGroup == 'interior_dashboard' || groupKey == 'diagnostics')) {
      return '$sourceGroup::$normalizedElement';
    }

    return sourceGroup;
  }

  List<_MediaTagOption> _mediaTagOptions(
    String groupKey, {
    String? elementType,
    Map<String, List<String>>? customTagsByScope,
  }) {
    if (groupKey == 'diagnostics' &&
        elementType != null &&
        _diagnosticTagOptionsByElement.containsKey(elementType)) {
      final options = _diagnosticTagOptionsByElement[elementType]!;
      final serious =
          _diagnosticSeriousTagsByElement[elementType] ?? const <String>{};
      final resolvedCustom = customTagsByScope ?? _mediaCustomTagsByScope;
      final scopeKey = _mediaTagScopeKey(groupKey, elementType: elementType);
      final custom = resolvedCustom[scopeKey] ?? const <String>[];
      final dedup = options.toSet();
      final result = options
          .map(
            (label) => _MediaTagOption(
              label: label,
              severity: serious.contains(label) ? 'serious' : 'minor',
            ),
          )
          .toList();
      for (final label in custom) {
        if (dedup.contains(label)) continue;
        dedup.add(label);
        result.add(
          _MediaTagOption(label: label, severity: 'minor', isCustom: true),
        );
      }
      return result;
    }

    final sourceGroup = _mediaTagSourceGroup(groupKey, elementType: elementType);
    final options = _mediaTagOptionsByGroup[sourceGroup] ?? const <String>[];
    final serious = _mediaSeriousTagsByGroup[sourceGroup] ?? const <String>{};
    final resolvedCustom = customTagsByScope ?? _mediaCustomTagsByScope;
    final scopeKey = _mediaTagScopeKey(groupKey, elementType: elementType);
    final custom = resolvedCustom[scopeKey] ?? const <String>[];
    final dedup = options.toSet();
    final result = options
        .map(
          (label) => _MediaTagOption(
            label: label,
            severity: serious.contains(label) ? 'serious' : 'minor',
          ),
        )
        .toList();
    for (final label in custom) {
      if (dedup.contains(label)) continue;
      dedup.add(label);
      result.add(
        _MediaTagOption(label: label, severity: 'minor', isCustom: true),
      );
    }
    return result;
  }

  List<_MediaTagGroup> _mediaTagGroups(
    String groupKey, {
    String? elementType,
    Map<String, List<String>>? customTagsByScope,
  }) {
    final options = _mediaTagOptions(
      groupKey,
      elementType: elementType,
      customTagsByScope: customTagsByScope,
    );
    if (options.isEmpty) return const <_MediaTagGroup>[];

    final serious = options
        .where((option) => option.severity == 'serious')
        .toList();
    final minor = options
        .where((option) => option.severity != 'serious')
        .toList();

    final seriousTitle = groupKey == 'diagnostics' ? 'Ошибки' : 'Серьёзные';
    final minorTitle = groupKey == 'diagnostics'
        ? 'Предупреждения'
        : 'Незначительные';

    final groups = <_MediaTagGroup>[];
    if (serious.isNotEmpty) {
      groups.add(_MediaTagGroup(title: seriousTitle, options: serious));
    }
    if (minor.isNotEmpty) {
      groups.add(_MediaTagGroup(title: minorTitle, options: minor));
    }
    return groups;
  }

  String _mediaTagSeverity(String groupKey, String tag, {String? elementType}) {
    for (final option in _mediaTagOptions(groupKey, elementType: elementType)) {
      if (option.label == tag) return option.severity;
    }
    return 'minor';
  }

  Color _mediaTagColor(String severity) {
    if (severity == 'serious') return kRedColor;
    return kYellowColor;
  }

  String _mediaNoDamageLabel(String groupKey) {
    if (groupKey == 'diagnostics') return 'Без ошибок';
    return 'Без повреждений';
  }

  bool _mediaInspectionHasData(_MediaInspection inspection) {
    return inspection.noDamage ||
        inspection.tags.isNotEmpty ||
        inspection.note.trim().isNotEmpty ||
        inspection.audioRecordings.isNotEmpty ||
        (inspection.elementType ?? '').trim().isNotEmpty;
  }

  bool _mediaItemHasIssue(_UploadedItem item) {
    final inspection = item.inspection;
    if (inspection.isDraft) return false;
    if (inspection.noDamage) return false;
    return inspection.tags.isNotEmpty;
  }

  bool _groupHasIssue(_MediaGroupState state) {
    if (state.files.any(_mediaItemHasIssue)) return true;
    return state.hasIssue;
  }

  List<_MediaElementSummary> _groupElementSummaries(
    String groupKey,
    _MediaGroupState state,
  ) {
    final byElement = <String, _MediaElementSummary>{};
    for (final file in state.files) {
      final inspection = file.inspection;
      if (inspection.isDraft) continue;
      final elementType = (inspection.elementType ?? '').trim();
      if (elementType.isEmpty) continue;
      final hasData =
          inspection.noDamage ||
          inspection.tags.isNotEmpty ||
          inspection.note.trim().isNotEmpty ||
          inspection.audioRecordings.isNotEmpty;
      if (!hasData) continue;

      final current =
          byElement[elementType] ??
          _MediaElementSummary(
            elementType: elementType,
            label: _mediaElementLabel(groupKey, elementType),
            noDamage: false,
            tags: const [],
            hasComment: false,
          );
      final tags = <String>{...current.tags};
      tags.addAll(inspection.tags);
      byElement[elementType] = _MediaElementSummary(
        elementType: elementType,
        label: current.label,
        noDamage: current.noDamage || inspection.noDamage,
        tags: tags.toList(),
        hasComment:
            current.hasComment ||
            inspection.note.trim().isNotEmpty ||
            inspection.audioRecordings.isNotEmpty,
      );
    }

    final order = _mediaElementOptions(
      groupKey,
    ).map((option) => option.id).toList();
    final summaries = byElement.values.toList();
    summaries.sort((a, b) {
      final ai = order.indexOf(a.elementType);
      final bi = order.indexOf(b.elementType);
      if (ai == -1 && bi == -1) return a.label.compareTo(b.label);
      if (ai == -1) return 1;
      if (bi == -1) return -1;
      return ai.compareTo(bi);
    });
    return summaries;
  }

  List<String> _mediaTagLabelsForSummary(
    String groupKey,
    _MediaElementSummary summary,
  ) {
    final options = _mediaTagOptions(
      groupKey,
      elementType: summary.elementType,
    ).map((e) => e.label);
    final order = options.toList();
    final tags = summary.tags.toSet();
    final sorted = <String>[];
    for (final label in order) {
      if (tags.remove(label)) sorted.add(label);
    }
    if (tags.isNotEmpty) {
      final tail = tags.toList()..sort();
      sorted.addAll(tail);
    }
    return sorted;
  }

  int _groupNoDamageElementsCount(String groupKey, _MediaGroupState state) {
    var count = 0;
    for (final summary in _groupElementSummaries(groupKey, state)) {
      final tags = _mediaTagLabelsForSummary(groupKey, summary);
      if (summary.noDamage && tags.isEmpty) count++;
    }
    return count;
  }

  int _groupSeriousTagCount(String groupKey, _MediaGroupState state) {
    var count = 0;
    for (final summary in _groupElementSummaries(groupKey, state)) {
      final tags = _mediaTagLabelsForSummary(groupKey, summary);
      for (final tag in tags) {
        if (_mediaTagSeverity(
              groupKey,
              tag,
              elementType: summary.elementType,
            ) ==
            'serious') {
          count++;
        }
      }
    }
    return count;
  }

  int _groupMinorTagCount(String groupKey, _MediaGroupState state) {
    var count = 0;
    for (final summary in _groupElementSummaries(groupKey, state)) {
      final tags = _mediaTagLabelsForSummary(groupKey, summary);
      for (final tag in tags) {
        if (_mediaTagSeverity(
              groupKey,
              tag,
              elementType: summary.elementType,
            ) !=
            'serious') {
          count++;
        }
      }
    }
    return count;
  }

  Widget _mediaElementSummaryList(String groupKey, _MediaGroupState state) {
    final summaries = _groupElementSummaries(groupKey, state);
    if (summaries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        ...summaries.map((summary) {
          final tagLabels = _mediaTagLabelsForSummary(groupKey, summary);
          final hasSeriousTag = tagLabels.any(
            (tag) =>
                _mediaTagSeverity(
                  groupKey,
                  tag,
                  elementType: summary.elementType,
                ) ==
                'serious',
          );

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (summary.noDamage && tagLabels.isEmpty)
                      const Icon(
                        Icons.check_circle_rounded,
                        color: kGreenColor,
                        size: 14,
                      )
                    else if (hasSeriousTag)
                      const Icon(
                        Icons.error_rounded,
                        color: kRedColor,
                        size: 14,
                      )
                    else if (tagLabels.isNotEmpty)
                      const Icon(
                        Icons.warning_rounded,
                        color: kYellowColor,
                        size: 14,
                      )
                    else
                      const Icon(
                        Icons.radio_button_unchecked_rounded,
                        color: kGreyColor,
                        size: 14,
                      ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: MyText(
                        text: summary.label.isEmpty
                            ? summary.elementType
                            : summary.label,
                        size: 11,
                        weight: FontWeight.w600,
                        color: kTertiaryColor,
                      ),
                    ),
                  ],
                ),
                if (summary.noDamage && tagLabels.isEmpty)
                  Padding(
                    padding: EdgeInsets.only(left: 18, top: 2),
                    child: MyText(
                      text: _mediaNoDamageLabel(groupKey),
                      size: 10,
                      color: kGreenColor,
                    ),
                  ),
                if (!summary.noDamage &&
                    tagLabels.isEmpty &&
                    summary.hasComment)
                  const Padding(
                    padding: EdgeInsets.only(left: 18, top: 2),
                    child: MyText(
                      text: 'Есть заметка',
                      size: 10,
                      color: kGreyColor,
                    ),
                  ),
                if (tagLabels.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 18, top: 4),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: tagLabels.map((tag) {
                        final color = _mediaTagColor(
                          _mediaTagSeverity(
                            groupKey,
                            tag,
                            elementType: summary.elementType,
                          ),
                        );
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: MyText(
                            text: tag,
                            size: 10,
                            color: color,
                            weight: FontWeight.w600,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
              ],
            ),
          );
        }),
      ],
    );
  }

  bool _groupHasCoverage(_MediaGroupState state) {
    return _parseUrls(state.rawUrls).isNotEmpty || state.files.isNotEmpty;
  }

  List<_MediaGroupConfig> _requiredMediaGroups() {
    const requiredKeys = {'body', 'glass', 'underhood', 'interior'};
    return _mediaGroupsConfig
        .where((config) => requiredKeys.contains(config.key))
        .toList();
  }

  List<_MediaGroupConfig> _missingRequiredMediaGroups() {
    return _requiredMediaGroups().where((config) {
      final state = _mediaState[config.key];
      return state == null || !_groupHasCoverage(state);
    }).toList();
  }

  bool _isFullInspection() {
    for (final config in _requiredMediaGroups()) {
      final state = _mediaState[config.key];
      if (state == null || !_groupHasCoverage(state)) {
        return false;
      }
    }
    return true;
  }

  _CalculatedSummary _calculateSummary() {
    var penalty = 0;
    final sections = <Map<String, dynamic>>[];
    final checklist = <String>[];

    final vin = _vinController.text.trim();
    final plateRaw = _sanitizePlate(_plateController.text.trim());
    final plate = plateRaw.isEmpty ? '' : _formatPlate(plateRaw);
    final adLink = _adLinkController.text.trim();
    final hasVinData = vin.isNotEmpty || _vinUnreadable;

    if (!hasVinData) {
      penalty += 8;
      checklist.add('VIN не заполнен и не отмечен как нечитаемый.');
    }

    sections.add({
      'title': 'Автомобиль',
      'status': hasVinData ? 'ok' : 'warn',
      'required': true,
      'details': [
        {
          'label': 'Марка / модель',
          'value': _carName().isEmpty ? 'Не указано' : _carName(),
          'severity': _carName().isEmpty ? 'info' : 'ok',
        },
        {
          'label': 'VIN',
          'value': _vinUnreadable
              ? 'Нечитабельный (отмечено)'
              : (vin.isEmpty ? 'Не указан' : vin),
          'severity': hasVinData ? 'ok' : 'minor',
        },
        if (plate.isNotEmpty)
          {'label': 'Госномер', 'value': plate, 'severity': 'ok'},
        if (adLink.isNotEmpty)
          {'label': 'Объявление', 'value': adLink, 'severity': 'ok'},
      ],
    });

    final mileage = _mileageController.text.trim();
    if (mileage.isEmpty) {
      penalty += 5;
      checklist.add('Не указан пробег автомобиля.');
    }
    if (_mileageMismatch) {
      penalty += 5;
      checklist.add('Пробег вызывает сомнения по состоянию автомобиля.');
    }

    sections.add({
      'title': 'Параметры',
      'status': mileage.isEmpty ? 'warn' : 'ok',
      'required': true,
      'details': [
        {
          'label': 'Пробег',
          'value': mileage.isEmpty ? 'Не указан' : mileage,
          'severity': mileage.isEmpty
              ? 'minor'
              : (_mileageMismatch ? 'minor' : 'ok'),
        },
        if (_engineVolumeController.text.trim().isNotEmpty)
          {
            'label': 'Объём ДВС',
            'value': _engineVolumeController.text.trim(),
            'severity': 'ok',
          },
        if (_engineTypeController.text.trim().isNotEmpty)
          {
            'label': 'Тип ДВС',
            'value': _engineTypeController.text.trim(),
            'severity': 'ok',
          },
        if (_gearboxTypeController.text.trim().isNotEmpty)
          {
            'label': 'КПП',
            'value': _gearboxTypeController.text.trim(),
            'severity': 'ok',
          },
        if (_driveTypeController.text.trim().isNotEmpty)
          {
            'label': 'Привод',
            'value': _driveTypeController.text.trim(),
            'severity': 'ok',
          },
        if (_colorController.text.trim().isNotEmpty)
          {
            'label': 'Цвет',
            'value': _colorController.text.trim(),
            'severity': 'ok',
          },
        if (_trimController.text.trim().isNotEmpty)
          {
            'label': 'Комплектация',
            'value': _trimController.text.trim(),
            'severity': 'ok',
          },
        if (_ownersCountController.text.trim().isNotEmpty)
          {
            'label': 'Владельцев',
            'value': _ownersCountController.text.trim(),
            'severity': 'ok',
          },
        if (_inspectionCityController.text.trim().isNotEmpty)
          {
            'label': 'Город осмотра',
            'value': _inspectionCityController.text.trim(),
            'severity': 'ok',
          },
        if (_inspectionDateController.text.trim().isNotEmpty)
          {
            'label': 'Дата осмотра',
            'value': _inspectionDateController.text.trim(),
            'severity': 'ok',
          },
      ],
    });

    final docsAllAnswered =
        _docsOwnerMatch != null &&
        _docsVinMatch != null &&
        _docsEngineMatch != null;
    final docsAllTrue =
        _docsOwnerMatch == true &&
        _docsVinMatch == true &&
        _docsEngineMatch == true;

    if (!docsAllAnswered) {
      penalty += 5;
      checklist.add('Сверка документов заполнена не полностью.');
    } else {
      if (_docsOwnerMatch == false) {
        penalty += 10;
        checklist.add('Есть расхождение по владельцу в документах.');
      }
      if (_docsVinMatch == false) {
        penalty += 14;
        checklist.add('VIN в документах не совпадает с автомобилем.');
      }
      if (_docsEngineMatch == false) {
        penalty += 10;
        checklist.add('Модель двигателя в документах не совпадает.');
      }
    }

    sections.add({
      'title': 'Сверка документов',
      'status': docsAllTrue ? 'ok' : (docsAllAnswered ? 'bad' : 'warn'),
      'required': true,
      'details': [
        {
          'label': 'Владелец',
          'value': _triStateLabel(_docsOwnerMatch),
          'severity': _docsOwnerMatch == false
              ? 'serious'
              : (_docsOwnerMatch == true ? 'ok' : 'minor'),
        },
        {
          'label': 'VIN',
          'value': _triStateLabel(_docsVinMatch),
          'severity': _docsVinMatch == false
              ? 'serious'
              : (_docsVinMatch == true ? 'ok' : 'minor'),
        },
        {
          'label': 'Модель двигателя',
          'value': _triStateLabel(_docsEngineMatch),
          'severity': _docsEngineMatch == false
              ? 'serious'
              : (_docsEngineMatch == true ? 'ok' : 'minor'),
        },
      ],
    });

    if (!_legalLoaded && !_legalSkipped) {
      penalty += _legalSkipped ? 5 : 3;
      checklist.add(
        _legalSkipped
            ? 'Юридическая проверка была пропущена.'
            : 'Юридическая проверка не подтверждена.',
      );
    }

    sections.add({
      'title': 'Юр. проверка',
      'status': _legalLoaded
          ? 'ok'
          : (_legalSkipped || _legalLoading ? 'warn' : 'warn'),
      'required': false,
      'details': [
        {
          'label': 'Статус',
          'value': _legalLoaded
              ? 'Проверка выполнена'
              : (_legalLoading
                    ? 'Идет загрузка'
                    : (_legalSkipped ? 'Пропущена' : 'Не заполнено')),
          'severity': _legalLoaded ? 'ok' : 'minor',
        },
        if (_legalFiles.isNotEmpty)
          {
            'label': 'Файлы',
            'value': '${_legalFiles.length} файл(ов)',
            'severity': 'ok',
          },
        if (_legalNoteController.text.trim().isNotEmpty)
          {
            'label': 'Комментарий',
            'value': _legalNoteController.text.trim(),
            'severity': 'minor',
          },
      ],
    });

    for (final config in _mediaGroupsConfig) {
      final state = _mediaState[config.key]!;
      final mediaCount = _parseUrls(state.rawUrls).length + state.files.length;
      final hasCoverage = mediaCount > 0;
      final hasIssue = _groupHasIssue(state);

      var status = 'ok';
      if (hasIssue && config.severeIfIssue) {
        status = 'bad';
      } else if (hasIssue || (config.required && !hasCoverage)) {
        status = 'warn';
      }

      if (config.required && !hasCoverage) {
        penalty += 4;
        checklist.add('${config.title}: нет фото/видео подтверждения осмотра.');
      }

      if (hasIssue) {
        penalty += config.severeIfIssue ? 12 : 6;
        checklist.add('${config.title}: зафиксированы замечания.');
      }

      sections.add({
        'title': config.title,
        'status': status,
        'required': config.required,
        'details': [
          {
            'label': 'Состояние',
            'value': hasIssue ? 'Есть замечания' : 'Без замечаний',
            'severity': hasIssue
                ? (config.severeIfIssue ? 'serious' : 'minor')
                : 'ok',
          },
          {
            'label': 'Медиа',
            'value': mediaCount == 0 ? 'Не добавлено' : '$mediaCount файл(ов)',
            'severity': mediaCount == 0 ? 'minor' : 'ok',
          },
          if (state.note.trim().isNotEmpty)
            {
              'label': 'Комментарий',
              'value': state.note.trim(),
              'severity': hasIssue ? 'minor' : 'ok',
            },
        ],
      });
    }

    final tdConducted = _tdConductedValue();
    if (tdConducted == null) {
      penalty += 3;
      checklist.add('Статус тест-драйва не заполнен.');
    }

    final tdState = <String, Map<String, dynamic>>{
      'Двигатель на ходу': {'ok': _tdEngineOk, 'tags': _tdEngineTags},
      'Работа КПП': {'ok': _tdGearboxOk, 'tags': _tdGearboxTags},
      'Рулевое управление': {'ok': _tdSteeringOk, 'tags': _tdSteeringTags},
      'Подвеска и комфорт': {'ok': _tdRideOk, 'tags': _tdRideTags},
      'Торможение': {'ok': _tdBrakeOk, 'tags': _tdBrakeTags},
    };

    tdState.forEach((title, state) {
      if (tdConducted != true || _tdMode == _tdModeAllGood) return;
      final ok = state['ok'] == true;
      final tags = (state['tags'] as List<String>? ?? const []).length;
      if (!ok || tags > 0) {
        penalty += 5;
        checklist.add('Тест-драйв: замечания по пункту "$title".');
      }
    });

    final hasTdIssues = tdState.values.any((state) {
      if (tdConducted != true || _tdMode == _tdModeAllGood) return false;
      final ok = state['ok'] == true;
      final tags = (state['tags'] as List<String>? ?? const []).length;
      return !ok || tags > 0;
    });
    sections.add({
      'title': 'Тест-драйв',
      'status': tdConducted == true && !hasTdIssues ? 'ok' : 'warn',
      'required': true,
      'details': [
        {
          'label': 'Проведен',
          'value': _tdMode == _tdModeAllGood
              ? 'Да, все исправно'
              : (_tdMode == _tdModeProblems
                    ? 'Да, есть проблемы'
                    : (_tdMode == _tdModeNotConducted ? 'Нет' : 'Не указано')),
          'severity': tdConducted == true ? 'ok' : 'minor',
        },
        ...tdState.entries.map(
          (entry) => {
            'label': entry.key,
            'value': tdConducted != true
                ? 'Не проверено'
                : (_tdMode == _tdModeAllGood
                      ? 'Без замечаний'
                      : (entry.value['ok'] == true &&
                                ((entry.value['tags'] as List<String>).isEmpty)
                            ? 'Без замечаний'
                            : 'Есть замечания')),
            'severity': tdConducted != true
                ? 'minor'
                : (_tdMode == _tdModeAllGood
                      ? 'ok'
                      : (entry.value['ok'] == true &&
                                ((entry.value['tags'] as List<String>).isEmpty)
                            ? 'ok'
                            : 'minor')),
          },
        ),
        if (_tdNoteController.text.trim().isNotEmpty)
          {
            'label': 'Комментарий',
            'value': _tdNoteController.text.trim(),
            'severity': hasTdIssues ? 'minor' : 'ok',
          },
      ],
    });

    final score = math.max(0, 100 - penalty);

    String verdict;
    String verdictLabel;
    if (score >= 70) {
      verdict = 'recommended';
      verdictLabel = 'Рекомендуется к покупке';
    } else if (score >= 40) {
      verdict = 'with_reservations';
      verdictLabel = 'С оговорками';
    } else {
      verdict = 'not_recommended';
      verdictLabel = 'Не рекомендуется';
    }

    if (checklist.isEmpty) {
      checklist.add('Критичных замечаний не выявлено.');
    }

    checklist.add(
      verdict == 'recommended'
          ? 'Покупка возможна после стандартной проверки сделки.'
          : verdict == 'with_reservations'
          ? 'Нужна дополнительная проверка и торг по замечаниям.'
          : 'Покупка не рекомендуется без устранения рисков.',
    );

    return _CalculatedSummary(
      score: score,
      verdict: verdict,
      verdictLabel: verdictLabel,
      sections: sections,
      checklist: checklist,
      fullInspection: _isFullInspection(),
    );
  }

  String _triStateLabel(bool? value) {
    if (value == true) return 'Совпадает';
    if (value == false) return 'Не совпадает';
    return 'Не проверено';
  }

  String _summaryTemplate(_CalculatedSummary summary) {
    final car = _carName().isEmpty ? 'автомобилю' : _carName();
    final topLines = summary.checklist.take(3).join(' ');
    return 'Отчет по $car. Итог: ${summary.verdictLabel} (${summary.score}/100). '
        '${topLines.isEmpty ? 'Замечания отсутствуют.' : topLines}';
  }

  void _ensureSummaryAutofill({bool force = false}) {
    final summary = _calculateSummary();
    if (!force && _summaryController.text.trim().isNotEmpty) return;
    _summaryController.text = _summaryTemplate(summary);
    if (_expertController.text.trim().isEmpty || force) {
      _expertController.text = summary.verdict == 'recommended'
          ? 'Автомобиль рекомендован к покупке.'
          : summary.verdict == 'with_reservations'
          ? 'Покупка возможна после дополнительной проверки и торга.'
          : 'Покупка не рекомендуется без устранения выявленных рисков.';
    }
  }

  Map<String, dynamic> _buildDraftPayload() {
    final now = DateTime.now();
    final mediaPayload = <String, dynamic>{};
    for (final entry in _mediaState.entries) {
      mediaPayload[entry.key] = {
        'hasIssue': _groupHasIssue(entry.value),
        'note': entry.value.note,
        'rawUrls': entry.value.rawUrls,
        'files': _uploadedToJson(entry.value.files),
      };
    }
    final customTagsPayload = <String, List<String>>{};
    for (final entry in _mediaCustomTagsByScope.entries) {
      final tags = entry.value
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();
      if (tags.isEmpty) continue;
      customTagsPayload[entry.key] = tags;
    }

    return {
      'id': _draftId,
      'assignmentId': _assignmentId,
      'reportCode': _reportCode,
      'createdAt': _createdAt,
      'updatedAt': _dateLabel(now),
      'currentStep': _stepIndex + 1,
      'totalSteps': _steps.length,
      'reportName': _reportNameController.text.trim(),
      'car': _carName(),
      'brand': _brandController.text.trim(),
      'model': _modelController.text.trim(),
      'generation': _generationController.text.trim(),
      'restyling': _restylingLabel.trim(),
      'carPhotoUrl': _carPhotoUrl.trim(),
      'carFrames': _carFrames.trim(),
      'vin': _vinController.text.trim(),
      'vinUnreadable': _vinUnreadable,
      'plate': _sanitizePlate(_plateController.text.trim()),
      'adLink': _adLinkController.text.trim(),
      'mileage': _mileageController.text.trim(),
      'mileageMismatch': _mileageMismatch,
      'engineVolume': _engineVolumeController.text.trim(),
      'engineType': _engineTypeController.text.trim(),
      'gearboxType': _gearboxTypeController.text.trim(),
      'driveType': _driveTypeController.text.trim(),
      'color': _colorController.text.trim(),
      'trim': _trimController.text.trim(),
      'ownersCount': _ownersCountController.text.trim(),
      'inspectionCity': _inspectionCityController.text.trim(),
      'inspectionDate': _inspectionDateController.text.trim(),
      'docsOwnerMatch': _docsOwnerMatch,
      'docsVinMatch': _docsVinMatch,
      'docsEngineMatch': _docsEngineMatch,
      'legalLoading': _legalLoading,
      'legalLoaded': _legalLoaded,
      'legalSkipped': _legalSkipped,
      'legalTimedOut': _legalTimedOut,
      'legalPurchased': _legalPurchased,
      'legalFiles': _uploadedToJson(_legalFiles),
      'legalNote': _legalNoteController.text.trim(),
      'bodyPaintFrom': _bodyPaintFrom,
      'bodyPaintTo': _bodyPaintTo,
      'structPaintFrom': _structPaintFrom,
      'structPaintTo': _structPaintTo,
      'tdConducted': _tdConductedValue(),
      'tdConductedMode': _tdMode,
      'tdEngineOk': _tdEngineOk,
      'tdGearboxOk': _tdGearboxOk,
      'tdSteeringOk': _tdSteeringOk,
      'tdRideOk': _tdRideOk,
      'tdBrakeOk': _tdBrakeOk,
      'tdEngineIssue': !_tdEngineOk || _tdEngineTags.isNotEmpty,
      'tdGearboxIssue': !_tdGearboxOk || _tdGearboxTags.isNotEmpty,
      'tdSteeringIssue': !_tdSteeringOk || _tdSteeringTags.isNotEmpty,
      'tdRideIssue': !_tdRideOk || _tdRideTags.isNotEmpty,
      'tdBrakeIssue': !_tdBrakeOk || _tdBrakeTags.isNotEmpty,
      'tdEngineTags': _tdEngineTags,
      'tdGearboxTags': _tdGearboxTags,
      'tdSteeringTags': _tdSteeringTags,
      'tdRideTags': _tdRideTags,
      'tdBrakeTags': _tdBrakeTags,
      'tdNote': _tdNoteController.text.trim(),
      'summaryNote': _summaryController.text.trim(),
      'expertConclusion': _expertController.text.trim(),
      'expertAudioFiles': _uploadedToJson(_expertAudioFiles),
      'inspector': _inspectorController.text.trim(),
      'mediaGroupsState': mediaPayload,
      'mediaCustomTags': customTagsPayload,
    };
  }

  Future<void> _saveDraft({bool showToast = true}) async {
    await SparkJoyStorage.upsertDraft(_buildDraftPayload());
    if (!mounted || !showToast) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Черновик сохранен')));
  }

  Map<String, dynamic> _buildCompletedReport() {
    final now = DateTime.now();
    final date = _dateLabel(now);
    final summary = _calculateSummary();

    final mediaGroups = <String, List<Map<String, dynamic>>>{};
    final flatImages = <String>[];

    for (final config in _mediaGroupsConfig) {
      final state = _mediaState[config.key]!;
      final urls = _parseUrls(state.rawUrls);
      if (urls.isEmpty && state.files.isEmpty) continue;
      final items = <Map<String, dynamic>>[];

      for (var i = 0; i < urls.length; i++) {
        final raw = urls[i];
        final isVideo = raw.contains('data:video/');
        final item = {
          'id': '${config.key}_${now.microsecondsSinceEpoch}_$i',
          'url': raw,
          'type': isVideo ? 'video' : 'image',
          'inspection': {
            'noDamage': !_groupHasIssue(state),
            'isDraft': false,
            'tags': _groupHasIssue(state) ? ['issue'] : [],
          },
        };
        items.add(item);
        if (!isVideo) flatImages.add(raw);
      }

      for (var i = 0; i < state.files.length; i++) {
        final file = state.files[i];
        final isVideo = file.isVideo;
        final item = {
          'id':
              '${config.key}_${now.microsecondsSinceEpoch}_${urls.length + i}',
          'url': file.dataUrl,
          'type': isVideo ? 'video' : 'image',
          'inspection': file.inspection.toJson(),
        };
        items.add(item);
        if (!isVideo) flatImages.add(file.dataUrl);
      }
      mediaGroups[config.key] = items;
    }

    if (flatImages.isEmpty) {
      const fallback =
          'https://images.unsplash.com/photo-1492144534655-ae79c964c9d7?w=1200&q=80&auto=format&fit=crop';
      flatImages.add(fallback);
      mediaGroups['overview'] = [
        {
          'id': 'overview_${now.microsecondsSinceEpoch}',
          'url': fallback,
          'type': 'image',
          'inspection': {'noDamage': true, 'isDraft': false, 'tags': []},
        },
      ];
    }

    final overview = <Map<String, dynamic>>[];
    mediaGroups.forEach((groupName, items) {
      final state = _mediaState[groupName];
      if (state == null || _groupHasIssue(state)) return;
      overview.addAll(items);
    });
    if (overview.isNotEmpty) {
      mediaGroups['overview'] = overview;
    }

    final checklist = [
      for (final line in summary.checklist) {'text': line, 'severity': 'minor'},
    ];

    final reportName = _reportNameController.text.trim();
    final carName = _carName();
    final issueLines = summary.checklist
        .where(
          (line) =>
              !line.contains('Покупка') &&
              !line.contains('Критичных замечаний не выявлено'),
        )
        .take(3)
        .toList();

    return {
      'id': 'spark_report_${now.microsecondsSinceEpoch}',
      'assignmentId': _assignmentId,
      'createdAt': date,
      'updatedAt': date,
      'reportCode': _reportCode,
      'reportName': reportName,
      'car': carName.isEmpty ? 'Автомобиль' : carName,
      'make': _brandController.text.trim(),
      'model': _modelController.text.trim(),
      'generation': _generationController.text.trim(),
      'restyling': _restylingLabel.trim(),
      'carPhotoUrl': _carPhotoUrl.trim(),
      'carFrames': _carFrames.trim(),
      'inspector': _inspectorController.text.trim().isEmpty
          ? 'Специалист'
          : _inspectorController.text.trim(),
      'date': date,
      'verdict': summary.verdict,
      'verdictLabel': summary.verdictLabel,
      'score': '${summary.score}/100',
      'price': '—',
      'issues': issueLines.isEmpty
          ? 'Без критичных замечаний'
          : issueLines.join(' '),
      'summary': _summaryController.text.trim(),
      'vin': _vinController.text.trim(),
      'plate': _sanitizePlate(_plateController.text.trim()),
      'mileage': _mileageController.text.trim(),
      'owners': _ownersCountController.text.trim(),
      'engine': [
        _engineVolumeController.text.trim(),
        _engineTypeController.text.trim(),
      ].where((e) => e.isNotEmpty).join(' '),
      'transmission': _gearboxTypeController.text.trim(),
      'drive': _driveTypeController.text.trim(),
      'reportsCount': 1,
      'images': flatImages,
      'sections': summary.sections,
      'checklist': checklist,
      'mediaGroups': mediaGroups,
      'legalFiles': _uploadedToJson(_legalFiles),
      'expertAudioFiles': _uploadedToJson(_expertAudioFiles),
      'summaryNote': _summaryController.text.trim(),
      'expertConclusion': _expertController.text.trim(),
      'fullInspection': summary.fullInspection,
    };
  }

  Future<void> _finishReport() async {
    final missingReasons = _summaryMissingReasons();
    if (missingReasons.isNotEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(missingReasons.join('\n'))));
      return;
    }

    _ensureSummaryAutofill();
    final completed = _buildCompletedReport();
    await SparkJoyStorage.moveDraftToCompleted(
      draftId: _draftId,
      completedReport: completed,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Отчет завершен')));
    Navigator.of(context).pop(true);
  }

  Future<void> _pickInspectionDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2010),
      lastDate: DateTime(2100),
      locale: const Locale('ru', 'RU'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: kSecondaryColor,
              onPrimary: kWhiteColor,
              surface: kWhiteColor,
              onSurface: kTertiaryColor,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );

    if (selected == null) return;
    setState(() {
      _inspectionDateController.text = _dateLabel(selected);
    });
  }

  Uint8List _cropVinGuideArea(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    final oriented = img.bakeOrientation(decoded);
    final width = oriented.width;
    final height = oriented.height;
    if (width < 2 || height < 2) return bytes;

    // Mirrors live scanner guide proportions:
    // top 39%, middle 22%; left/right 7%, center 86%.
    final left = (width * 0.07).round();
    final top = (height * 0.39).round();
    final targetWidth = (width * 0.86).round();
    final targetHeight = (height * 0.22).round();

    final safeLeft = left.clamp(0, width - 1).toInt();
    final safeTop = top.clamp(0, height - 1).toInt();
    final safeWidth = math.max(1, math.min(targetWidth, width - safeLeft));
    final safeHeight = math.max(1, math.min(targetHeight, height - safeTop));

    var cropped = img.copyCrop(
      oriented,
      x: safeLeft,
      y: safeTop,
      width: safeWidth,
      height: safeHeight,
    );

    if (cropped.width < 1200) {
      final upscaleWidth = 1200;
      final upscaleHeight = math.max(
        1,
        (cropped.height * (upscaleWidth / cropped.width)).round(),
      );
      cropped = img.copyResize(
        cropped,
        width: upscaleWidth,
        height: upscaleHeight,
        interpolation: img.Interpolation.cubic,
      );
    }

    return Uint8List.fromList(img.encodeJpg(cropped, quality: 92));
  }

  Future<void> _openVinScannerDialog() async {
    final picker = ImagePicker();
    final controller = TextEditingController(text: _vinController.text);

    Uint8List? previewBytes;
    var processing = false;
    var rawText = '';
    String? error;
    var currentVin = _sanitizeVin(controller.text);
    CameraController? liveCameraController;
    var cameraLoading = false;
    var cameraLive = false;
    var cameraError = '';
    var cameraInitialized = false;
    var cameraStarting = false;
    var selectedSource = 'none';

    Future<void> stopLiveCamera() async {
      final current = liveCameraController;
      liveCameraController = null;
      if (current == null) return;
      try {
        await current.dispose();
      } catch (_) {}
    }

    Future<void> recognizeBytes(
      Uint8List bytes,
      StateSetter setLocalState,
      Uint8List? fallbackBytes,
    ) async {
      await stopLiveCamera();
      setLocalState(() {
        processing = true;
        cameraLive = false;
        previewBytes = bytes;
        error = null;
        rawText = '';
      });

      final firstResult = await scanVinFromImageBytes(bytes);
      var finalVin = _sanitizeVin(firstResult.vin);
      if (!_isStrictVin(finalVin)) {
        finalVin = '';
      }
      var finalRaw = firstResult.rawText;
      var finalError = firstResult.error;

      if (finalVin.isEmpty && fallbackBytes != null) {
        final secondResult = await scanVinFromImageBytes(fallbackBytes);
        final secondVin = _sanitizeVin(secondResult.vin);
        final secondVinValid = _isStrictVin(secondVin);
        finalRaw = [
          if (firstResult.rawText.trim().isNotEmpty) firstResult.rawText.trim(),
          if (secondResult.rawText.trim().isNotEmpty)
            secondResult.rawText.trim(),
        ].join('\n-----\n');

        if (secondVinValid) {
          finalVin = secondVin;
          finalError = secondResult.error;
        } else {
          finalError = secondResult.error ?? firstResult.error;
        }
      }

      setLocalState(() {
        processing = false;
        rawText = finalRaw;
        error = finalError;
        if (_isStrictVin(finalVin)) {
          controller.text = finalVin;
          currentVin = finalVin;
        } else if (error == null || error!.trim().isEmpty) {
          error =
              'Не удалось распознать валидный VIN (17 символов). Попробуйте снять VIN ещё раз.';
        }
      });
    }

    Future<void> startLiveCamera(StateSetter setLocalState) async {
      if (cameraStarting) return;
      cameraStarting = true;

      setLocalState(() {
        selectedSource = 'camera';
        cameraLoading = true;
        cameraInitialized = false;
        cameraError = '';
        previewBytes = null;
        rawText = '';
        error = null;
        processing = false;
      });

      try {
        await stopLiveCamera();
        final cameras = await availableCameras();
        if (cameras.isEmpty) {
          throw Exception('На устройстве не найдена камера.');
        }

        final selected = cameras.firstWhere(
          (camera) => camera.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first,
        );
        final nextController = CameraController(
          selected,
          ResolutionPreset.medium,
          enableAudio: false,
        );
        await nextController.initialize();

        liveCameraController = nextController;
        setLocalState(() {
          cameraInitialized = true;
          cameraLive = true;
          cameraLoading = false;
        });
      } catch (e, st) {
        debugPrint('VIN live camera error: $e');
        debugPrint(st.toString());
        await stopLiveCamera();
        setLocalState(() {
          cameraLive = false;
          cameraInitialized = false;
          cameraLoading = false;
          cameraError = 'Не удалось открыть камеру. Используйте фото.';
        });
      } finally {
        cameraStarting = false;
      }
    }

    Future<void> pickAndRecognize(
      ImageSource source,
      StateSetter setLocalState,
    ) async {
      if (source == ImageSource.gallery) {
        await stopLiveCamera();
        setLocalState(() {
          selectedSource = 'gallery';
          cameraLive = false;
          cameraInitialized = false;
          cameraLoading = false;
          cameraError = '';
        });
      }
      final file = await picker.pickImage(source: source, imageQuality: 95);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      await recognizeBytes(bytes, setLocalState, null);
    }

    Future<void> captureFromLiveCamera(StateSetter setLocalState) async {
      final live = liveCameraController;
      if (live == null || !live.value.isInitialized) return;
      try {
        final shot = await live.takePicture();
        final fullFrame = await shot.readAsBytes();
        final croppedVinArea = _cropVinGuideArea(fullFrame);
        await recognizeBytes(croppedVinArea, setLocalState, fullFrame);
      } catch (e, st) {
        debugPrint('VIN live capture error: $e');
        debugPrint(st.toString());
        var openedSystemCamera = false;
        try {
          await pickAndRecognize(ImageSource.camera, setLocalState);
          openedSystemCamera = true;
        } catch (_) {}
        if (!openedSystemCamera) {
          setLocalState(() {
            error =
                'Не удалось снять VIN через live-камеру. Попробуйте системную камеру или галерею.';
          });
        }
      }
    }

    final resultVin = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            final sanitized = _sanitizeVin(currentVin);
            final valid = _isStrictVin(sanitized);
            final isCameraMode = selectedSource == 'camera';
            final canCapture =
                cameraInitialized &&
                liveCameraController != null &&
                liveCameraController!.value.isInitialized &&
                !processing;

            return AlertDialog(
              title: const Text('Сканирование VIN'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const MyText(
                        text: 'Выберите источник для сканирования VIN',
                        size: 11,
                        color: kGreyColor,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: processing
                                  ? null
                                  : () => startLiveCamera(setLocalState),
                              icon: const Icon(Icons.camera_alt_outlined),
                              label: const Text('Открыть камеру'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: processing
                                  ? null
                                  : () => pickAndRecognize(
                                      ImageSource.gallery,
                                      setLocalState,
                                    ),
                              icon: const Icon(Icons.photo_library_outlined),
                              label: const Text('Из галереи'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (isCameraMode &&
                          previewBytes == null &&
                          !processing) ...[
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: AspectRatio(
                            aspectRatio: 3 / 4,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                if (cameraInitialized &&
                                    liveCameraController != null &&
                                    liveCameraController!.value.isInitialized)
                                  CameraPreview(liveCameraController!),
                                IgnorePointer(
                                  child: Column(
                                    children: [
                                      Expanded(
                                        flex: 39,
                                        child: Container(color: Colors.black54),
                                      ),
                                      Expanded(
                                        flex: 22,
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 7,
                                              child: Container(
                                                color: Colors.black54,
                                              ),
                                            ),
                                            Expanded(
                                              flex: 86,
                                              child: _VinGuideFrame(
                                                animate:
                                                    cameraLive &&
                                                    !cameraLoading &&
                                                    cameraError.isEmpty,
                                              ),
                                            ),
                                            Expanded(
                                              flex: 7,
                                              child: Container(
                                                color: Colors.black54,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 39,
                                        child: Container(color: Colors.black54),
                                      ),
                                    ],
                                  ),
                                ),
                                if (cameraLoading)
                                  const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                if (cameraError.isNotEmpty && !cameraLoading)
                                  Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: MyText(
                                        text: cameraError,
                                        size: 12,
                                        color: kWhiteColor,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                if (cameraLive &&
                                    cameraError.isEmpty &&
                                    !cameraLoading)
                                  const Align(
                                    alignment: Alignment(0, -0.34),
                                    child: _VinGuideBadge(),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: canCapture
                              ? () => captureFromLiveCamera(setLocalState)
                              : null,
                          icon: const Icon(Icons.document_scanner_outlined),
                          label: const Text('Распознать'),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (previewBytes != null) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            previewBytes!,
                            height: 160,
                            fit: BoxFit.cover,
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (isCameraMode &&
                          cameraError.isNotEmpty &&
                          !processing) ...[
                        MyText(text: cameraError, size: 11, color: kRedColor),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => pickAndRecognize(
                            ImageSource.camera,
                            setLocalState,
                          ),
                          icon: const Icon(Icons.photo_camera_outlined),
                          label: const Text('Системная камера'),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => startLiveCamera(setLocalState),
                          icon: const Icon(Icons.replay),
                          label: const Text('Повторить запуск камеры'),
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (processing) ...[
                        const Row(
                          children: [
                            SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: MyText(
                                text: 'Распознаю VIN...',
                                size: 11,
                                color: kGreyColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (!vinOcrSupported) ...[
                        const MyText(
                          text: 'OCR недоступен. Можно вставить VIN вручную.',
                          size: 11,
                          color: kGreyColor,
                        ),
                        const SizedBox(height: 8),
                      ],
                      TextField(
                        controller: controller,
                        maxLength: 17,
                        onChanged: (value) {
                          final sanitizedValue = _sanitizeVin(value);
                          if (sanitizedValue != value) {
                            controller.value = TextEditingValue(
                              text: sanitizedValue,
                              selection: TextSelection.collapsed(
                                offset: sanitizedValue.length,
                              ),
                            );
                          }
                          setLocalState(() {
                            currentVin = sanitizedValue;
                          });
                        },
                        decoration: _fieldDecoration(
                          'Распознанный VIN (можно исправить)',
                        ).copyWith(counterText: ''),
                      ),
                      if (sanitized.isNotEmpty && !valid)
                        MyText(
                          text: '${sanitized.length} из 17 символов',
                          size: 11,
                          color: kYellowColor,
                        ),
                      if (rawText.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const MyText(
                            text: 'Сырой текст OCR',
                            size: 11,
                            color: kGreyColor,
                          ),
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                border: Border.all(color: kBorderColor),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: SelectableText(
                                rawText,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: kGreyColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (error != null && error!.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        MyText(text: error!, size: 11, color: kRedColor),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () {
                            if (isCameraMode) {
                              startLiveCamera(setLocalState);
                            } else {
                              pickAndRecognize(
                                ImageSource.gallery,
                                setLocalState,
                              );
                            }
                          },
                          icon: const Icon(Icons.replay),
                          label: const Text('Заново'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Отмена'),
                ),
                TextButton(
                  onPressed: !valid
                      ? null
                      : () => Navigator.of(context).pop(sanitized),
                  child: const Text('Применить'),
                ),
              ],
            );
          },
        );
      },
    );

    await stopLiveCamera();
    controller.dispose();

    if (resultVin == null || resultVin.isEmpty || !mounted) return;
    setState(() {
      _vinUnreadable = false;
      _vinController.text = resultVin;
    });
  }

  Future<void> _openCarPickerDialog() async {
    bool same(String left, String right) {
      return left.trim().toLowerCase() == right.trim().toLowerCase();
    }

    _CarCatalogBrand? selectedBrand;
    _CarCatalogModel? selectedModel;
    _CarCatalogGeneration? selectedGeneration;
    _CarPickerStep step = _CarPickerStep.brand;
    var search = '';

    final savedBrand = _brandController.text.trim();
    final savedModel = _modelController.text.trim();
    final savedGeneration = _generationController.text.trim();
    final savedRestyling = _restylingLabel.trim();

    for (final brand in _carCatalog) {
      if (!same(brand.name, savedBrand)) continue;
      selectedBrand = brand;
      for (final model in brand.models) {
        if (!same(model.name, savedModel)) continue;
        selectedModel = model;
        for (final generation in model.generations) {
          if (!same(generation.name, savedGeneration)) continue;
          selectedGeneration = generation;
          break;
        }
        break;
      }
      break;
    }

    if (selectedBrand != null) {
      step = _CarPickerStep.model;
    }
    if (selectedModel != null) {
      step = _CarPickerStep.generation;
    }
    if (selectedGeneration != null && savedRestyling.isNotEmpty) {
      step = _CarPickerStep.restyling;
    }

    String titleForStep(_CarPickerStep value) {
      switch (value) {
        case _CarPickerStep.brand:
          return 'Выберите марку';
        case _CarPickerStep.model:
          return 'Выберите модель';
        case _CarPickerStep.generation:
          return 'Выберите поколение';
        case _CarPickerStep.restyling:
          return 'Выберите рестайлинг';
      }
    }

    String breadcrumb() {
      final parts = <String>[
        if (selectedBrand != null) selectedBrand!.name,
        if (selectedModel != null) selectedModel!.name,
        if (selectedGeneration != null && step == _CarPickerStep.restyling)
          'Пок. ${selectedGeneration!.name}',
      ];
      return parts.join(' -> ');
    }

    _CarPickerSelection? buildSelection(_CarCatalogRestyling restyling) {
      if (selectedBrand == null ||
          selectedModel == null ||
          selectedGeneration == null) {
        return null;
      }
      return _CarPickerSelection(
        brand: selectedBrand!.name,
        model: selectedModel!.name,
        generation: selectedGeneration!.name,
        restyling: restyling.label,
        frames: restyling.frames,
        photoUrl: restyling.photoUrl,
      );
    }

    final selection = await showDialog<_CarPickerSelection>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            final showSearch =
                step == _CarPickerStep.brand || step == _CarPickerStep.model;
            final searchHint = step == _CarPickerStep.brand
                ? 'Поиск марки...'
                : 'Поиск модели...';
            final currentBreadcrumb = breadcrumb();

            void goBack() {
              if (step == _CarPickerStep.brand) {
                Navigator.of(context).pop();
                return;
              }
              setLocalState(() {
                if (step == _CarPickerStep.model) {
                  step = _CarPickerStep.brand;
                  selectedBrand = null;
                  selectedModel = null;
                  selectedGeneration = null;
                  search = '';
                  return;
                }
                if (step == _CarPickerStep.generation) {
                  step = _CarPickerStep.model;
                  selectedModel = null;
                  selectedGeneration = null;
                  search = '';
                  return;
                }
                if (step == _CarPickerStep.restyling) {
                  step = _CarPickerStep.generation;
                  search = '';
                }
              });
            }

            Widget listContent() {
              if (step == _CarPickerStep.brand) {
                final brands = _carCatalog
                    .where(
                      (brand) => search.trim().isEmpty
                          ? true
                          : brand.name.toLowerCase().contains(
                              search.trim().toLowerCase(),
                            ),
                    )
                    .toList();
                if (brands.isEmpty) {
                  return const Center(child: Text('Ничего не найдено'));
                }
                return ListView.separated(
                  itemCount: brands.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final brand = brands[index];
                    return ListTile(
                      title: Text(brand.name),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        setLocalState(() {
                          selectedBrand = brand;
                          selectedModel = null;
                          selectedGeneration = null;
                          step = _CarPickerStep.model;
                          search = '';
                        });
                      },
                    );
                  },
                );
              }

              if (step == _CarPickerStep.model) {
                final models =
                    (selectedBrand?.models ?? const <_CarCatalogModel>[])
                        .where(
                          (model) => search.trim().isEmpty
                              ? true
                              : model.name.toLowerCase().contains(
                                  search.trim().toLowerCase(),
                                ),
                        )
                        .toList();
                if (models.isEmpty) {
                  return const Center(child: Text('Нет моделей'));
                }
                return ListView.separated(
                  itemCount: models.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final model = models[index];
                    return ListTile(
                      title: Text(model.name),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        setLocalState(() {
                          selectedModel = model;
                          selectedGeneration = null;
                          step = _CarPickerStep.generation;
                          search = '';
                        });
                      },
                    );
                  },
                );
              }

              if (step == _CarPickerStep.generation) {
                final generations =
                    selectedModel?.generations ??
                    const <_CarCatalogGeneration>[];
                if (generations.isEmpty) {
                  return const Center(child: Text('Нет поколений'));
                }
                return ListView.separated(
                  itemCount: generations.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final generation = generations[index];
                    return ListTile(
                      title: Text('Поколение ${generation.name}'),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        if (generation.restylings.length == 1) {
                          final result = buildSelection(
                            generation.restylings[0],
                          );
                          if (result == null) return;
                          Navigator.of(context).pop(result);
                          return;
                        }
                        setLocalState(() {
                          selectedGeneration = generation;
                          step = _CarPickerStep.restyling;
                          search = '';
                        });
                      },
                    );
                  },
                );
              }

              final restylings =
                  selectedGeneration?.restylings ??
                  const <_CarCatalogRestyling>[];
              if (restylings.isEmpty) {
                return const Center(child: Text('Нет рестайлингов'));
              }
              return ListView.separated(
                itemCount: restylings.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final restyling = restylings[index];
                  return ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        restyling.photoUrl,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                    ),
                    title: Text(restyling.label),
                    subtitle: Text(restyling.frames),
                    trailing: const Icon(Icons.check_rounded),
                    onTap: () {
                      final result = buildSelection(restyling);
                      if (result == null) return;
                      Navigator.of(context).pop(result);
                    },
                  );
                },
              );
            }

            return AlertDialog(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 24,
              ),
              title: Row(
                children: [
                  IconButton(
                    onPressed: goBack,
                    icon: const Icon(Icons.arrow_back_rounded),
                    splashRadius: 20,
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(titleForStep(step)),
                        if (currentBreadcrumb.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 2),
                            child: Text(
                              currentBreadcrumb,
                              style: const TextStyle(
                                fontSize: 12,
                                color: kGreyColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 420,
                height: 460,
                child: Column(
                  children: [
                    if (showSearch) ...[
                      TextField(
                        onChanged: (value) {
                          setLocalState(() {
                            search = value;
                          });
                        },
                        decoration: _fieldDecoration(searchHint),
                      ),
                      const SizedBox(height: 8),
                    ],
                    Expanded(child: listContent()),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Отмена'),
                ),
              ],
            );
          },
        );
      },
    );

    if (selection == null || !mounted) return;
    setState(() {
      _brandController.text = selection.brand;
      _modelController.text = selection.model;
      _generationController.text = selection.generation;
      _restylingLabel = selection.restyling;
      _carFrames = selection.frames;
      _carPhotoUrl = selection.photoUrl;
    });
  }

  String _reportTitle() {
    final value = _reportNameController.text.trim();
    if (value.isNotEmpty) return value;
    final car = _carName().trim();
    if (car.isNotEmpty) return car;
    return 'Новый отчет';
  }

  Future<void> _editReportTitle() async {
    final controller = TextEditingController(text: _reportNameController.text);
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Название отчета'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: _fieldDecoration('Например: Тойота для Михаила'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );

    if (saved != true || !mounted) return;
    setState(() {
      _reportNameController.text = controller.text.trim();
    });
    await _saveDraft(showToast: false);
  }

  Future<void> _openSection(int index) async {
    setState(() {
      _stepIndex = index;
      _editingSection = true;
      if (_stepIndex == _steps.length - 1) {
        _ensureSummaryAutofill();
      }
    });
  }

  bool _isVehicleReadyForContinue() {
    return _vinUnreadable || _vinController.text.trim().isNotEmpty;
  }

  String? _normalizeTdMode(String rawValue) {
    switch (rawValue.trim()) {
      case _tdModeAllGood:
      case _tdModeProblems:
      case _tdModeNotConducted:
        return rawValue.trim();
      default:
        return null;
    }
  }

  bool? _tdConductedValue() {
    if (_tdMode == _tdModeAllGood || _tdMode == _tdModeProblems) return true;
    if (_tdMode == _tdModeNotConducted) return false;
    return null;
  }

  bool _areAllTdSectionsClean() {
    return _tdEngineOk &&
        _tdGearboxOk &&
        _tdSteeringOk &&
        _tdRideOk &&
        _tdBrakeOk &&
        _tdEngineTags.isEmpty &&
        _tdGearboxTags.isEmpty &&
        _tdSteeringTags.isEmpty &&
        _tdRideTags.isEmpty &&
        _tdBrakeTags.isEmpty;
  }

  void _applyTdAllGoodPreset() {
    _tdEngineOk = true;
    _tdGearboxOk = true;
    _tdSteeringOk = true;
    _tdRideOk = true;
    _tdBrakeOk = true;
    _tdEngineTags = const [];
    _tdGearboxTags = const [];
    _tdSteeringTags = const [];
    _tdRideTags = const [];
    _tdBrakeTags = const [];
  }

  void _applyTdProblemsPreset() {
    _tdEngineOk = false;
    _tdGearboxOk = false;
    _tdSteeringOk = false;
    _tdRideOk = false;
    _tdBrakeOk = false;
    _tdEngineTags = const [];
    _tdGearboxTags = const [];
    _tdSteeringTags = const [];
    _tdRideTags = const [];
    _tdBrakeTags = const [];
  }

  void _selectTdMode(String mode) {
    if (_tdMode == mode) return;
    setState(() {
      _tdMode = mode;
      if (mode == _tdModeAllGood) {
        _applyTdAllGoodPreset();
      } else if (mode == _tdModeProblems) {
        _applyTdProblemsPreset();
      }
    });
  }

  bool _testDriveSectionHasData(bool ok, List<String> tags) {
    return ok || tags.isNotEmpty;
  }

  List<String> _testDriveMissingReasons() {
    final reasons = <String>[];
    final tdConducted = _tdConductedValue();
    if (tdConducted == null) {
      reasons.add('Выберите, проводился ли тест-драйв');
      return reasons;
    }
    if (tdConducted == false || _tdMode == _tdModeAllGood) return reasons;

    if (!_testDriveSectionHasData(_tdEngineOk, _tdEngineTags)) {
      reasons.add('Проверьте двигатель');
    }
    if (!_testDriveSectionHasData(_tdGearboxOk, _tdGearboxTags)) {
      reasons.add('Проверьте КПП');
    }
    if (!_testDriveSectionHasData(_tdSteeringOk, _tdSteeringTags)) {
      reasons.add('Проверьте рулевое управление');
    }
    if (!_testDriveSectionHasData(_tdRideOk, _tdRideTags)) {
      reasons.add('Проверьте подвеску на ходу');
    }
    if (!_testDriveSectionHasData(_tdBrakeOk, _tdBrakeTags)) {
      reasons.add('Проверьте тормоза на ходу');
    }
    return reasons;
  }

  List<String> _summaryMissingReasons() {
    final reasons = <String>[];
    final hasVehicle =
        _vinController.text.trim().isNotEmpty ||
        _vinUnreadable ||
        _carName().trim().isNotEmpty;
    final hasParams = _mileageController.text.trim().isNotEmpty;
    final hasDocs =
        _docsOwnerMatch != null &&
        _docsVinMatch != null &&
        _docsEngineMatch != null;
    final requiredMediaKeys = {'body', 'glass', 'underhood', 'interior'};
    final missingMedia = <String>[];
    for (final key in requiredMediaKeys) {
      final state = _mediaState[key];
      if (state == null || !_groupHasCoverage(state)) {
        missingMedia.add(_mediaGroupLabelByKey[key] ?? key);
      }
    }
    final hasTestDrive = _tdMode != null;
    final hasExpertConclusion = _expertController.text.trim().isNotEmpty;

    if (!hasVehicle) {
      reasons.add('Автомобиль — укажите VIN или марку/модель');
    }
    if (!hasParams) {
      reasons.add('Параметры — укажите пробег');
    }
    if (!hasDocs) {
      reasons.add('Сверка документов — ответьте на все вопросы');
    }
    if (!hasTestDrive) {
      reasons.add('Тест-драйв — отметьте проведение');
    }
    for (final label in missingMedia) {
      reasons.add('Осмотр — добавьте фото: $label');
    }
    if (!hasExpertConclusion) {
      reasons.add('Итог специалиста — заполните заключение');
    }
    return reasons;
  }

  Future<Map<String, dynamic>?> _findDuplicateVinDraft() async {
    final normalizedVin = _sanitizeVin(_vinController.text.trim());
    if (normalizedVin.isEmpty || _vinUnreadable) return null;

    final drafts = await SparkJoyStorage.loadDrafts();
    for (final draft in drafts) {
      final draftId = (draft['id'] ?? '').toString();
      if (draftId.isEmpty || draftId == _draftId) continue;
      final draftVin = _sanitizeVin((draft['vin'] ?? '').toString());
      if (draftVin.isEmpty) continue;
      if (draftVin == normalizedVin) return draft;
    }
    return null;
  }

  Future<bool?> _showDuplicateVinDialog(Map<String, dynamic> draft) {
    final duplicateVin = (draft['vin'] ?? '').toString().trim();
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Черновик с таким VIN уже есть'),
          content: Text(
            'Найден незавершённый отчёт с VIN $duplicateVin. '
            'Хотите продолжить его или заполнить новый?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Заполнить заново'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Продолжить черновик'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _handleVehicleContinue() async {
    if (!_isVehicleReadyForContinue()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Укажите VIN-номер или отметьте как нечитаемый'),
        ),
      );
      return;
    }

    final duplicateDraft = await _findDuplicateVinDraft();
    if (duplicateDraft != null) {
      final openExisting = await _showDuplicateVinDialog(duplicateDraft);
      if (openExisting == true) {
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => SparkJoyCreateReportScreen(
              initialReportName:
                  (duplicateDraft['reportName'] ?? '').toString().trim().isEmpty
                  ? null
                  : (duplicateDraft['reportName'] ?? '').toString().trim(),
              draft: duplicateDraft,
              assignment: widget.assignment,
            ),
          ),
        );
        return;
      }
    }

    await _saveAndOpenNextSection();
  }

  Future<void> _saveAndOpenNextSection() async {
    await _saveDraft(showToast: false);
    if (!mounted) return;
    if (_stepIndex >= _steps.length - 1) return;
    setState(() {
      _stepIndex += 1;
      _editingSection = true;
      if (_stepIndex == _steps.length - 1) {
        _ensureSummaryAutofill();
      }
    });
  }

  Future<void> _closeSection({bool save = false}) async {
    if (save) {
      await _saveDraft(showToast: false);
      if (!mounted) return;
    }
    setState(() {
      _editingSection = false;
    });
  }

  String _sectionValue(String stepId) {
    switch (stepId) {
      case 'vehicle':
        final chunks = <String>[];
        if (_carName().isNotEmpty) chunks.add(_carName());
        if (_vinController.text.trim().isNotEmpty) {
          chunks.add(_vinController.text.trim());
        } else if (_vinUnreadable) {
          chunks.add('VIN нечитаемый');
        }
        if (_plateController.text.trim().isNotEmpty) {
          chunks.add(
            _formatPlate(_sanitizePlate(_plateController.text.trim())),
          );
        }
        return chunks.join(' · ');
      case 'params':
        final chunks = <String>[];
        if (_mileageController.text.trim().isNotEmpty) {
          chunks.add('${_mileageController.text.trim()} км');
        }
        if (_engineVolumeController.text.trim().isNotEmpty) {
          chunks.add('${_engineVolumeController.text.trim()} л');
        }
        if (_engineTypeController.text.trim().isNotEmpty) {
          chunks.add(_engineTypeController.text.trim());
        }
        return chunks.join(' · ');
      case 'docs_check':
        if (_docsOwnerMatch == null ||
            _docsVinMatch == null ||
            _docsEngineMatch == null) {
          return '';
        }
        final count = [
          _docsOwnerMatch == true,
          _docsVinMatch == true,
          _docsEngineMatch == true,
        ].where((v) => v).length;
        return '$count из 3';
      case 'legal':
        if (_legalLoaded) return 'Проверено';
        if (_legalSkipped) return 'Пропущено';
        if (_legalLoading) return 'Загрузка...';
        return '';
      case 'media':
        final covered = _mediaState.values.where(_groupHasCoverage).length;
        return covered == 0 ? '' : 'Групп с файлами: $covered';
      case 'test_drive':
        if (_tdMode == null) return '';
        if (_tdMode == _tdModeNotConducted) return 'Не проводился';
        if (_tdMode == _tdModeAllGood) return 'Да, всё исправно';
        return 'Да, есть проблемы';
      case 'summary':
        if (_expertController.text.trim().isEmpty) return '';
        return 'Итог заполнен';
      default:
        return '';
    }
  }

  Widget _sectionCard(int index) {
    final step = _steps[index];
    final isSummary = index == _steps.length - 1;
    final value = _sectionValue(step.id);
    final done = value.isNotEmpty;
    return InkWell(
      onTap: () => _openSection(index),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: kWhiteColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: done ? kSecondaryColor : kLightGreyColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: MyText(
                text: done ? '✓' : '${index + 1}',
                size: 12,
                weight: FontWeight.w700,
                color: done ? kWhiteColor : kGreyColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  MyText(
                    text: step.title,
                    size: 16,
                    weight: FontWeight.w700,
                    color: kTertiaryColor,
                  ),
                  if (value.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    MyText(text: value, size: 11, color: kSecondaryColor),
                  ],
                ],
              ),
            ),
            Icon(
              isSummary ? Icons.done_rounded : Icons.chevron_right_rounded,
              color: kGreyColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionsOverview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(color: kBorderColor, height: 1),
        const SizedBox(height: 16),
        ...List.generate(_steps.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _sectionCard(index),
          );
        }),
      ],
    );
  }

  Widget _card({required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kWhiteColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorderColor),
      ),
      child: child,
    );
  }

  Widget _input(
    TextEditingController controller,
    String hint, {
    int minLines = 1,
    int maxLines = 1,
    TextInputType? keyboardType,
    bool readOnly = false,
    VoidCallback? onTap,
  }) {
    return TextField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      keyboardType: keyboardType,
      readOnly: readOnly,
      onTap: onTap,
      decoration: _fieldDecoration(hint),
    );
  }

  Widget _dropdownField(
    TextEditingController controller,
    String hint,
    List<String> options,
  ) {
    final selected = options.contains(controller.text.trim())
        ? controller.text.trim()
        : null;
    return DropdownButtonFormField<String>(
      initialValue: selected,
      decoration: _fieldDecoration(hint),
      items: options
          .map((option) => DropdownMenuItem(value: option, child: Text(option)))
          .toList(),
      onChanged: (value) {
        setState(() {
          controller.text = value ?? '';
        });
      },
    );
  }

  Widget _yesNoSelector({
    required String title,
    required bool? value,
    required ValueChanged<bool> onChanged,
    String? subtitle,
  }) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MyText(text: title, size: 13, weight: FontWeight.w700),
          if (subtitle != null) ...[
            const SizedBox(height: 3),
            MyText(text: subtitle, size: 11, color: kGreyColor),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => onChanged(true),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: value == true ? kGreenColor : kBorderColor,
                    ),
                    backgroundColor: value == true
                        ? kGreenColor.withValues(alpha: 0.1)
                        : kWhiteColor,
                  ),
                  child: Text(
                    'Да',
                    style: TextStyle(
                      color: value == true ? kGreenColor : kGreyColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => onChanged(false),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: value == false ? kRedColor : kBorderColor,
                    ),
                    backgroundColor: value == false
                        ? kRedColor.withValues(alpha: 0.1)
                        : kWhiteColor,
                  ),
                  child: Text(
                    'Нет',
                    style: TextStyle(
                      color: value == false ? kRedColor : kGreyColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _testDriveSubsystemCard({
    required String sectionLabel,
    required bool ok,
    required ValueChanged<bool> onOkChanged,
    required String okLabel,
    required List<String> options,
    required List<String> selected,
    required ValueChanged<List<String>> onTagsChanged,
  }) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MyText(text: sectionLabel, size: 11, color: kGreyColor),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => onOkChanged(!ok),
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: ok
                      ? kGreenColor.withValues(alpha: 0.45)
                      : kBorderColor,
                ),
                color: ok ? kGreenColor.withValues(alpha: 0.08) : kWhiteColor,
              ),
              child: Row(
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: ok ? kGreenColor : kBorderColor,
                        width: 1.6,
                      ),
                      color: ok ? kGreenColor : kWhiteColor,
                    ),
                    child: ok
                        ? const Icon(
                            Icons.check_rounded,
                            size: 14,
                            color: kWhiteColor,
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: MyText(
                      text: okLabel,
                      size: 12,
                      weight: FontWeight.w600,
                      color: ok ? kGreenColor : kTertiaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (!ok) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((option) {
                final active = selected.contains(option);
                return _chip(
                  label: option,
                  selected: active,
                  selectedColor: kYellowColor,
                  onTap: () {
                    final next = [...selected];
                    if (active) {
                      next.remove(option);
                    } else {
                      next.add(option);
                    }
                    onTagsChanged(next);
                  },
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _testDriveConductedSelector() {
    Widget optionButton({
      required String title,
      required String mode,
      required Color activeColor,
    }) {
      final isSelected = _tdMode == mode;
      return OutlinedButton(
        onPressed: () => _selectTdMode(mode),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 42),
          alignment: Alignment.centerLeft,
          side: BorderSide(
            color: isSelected
                ? activeColor.withValues(alpha: 0.55)
                : kBorderColor,
          ),
          backgroundColor: isSelected
              ? activeColor.withValues(alpha: 0.12)
              : kWhiteColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected ? activeColor : kTertiaryColor,
          ),
        ),
      );
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MyText(
            text: 'Тест-драйв проводился?',
            size: 13,
            weight: FontWeight.w600,
          ),
          const SizedBox(height: 8),
          optionButton(
            title: 'Да, все работает исправно',
            mode: _tdModeAllGood,
            activeColor: kGreenColor,
          ),
          const SizedBox(height: 6),
          optionButton(
            title: 'Да, есть проблемы',
            mode: _tdModeProblems,
            activeColor: kYellowColor,
          ),
          const SizedBox(height: 6),
          optionButton(
            title: 'Нет',
            mode: _tdModeNotConducted,
            activeColor: kRedColor,
          ),
        ],
      ),
    );
  }

  Widget _testDriveNoteBlock(String placeholder) {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.description_outlined, size: 14, color: kGreyColor),
              SizedBox(width: 5),
              MyText(
                text: 'Заметка',
                size: 11,
                color: kGreyColor,
                weight: FontWeight.w700,
              ),
            ],
          ),
          const SizedBox(height: 8),
          _input(_tdNoteController, placeholder, minLines: 3, maxLines: 5),
        ],
      ),
    );
  }

  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required Color selectedColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected
              ? selectedColor.withValues(alpha: 0.12)
              : kLightGreyColor,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? selectedColor.withValues(alpha: 0.45)
                : kBorderColor,
          ),
        ),
        child: MyText(
          text: label,
          size: 11,
          weight: FontWeight.w700,
          color: selected ? selectedColor : kGreyColor,
        ),
      ),
    );
  }

  Widget _stepVehicle() {
    final vinError = _vinError();
    final plateError = _plateError();
    final vinValid =
        !_vinUnreadable &&
        _vinController.text.trim().isNotEmpty &&
        vinError == null;
    final plateValid =
        _plateController.text.trim().isNotEmpty && plateError == null;
    final carButtonTitle = _carButtonName();
    final carTitle = _carName();
    final carMeta = _carMetaLabel();

    return Column(
      children: [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const MyText(
                text: 'VIN-номер *',
                size: 12,
                weight: FontWeight.w700,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _vinController,
                      enabled: !_vinUnreadable,
                      maxLength: 17,
                      onChanged: (value) {
                        final sanitized = _sanitizeVin(value);
                        if (sanitized == value) {
                          setState(() {});
                          return;
                        }
                        _vinController.value = TextEditingValue(
                          text: sanitized,
                          selection: TextSelection.collapsed(
                            offset: sanitized.length,
                          ),
                        );
                        setState(() {});
                      },
                      decoration: _fieldDecoration(
                        'XW7BF4FK10S012345',
                      ).copyWith(counterText: ''),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 52,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: _vinUnreadable ? null : _openVinScannerDialog,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        side: const BorderSide(color: kBorderColor),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Icon(Icons.document_scanner_outlined),
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    _vinUnreadable = !_vinUnreadable;
                    if (_vinUnreadable) {
                      _vinController.clear();
                    }
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: Row(
                  children: [
                    Checkbox(
                      value: _vinUnreadable,
                      onChanged: (value) {
                        setState(() {
                          _vinUnreadable = value ?? false;
                          if (_vinUnreadable) {
                            _vinController.clear();
                          }
                        });
                      },
                      activeColor: kSecondaryColor,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MyText(
                            text: 'Нечитабельный VIN',
                            size: 12,
                            color: kTertiaryColor,
                          ),
                          SizedBox(height: 2),
                          MyText(
                            text: 'VIN-номер повреждён или не читается',
                            size: 10,
                            color: kGreyColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (vinError != null)
                MyText(text: vinError, size: 11, color: kRedColor),
              if (vinValid)
                const MyText(
                  text: 'VIN корректен',
                  size: 11,
                  color: kGreenColor,
                ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const MyText(
                text: 'Госномер (необяз.)',
                size: 12,
                weight: FontWeight.w700,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _plateController,
                maxLength: 12,
                onChanged: (value) {
                  final sanitized = _sanitizePlate(value);
                  final formatted = _formatPlate(sanitized);
                  _plateController.value = TextEditingValue(
                    text: formatted,
                    selection: TextSelection.collapsed(
                      offset: formatted.length,
                    ),
                  );
                  setState(() {});
                },
                textAlign: TextAlign.center,
                decoration: _fieldDecoration(
                  'А 000 АА 000',
                ).copyWith(counterText: ''),
              ),
              if (plateError != null) ...[
                const SizedBox(height: 6),
                MyText(text: plateError, size: 11, color: kRedColor),
              ],
              if (plateValid) ...[
                const SizedBox(height: 6),
                const MyText(
                  text: '✓ Госномер корректен',
                  size: 11,
                  color: kGreenColor,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const MyText(
                text: 'Марка и модель (необяз.)',
                size: 12,
                weight: FontWeight.w700,
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: _openCarPickerDialog,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  height: 52,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: kBorderColor),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: MyText(
                          text: carButtonTitle.isEmpty
                              ? 'Нажмите для выбора автомобиля'
                              : carButtonTitle,
                          size: 13,
                          color: carButtonTitle.isEmpty
                              ? kGreyColor
                              : kTertiaryColor,
                          maxLines: 1,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: kGreyColor,
                      ),
                    ],
                  ),
                ),
              ),
              if (carTitle.isNotEmpty) ...[
                const SizedBox(height: 8),
                _card(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_carPhotoUrl.trim().isNotEmpty) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  _carPhotoUrl.trim(),
                                  width: double.infinity,
                                  height: 112,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Container(
                                      width: double.infinity,
                                      height: 112,
                                      color: kLightGreyColor,
                                      alignment: Alignment.center,
                                      child: const Icon(
                                        Icons.directions_car_outlined,
                                        color: kGreyColor,
                                      ),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],
                            MyText(
                              text: carTitle,
                              size: 12,
                              weight: FontWeight.w700,
                            ),
                            if (carMeta.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              MyText(
                                text: carMeta,
                                size: 11,
                                color: kGreyColor,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        _input(
          _adLinkController,
          'https://auto.ru/...',
          keyboardType: TextInputType.url,
        ),
      ],
    );
  }

  Widget _stepParams() {
    final engineVolumes = List<String>.generate(43, (i) {
      return (0.8 + i * 0.1).toStringAsFixed(1);
    });

    return Column(
      children: [
        TextField(
          controller: _mileageController,
          keyboardType: TextInputType.number,
          onChanged: (value) {
            final cleaned = value.replaceAll(RegExp(r'[^0-9]'), '');
            if (cleaned == value) return;
            _mileageController.value = TextEditingValue(
              text: cleaned,
              selection: TextSelection.collapsed(offset: cleaned.length),
            );
          },
          decoration: _fieldDecoration('Пробег (км)'),
        ),
        const SizedBox(height: 10),
        _yesNoSelector(
          title: 'По внешнему состоянию пробег не соответствует заявленному',
          value: _mileageMismatch,
          onChanged: (v) => setState(() => _mileageMismatch = v),
        ),
        const SizedBox(height: 10),
        _dropdownField(
          _engineVolumeController,
          'Объём двигателя (л)',
          engineVolumes,
        ),
        const SizedBox(height: 10),
        _dropdownField(_engineTypeController, 'Тип двигателя', _engineTypes),
        const SizedBox(height: 10),
        _dropdownField(
          _gearboxTypeController,
          'Коробка передач',
          _gearboxTypes,
        ),
        const SizedBox(height: 10),
        _dropdownField(_driveTypeController, 'Привод', _driveTypes),
        const SizedBox(height: 10),
        _dropdownField(_colorController, 'Цвет', _colors),
        const SizedBox(height: 10),
        _input(_trimController, 'Комплектация'),
        const SizedBox(height: 10),
        _dropdownField(
          _ownersCountController,
          'Количество владельцев',
          _ownersCounts,
        ),
        const SizedBox(height: 10),
        _input(_inspectionCityController, 'Город осмотра'),
        const SizedBox(height: 10),
        _input(
          _inspectionDateController,
          'Дата осмотра',
          readOnly: true,
          onTap: _pickInspectionDate,
        ),
      ],
    );
  }

  Widget _stepDocsCheck() {
    return Column(
      children: [
        _yesNoSelector(
          title: 'Данные владельца',
          subtitle: 'ФИО владельца совпадает с ПТС / СТС',
          value: _docsOwnerMatch,
          onChanged: (v) => setState(() => _docsOwnerMatch = v),
        ),
        const SizedBox(height: 10),
        _yesNoSelector(
          title: 'Идентификационные номера',
          subtitle: 'VIN-номер на кузове совпадает с ПТС / СТС',
          value: _docsVinMatch,
          onChanged: (v) => setState(() => _docsVinMatch = v),
        ),
        const SizedBox(height: 10),
        _yesNoSelector(
          title: 'Модель двигателя',
          subtitle: 'Модель ДВС совпадает с ПТС / СТС',
          value: _docsEngineMatch,
          onChanged: (v) => setState(() => _docsEngineMatch = v),
        ),
      ],
    );
  }

  Widget _stepLegal() {
    Future<void> continueFromLegal() async {
      await _saveAndOpenNextSection();
    }

    if (_legalLoaded) {
      return Column(
        children: [
          _card(
            child: Column(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: kGreenColor,
                  size: 34,
                ),
                const SizedBox(height: 8),
                const MyText(
                  text: 'Проверка завершена',
                  size: 14,
                  weight: FontWeight.w700,
                ),
                const SizedBox(height: 4),
                const MyText(
                  text: 'Юридическая информация загружена',
                  size: 11,
                  color: kGreyColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          MyButton(buttonText: 'Продолжить', onTap: continueFromLegal),
        ],
      );
    }

    if (_legalLoading) {
      const labels = ['Владельцы', 'ДТП', 'Залоги', 'Ограничения'];
      return Column(
        children: [
          _card(
            child: Column(
              children: const [
                SizedBox(height: 8),
                CircularProgressIndicator(color: kSecondaryColor),
                SizedBox(height: 12),
                MyText(
                  text: 'Загрузка данных…',
                  size: 13,
                  weight: FontWeight.w700,
                ),
                SizedBox(height: 4),
                MyText(
                  text: 'Проверяем юридическую историю автомобиля',
                  size: 11,
                  color: kGreyColor,
                ),
                SizedBox(height: 8),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ...labels.map((label) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _card(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        color: kLightGreyColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MyText(text: label, size: 11, color: kGreyColor),
                          const SizedBox(height: 6),
                          Container(
                            height: 8,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: kLightGreyColor,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      );
    }

    if (!_legalPurchased && !_legalTimedOut) {
      return Column(
        children: [
          _card(
            child: Column(
              children: [
                const Icon(
                  Icons.find_in_page_outlined,
                  color: kSecondaryColor,
                  size: 34,
                ),
                const SizedBox(height: 8),
                const MyText(
                  text: 'Юридическая проверка',
                  size: 14,
                  weight: FontWeight.w700,
                ),
                const SizedBox(height: 4),
                const MyText(
                  text:
                      'Проверка владельцев, ДТП, залогов, ограничений и розыска',
                  size: 11,
                  color: kGreyColor,
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kSecondaryColor.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: kSecondaryColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const MyText(
                        text: 'Купить полный отчёт',
                        size: 13,
                        weight: FontWeight.w700,
                      ),
                      const SizedBox(height: 6),
                      const MyText(
                        text:
                            'Получите полную юридическую проверку: владельцы, ДТП, залоги, ограничения, розыск и история обслуживания.',
                        size: 11,
                        color: kGreyColor,
                      ),
                      const SizedBox(height: 10),
                      MyButton(
                        buttonText: 'Купить отчёт — 50 ₽',
                        onTap: _startLegalLoading,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () async {
              setState(() => _legalSkipped = true);
              await continueFromLegal();
            },
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              side: const BorderSide(color: kBorderColor),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Пропустить'),
          ),
        ],
      );
    }

    if (_legalTimedOut && !_legalSkipped) {
      return Column(
        children: [
          _card(
            child: Column(
              children: const [
                Icon(Icons.error_outline, color: kRedColor, size: 30),
                SizedBox(height: 8),
                MyText(
                  text: 'Не удалось подгрузить данные',
                  size: 13,
                  weight: FontWeight.w700,
                ),
                SizedBox(height: 4),
                MyText(
                  text: 'Сервер не ответил. Вы можете загрузить данные позже.',
                  size: 11,
                  color: kGreyColor,
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: () async {
              setState(() => _legalSkipped = true);
              await continueFromLegal();
            },
            icon: const Icon(Icons.schedule_outlined),
            label: const Text('Подгрузить позже'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(44),
              side: const BorderSide(color: kYellowColor),
              foregroundColor: kYellowColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        _card(
          child: Column(
            children: [
              if (_legalPurchased) ...[
                const Icon(
                  Icons.check_circle_outline,
                  color: kSecondaryColor,
                  size: 34,
                ),
                const SizedBox(height: 8),
                const MyText(
                  text: 'Отчёт уже куплен',
                  size: 14,
                  weight: FontWeight.w700,
                ),
                const SizedBox(height: 4),
                const MyText(
                  text:
                      'Данные будут загружены автоматически, когда сервер ответит',
                  size: 11,
                  color: kGreyColor,
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _startLegalLoading,
                  icon: const Icon(Icons.find_in_page_outlined),
                  label: const Text('Повторить загрузку'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ] else ...[
                const MyText(
                  text: 'Проверка пропущена',
                  size: 13,
                  color: kGreyColor,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        MyButton(buttonText: 'Продолжить', onTap: continueFromLegal),
      ],
    );
  }

  Widget _paintRangeBlock({
    required String title,
    required double from,
    required double to,
    required bool editing,
    required VoidCallback onToggle,
    required ValueChanged<RangeValues> onChanged,
  }) {
    final safeFrom = from.clamp(50, 1500).toDouble();
    final safeTo = to.clamp(safeFrom, 1500).toDouble();
    final manuallySet = safeFrom != 80 || safeTo != 200;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: MyText(text: title, size: 11, color: kGreyColor),
            ),
            TextButton(
              onPressed: onToggle,
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                editing ? 'Готово' : 'Изменить',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: kSecondaryColor,
                ),
              ),
            ),
          ],
        ),
        Row(
          children: [
            MyText(
              text: '${safeFrom.round()}–${safeTo.round()}',
              size: 18,
              weight: FontWeight.w800,
            ),
            const SizedBox(width: 4),
            const MyText(text: 'мкм', size: 11, color: kGreyColor),
          ],
        ),
        const SizedBox(height: 2),
        MyText(
          text: manuallySet ? 'Задано вручную' : 'Нет данных — задайте вручную',
          size: 11,
          color: kGreyColor,
        ),
        if (editing) ...[
          RangeSlider(
            values: RangeValues(safeFrom, safeTo),
            min: 50,
            max: 1500,
            divisions: 29,
            onChanged: onChanged,
          ),
          const Row(
            children: [
              MyText(text: '50 мкм', size: 10, color: kGreyColor),
              Spacer(),
              MyText(text: '1500 мкм', size: 10, color: kGreyColor),
            ],
          ),
        ],
      ],
    );
  }

  String _mediaElementLabel(String groupKey, String? elementType) {
    if (elementType == null || elementType.trim().isEmpty) return '';
    final options = _mediaElementOptions(groupKey);
    for (final option in options) {
      if (option.id == elementType) return option.label;
    }
    return '';
  }

  Future<void> _openMediaInspectionEditor({
    required String groupKey,
    required int index,
  }) async {
    final group = _mediaState[groupKey];
    if (group == null || index < 0 || index >= group.files.length) return;

    final item = group.files[index];
    var noDamage = item.inspection.noDamage;
    var selectedTags = [...item.inspection.tags];
    var elementType = item.inspection.elementType;
    var audioRecordings = [...item.inspection.audioRecordings];
    var customTagsByScope = <String, List<String>>{
      for (final entry in _mediaCustomTagsByScope.entries)
        entry.key: [...entry.value],
    };
    var showElementError = false;
    var isRecording = false;
    var recordingDuration = 0;
    var isDictating = false;
    var speechInitialized = false;
    var speechAvailable = false;
    var playingAudioIndex = -1;
    var dialogActive = true;
    var shouldRecord = false;
    var shouldDictate = false;

    final noteController = TextEditingController(text: item.inspection.note);
    final customTagController = TextEditingController();
    final recorder = AudioRecorder();
    final player = AudioPlayer();
    final speechToText = SpeechToText();
    StreamSubscription<Uint8List>? recordSubscription;
    StreamSubscription<void>? playerCompleteSubscription;
    BytesBuilder? recordBuffer;
    Timer? recordingTimer;

    Future<void> showMessage(String text) async {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(text)));
    }

    Future<void> startRecording(StateSetter setLocalState) async {
      shouldRecord = true;
      if (isRecording) return;

      final hasPermission = await recorder.hasPermission();
      if (!hasPermission) {
        shouldRecord = false;
        await showMessage('Нет доступа к микрофону');
        return;
      }

      try {
        recordBuffer = BytesBuilder(copy: false);
        await recordSubscription?.cancel();
        recordSubscription = (await recorder.startStream(
          const RecordConfig(
            encoder: AudioEncoder.pcm16bits,
            sampleRate: 16000,
            numChannels: 1,
          ),
        )).listen((chunk) {
          recordBuffer?.add(chunk);
        });
        recordingTimer?.cancel();
        recordingDuration = 0;
        recordingTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!dialogActive) return;
          setLocalState(() => recordingDuration += 1);
        });
        if (!shouldRecord) {
          await recorder.stop();
          recordingTimer?.cancel();
          recordingTimer = null;
          await recordSubscription?.cancel();
          recordSubscription = null;
          recordBuffer = null;
          return;
        }
        if (!dialogActive) return;
        setLocalState(() {
          isRecording = true;
        });
      } catch (_) {
        shouldRecord = false;
        await showMessage('Не удалось начать запись');
      }
    }

    Future<void> stopRecording(
      StateSetter setLocalState, {
      bool keepResult = true,
    }) async {
      shouldRecord = false;
      if (!isRecording && recordBuffer == null) return;

      try {
        await recorder.stop();
      } catch (_) {}

      recordingTimer?.cancel();
      recordingTimer = null;
      await recordSubscription?.cancel();
      recordSubscription = null;

      final pcmBytes = recordBuffer?.takeBytes() ?? Uint8List(0);
      recordBuffer = null;

      if (keepResult && pcmBytes.isNotEmpty) {
        final wavBytes = _pcm16ToWav(pcmBytes, sampleRate: 16000);
        audioRecordings = [
          ...audioRecordings,
          'data:audio/wav;base64,${base64Encode(wavBytes)}',
        ];
      }

      if (!dialogActive) return;
      setLocalState(() {
        isRecording = false;
        recordingDuration = 0;
      });
    }

    Future<void> ensureSpeech(StateSetter setLocalState) async {
      if (speechInitialized) return;
      speechInitialized = true;
      speechAvailable = await speechToText.initialize(
        onStatus: (status) {
          if (!dialogActive) return;
          if (status == 'done' || status == 'notListening') {
            setLocalState(() => isDictating = false);
          }
        },
        onError: (_) {
          if (!dialogActive) return;
          setLocalState(() => isDictating = false);
        },
      );
      if (!speechAvailable) {
        await showMessage('Надиктовка недоступна в этом браузере');
      }
    }

    Future<void> startDictation(StateSetter setLocalState) async {
      shouldDictate = true;
      if (isDictating) return;
      await ensureSpeech(setLocalState);
      if (!speechAvailable) return;
      if (!shouldDictate) return;
      try {
        await speechToText.listen(
          localeId: 'ru_RU',
          listenOptions: SpeechListenOptions(
            listenMode: ListenMode.dictation,
            partialResults: false,
            cancelOnError: true,
          ),
          onResult: (result) {
            if (!result.finalResult) return;
            final transcript = result.recognizedWords.trim();
            if (transcript.isEmpty) return;

            final previous = noteController.text.trimRight();
            final separator =
                previous.isEmpty ||
                    previous.endsWith(' ') ||
                    previous.endsWith('\n')
                ? ''
                : ' ';
            final next = '$previous$separator$transcript';
            noteController
              ..text = next
              ..selection = TextSelection.collapsed(offset: next.length);
            if (!dialogActive) return;
            setLocalState(() {});
          },
        );
        if (!dialogActive) return;
        setLocalState(() => isDictating = true);
      } catch (_) {
        shouldDictate = false;
        await showMessage('Не удалось запустить надиктовку');
      }
    }

    Future<void> stopDictation(StateSetter setLocalState) async {
      shouldDictate = false;
      if (!isDictating) return;
      try {
        await speechToText.stop();
      } catch (_) {}
      if (!dialogActive) return;
      setLocalState(() => isDictating = false);
    }

    String recordingLabel() {
      final minutes = (recordingDuration ~/ 60).toString();
      final seconds = (recordingDuration % 60).toString().padLeft(2, '0');
      return '$minutes:$seconds';
    }

    bool? saved;
    try {
      saved = await showDialog<bool>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setLocalState) {
              playerCompleteSubscription ??= player.onPlayerComplete.listen((_) {
                if (!dialogActive) return;
                setLocalState(() => playingAudioIndex = -1);
              });

              final elementOptions = _mediaElementOptions(groupKey);
              final requiresElementType = elementOptions.isNotEmpty;
              final canEditDetails =
                  !requiresElementType ||
                  (elementType ?? '').trim().isNotEmpty;
              final tagGroups = _mediaTagGroups(
                groupKey,
                elementType: elementType,
                customTagsByScope: customTagsByScope,
              );
              final scopeKey = _mediaTagScopeKey(
                groupKey,
                elementType: elementType,
              );
              final customTagsInScope =
                  customTagsByScope[scopeKey] ?? const <String>[];

              return AlertDialog(
                title: const Text('Заметка элемента'),
                content: SizedBox(
                  width: 420,
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<String>(
                          isExpanded: true,
                          isDense: true,
                          initialValue: (elementType ?? '').isEmpty
                              ? null
                              : elementType,
                          decoration: _fieldDecoration('Элемент').copyWith(
                            errorText: showElementError
                                ? 'Выберите тип элемента'
                                : null,
                          ),
                          selectedItemBuilder: (context) {
                            return elementOptions.map((option) {
                              return Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  option.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }).toList();
                          },
                          items: elementOptions.map((option) {
                            return DropdownMenuItem<String>(
                              value: option.id,
                              child: Text(
                                option.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setLocalState(() {
                              elementType = value;
                              selectedTags = [];
                              noDamage = false;
                              showElementError = false;
                            });
                          },
                        ),
                        if (requiresElementType && !canEditDetails) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: kBorderColor),
                              color: kInputBgColor,
                            ),
                            child: const MyText(
                              text:
                                  'Сначала выберите тип элемента, затем отметьте состояние и теги.',
                              size: 11,
                              color: kGreyColor,
                            ),
                          ),
                        ],
                        if (canEditDetails) ...[
                          const SizedBox(height: 10),
                          InkWell(
                            onTap: () {
                              setLocalState(() {
                                noDamage = !noDamage;
                                if (noDamage) selectedTags = [];
                              });
                            },
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: noDamage ? kGreenColor : kBorderColor,
                                ),
                                color: noDamage
                                    ? kGreenColor.withValues(alpha: 0.1)
                                    : kWhiteColor,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    noDamage
                                        ? Icons.check_box
                                        : Icons.check_box_outline_blank,
                                    color: noDamage ? kGreenColor : kGreyColor,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: MyText(
                                      text: _mediaNoDamageLabel(groupKey),
                                      size: 12,
                                      weight: FontWeight.w600,
                                      color: noDamage
                                          ? kGreenColor
                                          : kTertiaryColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (canEditDetails && !noDamage) ...[
                          const SizedBox(height: 10),
                          if (tagGroups.isEmpty)
                            const MyText(
                              text: 'Для выбранного элемента теги не заданы',
                              size: 11,
                              color: kGreyColor,
                            )
                          else
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: tagGroups.map((group) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      MyText(
                                        text: group.title,
                                        size: 11,
                                        color: kGreyColor,
                                        weight: FontWeight.w700,
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: group.options.map((tag) {
                                          final selected = selectedTags
                                              .contains(tag.label);
                                          return _chip(
                                            label: tag.label,
                                            selected: selected,
                                            selectedColor: _mediaTagColor(
                                              tag.severity,
                                            ),
                                            onTap: () {
                                              setLocalState(() {
                                                if (selected) {
                                                  selectedTags.remove(tag.label);
                                                } else {
                                                  selectedTags.add(tag.label);
                                                }
                                              });
                                            },
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: customTagController,
                                  decoration: _fieldDecoration(
                                    'Свой тег',
                                  ).copyWith(
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: () {
                                  final input = customTagController.text.trim();
                                  if (input.isEmpty) return;

                                  final next =
                                      customTagsByScope[scopeKey] != null
                                      ? [...customTagsByScope[scopeKey]!]
                                      : <String>[];

                                  String selectedValue = input;
                                  final lower = input.toLowerCase();
                                  for (final tag in next) {
                                    if (tag.toLowerCase() == lower) {
                                      selectedValue = tag;
                                      break;
                                    }
                                  }
                                  if (!next.any(
                                    (tag) => tag.toLowerCase() == lower,
                                  )) {
                                    next.add(input);
                                    selectedValue = input;
                                  }
                                  customTagsByScope[scopeKey] = next;
                                  if (!selectedTags.any(
                                    (tag) =>
                                        tag.toLowerCase() ==
                                        selectedValue.toLowerCase(),
                                  )) {
                                    selectedTags.add(selectedValue);
                                  }
                                  customTagController.clear();
                                  setLocalState(() {});
                                },
                                child: const Text('Добавить'),
                              ),
                            ],
                          ),
                          if (customTagsInScope.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            MyText(
                              text: 'Кастомные теги: ${customTagsInScope.length}',
                              size: 11,
                              color: kGreyColor,
                            ),
                          ],
                        ],
                        if (canEditDetails) ...[
                          const SizedBox(height: 10),
                          TextField(
                            controller: noteController,
                            minLines: 3,
                            maxLines: 5,
                            decoration: _fieldDecoration('Комментарий'),
                          ),
                          if (isDictating) ...[
                            const SizedBox(height: 6),
                            const MyText(
                              text: 'Идёт надиктовка...',
                              size: 11,
                              color: kRedColor,
                              weight: FontWeight.w700,
                            ),
                          ],
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: GestureDetector(
                                  onTapDown: (_) => startDictation(setLocalState),
                                  onTapUp: (_) => stopDictation(setLocalState),
                                  onTapCancel: () => stopDictation(setLocalState),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isDictating
                                            ? kRedColor.withValues(alpha: 0.4)
                                            : kBorderColor,
                                      ),
                                      color: isDictating
                                          ? kRedColor.withValues(alpha: 0.08)
                                          : kInputBgColor,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          isDictating
                                              ? Icons.mic_off_rounded
                                              : Icons.mic_rounded,
                                          size: 16,
                                          color: isDictating
                                              ? kRedColor
                                              : kSecondaryColor,
                                        ),
                                        const SizedBox(width: 6),
                                        MyText(
                                          text: isDictating
                                              ? 'Говорите...'
                                              : 'Зажмите для диктовки',
                                          size: 11,
                                          weight: FontWeight.w700,
                                          color: isDictating
                                              ? kRedColor
                                              : kTertiaryColor,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: GestureDetector(
                                  onTapDown: (_) => startRecording(setLocalState),
                                  onTapUp: (_) => stopRecording(setLocalState),
                                  onTapCancel: () => stopRecording(setLocalState),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isRecording
                                            ? kRedColor.withValues(alpha: 0.4)
                                            : kBorderColor,
                                      ),
                                      color: isRecording
                                          ? kRedColor.withValues(alpha: 0.08)
                                          : kInputBgColor,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          isRecording
                                              ? Icons.radio_button_checked
                                              : Icons.graphic_eq_rounded,
                                          size: 16,
                                          color: isRecording
                                              ? kRedColor
                                              : kSecondaryColor,
                                        ),
                                        const SizedBox(width: 6),
                                        MyText(
                                          text: isRecording
                                              ? 'Запись ${recordingLabel()}'
                                              : 'Зажмите для записи',
                                          size: 11,
                                          weight: FontWeight.w700,
                                          color: isRecording
                                              ? kRedColor
                                              : kTertiaryColor,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: OutlinedButton.icon(
                              onPressed: () async {
                                final picked = await _pickFiles(
                                  type: FileType.custom,
                                  allowedExtensions: const [
                                    'mp3',
                                    'm4a',
                                    'wav',
                                    'aac',
                                    'ogg',
                                    'oga',
                                  ],
                                );
                                if (picked.isEmpty) return;
                                setLocalState(() {
                                  final next = <String>[
                                    ...audioRecordings,
                                    ...picked
                                        .where((file) => file.isAudio)
                                        .map((file) => file.dataUrl),
                                  ];
                                  audioRecordings = next;
                                });
                              },
                              icon: const Icon(
                                Icons.upload_file_rounded,
                                size: 16,
                              ),
                              label: const Text('Добавить аудиофайл'),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: MyText(
                                  text:
                                      'Аудиозаметки: ${audioRecordings.length}',
                                  size: 11,
                                  color: kGreyColor,
                                  weight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          if (audioRecordings.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            ...List.generate(audioRecordings.length, (
                              audioIndex,
                            ) {
                              final playing = playingAudioIndex == audioIndex;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: kBorderColor),
                                    color: kInputBgColor,
                                  ),
                                  child: Row(
                                    children: [
                                      InkWell(
                                        onTap: () async {
                                          try {
                                            if (playing) {
                                              await player.stop();
                                              if (!dialogActive) return;
                                              setLocalState(
                                                () => playingAudioIndex = -1,
                                              );
                                            } else {
                                              await player.stop();
                                              await player.play(
                                                UrlSource(
                                                  audioRecordings[audioIndex],
                                                ),
                                              );
                                              if (!dialogActive) return;
                                              setLocalState(
                                                () =>
                                                    playingAudioIndex =
                                                        audioIndex,
                                              );
                                            }
                                          } catch (_) {
                                            await showMessage(
                                              'Не удалось воспроизвести аудио',
                                            );
                                          }
                                        },
                                        borderRadius: BorderRadius.circular(999),
                                        child: Padding(
                                          padding: const EdgeInsets.all(2),
                                          child: Icon(
                                            playing
                                                ? Icons.pause_circle_outline
                                                : Icons.play_circle_outline,
                                            size: 20,
                                            color: kSecondaryColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: MyText(
                                          text: 'Аудиозапись ${audioIndex + 1}',
                                          size: 11,
                                          color: kTertiaryColor,
                                        ),
                                      ),
                                      InkWell(
                                        onTap: () async {
                                          if (playingAudioIndex == audioIndex) {
                                            await player.stop();
                                            playingAudioIndex = -1;
                                          }
                                          setLocalState(() {
                                            audioRecordings.removeAt(audioIndex);
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(999),
                                        child: const Padding(
                                          padding: EdgeInsets.all(2),
                                          child: Icon(
                                            Icons.delete_outline_rounded,
                                            size: 16,
                                            color: kGreyColor,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () async {
                      await stopDictation(setLocalState);
                      await stopRecording(setLocalState, keepResult: false);
                      await player.stop();
                      if (!context.mounted) return;
                      Navigator.of(context).pop(false);
                    },
                    child: const Text('Отмена'),
                  ),
                  TextButton(
                    onPressed: () async {
                      final requiresElementType = _mediaElementOptions(
                        groupKey,
                      ).isNotEmpty;
                      if (requiresElementType &&
                          (elementType ?? '').trim().isEmpty) {
                        setLocalState(() => showElementError = true);
                        return;
                      }
                      await stopDictation(setLocalState);
                      await stopRecording(setLocalState);
                      await player.stop();
                      if (!context.mounted) return;
                      Navigator.of(context).pop(true);
                    },
                    child: const Text('Сохранить'),
                  ),
                ],
              );
            },
          );
        },
      );
    } finally {
      dialogActive = false;
      recordingTimer?.cancel();
      await recordSubscription?.cancel();
      try {
        if (await recorder.isRecording()) {
          await recorder.stop();
        }
      } catch (_) {}
      try {
        await speechToText.stop();
      } catch (_) {}
      await playerCompleteSubscription?.cancel();
      try {
        await player.stop();
      } catch (_) {}
      await player.dispose();
      await recorder.dispose();
    }
    final noteValue = noteController.text.trim();
    noteController.dispose();
    customTagController.dispose();
    if (saved != true || !mounted) return;

    setState(() {
      _mediaCustomTagsByScope = _readStringListMap(customTagsByScope);
      final current = _mediaState[groupKey];
      if (current == null || index >= current.files.length) return;
      final nextFiles = [...current.files];
      nextFiles[index] = nextFiles[index].copyWith(
        inspection: _MediaInspection(
          noDamage: noDamage,
          tags: selectedTags,
          note: noteValue,
          elementType: (elementType ?? '').trim().isEmpty ? null : elementType,
          audioRecordings: audioRecordings,
          isDraft: false,
        ),
      );
      final hasIssue = nextFiles.any(_mediaItemHasIssue);
      _mediaState[groupKey] = current.copyWith(
        files: nextFiles,
        hasIssue: hasIssue,
      );
    });
  }

  Widget _uploadedMediaGrid({
    required List<_UploadedItem> items,
    required ValueChanged<int> onDelete,
    required String groupKey,
    ValueChanged<int>? onInspect,
  }) {
    if (items.isEmpty) {
      return const MyText(
        text: 'Файлы не добавлены',
        size: 11,
        color: kGreyColor,
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(items.length, (index) {
        final item = items[index];
        return SizedBox(
          width: 92,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 92,
                      height: 72,
                      color: kLightGreyColor,
                      child: item.isImage
                          ? Image.network(
                              item.dataUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(
                                  Icons.broken_image_outlined,
                                  color: kGreyColor,
                                );
                              },
                            )
                          : Icon(
                              item.isVideo
                                  ? Icons.videocam_outlined
                                  : Icons.insert_drive_file_outlined,
                              color: kGreyColor,
                            ),
                    ),
                  ),
                  if (_mediaInspectionHasData(item.inspection))
                    Positioned(
                      top: 2,
                      left: 2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 5,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: item.inspection.isDraft
                              ? kYellowColor
                              : kGreenColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: const Text(
                          'Заметка',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: kWhiteColor,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 2,
                    right: 2,
                    child: InkWell(
                      onTap: () => onDelete(index),
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        width: 20,
                        height: 20,
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          size: 14,
                          color: kWhiteColor,
                        ),
                      ),
                    ),
                  ),
                  if (onInspect != null)
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: InkWell(
                        onTap: () => onInspect(index),
                        borderRadius: BorderRadius.circular(999),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: const Text(
                            'Заметка',
                            style: TextStyle(
                              fontSize: 9,
                              color: kWhiteColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              MyText(text: item.name, size: 10, color: kGreyColor, maxLines: 1),
              if (item.inspection.elementType != null &&
                  item.inspection.elementType!.trim().isNotEmpty)
                MyText(
                  text: _mediaElementLabel(
                    groupKey,
                    item.inspection.elementType,
                  ),
                  size: 10,
                  color: kTertiaryColor,
                  maxLines: 1,
                ),
              if (item.inspection.audioRecordings.isNotEmpty)
                MyText(
                  text: 'Аудио: ${item.inspection.audioRecordings.length}',
                  size: 10,
                  color: kSecondaryColor,
                  maxLines: 1,
                ),
            ],
          ),
        );
      }),
    );
  }

  Widget _mediaGroupCardFixed(_MediaGroupState state) {
    final fileCount = state.files.length;
    final okElements = _groupNoDamageElementsCount(state.config.key, state);
    final seriousTags = _groupSeriousTagCount(state.config.key, state);
    final minorTags = _groupMinorTagCount(state.config.key, state);

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: MyText(
                  text: state.config.title,
                  size: 13,
                  weight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: state.config.required
                      ? kSecondaryColor.withValues(alpha: 0.08)
                      : kLightGreyColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: MyText(
                  text: state.config.required ? 'обяз.' : 'доп.',
                  size: 10,
                  color: state.config.required ? kSecondaryColor : kGreyColor,
                  weight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          MyText(text: state.config.description, size: 11, color: kGreyColor),
          if (state.config.key == 'body') ...[
            const SizedBox(height: 8),
            _paintRangeBlock(
              title: 'ЛКП — кузов',
              from: _bodyPaintFrom,
              to: _bodyPaintTo,
              editing: _bodyPaintEditing,
              onToggle: () =>
                  setState(() => _bodyPaintEditing = !_bodyPaintEditing),
              onChanged: (values) {
                setState(() {
                  _bodyPaintFrom = values.start.roundToDouble();
                  _bodyPaintTo = values.end.roundToDouble();
                });
              },
            ),
          ],
          if (state.config.key == 'structural') ...[
            const SizedBox(height: 8),
            _paintRangeBlock(
              title: 'ЛКП — силовые',
              from: _structPaintFrom,
              to: _structPaintTo,
              editing: _structPaintEditing,
              onToggle: () =>
                  setState(() => _structPaintEditing = !_structPaintEditing),
              onChanged: (values) {
                setState(() {
                  _structPaintFrom = values.start.roundToDouble();
                  _structPaintTo = values.end.roundToDouble();
                });
              },
            ),
          ],
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () => _pickMediaFiles(state.config.key),
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('Добавить фото/видео'),
          ),
          const SizedBox(height: 8),
          _uploadedMediaGrid(
            items: state.files,
            groupKey: state.config.key,
            onInspect: (index) {
              _openMediaInspectionEditor(
                groupKey: state.config.key,
                index: index,
              );
            },
            onDelete: (index) {
              setState(() {
                final current = _mediaState[state.config.key] ?? state;
                final next = [...current.files]..removeAt(index);
                _mediaState[state.config.key] = current.copyWith(
                  files: next,
                  hasIssue: next.any(_mediaItemHasIssue),
                );
              });
            },
          ),
          const SizedBox(height: 6),
          MyText(
            text: fileCount == 0
                ? 'Файлы не добавлены'
                : 'Добавлено: $fileCount · Размечено: ${state.files.where((f) => _mediaInspectionHasData(f.inspection)).length} · Ок: $okElements · Серьёзн.: $seriousTags · Незначит.: $minorTags',
            size: 11,
            color: fileCount == 0 ? kGreyColor : kSecondaryColor,
          ),
          if (fileCount > 0) _mediaElementSummaryList(state.config.key, state),
        ],
      ),
    );
  }

  Widget _stepMedia() {
    final required = _requiredMediaGroups();
    final missing = _missingRequiredMediaGroups();
    final filledCount = required.length - missing.length;

    return Column(
      children: [
        _card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MyText(
                text: 'Обязательные группы: $filledCount/${required.length}',
                size: 13,
                weight: FontWeight.w700,
              ),
              const SizedBox(height: 4),
              MyText(
                text: missing.isEmpty
                    ? 'Все обязательные группы заполнены'
                    : 'Нужно добавить фото: ${missing.map((e) => e.title).join(', ')}',
                size: 11,
                color: missing.isEmpty ? kGreenColor : kRedColor,
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        ..._mediaGroupsConfig.map((config) {
          final state = _mediaState[config.key]!;
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _mediaGroupCardFixed(state),
          );
        }),
      ],
    );
  }

  Widget _stepTestDrive() {
    final tdConducted = _tdConductedValue();

    return Column(
      children: [
        _testDriveConductedSelector(),
        if (tdConducted == true) ...[
          const SizedBox(height: 10),
          _testDriveSubsystemCard(
            sectionLabel: '🔧 Двигатель',
            ok: _tdEngineOk,
            onOkChanged: (value) {
              setState(() {
                if (_tdMode == _tdModeAllGood && !value) {
                  _tdMode = _tdModeProblems;
                }
                _tdEngineOk = value;
                if (value) _tdEngineTags = const [];
              });
            },
            okLabel: 'Двигатель работает исправно',
            options: _tdEngineTagOptions,
            selected: _tdEngineTags,
            onTagsChanged: (value) {
              setState(() {
                _tdEngineTags = value;
              });
            },
          ),
          const SizedBox(height: 10),
          _testDriveSubsystemCard(
            sectionLabel: '⚙️ КПП',
            ok: _tdGearboxOk,
            onOkChanged: (value) {
              setState(() {
                if (_tdMode == _tdModeAllGood && !value) {
                  _tdMode = _tdModeProblems;
                }
                _tdGearboxOk = value;
                if (value) _tdGearboxTags = const [];
              });
            },
            okLabel: 'КПП работает исправно',
            options: _tdGearboxTagOptions,
            selected: _tdGearboxTags,
            onTagsChanged: (value) {
              setState(() {
                _tdGearboxTags = value;
              });
            },
          ),
          const SizedBox(height: 10),
          _testDriveSubsystemCard(
            sectionLabel: '🎯 Рулевое управление',
            ok: _tdSteeringOk,
            onOkChanged: (value) {
              setState(() {
                if (_tdMode == _tdModeAllGood && !value) {
                  _tdMode = _tdModeProblems;
                }
                _tdSteeringOk = value;
                if (value) _tdSteeringTags = const [];
              });
            },
            okLabel: 'Рулевое без замечаний',
            options: _tdSteeringTagOptions,
            selected: _tdSteeringTags,
            onTagsChanged: (value) {
              setState(() {
                _tdSteeringTags = value;
              });
            },
          ),
          const SizedBox(height: 10),
          _testDriveSubsystemCard(
            sectionLabel: '🛣️ Подвеска на ходу',
            ok: _tdRideOk,
            onOkChanged: (value) {
              setState(() {
                if (_tdMode == _tdModeAllGood && !value) {
                  _tdMode = _tdModeProblems;
                }
                _tdRideOk = value;
                if (value) _tdRideTags = const [];
              });
            },
            okLabel: 'Подвеска без замечаний на ходу',
            options: _tdRideTagOptions,
            selected: _tdRideTags,
            onTagsChanged: (value) {
              setState(() {
                _tdRideTags = value;
              });
            },
          ),
          const SizedBox(height: 10),
          _testDriveSubsystemCard(
            sectionLabel: '🛑 Тормоза на ходу',
            ok: _tdBrakeOk,
            onOkChanged: (value) {
              setState(() {
                if (_tdMode == _tdModeAllGood && !value) {
                  _tdMode = _tdModeProblems;
                }
                _tdBrakeOk = value;
                if (value) _tdBrakeTags = const [];
              });
            },
            okLabel: 'Тормоза работают исправно',
            options: _tdBrakeTagOptions,
            selected: _tdBrakeTags,
            onTagsChanged: (value) {
              setState(() {
                _tdBrakeTags = value;
              });
            },
          ),
          const SizedBox(height: 10),
          _testDriveNoteBlock(
            _tdMode == _tdModeAllGood
                ? 'Комментарий по тест-драйву...'
                : 'Замечания по тест-драйву...',
          ),
        ],
        if (tdConducted == false) ...[
          const SizedBox(height: 10),
          _testDriveNoteBlock('Причина отсутствия тест-драйва...'),
        ],
      ],
    );
  }

  Color _summarySectionStatusColor(String status) {
    switch (status) {
      case 'ok':
        return kGreenColor;
      case 'bad':
      case 'danger':
      case 'error':
        return kRedColor;
      default:
        return kYellowColor;
    }
  }

  Color _summaryDetailSeverityColor(String severity) {
    switch (severity) {
      case 'ok':
        return kGreenColor;
      case 'serious':
      case 'critical':
        return kRedColor;
      case 'minor':
        return kYellowColor;
      default:
        return kGreyColor;
    }
  }

  Widget _summarySectionMediaPreview(String title) {
    final groupKey = _summaryTitleToGroupKey[title];
    if (groupKey == null) return const SizedBox.shrink();

    final state = _mediaState[groupKey];
    final files = state?.files ?? const <_UploadedItem>[];
    if (files.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: files.map((file) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 74,
              height: 74,
              color: kLightGreyColor,
              child: file.isImage
                  ? Image.network(
                      file.dataUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.broken_image_outlined,
                          color: kGreyColor,
                        );
                      },
                    )
                  : Icon(
                      file.isVideo
                          ? Icons.videocam_outlined
                          : Icons.insert_drive_file_outlined,
                      color: kGreyColor,
                    ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _summaryNoDamageMediaCard() {
    final cleanItems = <_UploadedItem>[];
    for (final entry in _mediaState.entries) {
      final state = entry.value;
      for (final file in state.files) {
        if (_mediaItemHasIssue(file)) continue;
        cleanItems.add(file);
      }
    }
    if (cleanItems.isEmpty) return const SizedBox.shrink();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('✅', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              const Expanded(
                child: MyText(
                  text: 'Обзор авто',
                  size: 13,
                  weight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: kGreenColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: MyText(
                  text: '${cleanItems.length} фото',
                  size: 10,
                  weight: FontWeight.w700,
                  color: kGreenColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const MyText(
            text: 'Элементы без выявленных повреждений и нераспределённые фото',
            size: 11,
            color: kGreyColor,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: cleanItems.map((file) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 74,
                  height: 74,
                  color: kLightGreyColor,
                  child: file.isImage
                      ? Image.network(
                          file.dataUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.broken_image_outlined,
                              color: kGreyColor,
                            );
                          },
                        )
                      : Icon(
                          file.isVideo
                              ? Icons.videocam_outlined
                              : Icons.insert_drive_file_outlined,
                          color: kGreyColor,
                        ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _summarySectionCard(Map<String, dynamic> section) {
    final title = (section['title'] ?? '').toString().trim();
    final status = (section['status'] ?? '').toString().trim();
    final required = section['required'] == true;
    final statusColor = _summarySectionStatusColor(status);

    final detailLines = <String>[];
    final detailMaps = <Map<String, dynamic>>[];
    final detailsRaw = section['details'];
    if (detailsRaw is List) {
      for (final detail in detailsRaw) {
        if (detail is String) {
          if (detail.trim().isNotEmpty) detailLines.add(detail.trim());
          continue;
        }
        if (detail is Map) {
          detailMaps.add(
            detail.map((key, value) => MapEntry(key.toString(), value)),
          );
        }
      }
    }

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: MyText(
                  text: title.isEmpty ? 'Раздел' : title,
                  size: 13,
                  weight: FontWeight.w700,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: required
                      ? kSecondaryColor.withValues(alpha: 0.08)
                      : kLightGreyColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: MyText(
                  text: required ? 'обяз.' : 'доп.',
                  size: 10,
                  color: required ? kSecondaryColor : kGreyColor,
                  weight: FontWeight.w700,
                ),
              ),
            ],
          ),
          if (status.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: MyText(
                text: status == 'ok'
                    ? 'ОК'
                    : (status == 'bad' ||
                              status == 'danger' ||
                              status == 'error'
                          ? 'Критично'
                          : 'Есть замечания'),
                size: 10,
                weight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ],
          if (detailLines.isNotEmpty || detailMaps.isNotEmpty)
            const SizedBox(height: 8),
          ...detailLines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: MyText(text: '• $line', size: 11, color: kGreyColor),
            ),
          ),
          ...detailMaps.map((detail) {
            final label = (detail['label'] ?? '').toString().trim();
            final value = (detail['value'] ?? '').toString().trim();
            final severity = (detail['severity'] ?? '').toString().trim();
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 11),
                  children: [
                    TextSpan(
                      text: '• ${label.isEmpty ? 'Проверка' : label}: ',
                      style: const TextStyle(color: kGreyColor),
                    ),
                    TextSpan(
                      text: value.isEmpty ? '-' : value,
                      style: TextStyle(
                        color: _summaryDetailSeverityColor(severity),
                        decoration: value.startsWith('http')
                            ? TextDecoration.underline
                            : TextDecoration.none,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          _summarySectionMediaPreview(title),
        ],
      ),
    );
  }

  Widget _summaryReportNameCard() {
    final name = _reportNameController.text.trim();
    if (name.isEmpty) return const SizedBox.shrink();
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MyText(text: 'Название отчёта', size: 11, color: kGreyColor),
          const SizedBox(height: 4),
          MyText(text: name, size: 13, weight: FontWeight.w700),
        ],
      ),
    );
  }

  Widget _summarySectionsList(_CalculatedSummary summary) {
    return Column(
      children: summary.sections.map((section) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _summarySectionCard(section),
        );
      }).toList(),
    );
  }

  Widget _summaryNoteCard() {
    final note = _summaryController.text.trim();
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MyText(
            text: 'Сводка по данным осмотра',
            size: 13,
            weight: FontWeight.w700,
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kBorderColor),
              color: kInputBgColor,
            ),
            child: MyText(
              text: note.isEmpty
                  ? 'Заполните разделы осмотра для формирования сводки.'
                  : note,
              size: 11,
              color: note.isEmpty ? kGreyColor : kTertiaryColor,
              lineHeight: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  void _formatExpertConclusionText() {
    final text = _expertController.text.trim();
    if (text.isEmpty) return;

    final sentences = text
        .replaceAll(RegExp(r'([.!?])\s+'), r'$1\n')
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (sentences.isEmpty) return;

    final paragraphs = <String>[];
    final current = <String>[];
    for (var i = 0; i < sentences.length; i++) {
      current.add(sentences[i]);
      if (current.length >= 3 || i == sentences.length - 1) {
        paragraphs.add(current.join(' '));
        current.clear();
      }
    }

    setState(() {
      _expertController.text = paragraphs.join('\n\n');
    });
  }

  Widget _summaryExpertConclusionCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('✍️', style: TextStyle(fontSize: 16)),
              SizedBox(width: 6),
              MyText(
                text: 'Итог специалиста',
                size: 13,
                weight: FontWeight.w700,
              ),
            ],
          ),
          const SizedBox(height: 4),
          const MyText(
            text: '🔒 Видна только заказчику',
            size: 11,
            color: kGreyColor,
          ),
          const SizedBox(height: 8),
          _input(
            _expertController,
            'Ваш вывод, рекомендации, условия сделки, комментарий для клиента...',
            minLines: 4,
            maxLines: 8,
          ),
          if (_expertController.text.trim().length > 10) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _formatExpertConclusionText,
              icon: const Icon(Icons.auto_fix_high, size: 16),
              label: const Text('Отформатировать с ИИ'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: kSecondaryColor.withValues(alpha: 0.22),
                ),
                foregroundColor: kSecondaryColor,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                minimumSize: const Size(0, 34),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _stepSummary() {
    final summary = _calculateSummary();
    return Column(
      children: [
        if (_reportNameController.text.trim().isNotEmpty) ...[
          _summaryReportNameCard(),
          const SizedBox(height: 10),
        ],
        _summaryNoDamageMediaCard(),
        if (_mediaState.values.any(
          (state) => state.files.any((file) => !_mediaItemHasIssue(file)),
        ))
          const SizedBox(height: 10),
        _summarySectionsList(summary),
        const SizedBox(height: 10),
        _summaryNoteCard(),
        const SizedBox(height: 10),
        _summaryExpertConclusionCard(),
      ],
    );
  }

  Widget _stepContent() {
    switch (_stepIndex) {
      case 0:
        return _stepVehicle();
      case 1:
        return _stepParams();
      case 2:
        return _stepDocsCheck();
      case 3:
        return _stepLegal();
      case 4:
        return _stepMedia();
      case 5:
        return _stepTestDrive();
      default:
        return _stepSummary();
    }
  }

  Widget _sectionEditor() {
    final step = _steps[_stepIndex];
    final isLast = _stepIndex == _steps.length - 1;
    final isVehicleStep = step.id == 'vehicle';
    final isMediaStep = step.id == 'media';
    final isTestDriveStep = step.id == 'test_drive';
    final isSummaryStep = step.id == 'summary';
    final canVehicleContinue = _isVehicleReadyForContinue();
    final missingMediaGroups = isMediaStep
        ? _missingRequiredMediaGroups().map((e) => e.title).toList()
        : const <String>[];
    final canMediaContinue = missingMediaGroups.isEmpty;
    final testDriveReasons = isTestDriveStep
        ? _testDriveMissingReasons()
        : const <String>[];
    final canTestDriveContinue = testDriveReasons.isEmpty;
    final summaryReasons = isSummaryStep
        ? _summaryMissingReasons()
        : const <String>[];
    final canSummaryFinish = summaryReasons.isEmpty;

    return Column(
      children: [
        _card(
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: kLightGreyColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: MyText(
                  text: '${_stepIndex + 1}',
                  size: 11,
                  color: kGreyColor,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MyText(text: step.title, size: 15, weight: FontWeight.w700),
                    const SizedBox(height: 2),
                    MyText(text: step.description, size: 11, color: kGreyColor),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _stepContent(),
        if (isVehicleStep && !canVehicleContinue) ...[
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerLeft,
            child: MyText(
              text: 'Укажите VIN-номер или отметьте VIN как нечитаемый',
              size: 11,
              color: kRedColor,
            ),
          ),
        ],
        if (isMediaStep && !canMediaContinue) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: MyText(
              text: 'Добавьте фото: ${missingMediaGroups.join(', ')}',
              size: 11,
              color: kRedColor,
            ),
          ),
        ],
        if (isTestDriveStep && !canTestDriveContinue) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: MyText(
              text: testDriveReasons.join(' · '),
              size: 11,
              color: kRedColor,
            ),
          ),
        ],
        if (isSummaryStep && !canSummaryFinish) ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: MyText(
              text: summaryReasons.join(' · '),
              size: 11,
              color: kRedColor,
            ),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => _closeSection(save: true),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: kBorderColor),
                  minimumSize: const Size.fromHeight(44),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'К разделам',
                  style: TextStyle(color: kSecondaryColor),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: MyButton(
                buttonText: isLast
                    ? (canSummaryFinish
                          ? 'Завершить отчет'
                          : 'Заполните обязательные разделы')
                    : (isVehicleStep || isMediaStep || isTestDriveStep
                          ? 'Продолжить'
                          : 'Сохранить'),
                bgColor:
                    (isLast && !canSummaryFinish) ||
                        (!isLast &&
                            ((isVehicleStep && !canVehicleContinue) ||
                                (isMediaStep && !canMediaContinue) ||
                                (isTestDriveStep && !canTestDriveContinue)))
                    ? kGreyColor.withValues(alpha: 0.5)
                    : null,
                onTap: () async {
                  if (isLast) {
                    if (!canSummaryFinish) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(summaryReasons.join('\n'))),
                      );
                      return;
                    }
                    await _finishReport();
                    return;
                  }

                  if (isVehicleStep) {
                    await _handleVehicleContinue();
                    return;
                  }
                  if (isMediaStep) {
                    if (!canMediaContinue) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Добавьте фото в обязательные группы: ${missingMediaGroups.join(', ')}',
                          ),
                        ),
                      );
                      return;
                    }
                    await _saveAndOpenNextSection();
                    return;
                  }
                  if (isTestDriveStep) {
                    if (!canTestDriveContinue) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(testDriveReasons.join('\n'))),
                      );
                      return;
                    }
                    await _saveAndOpenNextSection();
                    return;
                  }
                  await _saveAndOpenNextSection();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_editingSection,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_editingSection) {
          await _closeSection(save: false);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () {
              if (_editingSection) {
                _closeSection(save: false);
                return;
              }
              Navigator.of(context).pop();
            },
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          titleSpacing: 0,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MyText(text: _reportTitle(), size: 18, weight: FontWeight.w700),
              const SizedBox(height: 2),
              MyText(
                text: '$_reportCode от $_createdAt',
                size: 13,
                color: kGreyColor,
              ),
            ],
          ),
          actions: [
            if (!_editingSection)
              IconButton(
                onPressed: _editReportTitle,
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Переименовать',
              ),
            TextButton(
              onPressed: _saveDraft,
              child: const Text(
                'Сохранить',
                style: TextStyle(
                  color: kSecondaryColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        body: ListView(
          padding: AppSizes.listPaddingWithBottomBar(),
          children: [_editingSection ? _sectionEditor() : _sectionsOverview()],
        ),
      ),
    );
  }
}

enum _CarPickerStep { brand, model, generation, restyling }

class _CarPickerSelection {
  const _CarPickerSelection({
    required this.brand,
    required this.model,
    required this.generation,
    required this.restyling,
    required this.frames,
    required this.photoUrl,
  });

  final String brand;
  final String model;
  final String generation;
  final String restyling;
  final String frames;
  final String photoUrl;
}

class _CarCatalogBrand {
  const _CarCatalogBrand({required this.name, required this.models});

  final String name;
  final List<_CarCatalogModel> models;
}

class _CarCatalogModel {
  const _CarCatalogModel({required this.name, required this.generations});

  final String name;
  final List<_CarCatalogGeneration> generations;
}

class _CarCatalogGeneration {
  const _CarCatalogGeneration({required this.name, required this.restylings});

  final String name;
  final List<_CarCatalogRestyling> restylings;
}

class _CarCatalogRestyling {
  const _CarCatalogRestyling({
    required this.label,
    required this.frames,
    required this.photoUrl,
  });

  final String label;
  final String frames;
  final String photoUrl;
}

class _VinGuideFrame extends StatelessWidget {
  const _VinGuideFrame({required this.animate});

  final bool animate;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: kWhiteColor, width: 2),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        if (animate) const _VinGuideScanLine(),
        const _VinGuideCorners(),
      ],
    );
  }
}

class _VinGuideCorners extends StatelessWidget {
  const _VinGuideCorners();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Stack(
        children: [
          _VinGuideCorner(top: true, left: true),
          _VinGuideCorner(top: true, left: false),
          _VinGuideCorner(top: false, left: true),
          _VinGuideCorner(top: false, left: false),
        ],
      ),
    );
  }
}

class _VinGuideCorner extends StatelessWidget {
  const _VinGuideCorner({required this.top, required this.left});

  final bool top;
  final bool left;

  @override
  Widget build(BuildContext context) {
    const size = 18.0;
    const stroke = 3.0;
    final alignment = Alignment(left ? -1 : 1, top ? -1 : 1);

    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          border: Border(
            top: top
                ? const BorderSide(color: kWhiteColor, width: stroke)
                : BorderSide.none,
            bottom: top
                ? BorderSide.none
                : const BorderSide(color: kWhiteColor, width: stroke),
            left: left
                ? const BorderSide(color: kWhiteColor, width: stroke)
                : BorderSide.none,
            right: left
                ? BorderSide.none
                : const BorderSide(color: kWhiteColor, width: stroke),
          ),
          borderRadius: BorderRadius.only(
            topLeft: top && left ? const Radius.circular(6) : Radius.zero,
            topRight: top && !left ? const Radius.circular(6) : Radius.zero,
            bottomLeft: !top && left ? const Radius.circular(6) : Radius.zero,
            bottomRight: !top && !left ? const Radius.circular(6) : Radius.zero,
          ),
        ),
      ),
    );
  }
}

class _VinGuideScanLine extends StatefulWidget {
  const _VinGuideScanLine();

  @override
  State<_VinGuideScanLine> createState() => _VinGuideScanLineState();
}

class _VinGuideScanLineState extends State<_VinGuideScanLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final start = -width * 0.35;
              final end = width * 1.25;
              final left = start + (end - start) * _controller.value;

              return Stack(
                children: [
                  Positioned(
                    left: left,
                    top: 8,
                    bottom: 8,
                    child: Container(
                      width: 64,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Color(0xCC6EE7B7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _VinGuideBadge extends StatelessWidget {
  const _VinGuideBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: kWhiteColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const MyText(
        text: 'VIN',
        size: 11,
        color: kSecondaryColor,
        weight: FontWeight.w700,
      ),
    );
  }
}

class _StepConfig {
  const _StepConfig({
    required this.id,
    required this.title,
    required this.description,
  });

  final String id;
  final String title;
  final String description;
}

class _MediaGroupConfig {
  const _MediaGroupConfig({
    required this.key,
    required this.title,
    required this.description,
    required this.required,
    required this.severeIfIssue,
  });

  final String key;
  final String title;
  final String description;
  final bool required;
  final bool severeIfIssue;
}

class _MediaGroupState {
  const _MediaGroupState({
    required this.config,
    required this.hasIssue,
    required this.note,
    required this.rawUrls,
    required this.files,
  });

  final _MediaGroupConfig config;
  final bool hasIssue;
  final String note;
  final String rawUrls;
  final List<_UploadedItem> files;

  _MediaGroupState copyWith({
    bool? hasIssue,
    String? note,
    String? rawUrls,
    List<_UploadedItem>? files,
  }) {
    return _MediaGroupState(
      config: config,
      hasIssue: hasIssue ?? this.hasIssue,
      note: note ?? this.note,
      rawUrls: rawUrls ?? this.rawUrls,
      files: files ?? this.files,
    );
  }
}

class _MediaOption {
  const _MediaOption({required this.id, required this.label});

  final String id;
  final String label;
}

class _MediaTagOption {
  const _MediaTagOption({
    required this.label,
    required this.severity,
    this.isCustom = false,
  });

  final String label;
  final String severity;
  final bool isCustom;
}

class _MediaTagGroup {
  const _MediaTagGroup({required this.title, required this.options});

  final String title;
  final List<_MediaTagOption> options;
}

class _MediaElementSummary {
  const _MediaElementSummary({
    required this.elementType,
    required this.label,
    required this.noDamage,
    required this.tags,
    required this.hasComment,
  });

  final String elementType;
  final String label;
  final bool noDamage;
  final List<String> tags;
  final bool hasComment;
}

class _MediaInspection {
  const _MediaInspection({
    this.noDamage = false,
    this.tags = const [],
    this.note = '',
    this.elementType,
    this.audioRecordings = const [],
    this.isDraft = false,
  });

  final bool noDamage;
  final List<String> tags;
  final String note;
  final String? elementType;
  final List<String> audioRecordings;
  final bool isDraft;

  _MediaInspection copyWith({
    bool? noDamage,
    List<String>? tags,
    String? note,
    String? elementType,
    List<String>? audioRecordings,
    bool? isDraft,
  }) {
    return _MediaInspection(
      noDamage: noDamage ?? this.noDamage,
      tags: tags ?? this.tags,
      note: note ?? this.note,
      elementType: elementType ?? this.elementType,
      audioRecordings: audioRecordings ?? this.audioRecordings,
      isDraft: isDraft ?? this.isDraft,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'noDamage': noDamage,
      'tags': tags,
      'note': note,
      'elementType': elementType,
      'audioRecordings': audioRecordings,
      'isDraft': isDraft,
    };
  }
}

class _UploadedItem {
  const _UploadedItem({
    required this.name,
    required this.mimeType,
    required this.dataUrl,
    this.inspection = const _MediaInspection(),
  });

  final String name;
  final String mimeType;
  final String dataUrl;
  final _MediaInspection inspection;

  _UploadedItem copyWith({
    String? name,
    String? mimeType,
    String? dataUrl,
    _MediaInspection? inspection,
  }) {
    return _UploadedItem(
      name: name ?? this.name,
      mimeType: mimeType ?? this.mimeType,
      dataUrl: dataUrl ?? this.dataUrl,
      inspection: inspection ?? this.inspection,
    );
  }

  bool get isImage => mimeType.startsWith('image/');
  bool get isVideo => mimeType.startsWith('video/');
  bool get isAudio => mimeType.startsWith('audio/');
}

class _CalculatedSummary {
  const _CalculatedSummary({
    required this.score,
    required this.verdict,
    required this.verdictLabel,
    required this.sections,
    required this.checklist,
    required this.fullInspection,
  });

  final int score;
  final String verdict;
  final String verdictLabel;
  final List<Map<String, dynamic>> sections;
  final List<String> checklist;
  final bool fullInspection;
}
