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
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/vin_ocr_types.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:video_player/video_player.dart';

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
  static const Map<String, String> _summaryTitleToStepId = {
    'Автомобиль': 'vehicle',
    'Параметры': 'params',
    'Сверка документов': 'docs_check',
    'Юр. проверка': 'legal',
    'Кузов': 'media',
    'Остекление': 'media',
    'Силовые элементы кузова': 'media',
    'Светотехника': 'media',
    'Подкапотное пространство': 'media',
    'Салон': 'media',
    'Колёса и шины': 'media',
    'Колёса и тормозные механизмы': 'media',
    'Компьютерная диагностика': 'media',
    'Диагностика': 'media',
    'Тест-драйв': 'test_drive',
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
      description:
          'VIN, госномер, марка/модель, пробег, владельцы и город осмотра',
    ),
    _StepConfig(
      id: 'params',
      title: 'Параметры',
      description: 'Двигатель, КПП, привод, цвет, комплектация',
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
  Map<String, List<String>> _mediaCustomSeriousTagsByScope = {};
  Map<String, List<String>> _mediaDisabledDefaultTagsByScope = {};
  Map<String, List<String>> _mediaTagOrderByScope = {};
  final Map<String, Uint8List> _dataUrlImageBytesCache = {};
  final Map<String, String> _resolvedAudioPlaybackSources = {};
  String? _appDocumentsPath;
  bool _microphonePermissionGranted = false;
  bool _speechPermissionGranted = false;

  int _stepIndex = 0;
  bool _editingSection = false;

  final ScrollController _pageScrollController = ScrollController();

  bool? _mileageMismatch;
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

  String? _activeMediaGroupKey;
  bool _mediaGroupSelectMode = false;
  Set<int> _mediaGroupSelectedIndexes = <int>{};
  int _uploadedItemIdCounter = 0;
  int _localMediaFileCounter = 0;

  String _nextUploadedItemId({String prefix = 'upload'}) {
    _uploadedItemIdCounter += 1;
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_$_uploadedItemIdCounter';
  }

  @override
  void initState() {
    super.initState();
    unawaited(_prepareStoragePaths());
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

    _mileageMismatch = _readTriState(draft['mileageMismatch']);
    if (_mileageMismatch == null &&
        draft.containsKey('mileageMatchesClaimed')) {
      final legacyMatchesClaimed = _readTriState(
        draft['mileageMatchesClaimed'],
      );
      if (legacyMatchesClaimed != null) {
        _mileageMismatch = !legacyMatchesClaimed;
      }
    }
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
    _mediaCustomSeriousTagsByScope = _readStringListMap(
      draft['mediaCustomSeriousTags'],
    );
    _mediaDisabledDefaultTagsByScope = _readStringListMap(
      draft['mediaDisabledDefaultTags'],
    );
    _mediaTagOrderByScope = _readStringListMap(draft['mediaTagOrder']);
    unawaited(_compactInlineDraftMediaIfNeeded());

    if (_stepIndex == _steps.length - 1) {
      _ensureSummaryAutofill();
    }
  }

  @override
  void dispose() {
    _pageScrollController.dispose();
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
      _MediaPartInspection partInspection = const _MediaPartInspection();

      if (raw is Map && raw[config.key] is Map) {
        final group = Map<String, dynamic>.from(raw[config.key] as Map);
        note = _read(group, 'note');
        rawUrls = _read(group, 'rawUrls');
        hasIssue = _readBool(group, 'hasIssue');
        files = _readUploadedList(group['files']);
        partInspection = _readMediaPartInspection(group['partInspection']);
        if (!hasIssue && files.any(_mediaItemHasIssue)) {
          hasIssue = true;
        }
      }

      if (_mediaPartInspectionIsEmpty(partInspection)) {
        partInspection = _deriveGroupPartInspection(
          files: files,
          fallbackNote: note,
        );
      }

      byKey[config.key] = _MediaGroupState(
        config: config,
        hasIssue: hasIssue,
        note: note,
        rawUrls: rawUrls,
        files: files,
        partInspection: partInspection,
      );
    }

    return byKey;
  }

  Future<void> _compactInlineDraftMediaIfNeeded() async {
    if (kIsWeb) return;

    var changed = false;

    Future<String> compactSource(
      String source, {
      String? mimeType,
      required String prefix,
    }) async {
      final normalized = source.trim();
      if (!_isDataUrl(normalized)) return normalized;
      final persisted = await _persistDataUrlToAppStorage(
        normalized,
        mimeType: mimeType,
        prefix: prefix,
      );
      if (persisted == null || persisted.isEmpty) return normalized;
      if (persisted != normalized) {
        changed = true;
        _dataUrlImageBytesCache.remove(normalized);
      }
      return persisted;
    }

    Future<List<String>> compactAudioRecordings(
      List<String> values, {
      String prefix = 'audio',
    }) async {
      if (values.isEmpty) return values;
      final next = <String>[];
      for (final item in values) {
        final converted = await compactSource(
          item,
          mimeType: 'audio/wav',
          prefix: prefix,
        );
        next.add(converted);
      }
      return next;
    }

    final nextLegalFiles = <_UploadedItem>[];
    for (final file in _legalFiles) {
      final nextSource = await compactSource(
        file.dataUrl,
        mimeType: file.mimeType,
        prefix: 'legal',
      );
      final nextAudio = await compactAudioRecordings(
        file.inspection.audioRecordings,
      );
      final inspectionChanged = !listEquals(
        nextAudio,
        file.inspection.audioRecordings,
      );
      final nextInspection = inspectionChanged
          ? file.inspection.copyWith(audioRecordings: nextAudio)
          : file.inspection;
      nextLegalFiles.add(
        file.copyWith(dataUrl: nextSource, inspection: nextInspection),
      );
    }

    final nextExpertAudioFiles = <_UploadedItem>[];
    for (final file in _expertAudioFiles) {
      final nextSource = await compactSource(
        file.dataUrl,
        mimeType: file.mimeType,
        prefix: 'expert_audio',
      );
      nextExpertAudioFiles.add(file.copyWith(dataUrl: nextSource));
    }

    final nextMediaState = <String, _MediaGroupState>{};
    for (final entry in _mediaState.entries) {
      final groupKey = entry.key;
      final state = entry.value;
      final sourceRemap = <String, String>{};
      final nextFiles = <_UploadedItem>[];

      for (final file in state.files) {
        final nextSource = await compactSource(
          file.dataUrl,
          mimeType: file.mimeType,
          prefix: groupKey,
        );
        if (nextSource != file.dataUrl) {
          sourceRemap[file.dataUrl] = nextSource;
        }
        final nextAudio = await compactAudioRecordings(
          file.inspection.audioRecordings,
        );
        final nextInspection =
            !listEquals(nextAudio, file.inspection.audioRecordings)
            ? file.inspection.copyWith(audioRecordings: nextAudio)
            : file.inspection;
        nextFiles.add(
          file.copyWith(dataUrl: nextSource, inspection: nextInspection),
        );
      }

      final nextRawUrls = <String>[];
      for (final raw in _parseUrls(state.rawUrls)) {
        final remapped = sourceRemap[raw];
        if (remapped != null) {
          nextRawUrls.add(remapped);
          continue;
        }
        final compacted = await compactSource(
          raw,
          mimeType: _guessMimeType(raw),
          prefix: groupKey,
        );
        nextRawUrls.add(compacted);
      }

      final partAudio = await compactAudioRecordings(
        state.partInspection.audioRecordings,
      );
      final nextTagPhotos = <String, List<String>>{};
      for (final tagEntry in state.partInspection.tagPhotos.entries) {
        final urls = <String>[];
        for (final source in tagEntry.value) {
          final remapped = sourceRemap[source] ?? source;
          urls.add(remapped);
        }
        nextTagPhotos[tagEntry.key] = urls;
      }
      final nextPartInspection = state.partInspection.copyWith(
        audioRecordings: partAudio,
        tagPhotos: nextTagPhotos,
      );

      nextMediaState[groupKey] = state.copyWith(
        files: nextFiles,
        rawUrls: nextRawUrls.join('\n'),
        hasIssue: nextFiles.any(_mediaItemHasIssue),
        partInspection: nextPartInspection,
      );
    }

    if (!changed || !mounted) return;

    setState(() {
      _legalFiles = nextLegalFiles;
      _expertAudioFiles = nextExpertAudioFiles;
      _mediaState = nextMediaState;
    });
    await _saveDraft(showToast: false);
  }

  bool _isDataUrl(String source) {
    return source.trimLeft().startsWith('data:');
  }

  Future<void> _prepareStoragePaths() async {
    if (kIsWeb) return;
    try {
      final directory = await getApplicationDocumentsDirectory();
      _appDocumentsPath = directory.path;
    } catch (_) {}
  }

  String _normalizeDocumentsLocalPath(String path) {
    final normalized = path.trim();
    if (normalized.isEmpty || kIsWeb) return normalized;
    final docsPath = _appDocumentsPath;
    if (docsPath == null || docsPath.isEmpty) return normalized;
    const marker = '/Documents/';
    final markerIndex = normalized.indexOf(marker);
    if (markerIndex < 0) return normalized;
    final relative = normalized.substring(markerIndex + marker.length).trim();
    if (relative.isEmpty) return normalized;
    return '$docsPath/$relative';
  }

  String? _extractLocalMediaPath(String source) {
    final normalized = source.trim();
    if (normalized.isEmpty || _isDataUrl(normalized)) return null;
    final parsed = Uri.tryParse(normalized);
    if (parsed == null) return _normalizeDocumentsLocalPath(normalized);
    if (!parsed.hasScheme) return _normalizeDocumentsLocalPath(normalized);
    if (parsed.scheme == 'file') {
      try {
        return _normalizeDocumentsLocalPath(parsed.toFilePath());
      } catch (_) {
        final plain = normalized
            .replaceFirst(RegExp(r'^file://'), '')
            .replaceFirst(RegExp(r'^file:'), '');
        return _normalizeDocumentsLocalPath(plain);
      }
    }
    return null;
  }

  Uri _mediaSourceUri(String source) {
    final localPath = _extractLocalMediaPath(source);
    if (localPath != null) {
      return Uri.file(localPath);
    }
    return Uri.parse(source);
  }

  Source _audioPlayerSource(String source) {
    final localPath = _extractLocalMediaPath(source);
    if (!kIsWeb && localPath != null) {
      return DeviceFileSource(localPath);
    }
    return UrlSource(source);
  }

  Future<Source> _audioPlayerSourceForPlayback(String source) async {
    final normalized = source.trim();
    if (normalized.isEmpty) {
      return UrlSource(source);
    }

    if (_resolvedAudioPlaybackSources.containsKey(normalized)) {
      final resolved = _resolvedAudioPlaybackSources[normalized]!;
      return _audioPlayerSource(resolved);
    }

    if (_isDataUrl(normalized) && !kIsWeb) {
      final persisted = await _persistDataUrlToAppStorage(
        normalized,
        mimeType: _dataUrlMimeType(normalized),
        prefix: 'audio_play',
      );
      if ((persisted ?? '').isNotEmpty) {
        _resolvedAudioPlaybackSources[normalized] = persisted!;
        return _audioPlayerSource(persisted);
      }
    }

    return _audioPlayerSource(normalized);
  }

  Future<void> _playAudioSource(AudioPlayer player, String source) async {
    final preparedSource = await _audioPlayerSourceForPlayback(source);
    await player.play(preparedSource);
  }

  String _extensionForMimeType(String mimeType) {
    final normalized = mimeType.toLowerCase();
    if (normalized.contains('image/png')) return 'png';
    if (normalized.contains('image/jpeg')) return 'jpg';
    if (normalized.contains('image/webp')) return 'webp';
    if (normalized.contains('image/heic')) return 'heic';
    if (normalized.contains('image/heif')) return 'heif';
    if (normalized.contains('video/mp4')) return 'mp4';
    if (normalized.contains('video/quicktime')) return 'mov';
    if (normalized.contains('video/webm')) return 'webm';
    if (normalized.contains('audio/wav')) return 'wav';
    if (normalized.contains('audio/mpeg')) return 'mp3';
    if (normalized.contains('audio/mp4')) return 'm4a';
    if (normalized.contains('audio/aac')) return 'aac';
    if (normalized.contains('audio/ogg')) return 'ogg';
    return 'bin';
  }

  Future<String?> _persistBytesToAppStorage({
    required Uint8List bytes,
    required String mimeType,
    required String prefix,
  }) async {
    if (kIsWeb || bytes.isEmpty) return null;
    try {
      final directory = await getApplicationDocumentsDirectory();
      _appDocumentsPath = directory.path;
      _localMediaFileCounter += 1;
      final extension = _extensionForMimeType(mimeType);
      final fileName =
          'spark_${prefix}_${DateTime.now().microsecondsSinceEpoch}_$_localMediaFileCounter.$extension';
      final filePath = '${directory.path}/$fileName';
      final xFile = XFile.fromData(bytes, name: fileName, mimeType: mimeType);
      await xFile.saveTo(filePath);
      return Uri.file(filePath).toString();
    } catch (_) {
      return null;
    }
  }

  String _dataUrlMimeType(String dataUrl) {
    final commaIndex = dataUrl.indexOf(',');
    if (commaIndex <= 0) return 'application/octet-stream';
    final header = dataUrl.substring(0, commaIndex);
    final semicolonIndex = header.indexOf(';');
    final mimeStart = header.startsWith('data:') ? 5 : 0;
    if (semicolonIndex > mimeStart) {
      return header.substring(mimeStart, semicolonIndex);
    }
    final value = header.substring(mimeStart).trim();
    return value.isEmpty ? 'application/octet-stream' : value;
  }

  Future<String?> _persistDataUrlToAppStorage(
    String dataUrl, {
    String? mimeType,
    required String prefix,
  }) async {
    if (kIsWeb || !_isDataUrl(dataUrl)) return null;
    final commaIndex = dataUrl.indexOf(',');
    if (commaIndex <= 0 || commaIndex >= dataUrl.length - 1) return null;
    final header = dataUrl.substring(0, commaIndex).toLowerCase();
    if (!header.contains(';base64')) return null;
    try {
      final bytes = base64Decode(dataUrl.substring(commaIndex + 1));
      if (bytes.isEmpty) return null;
      final effectiveMimeType = (mimeType ?? '').trim().isEmpty
          ? _dataUrlMimeType(dataUrl)
          : mimeType!.trim();
      return _persistBytesToAppStorage(
        bytes: bytes,
        mimeType: effectiveMimeType,
        prefix: prefix,
      );
    } catch (_) {
      return null;
    }
  }

  Future<String?> _persistXFileToAppStorage(
    XFile file, {
    required String fileName,
    required String mimeType,
    required String prefix,
  }) async {
    if (kIsWeb) return null;
    try {
      final directory = await getApplicationDocumentsDirectory();
      _appDocumentsPath = directory.path;
      _localMediaFileCounter += 1;
      final extension = _extensionForMimeType(mimeType);
      final targetName =
          'spark_${prefix}_${DateTime.now().microsecondsSinceEpoch}_$_localMediaFileCounter.$extension';
      final targetPath = '${directory.path}/$targetName';
      await file.saveTo(targetPath);
      return Uri.file(targetPath).toString();
    } catch (_) {
      try {
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) return null;
        return _persistBytesToAppStorage(
          bytes: bytes,
          mimeType: mimeType,
          prefix: prefix,
        );
      } catch (_) {
        return null;
      }
    }
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

  double? _readNullableDouble(Map<String, dynamic> map, String key) {
    if (!map.containsKey(key)) return null;
    final value = map[key];
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
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
    for (var index = 0; index < value.length; index++) {
      final entry = value[index];
      if (entry is! Map) continue;
      final map = Map<String, dynamic>.from(entry);
      final name = _read(map, 'name');
      final dataUrl = _read(map, 'dataUrl');
      if (name.isEmpty || dataUrl.isEmpty) continue;
      final id = _read(map, 'id').trim().isNotEmpty
          ? _read(map, 'id').trim()
          : 'legacy_${index}_${name.hashCode}_${dataUrl.hashCode}';
      items.add(
        _UploadedItem(
          id: id,
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
    double? paintFrom = _readNullableDouble(map, 'paintFrom');
    double? paintTo = _readNullableDouble(map, 'paintTo');
    final paint = map['paintThickness'];
    if (paint is Map) {
      final paintMap = Map<String, dynamic>.from(paint);
      paintFrom ??= _readNullableDouble(paintMap, 'from');
      paintTo ??= _readNullableDouble(paintMap, 'to');
    }
    return _MediaInspection(
      noDamage: _readBool(map, 'noDamage'),
      tags: _readStringList(map['tags']),
      note: _read(map, 'note'),
      elementType: _read(map, 'elementType'),
      audioRecordings: _readStringList(map['audioRecordings']),
      paintFrom: paintFrom,
      paintTo: paintTo,
      isDraft: _readBool(map, 'isDraft', fallback: true),
    );
  }

  _MediaPartInspection _readMediaPartInspection(dynamic value) {
    if (value is! Map) return const _MediaPartInspection();
    final map = Map<String, dynamic>.from(value);
    double? paintFrom = _readNullableDouble(map, 'paintFrom');
    double? paintTo = _readNullableDouble(map, 'paintTo');
    final paint = map['paintThickness'];
    if (paint is Map) {
      final paintMap = Map<String, dynamic>.from(paint);
      paintFrom ??= _readNullableDouble(paintMap, 'from');
      paintTo ??= _readNullableDouble(paintMap, 'to');
    }
    final rawTagPhotos = map['tagPhotos'];
    final tagPhotos = <String, List<String>>{};
    if (rawTagPhotos is Map) {
      for (final entry in rawTagPhotos.entries) {
        final key = entry.key.toString().trim();
        if (key.isEmpty) continue;
        final values = _readStringList(entry.value);
        if (values.isEmpty) continue;
        tagPhotos[key] = values;
      }
    }
    return _MediaPartInspection(
      noDamage: _readBool(map, 'noDamage'),
      tags: _readStringList(map['tags']),
      note: _read(map, 'note'),
      elementType: _read(map, 'elementType'),
      audioRecordings: _readStringList(map['audioRecordings']),
      paintFrom: paintFrom,
      paintTo: paintTo,
      tagPhotos: tagPhotos,
      isDraft: _readBool(map, 'isDraft', fallback: true),
    );
  }

  bool _mediaPartInspectionIsEmpty(_MediaPartInspection inspection) {
    return !inspection.noDamage &&
        inspection.tags.isEmpty &&
        inspection.note.trim().isEmpty &&
        inspection.audioRecordings.isEmpty &&
        (inspection.elementType ?? '').trim().isEmpty &&
        inspection.tagPhotos.isEmpty &&
        !(inspection.paintFrom != null && inspection.paintTo != null);
  }

  _MediaPartInspection _deriveGroupPartInspection({
    required List<_UploadedItem> files,
    String fallbackNote = '',
  }) {
    final normalizedTags = <String, String>{};
    final tagPhotos = <String, List<String>>{};
    final audio = <String>[];
    String? elementType;
    String note = fallbackNote.trim();
    bool anyNoDamage = false;
    bool hasSavedInspection = false;
    double? paintFrom;
    double? paintTo;

    for (final file in files) {
      final inspection = file.inspection;
      if (!inspection.isDraft) {
        hasSavedInspection = true;
      }
      if (inspection.noDamage) {
        anyNoDamage = true;
      }

      final normalizedElement = (inspection.elementType ?? '').trim();
      if (elementType == null && normalizedElement.isNotEmpty) {
        elementType = normalizedElement;
      }
      if (note.isEmpty && inspection.note.trim().isNotEmpty) {
        note = inspection.note.trim();
      }
      if (paintFrom == null &&
          paintTo == null &&
          inspection.paintFrom != null &&
          inspection.paintTo != null) {
        paintFrom = inspection.paintFrom;
        paintTo = inspection.paintTo;
      }

      for (final audioUrl in inspection.audioRecordings) {
        final normalized = audioUrl.trim();
        if (normalized.isEmpty) continue;
        if (!audio.contains(normalized)) {
          audio.add(normalized);
        }
      }

      for (final rawTag in inspection.tags) {
        final tag = rawTag.trim();
        if (tag.isEmpty) continue;
        final marker = tag.toLowerCase();
        final canonical = normalizedTags.putIfAbsent(marker, () => tag);
        final list = tagPhotos.putIfAbsent(canonical, () => <String>[]);
        if (!list.contains(file.dataUrl)) {
          list.add(file.dataUrl);
        }
      }
    }

    final tags = normalizedTags.values.toList();
    final noDamage = tags.isEmpty && anyNoDamage;

    return _MediaPartInspection(
      noDamage: noDamage,
      tags: tags,
      note: note,
      elementType: elementType,
      audioRecordings: audio,
      paintFrom: paintFrom,
      paintTo: paintTo,
      tagPhotos: tagPhotos,
      isDraft: !hasSavedInspection,
    );
  }

  _MediaPartInspection _syncPartInspectionWithFiles({
    required _MediaPartInspection partInspection,
    required List<_UploadedItem> files,
    String fallbackNote = '',
  }) {
    if (files.isEmpty) return const _MediaPartInspection();
    if (_mediaPartInspectionIsEmpty(partInspection)) {
      return _deriveGroupPartInspection(
        files: files,
        fallbackNote: fallbackNote,
      );
    }

    final existingUrls = files.map((file) => file.dataUrl).toSet();
    final canonicalByLower = <String, String>{};
    final tagPhotosByLower = <String, Set<String>>{};

    for (final rawTag in partInspection.tags) {
      final tag = rawTag.trim();
      if (tag.isEmpty) continue;
      canonicalByLower.putIfAbsent(tag.toLowerCase(), () => tag);
    }

    for (final entry in partInspection.tagPhotos.entries) {
      final tag = entry.key.trim();
      if (tag.isEmpty) continue;
      final lower = tag.toLowerCase();
      canonicalByLower.putIfAbsent(lower, () => tag);
      final urls = tagPhotosByLower.putIfAbsent(lower, () => <String>{});
      for (final rawUrl in entry.value) {
        final url = rawUrl.trim();
        if (url.isEmpty || !existingUrls.contains(url)) continue;
        urls.add(url);
      }
    }

    final tags = <String>[];
    for (final entry in canonicalByLower.entries) {
      tags.add(entry.value);
    }

    if (partInspection.noDamage) {
      return _MediaPartInspection(
        noDamage: true,
        tags: const [],
        note: partInspection.note.trim().isEmpty
            ? fallbackNote.trim()
            : partInspection.note.trim(),
        elementType: (partInspection.elementType ?? '').trim().isEmpty
            ? null
            : partInspection.elementType,
        audioRecordings: [...partInspection.audioRecordings],
        paintFrom: partInspection.paintFrom,
        paintTo: partInspection.paintTo,
        tagPhotos: const {},
        isDraft: partInspection.isDraft,
      );
    }

    final tagPhotos = <String, List<String>>{};
    for (final entry in canonicalByLower.entries) {
      final urls = tagPhotosByLower[entry.key] ?? <String>{};
      if (urls.isNotEmpty) {
        tagPhotos[entry.value] = urls.toList();
      }
    }

    return _MediaPartInspection(
      noDamage: false,
      tags: tags,
      note: partInspection.note.trim().isEmpty
          ? fallbackNote.trim()
          : partInspection.note.trim(),
      elementType: (partInspection.elementType ?? '').trim().isEmpty
          ? null
          : partInspection.elementType,
      audioRecordings: [...partInspection.audioRecordings],
      paintFrom: partInspection.paintFrom,
      paintTo: partInspection.paintTo,
      tagPhotos: tagPhotos,
      isDraft: partInspection.isDraft,
    );
  }

  List<_UploadedItem> _applyPartInspectionToFiles({
    required List<_UploadedItem> files,
    required _MediaPartInspection partInspection,
  }) {
    if (files.isEmpty) return const <_UploadedItem>[];
    final urlsByTagLower = <String, Set<String>>{};
    final canonicalTagByLower = <String, String>{};

    for (final rawTag in partInspection.tags) {
      final tag = rawTag.trim();
      if (tag.isEmpty) continue;
      canonicalTagByLower.putIfAbsent(tag.toLowerCase(), () => tag);
    }
    for (final entry in partInspection.tagPhotos.entries) {
      final tag = entry.key.trim();
      if (tag.isEmpty) continue;
      final lower = tag.toLowerCase();
      canonicalTagByLower.putIfAbsent(lower, () => tag);
      final urls = urlsByTagLower.putIfAbsent(lower, () => <String>{});
      for (final rawUrl in entry.value) {
        final url = rawUrl.trim();
        if (url.isEmpty) continue;
        urls.add(url);
      }
    }

    final orderedTagLowers = canonicalTagByLower.keys.toList();
    final normalizedElementType = (partInspection.elementType ?? '').trim();
    final normalizedAudio = partInspection.audioRecordings
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    final normalizedNote = partInspection.note.trim();

    return files.map((file) {
      final tagsForFile = <String>[];
      if (!partInspection.noDamage) {
        for (final lower in orderedTagLowers) {
          final urls = urlsByTagLower[lower] ?? <String>{};
          if (urls.contains(file.dataUrl)) {
            tagsForFile.add(canonicalTagByLower[lower]!);
          }
        }
      }
      final inspection = _MediaInspection(
        noDamage: partInspection.noDamage && tagsForFile.isEmpty,
        tags: tagsForFile,
        note: normalizedNote,
        elementType: normalizedElementType.isEmpty
            ? null
            : normalizedElementType,
        audioRecordings: normalizedAudio,
        paintFrom: partInspection.paintFrom,
        paintTo: partInspection.paintTo,
        isDraft: partInspection.isDraft,
      );
      return file.copyWith(inspection: inspection);
    }).toList();
  }

  List<Map<String, dynamic>> _uploadedToJson(List<_UploadedItem> items) {
    return items.map((e) {
      return {
        'id': e.id,
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

  Uint8List? _decodeDataUrlImageBytes(String dataUrl) {
    if (!_isDataUrl(dataUrl)) return null;
    final commaIndex = dataUrl.indexOf(',');
    if (commaIndex <= 0 || commaIndex >= dataUrl.length - 1) return null;
    final header = dataUrl.substring(0, commaIndex).toLowerCase();
    if (!header.contains('image/') || !header.contains(';base64')) return null;
    final cached = _dataUrlImageBytesCache[dataUrl];
    if (cached != null) return cached;
    final payload = dataUrl.substring(commaIndex + 1);
    try {
      final decoded = base64Decode(payload);
      _dataUrlImageBytesCache[dataUrl] = decoded;
      return decoded;
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _loadImageBytesFromSource(String source) async {
    final normalized = source.trim();
    if (normalized.isEmpty) return null;
    final cached = _dataUrlImageBytesCache[normalized];
    if (cached != null) return cached;

    final fromDataUrl = _decodeDataUrlImageBytes(normalized);
    if (fromDataUrl != null) return fromDataUrl;

    final localPath = _extractLocalMediaPath(normalized);
    if (localPath == null) return null;
    try {
      final bytes = await XFile(localPath).readAsBytes();
      if (bytes.isEmpty) return null;
      _dataUrlImageBytesCache[normalized] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  Widget _uploadedImageWidget(
    _UploadedItem item, {
    BoxFit fit = BoxFit.cover,
    Color errorColor = kGreyColor,
    double errorSize = 28,
    int? cacheWidth,
    int? cacheHeight,
    FilterQuality filterQuality = FilterQuality.low,
  }) {
    final source = item.dataUrl.trim();
    final bytes = _decodeDataUrlImageBytes(source);
    if (bytes != null) {
      return Image.memory(
        bytes,
        fit: fit,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        filterQuality: filterQuality,
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.broken_image_outlined,
          color: errorColor,
          size: errorSize,
        ),
      );
    }

    final localPath = _extractLocalMediaPath(source);
    if (localPath != null) {
      return FutureBuilder<Uint8List?>(
        future: _loadImageBytesFromSource(source),
        builder: (context, snapshot) {
          final localBytes = snapshot.data;
          if (localBytes == null) {
            if (snapshot.connectionState == ConnectionState.done) {
              return Icon(
                Icons.broken_image_outlined,
                color: errorColor,
                size: errorSize,
              );
            }
            return const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          return Image.memory(
            localBytes,
            fit: fit,
            cacheWidth: cacheWidth,
            cacheHeight: cacheHeight,
            filterQuality: filterQuality,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) => Icon(
              Icons.broken_image_outlined,
              color: errorColor,
              size: errorSize,
            ),
          );
        },
      );
    }

    return Image.network(
      source,
      fit: fit,
      errorBuilder: (context, error, stackTrace) =>
          Icon(Icons.broken_image_outlined, color: errorColor, size: errorSize),
    );
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
      withData: kIsWeb,
    );
    if (result == null || result.files.isEmpty) return const [];

    final items = <_UploadedItem>[];
    for (final file in result.files) {
      final fileName = file.name.trim().isEmpty ? 'picked_file' : file.name;
      final mimeType = _guessMimeType(fileName);
      String? storedSource;

      if (!kIsWeb && file.path != null && file.path!.trim().isNotEmpty) {
        storedSource = await _persistXFileToAppStorage(
          XFile(file.path!.trim()),
          fileName: fileName,
          mimeType: mimeType,
          prefix: 'picked',
        );
      }

      if ((storedSource ?? '').isEmpty) {
        final bytes = file.bytes;
        if (bytes == null || bytes.isEmpty) continue;
        if (!kIsWeb) {
          storedSource = await _persistBytesToAppStorage(
            bytes: bytes,
            mimeType: mimeType,
            prefix: 'picked',
          );
        }
        if ((storedSource ?? '').isEmpty) {
          final data = base64Encode(bytes);
          storedSource = 'data:$mimeType;base64,$data';
        }
      }

      items.add(
        _UploadedItem(
          id: _nextUploadedItemId(prefix: 'picked'),
          name: fileName,
          mimeType: mimeType,
          dataUrl: storedSource!,
        ),
      );
    }
    return items;
  }

  Future<List<_UploadedItem>> _uploadedItemsFromXFiles(
    List<XFile> files, {
    String prefix = 'picked',
  }) async {
    final items = <_UploadedItem>[];
    for (final file in files) {
      final fileName = file.name.trim().isEmpty ? 'media_file' : file.name;
      final mimeType = _guessMimeType(fileName);
      String? storedSource = await _persistXFileToAppStorage(
        file,
        fileName: fileName,
        mimeType: mimeType,
        prefix: prefix,
      );
      if ((storedSource ?? '').isEmpty) {
        final bytes = await file.readAsBytes();
        if (bytes.isEmpty) continue;
        if (!kIsWeb) {
          storedSource = await _persistBytesToAppStorage(
            bytes: bytes,
            mimeType: mimeType,
            prefix: prefix,
          );
        }
        if ((storedSource ?? '').isEmpty) {
          final data = base64Encode(bytes);
          storedSource = 'data:$mimeType;base64,$data';
        }
      }
      items.add(
        _UploadedItem(
          id: _nextUploadedItemId(prefix: prefix),
          name: fileName,
          mimeType: mimeType,
          dataUrl: storedSource!,
        ),
      );
    }
    return items;
  }

  Future<List<_UploadedItem>> _pickMediaFromDeviceGallery() async {
    final picker = ImagePicker();
    try {
      final picked = await picker.pickMultipleMedia();
      if (picked.isNotEmpty) {
        return _uploadedItemsFromXFiles(picked, prefix: 'media');
      }
    } catch (_) {}

    try {
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        return _uploadedItemsFromXFiles([image], prefix: 'media');
      }
    } catch (_) {}

    return const [];
  }

  Future<int> _pickMediaFiles(String groupKey) async {
    final nativeGalleryPlatform =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android);

    final items = nativeGalleryPlatform
        ? await _pickMediaFromDeviceGallery()
        : await _pickFiles(
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
    if (items.isEmpty || !mounted) return 0;
    setState(() {
      final state = _mediaState[groupKey];
      if (state == null) return;
      final nextPartInspection = _syncPartInspectionWithFiles(
        partInspection: state.partInspection,
        files: [...state.files, ...items],
        fallbackNote: state.note,
      );
      final nextFiles = _applyPartInspectionToFiles(
        files: [...state.files, ...items],
        partInspection: nextPartInspection,
      );
      _mediaState[groupKey] = state.copyWith(
        files: nextFiles,
        partInspection: nextPartInspection,
      );
    });
    return items.length;
  }

  Future<void> _pickLegalFiles() async {
    final items = await _pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf', 'doc', 'docx'],
    );
    if (items.isEmpty || !mounted) return;
    setState(() {
      _legalFiles = [..._legalFiles, ...items];
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

  String _normalizeVinOcrText(String value) {
    return value
        .toUpperCase()
        .replaceAll('А', 'A')
        .replaceAll('В', 'B')
        .replaceAll('С', 'C')
        .replaceAll('Е', 'E')
        .replaceAll('Н', 'H')
        .replaceAll('К', 'K')
        .replaceAll('М', 'M')
        .replaceAll('Р', 'P')
        .replaceAll('Т', 'T')
        .replaceAll('У', 'Y')
        .replaceAll('Х', 'X')
        .replaceAll('З', '3')
        .replaceAll('Б', '6')
        .replaceAll('І', '1')
        .replaceAll('|', '1')
        .replaceAll('I', '1')
        .replaceAll('L', '1')
        .replaceAll('O', '0')
        .replaceAll('Q', '0');
  }

  String _extractStrictVinFromText(String text) {
    final cleaned = _normalizeVinOcrText(
      text,
    ).replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (cleaned.length < 17) return '';
    for (var i = 0; i <= cleaned.length - 17; i++) {
      final candidate = cleaned.substring(i, i + 17);
      if (_isStrictVin(candidate)) return candidate;
    }
    return '';
  }

  String _extractVinFromOcrResult(VinOcrResult result) {
    final direct = _extractStrictVinFromText(result.vin);
    if (direct.isNotEmpty) return direct;
    return _extractStrictVinFromText(result.rawText);
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
    Map<String, List<String>>? customSeriousTagsByScope,
    Map<String, List<String>>? disabledDefaultTagsByScope,
    Map<String, List<String>>? tagOrderByScope,
    bool includeDisabledDefaults = false,
  }) {
    List<_MediaTagOption> applyOrderingAndVisibility(
      List<_MediaTagOption> source, {
      required String scopeKey,
      required Set<String> disabledDefaults,
    }) {
      final resolvedOrder = tagOrderByScope ?? _mediaTagOrderByScope;
      final order = (resolvedOrder[scopeKey] ?? const <String>[])
          .map((tag) => tag.toLowerCase())
          .toList();

      var result = source;
      if (order.isNotEmpty) {
        final indexed = <String, _MediaTagOption>{};
        for (final option in source) {
          indexed[option.label.toLowerCase()] = option;
        }
        final sorted = <_MediaTagOption>[];
        for (final key in order) {
          final option = indexed.remove(key);
          if (option != null) sorted.add(option);
        }
        for (final option in source) {
          final key = option.label.toLowerCase();
          if (indexed.containsKey(key)) {
            sorted.add(option);
            indexed.remove(key);
          }
        }
        result = sorted;
      }

      if (!includeDisabledDefaults && disabledDefaults.isNotEmpty) {
        result = result
            .where(
              (option) =>
                  option.isCustom ||
                  !disabledDefaults.contains(option.label.toLowerCase()),
            )
            .toList();
      }
      return result;
    }

    if (groupKey == 'diagnostics' &&
        elementType != null &&
        _diagnosticTagOptionsByElement.containsKey(elementType)) {
      final options = _diagnosticTagOptionsByElement[elementType]!;
      final serious =
          _diagnosticSeriousTagsByElement[elementType] ?? const <String>{};
      final resolvedCustom = customTagsByScope ?? _mediaCustomTagsByScope;
      final resolvedCustomSerious =
          customSeriousTagsByScope ?? _mediaCustomSeriousTagsByScope;
      final resolvedDisabled =
          disabledDefaultTagsByScope ?? _mediaDisabledDefaultTagsByScope;
      final scopeKey = _mediaTagScopeKey(groupKey, elementType: elementType);
      final custom = resolvedCustom[scopeKey] ?? const <String>[];
      final customSerious =
          (resolvedCustomSerious[scopeKey] ?? const <String>[])
              .map((tag) => tag.toLowerCase())
              .toSet();
      final disabledDefaults = (resolvedDisabled[scopeKey] ?? const <String>[])
          .map((tag) => tag.toLowerCase())
          .toSet();
      final dedup = options.toSet();
      var result = options
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
          _MediaTagOption(
            label: label,
            severity: customSerious.contains(label.toLowerCase())
                ? 'serious'
                : 'minor',
            isCustom: true,
          ),
        );
      }
      return applyOrderingAndVisibility(
        result,
        scopeKey: scopeKey,
        disabledDefaults: disabledDefaults,
      );
    }

    final sourceGroup = _mediaTagSourceGroup(
      groupKey,
      elementType: elementType,
    );
    final options = _mediaTagOptionsByGroup[sourceGroup] ?? const <String>[];
    final serious = _mediaSeriousTagsByGroup[sourceGroup] ?? const <String>{};
    final resolvedCustom = customTagsByScope ?? _mediaCustomTagsByScope;
    final resolvedCustomSerious =
        customSeriousTagsByScope ?? _mediaCustomSeriousTagsByScope;
    final resolvedDisabled =
        disabledDefaultTagsByScope ?? _mediaDisabledDefaultTagsByScope;
    final scopeKey = _mediaTagScopeKey(groupKey, elementType: elementType);
    final custom = resolvedCustom[scopeKey] ?? const <String>[];
    final customSerious = (resolvedCustomSerious[scopeKey] ?? const <String>[])
        .map((tag) => tag.toLowerCase())
        .toSet();
    final disabledDefaults = (resolvedDisabled[scopeKey] ?? const <String>[])
        .map((tag) => tag.toLowerCase())
        .toSet();
    final dedup = options.toSet();
    var result = options
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
        _MediaTagOption(
          label: label,
          severity: customSerious.contains(label.toLowerCase())
              ? 'serious'
              : 'minor',
          isCustom: true,
        ),
      );
    }
    return applyOrderingAndVisibility(
      result,
      scopeKey: scopeKey,
      disabledDefaults: disabledDefaults,
    );
  }

  List<_MediaTagGroup> _mediaTagGroups(
    String groupKey, {
    String? elementType,
    Map<String, List<String>>? customTagsByScope,
    Map<String, List<String>>? customSeriousTagsByScope,
    Map<String, List<String>>? disabledDefaultTagsByScope,
    Map<String, List<String>>? tagOrderByScope,
    bool includeDisabledDefaults = false,
  }) {
    final options = _mediaTagOptions(
      groupKey,
      elementType: elementType,
      customTagsByScope: customTagsByScope,
      customSeriousTagsByScope: customSeriousTagsByScope,
      disabledDefaultTagsByScope: disabledDefaultTagsByScope,
      tagOrderByScope: tagOrderByScope,
      includeDisabledDefaults: includeDisabledDefaults,
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
    for (final option in _mediaTagOptions(
      groupKey,
      elementType: elementType,
      includeDisabledDefaults: true,
    )) {
      if (option.label == tag) return option.severity;
    }
    return 'minor';
  }

  Color _mediaTagColor(String severity) {
    if (severity == 'serious') return kRedColor;
    return kYellowColor;
  }

  Color _mediaTagGroupTitleColor(_MediaTagGroup group) {
    final hasSerious = group.options.any(
      (option) => option.severity == 'serious',
    );
    final hasMinor = group.options.any(
      (option) => option.severity != 'serious',
    );
    if (hasSerious && !hasMinor) return kRedColor;
    if (hasMinor && !hasSerious) return kYellowColor;
    return kGreyColor;
  }

  String _mediaNoDamageLabel(String groupKey) {
    if (groupKey == 'diagnostics') return 'Без ошибок';
    return 'Без повреждений';
  }

  bool _mediaSupportsPaintThickness(String groupKey) {
    return groupKey == 'body' || groupKey == 'structural';
  }

  bool _mediaInspectionHasData(_MediaInspection inspection) {
    return inspection.noDamage ||
        inspection.tags.isNotEmpty ||
        inspection.note.trim().isNotEmpty ||
        inspection.audioRecordings.isNotEmpty ||
        (inspection.paintFrom != null && inspection.paintTo != null) ||
        (inspection.elementType ?? '').trim().isNotEmpty;
  }

  bool _mediaPartInspectionHasData(_MediaPartInspection inspection) {
    return inspection.noDamage ||
        inspection.tags.isNotEmpty ||
        inspection.note.trim().isNotEmpty ||
        inspection.audioRecordings.isNotEmpty ||
        inspection.tagPhotos.isNotEmpty ||
        (inspection.paintFrom != null && inspection.paintTo != null) ||
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
    final partInspection = state.partInspection;
    if (!partInspection.isDraft &&
        !partInspection.noDamage &&
        partInspection.tags.isNotEmpty) {
      return true;
    }
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

    final mileage = _mileageController.text.trim();
    if (mileage.isEmpty) {
      penalty += 5;
      checklist.add('Не указан пробег автомобиля.');
    }
    if (_mileageMismatch == true) {
      penalty += 5;
      checklist.add('Пробег вызывает сомнения по состоянию автомобиля.');
    }

    sections.add({
      'title': 'Автомобиль',
      'status': hasVinData && mileage.isNotEmpty ? 'ok' : 'warn',
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
        {
          'label': 'Пробег',
          'value': mileage.isEmpty ? 'Не указан' : '$mileage км',
          'severity': mileage.isEmpty ? 'minor' : 'ok',
        },
        {
          'label': 'Пробег по состоянию',
          'value': _mileageMismatch == null
              ? 'Не указано'
              : (_mileageMismatch == true
                    ? 'Не соответствует'
                    : 'Соответствует'),
          'severity': _mileageMismatch == null
              ? 'info'
              : (_mileageMismatch == true ? 'minor' : 'ok'),
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
        if (plate.isNotEmpty)
          {'label': 'Госномер', 'value': plate, 'severity': 'ok'},
        if (adLink.isNotEmpty)
          {'label': 'Объявление', 'value': adLink, 'severity': 'ok'},
      ],
    });

    final hasParamsDetails =
        _engineVolumeController.text.trim().isNotEmpty ||
        _engineTypeController.text.trim().isNotEmpty ||
        _gearboxTypeController.text.trim().isNotEmpty ||
        _driveTypeController.text.trim().isNotEmpty ||
        _colorController.text.trim().isNotEmpty ||
        _trimController.text.trim().isNotEmpty;

    sections.add({
      'title': 'Параметры',
      'status': hasParamsDetails ? 'ok' : 'info',
      'required': false,
      'details': [
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
        'partInspection': entry.value.partInspection.toJson(),
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
    final customSeriousTagsPayload = <String, List<String>>{};
    for (final entry in _mediaCustomSeriousTagsByScope.entries) {
      final tags = entry.value
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();
      if (tags.isEmpty) continue;
      customSeriousTagsPayload[entry.key] = tags;
    }
    final disabledDefaultsPayload = <String, List<String>>{};
    for (final entry in _mediaDisabledDefaultTagsByScope.entries) {
      final tags = entry.value
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();
      if (tags.isEmpty) continue;
      disabledDefaultsPayload[entry.key] = tags;
    }
    final tagOrderPayload = <String, List<String>>{};
    for (final entry in _mediaTagOrderByScope.entries) {
      final tags = entry.value
          .map((tag) => tag.trim())
          .where((tag) => tag.isNotEmpty)
          .toList();
      if (tags.isEmpty) continue;
      tagOrderPayload[entry.key] = tags;
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
      'mediaCustomSeriousTags': customSeriousTagsPayload,
      'mediaDisabledDefaultTags': disabledDefaultsPayload,
      'mediaTagOrder': tagOrderPayload,
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
    final supportsLiveCameraPreview = !kIsWeb;
    var dialogActive = true;

    void safeSetLocalState(StateSetter setLocalState, VoidCallback fn) {
      if (!mounted || !dialogActive) return;
      setLocalState(fn);
    }

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
      safeSetLocalState(setLocalState, () {
        processing = true;
        cameraLive = false;
        previewBytes = bytes;
        error = null;
        rawText = '';
      });

      final firstResult = await scanVinFromImageBytes(bytes);
      var finalVin = _extractVinFromOcrResult(firstResult);
      var finalRaw = firstResult.rawText;
      var finalError = firstResult.error;

      if (finalVin.isEmpty && fallbackBytes != null) {
        final secondResult = await scanVinFromImageBytes(fallbackBytes);
        final secondVin = _extractVinFromOcrResult(secondResult);
        final secondVinValid = secondVin.isNotEmpty;
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

      safeSetLocalState(setLocalState, () {
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

    Future<void> pickAndRecognize(
      ImageSource source,
      StateSetter setLocalState,
    ) async {
      await stopLiveCamera();
      safeSetLocalState(setLocalState, () {
        selectedSource = source == ImageSource.gallery ? 'gallery' : 'camera';
        cameraLive = false;
        cameraInitialized = false;
        cameraLoading = false;
        cameraError = '';
      });

      Uint8List? bytes;
      if (kIsWeb) {
        bytes = await pickVinImageBytes(
          preferCamera: source == ImageSource.camera,
        );
        if (bytes == null) {
          safeSetLocalState(setLocalState, () {
            error = source == ImageSource.camera
                ? 'Не удалось открыть камеру. Проверьте разрешение камеры в браузере и попробуйте снова.'
                : 'Не удалось открыть галерею.';
          });
          return;
        }
      } else {
        XFile? file;
        try {
          file = await picker.pickImage(source: source, imageQuality: 95);
        } catch (_) {
          safeSetLocalState(setLocalState, () {
            error = source == ImageSource.camera
                ? 'Не удалось открыть системную камеру. Проверьте разрешение камеры.'
                : 'Не удалось открыть галерею.';
          });
          return;
        }
        if (file == null) return;
        bytes = await file.readAsBytes();
      }
      await recognizeBytes(bytes, setLocalState, null);
    }

    String mapLiveCameraError(Object error) {
      if (error is TimeoutException) {
        return 'Камера не ответила вовремя. Нажмите «Системная камера» или попробуйте снова.';
      }
      if (error is CameraException) {
        if (error.code == 'CameraAccessDenied' ||
            error.code == 'CameraAccessDeniedWithoutPrompt') {
          return 'Нет доступа к камере. Разрешите камеру в браузере и попробуйте снова.';
        }
        if (error.code == 'CameraAccessRestricted') {
          return 'Доступ к камере ограничен системой. Используйте фото.';
        }
      }
      return 'Не удалось открыть камеру. Используйте фото.';
    }

    Future<void> startLiveCamera(StateSetter setLocalState) async {
      if (cameraStarting) return;
      cameraStarting = true;
      const startupTimeout = Duration(seconds: 10);

      safeSetLocalState(setLocalState, () {
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
        final cameras = kIsWeb
            ? await availableCameras()
            : await availableCameras().timeout(startupTimeout);
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
        if (kIsWeb) {
          await nextController.initialize();
        } else {
          await nextController.initialize().timeout(startupTimeout);
        }

        liveCameraController = nextController;
        safeSetLocalState(setLocalState, () {
          cameraInitialized = true;
          cameraLive = true;
          cameraLoading = false;
        });
      } catch (e, st) {
        debugPrint('VIN live camera error: $e');
        debugPrint(st.toString());
        await stopLiveCamera();
        final errorMessage = mapLiveCameraError(e);
        safeSetLocalState(setLocalState, () {
          cameraLive = false;
          cameraInitialized = false;
          cameraLoading = false;
          cameraError = errorMessage;
        });
        if (e is TimeoutException) {
          await pickAndRecognize(ImageSource.camera, setLocalState);
        }
      } finally {
        cameraStarting = false;
      }
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
          safeSetLocalState(setLocalState, () {
            error =
                'Не удалось снять VIN через live-камеру. Попробуйте системную камеру или галерею.';
          });
        }
      }
    }

    final resultVin =
        await showDialog<String>(
          context: context,
          useSafeArea: false,
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
                  insetPadding: EdgeInsets.zero,
                  clipBehavior: Clip.antiAlias,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                  titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                  contentPadding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  title: const Text('Сканирование VIN'),
                  content: SizedBox(
                    width: MediaQuery.of(context).size.width,
                    height: MediaQuery.of(context).size.height - 140,
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
                                      : () {
                                          if (supportsLiveCameraPreview) {
                                            startLiveCamera(setLocalState);
                                          } else {
                                            pickAndRecognize(
                                              ImageSource.camera,
                                              setLocalState,
                                            );
                                          }
                                        },
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
                                  icon: const Icon(
                                    Icons.photo_library_outlined,
                                  ),
                                  label: const Text('Из галереи'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (isCameraMode &&
                              supportsLiveCameraPreview &&
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
                                        liveCameraController!
                                            .value
                                            .isInitialized)
                                      CameraPreview(liveCameraController!),
                                    IgnorePointer(
                                      child: Column(
                                        children: [
                                          Expanded(
                                            flex: 39,
                                            child: Container(
                                              color: Colors.black54,
                                            ),
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
                                            child: Container(
                                              color: Colors.black54,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (cameraLoading)
                                      const Center(
                                        child: CircularProgressIndicator(),
                                      ),
                                    if (cameraError.isNotEmpty &&
                                        !cameraLoading)
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
                              supportsLiveCameraPreview &&
                              cameraError.isNotEmpty &&
                              !processing) ...[
                            MyText(
                              text: cameraError,
                              size: 11,
                              color: kRedColor,
                            ),
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
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
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
                              text:
                                  'OCR недоступен. Можно вставить VIN вручную.',
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
                                if (isCameraMode && supportsLiveCameraPreview) {
                                  startLiveCamera(setLocalState);
                                } else {
                                  pickAndRecognize(
                                    isCameraMode
                                        ? ImageSource.camera
                                        : ImageSource.gallery,
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
        ).whenComplete(() {
          dialogActive = false;
        });

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

  void _scrollEditorToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_pageScrollController.hasClients) return;
      _pageScrollController.jumpTo(0);
    });
  }

  void _dismissKeyboard() {
    final focus = FocusManager.instance.primaryFocus;
    if (focus != null && focus.hasFocus) {
      focus.unfocus();
    }
  }

  void _showErrorSnack(String message) {
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    messenger?.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openSection(int index) async {
    _dismissKeyboard();
    setState(() {
      _stepIndex = index;
      _editingSection = true;
      _activeMediaGroupKey = null;
      _mediaGroupSelectMode = false;
      _mediaGroupSelectedIndexes = <int>{};
      if (_stepIndex == _steps.length - 1) {
        _ensureSummaryAutofill();
      }
    });
    _scrollEditorToTop();
  }

  int _stepIndexById(String stepId) {
    return _steps.indexWhere((step) => step.id == stepId);
  }

  void _navigateToStepFromSummary(String stepId, {String? mediaGroupKey}) {
    final nextIndex = _stepIndexById(stepId);
    if (nextIndex < 0) return;

    _dismissKeyboard();
    setState(() {
      _stepIndex = nextIndex;
      _editingSection = true;
      _mediaGroupSelectMode = false;
      _mediaGroupSelectedIndexes = <int>{};
      if (stepId == 'media') {
        _activeMediaGroupKey = mediaGroupKey;
      } else {
        _activeMediaGroupKey = null;
      }
      if (_stepIndex == _steps.length - 1) {
        _ensureSummaryAutofill();
      }
    });
    _scrollEditorToTop();
  }

  void _openMediaGroupEditor(String groupKey) {
    setState(() {
      _activeMediaGroupKey = groupKey;
      _mediaGroupSelectMode = false;
      _mediaGroupSelectedIndexes = <int>{};
    });
  }

  Future<void> _openMediaGroupFlow(String groupKey) async {
    final state = _mediaState[groupKey];
    if (state == null) return;

    if (!mounted) return;
    _openMediaGroupEditor(groupKey);

    if (state.files.isNotEmpty) return;

    try {
      await _pickMediaFiles(groupKey);
    } catch (error) {
      _showErrorSnack('Не удалось открыть галерею: $error');
    }
  }

  void _closeMediaGroupEditor() {
    setState(() {
      _activeMediaGroupKey = null;
      _mediaGroupSelectMode = false;
      _mediaGroupSelectedIndexes = <int>{};
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
    final hasMileage = _mileageController.text.trim().isNotEmpty;
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
    if (!hasMileage) {
      reasons.add('Автомобиль — укажите пробег');
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

    final plateError = _plateError();
    if (plateError != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(plateError)));
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
    _dismissKeyboard();
    await _saveDraft(showToast: false);
    if (!mounted) return;
    if (_stepIndex >= _steps.length - 1) return;
    setState(() {
      _activeMediaGroupKey = null;
      _mediaGroupSelectMode = false;
      _mediaGroupSelectedIndexes = <int>{};
      _stepIndex += 1;
      _editingSection = true;
      if (_stepIndex == _steps.length - 1) {
        _ensureSummaryAutofill();
      }
    });
    _scrollEditorToTop();
  }

  Future<void> _closeSection({bool save = false}) async {
    _dismissKeyboard();
    if (save) {
      await _saveDraft(showToast: false);
      if (!mounted) return;
    }
    setState(() {
      _editingSection = false;
      _activeMediaGroupKey = null;
      _mediaGroupSelectMode = false;
      _mediaGroupSelectedIndexes = <int>{};
    });
  }

  Future<void> _handleSectionBack() async {
    if (_stepIndex == 4 && _activeMediaGroupKey != null) {
      _closeMediaGroupEditor();
      return;
    }
    await _closeSection(save: false);
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
        if (_mileageController.text.trim().isNotEmpty) {
          chunks.add('${_mileageController.text.trim()} км');
        }
        return chunks.join(' · ');
      case 'params':
        final chunks = <String>[];
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
    required ValueChanged<bool?> onChanged,
    String? subtitle,
    bool allowClear = false,
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
                  onPressed: () =>
                      onChanged(allowClear && value == true ? null : true),
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
                  onPressed: () =>
                      onChanged(allowClear && value == false ? null : false),
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
          if (allowClear) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: value == null ? null : () => onChanged(null),
                child: const Text('Сбросить выбор'),
              ),
            ),
          ],
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
                  if (formatted != value) {
                    _plateController.value = TextEditingValue(
                      text: formatted,
                      selection: TextSelection.collapsed(
                        offset: formatted.length,
                      ),
                      composing: TextRange.empty,
                    );
                  }
                  setState(() {});
                },
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                enableSuggestions: false,
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
        const SizedBox(height: 10),
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
          allowClear: true,
          onChanged: (v) => setState(() => _mileageMismatch = v),
        ),
        const SizedBox(height: 10),
        _dropdownField(
          _ownersCountController,
          'Количество владельцев',
          _ownersCounts,
        ),
        const SizedBox(height: 10),
        _input(_inspectionCityController, 'Город осмотра'),
      ],
    );
  }

  Widget _stepParams() {
    final engineVolumes = List<String>.generate(43, (i) {
      return (0.8 + i * 0.1).toStringAsFixed(1);
    });

    return Column(
      children: [
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

  Widget _legalFilesCard() {
    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.description_outlined, size: 16, color: kGreyColor),
              SizedBox(width: 6),
              MyText(
                text: 'Документы проверки',
                size: 12,
                weight: FontWeight.w700,
              ),
              Spacer(),
              MyText(text: 'PDF, Word', size: 10, color: kGreyColor),
            ],
          ),
          const SizedBox(height: 6),
          const MyText(
            text:
                'Загрузите файлы юридической проверки (отчёты, выписки, заключения)',
            size: 11,
            color: kGreyColor,
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _pickLegalFiles,
            icon: const Icon(Icons.upload_file_rounded),
            label: const Text('Загрузить файл'),
          ),
          if (_legalFiles.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...List.generate(_legalFiles.length, (index) {
              final file = _legalFiles[index];
              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: kInputBgColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kBorderColor),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.insert_drive_file_outlined,
                        size: 16,
                        color: kSecondaryColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: MyText(
                          text: file.name,
                          size: 11,
                          maxLines: 1,
                          color: kTertiaryColor,
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          setState(() {
                            final next = [..._legalFiles]..removeAt(index);
                            _legalFiles = next;
                          });
                        },
                        borderRadius: BorderRadius.circular(999),
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(
                            Icons.close_rounded,
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
      ),
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
          _legalFilesCard(),
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
        _legalFilesCard(),
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

  Future<bool> _openMediaInspectionEditor({
    required String groupKey,
    required int index,
    bool saveDraftOnClose = true,
  }) async {
    final group = _mediaState[groupKey];
    if (group == null || index < 0 || index >= group.files.length) return false;

    final item = group.files[index];
    final basePartInspection = _mediaPartInspectionIsEmpty(group.partInspection)
        ? _deriveGroupPartInspection(
            files: group.files,
            fallbackNote: group.note,
          )
        : group.partInspection;
    var noDamage = basePartInspection.noDamage;
    var selectedTags = [...item.inspection.tags];
    var elementType = basePartInspection.elementType;
    var audioRecordings = [...basePartInspection.audioRecordings];
    var tagPhotosByTag = <String, List<String>>{
      for (final entry in basePartInspection.tagPhotos.entries)
        entry.key: [...entry.value],
    };
    if (selectedTags.isEmpty && !basePartInspection.noDamage) {
      selectedTags = tagPhotosByTag.entries
          .where((entry) => entry.value.contains(item.dataUrl))
          .map((entry) => entry.key)
          .toList();
    }
    final supportsPaint = _mediaSupportsPaintThickness(groupKey);
    var paintFrom = basePartInspection.paintFrom ?? 80.0;
    var paintTo = basePartInspection.paintTo ?? 200.0;
    var paintEditing = false;
    var customTagsByScope = <String, List<String>>{
      for (final entry in _mediaCustomTagsByScope.entries)
        entry.key: [...entry.value],
    };
    var customSeriousTagsByScope = <String, List<String>>{
      for (final entry in _mediaCustomSeriousTagsByScope.entries)
        entry.key: [...entry.value],
    };
    var disabledDefaultTagsByScope = <String, List<String>>{
      for (final entry in _mediaDisabledDefaultTagsByScope.entries)
        entry.key: [...entry.value],
    };
    var tagOrderByScope = <String, List<String>>{
      for (final entry in _mediaTagOrderByScope.entries)
        entry.key: [...entry.value],
    };
    var showElementError = false;
    var manageTagsMode = false;
    var isRecording = false;
    var recordingDuration = 0;
    var isDictating = false;
    var speechInitialized = false;
    var speechAvailable = false;
    var playingAudioIndex = -1;
    var dialogActive = true;
    var shouldRecord = false;
    var shouldDictate = false;

    final noteController = TextEditingController(
      text: basePartInspection.note.trim().isEmpty
          ? item.inspection.note
          : basePartInspection.note,
    );
    final customTagController = TextEditingController();
    var customTagSeverity = 'minor';
    var paintToolsExpanded = false;
    final recorder = AudioRecorder();
    final player = AudioPlayer();
    final speechToText = SpeechToText();
    StreamSubscription<Uint8List>? recordSubscription;
    StreamSubscription<void>? playerCompleteSubscription;
    BytesBuilder? recordBuffer;
    Timer? recordingTimer;

    Future<void> showMessage(String text) async {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }

    Future<void> startRecording(StateSetter setLocalState) async {
      shouldRecord = true;
      if (isRecording) return;

      final hasPermission =
          _microphonePermissionGranted || await recorder.hasPermission();
      if (!hasPermission) {
        shouldRecord = false;
        await showMessage('Нет доступа к микрофону');
        return;
      }
      _microphonePermissionGranted = true;

      try {
        recordBuffer = BytesBuilder(copy: false);
        await recordSubscription?.cancel();
        recordSubscription =
            (await recorder.startStream(
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
      if (_speechPermissionGranted) {
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
        return;
      }
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
      if (speechAvailable) {
        _speechPermissionGranted = true;
      }
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

    void formatNoteWithAi(StateSetter setLocalState) {
      final text = noteController.text.trim();
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
        if (current.length >= 2 || i == sentences.length - 1) {
          paragraphs.add(current.join(' '));
          current.clear();
        }
      }
      final formatted = paragraphs.join('\n\n');
      noteController
        ..text = formatted
        ..selection = TextSelection.collapsed(offset: formatted.length);
      setLocalState(() {});
    }

    bool? saved;
    try {
      saved = await showDialog<bool>(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setLocalState) {
              playerCompleteSubscription ??= player.onPlayerComplete.listen((
                _,
              ) {
                if (!dialogActive) return;
                setLocalState(() => playingAudioIndex = -1);
              });

              final elementOptions = _mediaElementOptions(groupKey);
              final requiresElementType = elementOptions.isNotEmpty;
              final elementChosen =
                  !requiresElementType || (elementType ?? '').trim().isNotEmpty;
              final canEditDetails = !requiresElementType || elementChosen;
              final scopeKey = _mediaTagScopeKey(
                groupKey,
                elementType: elementType,
              );
              final tagGroups = _mediaTagGroups(
                groupKey,
                elementType: elementType,
                customTagsByScope: customTagsByScope,
                customSeriousTagsByScope: customSeriousTagsByScope,
                disabledDefaultTagsByScope: disabledDefaultTagsByScope,
                tagOrderByScope: tagOrderByScope,
              );
              final tagGroupsAll = _mediaTagGroups(
                groupKey,
                elementType: elementType,
                customTagsByScope: customTagsByScope,
                customSeriousTagsByScope: customSeriousTagsByScope,
                disabledDefaultTagsByScope: disabledDefaultTagsByScope,
                tagOrderByScope: tagOrderByScope,
                includeDisabledDefaults: true,
              );
              final customTagsInScope =
                  customTagsByScope[scopeKey] ?? const <String>[];
              final disabledDefaultsInScope =
                  disabledDefaultTagsByScope[scopeKey] ?? const <String>[];
              final viewportWidth = MediaQuery.of(context).size.width;
              final viewportHeight = MediaQuery.of(context).size.height;
              final dialogContentWidth = (viewportWidth - 32)
                  .clamp(220.0, 420.0)
                  .toDouble();
              final dialogShellWidth = viewportWidth > 560
                  ? 460.0
                  : viewportWidth;

              return Dialog(
                insetPadding: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                backgroundColor: kWhiteColor,
                child: SafeArea(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: dialogShellWidth,
                      height: viewportHeight,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
                            child: Row(
                              children: [
                                IconButton(
                                  onPressed: () async {
                                    await stopDictation(setLocalState);
                                    await stopRecording(
                                      setLocalState,
                                      keepResult: false,
                                    );
                                    await player.stop();
                                    if (!context.mounted) return;
                                    Navigator.of(context).pop(false);
                                  },
                                  icon: const Icon(Icons.arrow_back_rounded),
                                  tooltip: 'Назад',
                                ),
                                const Expanded(
                                  child: Center(
                                    child: MyText(
                                      text: 'Заметка элемента',
                                      size: 20,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 40),
                              ],
                            ),
                          ),
                          const Divider(height: 1),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                              child: SingleChildScrollView(
                                child: SizedBox(
                                  width: dialogContentWidth,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      DropdownButtonFormField<String>(
                                        isExpanded: true,
                                        isDense: true,
                                        initialValue:
                                            (elementType ?? '').isEmpty
                                            ? null
                                            : elementType,
                                        decoration: _fieldDecoration('Элемент')
                                            .copyWith(
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
                                            manageTagsMode = false;
                                            showElementError = false;
                                          });
                                        },
                                      ),
                                      if (requiresElementType &&
                                          !canEditDetails) ...[
                                        const SizedBox(height: 10),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: kBorderColor,
                                            ),
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
                                      if (canEditDetails && supportsPaint) ...[
                                        const SizedBox(height: 10),
                                        Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: kBorderColor,
                                            ),
                                          ),
                                          child: ExpansionTile(
                                            key: ValueKey(
                                              'paint-tools-$paintToolsExpanded',
                                            ),
                                            title: const MyText(
                                              text:
                                                  'Толщина ЛКП (дополнительно)',
                                              size: 12,
                                              weight: FontWeight.w700,
                                            ),
                                            initiallyExpanded:
                                                paintToolsExpanded,
                                            tilePadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                ),
                                            childrenPadding:
                                                const EdgeInsets.fromLTRB(
                                                  10,
                                                  0,
                                                  10,
                                                  10,
                                                ),
                                            onExpansionChanged: (expanded) {
                                              setLocalState(
                                                () => paintToolsExpanded =
                                                    expanded,
                                              );
                                            },
                                            children: [
                                              _paintRangeBlock(
                                                title: 'Толщина окраса',
                                                from: paintFrom,
                                                to: paintTo,
                                                editing: paintEditing,
                                                onToggle: () {
                                                  setLocalState(
                                                    () => paintEditing =
                                                        !paintEditing,
                                                  );
                                                },
                                                onChanged: (values) {
                                                  setLocalState(() {
                                                    paintFrom = values.start
                                                        .roundToDouble();
                                                    paintTo = values.end
                                                        .roundToDouble();
                                                  });
                                                },
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                      if (canEditDetails) ...[
                                        const SizedBox(height: 10),
                                        InkWell(
                                          onTap: () {
                                            setLocalState(() {
                                              noDamage = !noDamage;
                                              if (noDamage) {
                                                selectedTags = [];
                                                manageTagsMode = false;
                                              }
                                            });
                                          },
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          child: Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 10,
                                            ),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: noDamage
                                                    ? kGreenColor
                                                    : kBorderColor,
                                              ),
                                              color: noDamage
                                                  ? kGreenColor.withValues(
                                                      alpha: 0.1,
                                                    )
                                                  : kWhiteColor,
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  noDamage
                                                      ? Icons.check_box
                                                      : Icons
                                                            .check_box_outline_blank,
                                                  color: noDamage
                                                      ? kGreenColor
                                                      : kGreyColor,
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: MyText(
                                                    text: _mediaNoDamageLabel(
                                                      groupKey,
                                                    ),
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
                                        Row(
                                          children: [
                                            const Expanded(
                                              child: MyText(
                                                text: 'Теги',
                                                size: 11,
                                                color: kGreyColor,
                                                weight: FontWeight.w700,
                                              ),
                                            ),
                                            TextButton.icon(
                                              onPressed: () {
                                                setLocalState(
                                                  () => manageTagsMode =
                                                      !manageTagsMode,
                                                );
                                              },
                                              icon: Icon(
                                                manageTagsMode
                                                    ? Icons.check_rounded
                                                    : Icons.settings_rounded,
                                                size: 16,
                                              ),
                                              label: Text(
                                                manageTagsMode
                                                    ? 'Готово'
                                                    : 'Настроить',
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (manageTagsMode) ...[
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: kBorderColor,
                                              ),
                                              color: kInputBgColor,
                                            ),
                                            child: const MyText(
                                              text:
                                                  'Можно скрыть дефолтные теги и удалить кастомные.',
                                              size: 11,
                                              color: kGreyColor,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          if (tagGroupsAll.isEmpty)
                                            const MyText(
                                              text:
                                                  'Для выбранного элемента теги не заданы',
                                              size: 11,
                                              color: kGreyColor,
                                            )
                                          else
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: tagGroupsAll.map((
                                                group,
                                              ) {
                                                final groupTags = group.options;
                                                if (groupTags.isEmpty) {
                                                  return const SizedBox.shrink();
                                                }
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        bottom: 10,
                                                      ),
                                                  child: Row(
                                                    children: [
                                                      MyText(
                                                        text: group.title,
                                                        size: 11,
                                                        color:
                                                            _mediaTagGroupTitleColor(
                                                              group,
                                                            ),
                                                        weight: FontWeight.w700,
                                                      ),
                                                      const Spacer(),
                                                      MyText(
                                                        text:
                                                            '${groupTags.length}',
                                                        size: 10,
                                                        color: kGreyColor,
                                                        weight: FontWeight.w700,
                                                      ),
                                                    ],
                                                  ),
                                                );
                                              }).toList(),
                                            ),
                                          const SizedBox(height: 6),
                                          ...tagGroupsAll.map((group) {
                                            final groupTags = group.options;
                                            if (groupTags.isEmpty) {
                                              return const SizedBox.shrink();
                                            }
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 10,
                                              ),
                                              child: ReorderableListView.builder(
                                                key: ValueKey(
                                                  'tag-manage-$scopeKey-${group.title}',
                                                ),
                                                shrinkWrap: true,
                                                buildDefaultDragHandles: false,
                                                physics:
                                                    const NeverScrollableScrollPhysics(),
                                                itemCount: groupTags.length,
                                                onReorder: (oldIndex, newIndex) {
                                                  setLocalState(() {
                                                    final adjusted =
                                                        oldIndex < newIndex
                                                        ? newIndex - 1
                                                        : newIndex;
                                                    if (oldIndex == adjusted) {
                                                      return;
                                                    }

                                                    final reordered = [
                                                      ...groupTags.map(
                                                        (tag) => tag.label,
                                                      ),
                                                    ];
                                                    final moved = reordered
                                                        .removeAt(oldIndex);
                                                    reordered.insert(
                                                      adjusted,
                                                      moved,
                                                    );

                                                    final baseline = [
                                                      ...(tagOrderByScope[scopeKey] ??
                                                          tagGroupsAll
                                                              .expand(
                                                                (entry) => entry
                                                                    .options
                                                                    .map(
                                                                      (
                                                                        tag,
                                                                      ) => tag
                                                                          .label,
                                                                    ),
                                                              )
                                                              .toList()),
                                                    ];
                                                    final normalized =
                                                        <String>[];
                                                    for (final value
                                                        in baseline) {
                                                      if (normalized.any(
                                                        (item) =>
                                                            item.toLowerCase() ==
                                                            value.toLowerCase(),
                                                      )) {
                                                        continue;
                                                      }
                                                      normalized.add(value);
                                                    }

                                                    final groupSet = groupTags
                                                        .map(
                                                          (tag) => tag.label
                                                              .toLowerCase(),
                                                        )
                                                        .toSet();
                                                    final withoutGroup = normalized
                                                        .where(
                                                          (
                                                            value,
                                                          ) => !groupSet.contains(
                                                            value.toLowerCase(),
                                                          ),
                                                        )
                                                        .toList();
                                                    var insertAt = normalized
                                                        .indexWhere(
                                                          (
                                                            value,
                                                          ) => groupSet.contains(
                                                            value.toLowerCase(),
                                                          ),
                                                        );
                                                    if (insertAt < 0 ||
                                                        insertAt >
                                                            withoutGroup
                                                                .length) {
                                                      insertAt =
                                                          withoutGroup.length;
                                                    }
                                                    withoutGroup.insertAll(
                                                      insertAt,
                                                      reordered,
                                                    );
                                                    tagOrderByScope[scopeKey] =
                                                        withoutGroup;
                                                  });
                                                },
                                                itemBuilder: (context, index) {
                                                  final tag = groupTags[index];
                                                  final hidden =
                                                      !tag.isCustom &&
                                                      disabledDefaultsInScope.any(
                                                        (value) =>
                                                            value
                                                                .toLowerCase() ==
                                                            tag.label
                                                                .toLowerCase(),
                                                      );

                                                  return Container(
                                                    key: ValueKey(
                                                      'tag-item-$scopeKey-${group.title}-${tag.label}',
                                                    ),
                                                    margin:
                                                        const EdgeInsets.only(
                                                          bottom: 6,
                                                        ),
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 6,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            10,
                                                          ),
                                                      border: Border.all(
                                                        color: kBorderColor,
                                                      ),
                                                      color: hidden
                                                          ? kInputBgColor
                                                          : kWhiteColor,
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        ReorderableDragStartListener(
                                                          index: index,
                                                          child: const Padding(
                                                            padding:
                                                                EdgeInsets.symmetric(
                                                                  horizontal: 4,
                                                                ),
                                                            child: Icon(
                                                              Icons
                                                                  .drag_indicator_rounded,
                                                              size: 16,
                                                              color: kGreyColor,
                                                            ),
                                                          ),
                                                        ),
                                                        Expanded(
                                                          child: MyText(
                                                            text: tag.label,
                                                            size: 11,
                                                            color: hidden
                                                                ? kGreyColor
                                                                : kTertiaryColor,
                                                            weight:
                                                                FontWeight.w600,
                                                          ),
                                                        ),
                                                        if (tag.isCustom)
                                                          InkWell(
                                                            onTap: () {
                                                              setLocalState(() {
                                                                final next =
                                                                    (customTagsByScope[scopeKey] ??
                                                                            const <
                                                                              String
                                                                            >[])
                                                                        .where(
                                                                          (
                                                                            value,
                                                                          ) =>
                                                                              value.toLowerCase() !=
                                                                              tag.label.toLowerCase(),
                                                                        )
                                                                        .toList();
                                                                if (next
                                                                    .isEmpty) {
                                                                  customTagsByScope
                                                                      .remove(
                                                                        scopeKey,
                                                                      );
                                                                } else {
                                                                  customTagsByScope[scopeKey] =
                                                                      next;
                                                                }
                                                                final order =
                                                                    (tagOrderByScope[scopeKey] ??
                                                                            const <
                                                                              String
                                                                            >[])
                                                                        .where(
                                                                          (
                                                                            value,
                                                                          ) =>
                                                                              value.toLowerCase() !=
                                                                              tag.label.toLowerCase(),
                                                                        )
                                                                        .toList();
                                                                if (order
                                                                    .isEmpty) {
                                                                  tagOrderByScope
                                                                      .remove(
                                                                        scopeKey,
                                                                      );
                                                                } else {
                                                                  tagOrderByScope[scopeKey] =
                                                                      order;
                                                                }
                                                                selectedTags.removeWhere(
                                                                  (value) =>
                                                                      value
                                                                          .toLowerCase() ==
                                                                      tag.label
                                                                          .toLowerCase(),
                                                                );
                                                              });
                                                            },
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  999,
                                                                ),
                                                            child: const Padding(
                                                              padding:
                                                                  EdgeInsets.all(
                                                                    4,
                                                                  ),
                                                              child: Icon(
                                                                Icons
                                                                    .delete_outline_rounded,
                                                                size: 16,
                                                                color:
                                                                    kGreyColor,
                                                              ),
                                                            ),
                                                          )
                                                        else
                                                          InkWell(
                                                            onTap: () {
                                                              setLocalState(() {
                                                                final next = [
                                                                  ...(disabledDefaultTagsByScope[scopeKey] ??
                                                                      const <
                                                                        String
                                                                      >[]),
                                                                ];
                                                                next.removeWhere(
                                                                  (value) =>
                                                                      value
                                                                          .toLowerCase() ==
                                                                      tag.label
                                                                          .toLowerCase(),
                                                                );
                                                                if (!hidden) {
                                                                  next.add(
                                                                    tag.label,
                                                                  );
                                                                  selectedTags.removeWhere(
                                                                    (value) =>
                                                                        value
                                                                            .toLowerCase() ==
                                                                        tag.label
                                                                            .toLowerCase(),
                                                                  );
                                                                }
                                                                if (next
                                                                    .isEmpty) {
                                                                  disabledDefaultTagsByScope
                                                                      .remove(
                                                                        scopeKey,
                                                                      );
                                                                } else {
                                                                  disabledDefaultTagsByScope[scopeKey] =
                                                                      next;
                                                                }
                                                              });
                                                            },
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  999,
                                                                ),
                                                            child: Padding(
                                                              padding:
                                                                  const EdgeInsets.all(
                                                                    4,
                                                                  ),
                                                              child: Icon(
                                                                hidden
                                                                    ? Icons
                                                                          .visibility_off_outlined
                                                                    : Icons
                                                                          .visibility_rounded,
                                                                size: 16,
                                                                color: hidden
                                                                    ? kGreyColor
                                                                    : kSecondaryColor,
                                                              ),
                                                            ),
                                                          ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                            );
                                          }),
                                          if (customTagsInScope.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            MyText(
                                              text:
                                                  'Кастомных тегов: ${customTagsInScope.length}',
                                              size: 11,
                                              color: kGreyColor,
                                            ),
                                          ],
                                          const SizedBox(height: 8),
                                          Container(
                                            width: double.infinity,
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: kBorderColor,
                                              ),
                                              color: kInputBgColor,
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                const MyText(
                                                  text: 'Добавить свой тег',
                                                  size: 11,
                                                  color: kGreyColor,
                                                  weight: FontWeight.w700,
                                                ),
                                                const SizedBox(height: 8),
                                                Wrap(
                                                  spacing: 8,
                                                  runSpacing: 8,
                                                  children: [
                                                    ChoiceChip(
                                                      label: const Text(
                                                        'Незначительный',
                                                      ),
                                                      selected:
                                                          customTagSeverity ==
                                                          'minor',
                                                      onSelected: (_) {
                                                        setLocalState(
                                                          () =>
                                                              customTagSeverity =
                                                                  'minor',
                                                        );
                                                      },
                                                    ),
                                                    ChoiceChip(
                                                      label: const Text(
                                                        'Серьёзный',
                                                      ),
                                                      selected:
                                                          customTagSeverity ==
                                                          'serious',
                                                      selectedColor: kRedColor
                                                          .withValues(
                                                            alpha: 0.16,
                                                          ),
                                                      onSelected: (_) {
                                                        setLocalState(
                                                          () =>
                                                              customTagSeverity =
                                                                  'serious',
                                                        );
                                                      },
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 8),
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: TextField(
                                                        controller:
                                                            customTagController,
                                                        decoration:
                                                            _fieldDecoration(
                                                              'Свой тег',
                                                            ).copyWith(
                                                              contentPadding:
                                                                  const EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        12,
                                                                    vertical: 8,
                                                                  ),
                                                            ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    OutlinedButton(
                                                      onPressed: () {
                                                        final input =
                                                            customTagController
                                                                .text
                                                                .trim();
                                                        if (input.isEmpty) {
                                                          return;
                                                        }

                                                        final next =
                                                            customTagsByScope[scopeKey] !=
                                                                null
                                                            ? [
                                                                ...customTagsByScope[scopeKey]!,
                                                              ]
                                                            : <String>[];

                                                        String selectedValue =
                                                            input;
                                                        final lower = input
                                                            .toLowerCase();
                                                        for (final tag
                                                            in next) {
                                                          if (tag.toLowerCase() ==
                                                              lower) {
                                                            selectedValue = tag;
                                                            break;
                                                          }
                                                        }
                                                        if (!next.any(
                                                          (tag) =>
                                                              tag.toLowerCase() ==
                                                              lower,
                                                        )) {
                                                          next.add(input);
                                                          selectedValue = input;
                                                        }
                                                        customTagsByScope[scopeKey] =
                                                            next;
                                                        final customSerious =
                                                            customSeriousTagsByScope[scopeKey] !=
                                                                null
                                                            ? [
                                                                ...customSeriousTagsByScope[scopeKey]!,
                                                              ]
                                                            : <String>[];
                                                        customSerious.removeWhere(
                                                          (tag) =>
                                                              tag
                                                                  .toLowerCase() ==
                                                              selectedValue
                                                                  .toLowerCase(),
                                                        );
                                                        if (customTagSeverity ==
                                                            'serious') {
                                                          customSerious.add(
                                                            selectedValue,
                                                          );
                                                        }
                                                        if (customSerious
                                                            .isEmpty) {
                                                          customSeriousTagsByScope
                                                              .remove(scopeKey);
                                                        } else {
                                                          customSeriousTagsByScope[scopeKey] =
                                                              customSerious;
                                                        }
                                                        disabledDefaultTagsByScope[scopeKey] =
                                                            (disabledDefaultTagsByScope[scopeKey] ??
                                                                    const <
                                                                      String
                                                                    >[])
                                                                .where(
                                                                  (tag) =>
                                                                      tag.toLowerCase() !=
                                                                      lower,
                                                                )
                                                                .toList();
                                                        final order = [
                                                          ...(tagOrderByScope[scopeKey] ??
                                                              const <String>[]),
                                                        ];
                                                        if (!order.any(
                                                          (tag) =>
                                                              tag
                                                                  .toLowerCase() ==
                                                              selectedValue
                                                                  .toLowerCase(),
                                                        )) {
                                                          order.add(
                                                            selectedValue,
                                                          );
                                                        }
                                                        tagOrderByScope[scopeKey] =
                                                            order;
                                                        if (!selectedTags.any(
                                                          (tag) =>
                                                              tag
                                                                  .toLowerCase() ==
                                                              selectedValue
                                                                  .toLowerCase(),
                                                        )) {
                                                          selectedTags.add(
                                                            selectedValue,
                                                          );
                                                        }
                                                        customTagSeverity =
                                                            'minor';
                                                        customTagController
                                                            .clear();
                                                        setLocalState(() {});
                                                      },
                                                      child: const Text(
                                                        'Добавить',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                        ] else ...[
                                          if (tagGroups.isEmpty)
                                            const MyText(
                                              text:
                                                  'Для выбранного элемента теги не заданы',
                                              size: 11,
                                              color: kGreyColor,
                                            )
                                          else
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: tagGroups.map((group) {
                                                return Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        bottom: 10,
                                                      ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      MyText(
                                                        text: group.title,
                                                        size: 11,
                                                        color:
                                                            _mediaTagGroupTitleColor(
                                                              group,
                                                            ),
                                                        weight: FontWeight.w700,
                                                      ),
                                                      const SizedBox(height: 6),
                                                      Wrap(
                                                        spacing: 8,
                                                        runSpacing: 8,
                                                        children: group.options.map((
                                                          tag,
                                                        ) {
                                                          final selected =
                                                              selectedTags
                                                                  .contains(
                                                                    tag.label,
                                                                  );
                                                          return _chip(
                                                            label: tag.label,
                                                            selected: selected,
                                                            selectedColor:
                                                                _mediaTagColor(
                                                                  tag.severity,
                                                                ),
                                                            onTap: () {
                                                              setLocalState(() {
                                                                if (selected) {
                                                                  selectedTags
                                                                      .remove(
                                                                        tag.label,
                                                                      );
                                                                } else {
                                                                  selectedTags
                                                                      .add(
                                                                        tag.label,
                                                                      );
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
                                        ],
                                      ],
                                      if (canEditDetails) ...[
                                        const SizedBox(height: 10),
                                        const MyText(
                                          text: 'Комментарий по элементу',
                                          size: 11,
                                          color: kGreyColor,
                                          weight: FontWeight.w700,
                                        ),
                                        const SizedBox(height: 6),
                                        Container(
                                          width: double.infinity,
                                          padding: const EdgeInsets.fromLTRB(
                                            12,
                                            10,
                                            12,
                                            10,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: kBorderColor,
                                            ),
                                            color: kWhiteColor,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              TextField(
                                                controller: noteController,
                                                minLines: 5,
                                                maxLines: 7,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                ),
                                                decoration:
                                                    const InputDecoration(
                                                      hintText:
                                                          'Добавьте комментарий',
                                                      hintStyle: TextStyle(
                                                        fontSize: 14,
                                                        color: kGreyColor,
                                                      ),
                                                      border: InputBorder.none,
                                                      enabledBorder:
                                                          InputBorder.none,
                                                      focusedBorder:
                                                          InputBorder.none,
                                                      contentPadding:
                                                          EdgeInsets.zero,
                                                    ),
                                              ),
                                              const SizedBox(height: 10),
                                              if (isDictating) ...[
                                                const MyText(
                                                  text: 'Идёт надиктовка...',
                                                  size: 11,
                                                  color: kRedColor,
                                                  weight: FontWeight.w700,
                                                ),
                                                const SizedBox(height: 8),
                                              ],
                                              Align(
                                                alignment:
                                                    Alignment.centerRight,
                                                child: Wrap(
                                                  spacing: 8,
                                                  runSpacing: 8,
                                                  children: [
                                                    InkWell(
                                                      onTap: () async {
                                                        if (isDictating) {
                                                          await stopDictation(
                                                            setLocalState,
                                                          );
                                                        } else {
                                                          await startDictation(
                                                            setLocalState,
                                                          );
                                                        }
                                                      },
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            999,
                                                          ),
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 10,
                                                              vertical: 6,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                999,
                                                              ),
                                                          border: Border.all(
                                                            color: isDictating
                                                                ? kRedColor
                                                                      .withValues(
                                                                        alpha:
                                                                            0.45,
                                                                      )
                                                                : kBorderColor,
                                                          ),
                                                          color: isDictating
                                                              ? kRedColor
                                                                    .withValues(
                                                                      alpha:
                                                                          0.08,
                                                                    )
                                                              : kInputBgColor,
                                                        ),
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            Icon(
                                                              isDictating
                                                                  ? Icons
                                                                        .mic_off_rounded
                                                                  : Icons
                                                                        .mic_rounded,
                                                              size: 14,
                                                              color: isDictating
                                                                  ? kRedColor
                                                                  : kSecondaryColor,
                                                            ),
                                                            const SizedBox(
                                                              width: 5,
                                                            ),
                                                            MyText(
                                                              text: isDictating
                                                                  ? 'Стоп'
                                                                  : 'Голос в текст',
                                                              size: 10,
                                                              weight: FontWeight
                                                                  .w700,
                                                              color: isDictating
                                                                  ? kRedColor
                                                                  : kTertiaryColor,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                    InkWell(
                                                      onTap: () =>
                                                          formatNoteWithAi(
                                                            setLocalState,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            999,
                                                          ),
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 10,
                                                              vertical: 6,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                999,
                                                              ),
                                                          border: Border.all(
                                                            color:
                                                                kSecondaryColor
                                                                    .withValues(
                                                                      alpha:
                                                                          0.25,
                                                                    ),
                                                          ),
                                                          color: kSecondaryColor
                                                              .withValues(
                                                                alpha: 0.08,
                                                              ),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: const [
                                                            Icon(
                                                              Icons
                                                                  .auto_awesome_rounded,
                                                              size: 14,
                                                              color:
                                                                  kSecondaryColor,
                                                            ),
                                                            SizedBox(width: 5),
                                                            MyText(
                                                              text:
                                                                  'ИИ для комментария',
                                                              size: 10,
                                                              weight: FontWeight
                                                                  .w700,
                                                              color:
                                                                  kSecondaryColor,
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                onPressed: () async {
                                                  if (isRecording) {
                                                    await stopRecording(
                                                      setLocalState,
                                                    );
                                                  } else {
                                                    await startRecording(
                                                      setLocalState,
                                                    );
                                                  }
                                                },
                                                icon: const Icon(
                                                  Icons.graphic_eq_rounded,
                                                  size: 16,
                                                ),
                                                label: Text(
                                                  isRecording
                                                      ? 'Стоп (${recordingLabel()})'
                                                      : 'Аудиозапись',
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: OutlinedButton.icon(
                                                onPressed: () async {
                                                  final picked =
                                                      await _pickFiles(
                                                        type: FileType.custom,
                                                        allowedExtensions:
                                                            const [
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
                                                          .where(
                                                            (file) =>
                                                                file.isAudio,
                                                          )
                                                          .map(
                                                            (file) =>
                                                                file.dataUrl,
                                                          ),
                                                    ];
                                                    audioRecordings = next;
                                                  });
                                                },
                                                icon: const Icon(
                                                  Icons.upload_file_rounded,
                                                  size: 16,
                                                ),
                                                label: const Text('Аудиофайл'),
                                              ),
                                            ),
                                          ],
                                        ),
                                        if (audioRecordings.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          ...List.generate(audioRecordings.length, (
                                            audioIndex,
                                          ) {
                                            final playing =
                                                playingAudioIndex == audioIndex;
                                            return Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 6,
                                              ),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 8,
                                                    ),
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: kBorderColor,
                                                  ),
                                                  color: kInputBgColor,
                                                ),
                                                child: Row(
                                                  children: [
                                                    InkWell(
                                                      onTap: () async {
                                                        try {
                                                          if (playing) {
                                                            await player.stop();
                                                            if (!dialogActive) {
                                                              return;
                                                            }
                                                            setLocalState(
                                                              () =>
                                                                  playingAudioIndex =
                                                                      -1,
                                                            );
                                                          } else {
                                                            await player.stop();
                                                            await _playAudioSource(
                                                              player,
                                                              audioRecordings[audioIndex],
                                                            );
                                                            if (!dialogActive) {
                                                              return;
                                                            }
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
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            999,
                                                          ),
                                                      child: Padding(
                                                        padding:
                                                            const EdgeInsets.all(
                                                              2,
                                                            ),
                                                        child: Icon(
                                                          playing
                                                              ? Icons
                                                                    .pause_circle_outline
                                                              : Icons
                                                                    .play_circle_outline,
                                                          size: 20,
                                                          color:
                                                              kSecondaryColor,
                                                        ),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Expanded(
                                                      child: MyText(
                                                        text:
                                                            'Аудиозапись ${audioIndex + 1}',
                                                        size: 11,
                                                        color: kTertiaryColor,
                                                      ),
                                                    ),
                                                    InkWell(
                                                      onTap: () async {
                                                        if (playingAudioIndex ==
                                                            audioIndex) {
                                                          await player.stop();
                                                          playingAudioIndex =
                                                              -1;
                                                        }
                                                        setLocalState(() {
                                                          audioRecordings
                                                              .removeAt(
                                                                audioIndex,
                                                              );
                                                        });
                                                      },
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            999,
                                                          ),
                                                      child: const Padding(
                                                        padding: EdgeInsets.all(
                                                          2,
                                                        ),
                                                        child: Icon(
                                                          Icons
                                                              .delete_outline_rounded,
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
                            ),
                          ),
                          const Divider(height: 1),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                            child: Row(
                              children: [
                                OutlinedButton(
                                  onPressed: () async {
                                    await stopDictation(setLocalState);
                                    await stopRecording(
                                      setLocalState,
                                      keepResult: false,
                                    );
                                    await player.stop();
                                    if (!context.mounted) return;
                                    Navigator.of(context).pop(false);
                                  },
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(98, 42),
                                  ),
                                  child: const Text('Отмена'),
                                ),
                                const Spacer(),
                                ElevatedButton(
                                  onPressed: () async {
                                    final requiresElementType =
                                        _mediaElementOptions(
                                          groupKey,
                                        ).isNotEmpty;
                                    if (requiresElementType &&
                                        (elementType ?? '').trim().isEmpty) {
                                      setLocalState(
                                        () => showElementError = true,
                                      );
                                      return;
                                    }
                                    await stopDictation(setLocalState);
                                    await stopRecording(setLocalState);
                                    await player.stop();
                                    if (!context.mounted) return;
                                    Navigator.of(context).pop(true);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    minimumSize: const Size(108, 42),
                                  ),
                                  child: const Text('Сохранить'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
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
    if (!mounted) return false;

    final selectedByLower = <String, String>{};
    for (final rawTag in selectedTags) {
      final tag = rawTag.trim();
      if (tag.isEmpty) continue;
      selectedByLower.putIfAbsent(tag.toLowerCase(), () => tag);
    }
    selectedTags = selectedByLower.values.toList();

    final normalizedTagPhotosByLower = <String, Set<String>>{};
    final tagDisplayByLower = <String, String>{};
    for (final entry in tagPhotosByTag.entries) {
      final tag = entry.key.trim();
      if (tag.isEmpty) continue;
      final lower = tag.toLowerCase();
      tagDisplayByLower.putIfAbsent(lower, () => tag);
      final urls = normalizedTagPhotosByLower.putIfAbsent(
        lower,
        () => <String>{},
      );
      for (final rawUrl in entry.value) {
        final url = rawUrl.trim();
        if (url.isEmpty) continue;
        urls.add(url);
      }
    }
    for (final entry in selectedByLower.entries) {
      tagDisplayByLower[entry.key] = entry.value;
      final urls = normalizedTagPhotosByLower.putIfAbsent(
        entry.key,
        () => <String>{},
      );
      urls.add(item.dataUrl);
    }
    for (final entry in normalizedTagPhotosByLower.entries) {
      if (selectedByLower.containsKey(entry.key)) continue;
      entry.value.remove(item.dataUrl);
    }

    final nextTagPhotos = <String, List<String>>{};
    if (!noDamage) {
      for (final entry in normalizedTagPhotosByLower.entries) {
        final label = tagDisplayByLower[entry.key] ?? entry.key;
        final urls = entry.value.where((url) => url.trim().isNotEmpty).toList();
        if (urls.isNotEmpty) {
          nextTagPhotos[label] = urls;
        }
      }
    }

    final partInspection = _MediaPartInspection(
      noDamage: noDamage,
      tags: noDamage ? const [] : nextTagPhotos.keys.toList(),
      note: noteValue,
      elementType: (elementType ?? '').trim().isEmpty ? null : elementType,
      audioRecordings: [
        ...audioRecordings
            .map((audio) => audio.trim())
            .where((audio) => audio.isNotEmpty),
      ],
      paintFrom: supportsPaint ? paintFrom : null,
      paintTo: supportsPaint ? paintTo : null,
      tagPhotos: noDamage ? const {} : nextTagPhotos,
      isDraft: saved == true ? false : true,
    );

    final shouldPersist =
        saved == true ||
        (saveDraftOnClose && _mediaPartInspectionHasData(partInspection));
    if (!shouldPersist) return false;

    setState(() {
      _mediaCustomTagsByScope = _readStringListMap(customTagsByScope);
      _mediaCustomSeriousTagsByScope = _readStringListMap(
        customSeriousTagsByScope,
      );
      _mediaDisabledDefaultTagsByScope = _readStringListMap(
        disabledDefaultTagsByScope,
      );
      _mediaTagOrderByScope = _readStringListMap(tagOrderByScope);
      final current = _mediaState[groupKey];
      if (current == null || index >= current.files.length) return;
      final nextPartInspection = _syncPartInspectionWithFiles(
        partInspection: partInspection,
        files: current.files,
        fallbackNote: current.note,
      );
      final nextFiles = _applyPartInspectionToFiles(
        files: current.files,
        partInspection: nextPartInspection,
      );
      final hasIssue = nextFiles.any(_mediaItemHasIssue);
      _mediaState[groupKey] = current.copyWith(
        note: nextPartInspection.note.trim().isEmpty
            ? current.note
            : nextPartInspection.note.trim(),
        files: nextFiles,
        hasIssue: hasIssue,
        partInspection: nextPartInspection,
      );
    });
    return true;
  }

  void _toggleMediaSelectMode() {
    setState(() {
      _mediaGroupSelectMode = !_mediaGroupSelectMode;
      if (!_mediaGroupSelectMode) {
        _mediaGroupSelectedIndexes = <int>{};
      }
    });
  }

  void _toggleMediaGroupSelection(int index) {
    setState(() {
      final next = <int>{..._mediaGroupSelectedIndexes};
      if (next.contains(index)) {
        next.remove(index);
      } else {
        next.add(index);
      }
      _mediaGroupSelectedIndexes = next;
      if (_mediaGroupSelectedIndexes.isEmpty) {
        _mediaGroupSelectMode = false;
      }
    });
  }

  void _deleteMediaInGroup({
    required String groupKey,
    required List<int> indexes,
  }) {
    if (indexes.isEmpty) return;
    setState(() {
      final current = _mediaState[groupKey];
      if (current == null || current.files.isEmpty) return;
      final toDelete = indexes.toSet();
      final next = <_UploadedItem>[];
      for (var i = 0; i < current.files.length; i++) {
        if (!toDelete.contains(i)) {
          next.add(current.files[i]);
        }
      }
      final nextPartInspection = _syncPartInspectionWithFiles(
        partInspection: current.partInspection,
        files: next,
        fallbackNote: current.note,
      );
      final nextFiles = _applyPartInspectionToFiles(
        files: next,
        partInspection: nextPartInspection,
      );
      _mediaState[groupKey] = current.copyWith(
        files: nextFiles,
        hasIssue: nextFiles.any(_mediaItemHasIssue),
        partInspection: nextPartInspection,
      );
      _mediaGroupSelectedIndexes = <int>{};
      _mediaGroupSelectMode = false;
    });
  }

  Future<void> _applyInspectionToSelected(String groupKey) async {
    final current = _mediaState[groupKey];
    if (current == null) return;
    final selected = _mediaGroupSelectedIndexes.toList()..sort();
    final targetIndexes = selected.isEmpty
        ? List<int>.generate(current.files.length, (i) => i)
        : selected;
    final validSelected = targetIndexes
        .where((index) => index >= 0 && index < current.files.length)
        .toList();
    if (validSelected.isEmpty) return;
    final templateIndex = validSelected.first;

    final saved = await _openMediaInspectionEditor(
      groupKey: groupKey,
      index: templateIndex,
      saveDraftOnClose: false,
    );
    if (!saved || !mounted) return;

    setState(() {
      _mediaGroupSelectMode = false;
      _mediaGroupSelectedIndexes = <int>{};
    });
  }

  Future<void> _openMediaGroupLightbox({
    required String groupKey,
    required int initialIndex,
  }) async {
    final initialState = _mediaState[groupKey];
    if (initialState == null || initialState.files.isEmpty) return;

    var currentIndex = initialIndex.clamp(0, initialState.files.length - 1);
    final controller = PageController(initialPage: currentIndex);
    final audioPlayer = AudioPlayer();
    StreamSubscription<void>? playerCompleteSubscription;
    var playingAudioIndex = -1;
    var dialogActive = true;
    VideoPlayerController? videoController;
    String? videoSourceUrl;
    var videoInitializing = false;
    String? videoErrorMessage;

    Future<void> disposeVideoController() async {
      final previous = videoController;
      videoController = null;
      videoSourceUrl = null;
      videoInitializing = false;
      videoErrorMessage = null;
      if (previous == null) return;
      try {
        await previous.pause();
      } catch (_) {}
      await previous.dispose();
    }

    Future<void> prepareVideo(
      _UploadedItem file,
      StateSetter setLocalState,
    ) async {
      if (!file.isVideo) {
        await disposeVideoController();
        if (!dialogActive) return;
        setLocalState(() {});
        return;
      }

      final source = file.dataUrl;
      if (videoSourceUrl == source &&
          videoController != null &&
          videoController!.value.isInitialized) {
        return;
      }
      if (videoInitializing && videoSourceUrl == source) return;

      videoInitializing = true;
      videoErrorMessage = null;
      videoSourceUrl = source;
      if (dialogActive) setLocalState(() {});

      final previous = videoController;
      videoController = null;
      if (previous != null) {
        try {
          await previous.pause();
        } catch (_) {}
        await previous.dispose();
      }

      try {
        final nextController = VideoPlayerController.networkUrl(
          _mediaSourceUri(source),
        );
        await nextController.initialize();
        await nextController.setLooping(true);
        await nextController.play();
        if (!dialogActive) {
          await nextController.dispose();
          return;
        }
        videoController = nextController;
        videoInitializing = false;
        setLocalState(() {});
      } catch (_) {
        videoInitializing = false;
        videoErrorMessage = 'Не удалось воспроизвести видео';
        if (!dialogActive) return;
        setLocalState(() {});
      }
    }

    int? editIndex;
    try {
      editIndex = await showDialog<int>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setLocalState) {
              playerCompleteSubscription ??= audioPlayer.onPlayerComplete
                  .listen((_) {
                    if (!dialogActive) return;
                    setLocalState(() => playingAudioIndex = -1);
                  });

              final liveState = _mediaState[groupKey] ?? initialState;
              final files = liveState.files;
              if (files.isEmpty) {
                return AlertDialog(
                  content: const Text('Файлы отсутствуют'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('Закрыть'),
                    ),
                  ],
                );
              }

              if (currentIndex >= files.length) {
                currentIndex = files.length - 1;
              }
              if (currentIndex < 0) currentIndex = 0;

              final item = files[currentIndex];
              final note = item.inspection.note.trim();
              final elementLabel = _mediaElementLabel(
                groupKey,
                item.inspection.elementType,
              );
              final hasInspection = _mediaInspectionHasData(item.inspection);
              final tags = item.inspection.tags;
              final hasNoDamage = item.inspection.noDamage;
              final audioNotes = item.inspection.audioRecordings;
              final paintFrom = item.inspection.paintFrom;
              final paintTo = item.inspection.paintTo;
              final noteDisplay = note.isEmpty
                  ? 'Заметка не добавлена'
                  : (elementLabel.isEmpty ? note : '[$elementLabel] $note');

              return Dialog.fullscreen(
                child: Scaffold(
                  backgroundColor: Colors.black,
                  appBar: AppBar(
                    backgroundColor: Colors.black,
                    foregroundColor: kWhiteColor,
                    elevation: 0,
                    leading: IconButton(
                      onPressed: () async {
                        await audioPlayer.stop();
                        await disposeVideoController();
                        if (!dialogContext.mounted) return;
                        Navigator.of(dialogContext).pop();
                      },
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    title: Text(
                      '${currentIndex + 1}/${files.length}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    actions: [
                      TextButton.icon(
                        onPressed: () async {
                          await audioPlayer.stop();
                          await disposeVideoController();
                          if (!dialogContext.mounted) return;
                          Navigator.of(dialogContext).pop(currentIndex);
                        },
                        icon: const Icon(
                          Icons.edit_note_rounded,
                          size: 18,
                          color: kWhiteColor,
                        ),
                        label: Text(
                          hasInspection ? 'Заметка' : 'Добавить заметку',
                          style: const TextStyle(
                            color: kWhiteColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  body: PageView.builder(
                    controller: controller,
                    itemCount: files.length,
                    onPageChanged: (index) {
                      unawaited(audioPlayer.stop());
                      unawaited(prepareVideo(files[index], setLocalState));
                      setLocalState(() {
                        currentIndex = index;
                        playingAudioIndex = -1;
                      });
                    },
                    itemBuilder: (context, index) {
                      final file = files[index];
                      if (file.isImage) {
                        if (index == currentIndex && videoController != null) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!dialogActive) return;
                            unawaited(disposeVideoController());
                          });
                        }
                        return InteractiveViewer(
                          minScale: 1,
                          maxScale: 4,
                          child: Center(
                            child: _uploadedImageWidget(
                              file,
                              fit: BoxFit.contain,
                              errorColor: kWhiteColor,
                              errorSize: 44,
                            ),
                          ),
                        );
                      }
                      if (index != currentIndex) {
                        return const Center(
                          child: Icon(
                            Icons.videocam_outlined,
                            color: kWhiteColor,
                            size: 44,
                          ),
                        );
                      }
                      if ((videoController == null ||
                              videoSourceUrl != file.dataUrl ||
                              !videoController!.value.isInitialized) &&
                          !videoInitializing) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!dialogActive) return;
                          unawaited(prepareVideo(file, setLocalState));
                        });
                      }
                      if (videoInitializing &&
                          videoSourceUrl == file.dataUrl &&
                          (videoController == null ||
                              !videoController!.value.isInitialized)) {
                        return const Center(
                          child: CircularProgressIndicator(color: kWhiteColor),
                        );
                      }
                      if (videoErrorMessage != null &&
                          videoSourceUrl == file.dataUrl) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: kWhiteColor,
                                size: 40,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                videoErrorMessage!,
                                style: const TextStyle(color: kWhiteColor),
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton(
                                onPressed: () =>
                                    prepareVideo(file, setLocalState),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: kWhiteColor,
                                  side: BorderSide(
                                    color: kWhiteColor.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: const Text('Повторить'),
                              ),
                            ],
                          ),
                        );
                      }
                      final activeVideo = videoController;
                      if (activeVideo == null ||
                          !activeVideo.value.isInitialized ||
                          videoSourceUrl != file.dataUrl) {
                        return const Center(
                          child: CircularProgressIndicator(color: kWhiteColor),
                        );
                      }
                      final ratio = activeVideo.value.aspectRatio;
                      return GestureDetector(
                        onTap: () async {
                          if (activeVideo.value.isPlaying) {
                            await activeVideo.pause();
                          } else {
                            await activeVideo.play();
                          }
                          if (!dialogActive) return;
                          setLocalState(() {});
                        },
                        child: Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              AspectRatio(
                                aspectRatio: ratio <= 0 ? 16 / 9 : ratio,
                                child: VideoPlayer(activeVideo),
                              ),
                              AnimatedOpacity(
                                opacity: activeVideo.value.isPlaying ? 0 : 1,
                                duration: const Duration(milliseconds: 140),
                                child: Container(
                                  width: 62,
                                  height: 62,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.45),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: kWhiteColor,
                                    size: 36,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  bottomNavigationBar: Container(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 18),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.82),
                      border: Border(
                        top: BorderSide(
                          color: kWhiteColor.withValues(alpha: 0.16),
                          width: 0.8,
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (files.length > 1) ...[
                          Center(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: List.generate(files.length, (dotIndex) {
                                final active = dotIndex == currentIndex;
                                return InkWell(
                                  onTap: () async {
                                    await controller.animateToPage(
                                      dotIndex,
                                      duration: const Duration(
                                        milliseconds: 220,
                                      ),
                                      curve: Curves.easeOut,
                                    );
                                    if (!dialogActive) return;
                                    setLocalState(
                                      () => currentIndex = dotIndex,
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(999),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: active ? 18 : 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: active
                                          ? kWhiteColor
                                          : kWhiteColor.withValues(alpha: 0.35),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (elementLabel.isNotEmpty)
                          Text(
                            elementLabel,
                            style: const TextStyle(
                              color: kWhiteColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        if (elementLabel.isNotEmpty) const SizedBox(height: 4),
                        if (hasNoDamage)
                          Container(
                            margin: const EdgeInsets.only(bottom: 6),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: kGreenColor.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _mediaNoDamageLabel(groupKey),
                              style: const TextStyle(
                                color: kWhiteColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        if (tags.isNotEmpty) ...[
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: tags.map((tag) {
                              final color = _mediaTagColor(
                                _mediaTagSeverity(
                                  groupKey,
                                  tag,
                                  elementType: item.inspection.elementType,
                                ),
                              );
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.24),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  tag,
                                  style: const TextStyle(
                                    color: kWhiteColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 6),
                        ],
                        if (!hasNoDamage &&
                            paintFrom != null &&
                            paintTo != null) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.brush_outlined,
                                size: 14,
                                color: kWhiteColor.withValues(alpha: 0.8),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${paintFrom.round()}–${paintTo.round()} мкм',
                                style: TextStyle(
                                  color: kWhiteColor.withValues(alpha: 0.8),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],
                        Text(
                          noteDisplay,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: note.isEmpty
                                ? kWhiteColor.withValues(alpha: 0.68)
                                : kWhiteColor,
                            fontSize: 11,
                            height: 1.3,
                          ),
                        ),
                        if (audioNotes.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          ...List.generate(audioNotes.length, (audioIndex) {
                            final playing = playingAudioIndex == audioIndex;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: InkWell(
                                onTap: () async {
                                  try {
                                    if (playing) {
                                      await audioPlayer.stop();
                                      if (!dialogActive) return;
                                      setLocalState(
                                        () => playingAudioIndex = -1,
                                      );
                                    } else {
                                      await audioPlayer.stop();
                                      await _playAudioSource(
                                        audioPlayer,
                                        audioNotes[audioIndex],
                                      );
                                      if (!dialogActive) return;
                                      setLocalState(
                                        () => playingAudioIndex = audioIndex,
                                      );
                                    }
                                  } catch (_) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Не удалось воспроизвести аудио',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: kWhiteColor.withValues(alpha: 0.08),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        playing
                                            ? Icons.pause_circle_outline
                                            : Icons.play_circle_outline,
                                        size: 20,
                                        color: kWhiteColor,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Аудиозапись ${audioIndex + 1}',
                                        style: TextStyle(
                                          color: kWhiteColor.withValues(
                                            alpha: 0.88,
                                          ),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      dialogActive = false;
      await playerCompleteSubscription?.cancel();
      try {
        await audioPlayer.stop();
      } catch (_) {}
      await disposeVideoController();
      await audioPlayer.dispose();
      controller.dispose();
    }

    if (editIndex == null || !mounted) return;
    await _openMediaInspectionEditor(groupKey: groupKey, index: editIndex);
  }

  bool _groupFullyMarked(_MediaGroupState state) {
    if (state.files.isEmpty) return false;
    return state.files.every((file) {
      final inspection = file.inspection;
      return inspection.noDamage ||
          inspection.tags.isNotEmpty ||
          (inspection.elementType ?? '').trim().isNotEmpty ||
          inspection.note.trim().isNotEmpty ||
          inspection.audioRecordings.isNotEmpty ||
          (inspection.paintFrom != null && inspection.paintTo != null);
    });
  }

  String _mediaGroupShortStats(String groupKey, _MediaGroupState state) {
    final fileCount = state.files.length;
    if (fileCount == 0) return 'Нажмите, чтобы добавить';

    final parts = <String>['$fileCount фото'];
    final ok = _groupNoDamageElementsCount(groupKey, state);
    final serious = _groupSeriousTagCount(groupKey, state);
    final minor = _groupMinorTagCount(groupKey, state);

    if (ok > 0) parts.add('$ok ок');
    if (serious > 0) parts.add('$serious серьёзн.');
    if (minor > 0) parts.add('$minor незначит.');
    return parts.join(' · ');
  }

  Widget _mediaPaintSummaryBlock({
    required String title,
    required double from,
    required double to,
    required bool editing,
    required VoidCallback onToggle,
    required ValueChanged<RangeValues> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: MyText(
                  text: title.toUpperCase(),
                  size: 11,
                  color: kGreyColor,
                  weight: FontWeight.w700,
                ),
              ),
              TextButton(
                onPressed: onToggle,
                style: TextButton.styleFrom(
                  minimumSize: const Size(0, 28),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(editing ? 'Готово' : 'Изменить'),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              MyText(
                text: '${from.round()}–${to.round()}',
                size: 24,
                weight: FontWeight.w800,
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(bottom: 3),
                child: MyText(text: 'мкм', size: 12, color: kGreyColor),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (!editing)
            const MyText(
              text: 'Нет данных — задайте вручную',
              size: 11,
              color: kGreyColor,
            )
          else ...[
            RangeSlider(
              values: RangeValues(from, to),
              min: 50,
              max: 1500,
              divisions: 145,
              onChanged: onChanged,
            ),
            Row(
              children: const [
                MyText(text: '50 мкм', size: 10, color: kGreyColor),
                Spacer(),
                MyText(text: '1500 мкм', size: 10, color: kGreyColor),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _mediaGroupListRow(_MediaGroupState state) {
    final groupKey = state.config.key;
    final fileCount = state.files.length;
    final hasFiles = fileCount > 0;
    final hasIssue = _groupHasIssue(state);
    final fullyMarked = _groupFullyMarked(state);
    final subtitle = hasFiles
        ? _mediaGroupShortStats(groupKey, state)
        : 'Нажмите, чтобы добавить';
    final leadBg = hasFiles
        ? (hasIssue
              ? kRedColor.withValues(alpha: 0.1)
              : kSecondaryColor.withValues(alpha: 0.1))
        : kInputBgColor;
    final leadColor = hasFiles
        ? (hasIssue ? kRedColor : kSecondaryColor)
        : kGreyColor;

    Widget? footer;
    if (groupKey == 'body') {
      footer = _mediaPaintSummaryBlock(
        title: 'ЛКП — кузов',
        from: _bodyPaintFrom,
        to: _bodyPaintTo,
        editing: _bodyPaintEditing,
        onToggle: () => setState(() => _bodyPaintEditing = !_bodyPaintEditing),
        onChanged: (values) {
          setState(() {
            _bodyPaintFrom = values.start.roundToDouble();
            _bodyPaintTo = values.end.roundToDouble();
          });
        },
      );
    } else if (groupKey == 'structural') {
      footer = _mediaPaintSummaryBlock(
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
      );
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: kWhiteColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: fullyMarked && !hasIssue
                ? kGreenColor.withValues(alpha: 0.3)
                : kBorderColor,
          ),
        ),
        child: Column(
          children: [
            InkWell(
              onTap: () => _openMediaGroupFlow(groupKey),
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: leadBg,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      alignment: Alignment.center,
                      child: hasFiles
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.photo_outlined, size: 16),
                                const SizedBox(width: 2),
                                MyText(
                                  text: '$fileCount',
                                  size: 11,
                                  color: leadColor,
                                  weight: FontWeight.w700,
                                ),
                              ],
                            )
                          : Icon(Icons.add_rounded, color: leadColor, size: 26),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MyText(
                            text: state.config.title,
                            size: 16,
                            weight: FontWeight.w700,
                          ),
                          const SizedBox(height: 4),
                          MyText(text: subtitle, size: 11, color: kGreyColor),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: kGreyColor),
                  ],
                ),
              ),
            ),
            if (footer != null) ...[const Divider(height: 1), footer],
          ],
        ),
      ),
    );
  }

  Widget _mediaGroupEditor() {
    final groupKey = _activeMediaGroupKey;
    if (groupKey == null) return const SizedBox.shrink();

    final state = _mediaState[groupKey];
    if (state == null) {
      return _card(
        child: const MyText(
          text: 'Группа не найдена',
          size: 12,
          color: kRedColor,
        ),
      );
    }

    final files = state.files;
    final selectedCount = _mediaGroupSelectedIndexes.length;

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: kWhiteColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kBorderColor),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: _closeMediaGroupEditor,
                icon: const Icon(Icons.arrow_back_rounded),
                tooltip: 'К группам',
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MyText(
                      text: state.config.title,
                      size: 16,
                      weight: FontWeight.w700,
                    ),
                    MyText(
                      text: '${files.length} файлов',
                      size: 11,
                      color: kGreyColor,
                    ),
                  ],
                ),
              ),
              if (files.isNotEmpty)
                TextButton(
                  onPressed: _toggleMediaSelectMode,
                  child: Text(_mediaGroupSelectMode ? 'Отмена' : 'Выбрать'),
                ),
              const SizedBox(width: 6),
            ],
          ),
        ),
        const SizedBox(height: 10),
        if (_mediaGroupSelectMode && selectedCount > 0)
          _card(
            child: Row(
              children: [
                Expanded(
                  child: MyText(
                    text: 'Выбрано: $selectedCount',
                    size: 11,
                    color: kGreyColor,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _applyInspectionToSelected(groupKey),
                  icon: const Icon(
                    Icons.assignment_turned_in_outlined,
                    size: 18,
                    color: kSecondaryColor,
                  ),
                  label: const Text(
                    'Заметка',
                    style: TextStyle(color: kSecondaryColor),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _deleteMediaInGroup(
                    groupKey: groupKey,
                    indexes: _mediaGroupSelectedIndexes.toList(),
                  ),
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: kRedColor,
                  ),
                  label: const Text(
                    'Удалить',
                    style: TextStyle(color: kRedColor),
                  ),
                ),
              ],
            ),
          ),
        if (_mediaGroupSelectMode && selectedCount > 0)
          const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 1.34,
          ),
          itemCount: files.length + 1,
          itemBuilder: (context, index) {
            if (index == 0) {
              return InkWell(
                onTap: () async {
                  try {
                    await _pickMediaFiles(groupKey);
                  } catch (error) {
                    _showErrorSnack('Не удалось открыть галерею: $error');
                  }
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  decoration: BoxDecoration(
                    color: kInputBgColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: kBorderColor),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 56, color: kGreyColor),
                        SizedBox(height: 6),
                        MyText(
                          text: 'Фото / Видео',
                          size: 12,
                          color: kGreyColor,
                          weight: FontWeight.w700,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final fileIndex = index - 1;
            final item = files[fileIndex];
            final selected = _mediaGroupSelectedIndexes.contains(fileIndex);
            final hasInspection = _mediaInspectionHasData(item.inspection);

            return InkWell(
              key: ValueKey('media-item-$groupKey-${item.id}'),
              onLongPress: () {
                if (!_mediaGroupSelectMode) {
                  setState(() {
                    _mediaGroupSelectMode = true;
                    _mediaGroupSelectedIndexes = {fileIndex};
                  });
                  return;
                }
                _toggleMediaGroupSelection(fileIndex);
              },
              onTap: () {
                if (_mediaGroupSelectMode) {
                  _toggleMediaGroupSelection(fileIndex);
                  return;
                }
                _openMediaGroupLightbox(
                  groupKey: groupKey,
                  initialIndex: fileIndex,
                );
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                decoration: BoxDecoration(
                  color: selected
                      ? kSecondaryColor.withValues(alpha: 0.08)
                      : kWhiteColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected
                        ? kSecondaryColor.withValues(alpha: 0.45)
                        : kBorderColor,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          color: kLightGreyColor,
                          child: item.isImage
                              ? _uploadedImageWidget(
                                  item,
                                  fit: BoxFit.cover,
                                  cacheWidth: 720,
                                  cacheHeight: 720,
                                )
                              : Icon(
                                  item.isVideo
                                      ? Icons.videocam_outlined
                                      : Icons.insert_drive_file_outlined,
                                  color: kGreyColor,
                                ),
                        ),
                      ),
                    ),
                    if (_mediaGroupSelectMode)
                      Positioned(
                        left: 10,
                        top: 10,
                        child: Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: selected ? kSecondaryColor : kWhiteColor,
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: selected ? kSecondaryColor : kBorderColor,
                            ),
                          ),
                          alignment: Alignment.center,
                          child: selected
                              ? const Icon(
                                  Icons.check_rounded,
                                  size: 14,
                                  color: kWhiteColor,
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                    if (!_mediaGroupSelectMode)
                      Positioned(
                        left: 10,
                        top: 10,
                        child: InkWell(
                          onTap: () => _deleteMediaInGroup(
                            groupKey: groupKey,
                            indexes: [fileIndex],
                          ),
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.55),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: kWhiteColor,
                            ),
                          ),
                        ),
                      ),
                    if (!_mediaGroupSelectMode)
                      Positioned(
                        right: 10,
                        top: 10,
                        child: InkWell(
                          onTap: () => _openMediaInspectionEditor(
                            groupKey: groupKey,
                            index: fileIndex,
                          ),
                          borderRadius: BorderRadius.circular(999),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.62),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  hasInspection
                                      ? Icons.edit_note_rounded
                                      : Icons.add_rounded,
                                  size: 16,
                                  color: kWhiteColor,
                                ),
                                const SizedBox(width: 4),
                                const MyText(
                                  text: 'ЗАМЕТКА',
                                  size: 11,
                                  color: kWhiteColor,
                                  weight: FontWeight.w700,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _stepMedia() {
    final requiredGroups = _mediaGroupsConfig
        .where((config) => config.required)
        .toList();
    final optionalGroups = _mediaGroupsConfig
        .where((config) => !config.required)
        .toList();
    final requiredFilled = requiredGroups.where((config) {
      final state = _mediaState[config.key];
      return state != null && _groupHasCoverage(state);
    }).length;

    if (_activeMediaGroupKey != null) {
      return _mediaGroupEditor();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 10, bottom: 8),
          child: MyText(
            text: 'ОБЯЗАТЕЛЬНЫЕ · $requiredFilled/${requiredGroups.length}',
            size: 13,
            color: kGreyColor,
            weight: FontWeight.w700,
          ),
        ),
        ...requiredGroups.map((config) {
          final state = _mediaState[config.key]!;
          return _mediaGroupListRow(state);
        }),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.only(left: 10, bottom: 8),
          child: MyText(
            text: 'ДОПОЛНИТЕЛЬНЫЕ',
            size: 13,
            color: kGreyColor,
            weight: FontWeight.w700,
          ),
        ),
        ...optionalGroups.map((config) {
          final state = _mediaState[config.key]!;
          return _mediaGroupListRow(state);
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

  void _openSummarySectionEditor(String title) {
    final stepId = _summaryTitleToStepId[title];
    if (stepId == null || stepId.trim().isEmpty) return;
    final mediaGroup = stepId == 'media'
        ? _summaryTitleToGroupKey[title]
        : null;
    _navigateToStepFromSummary(stepId, mediaGroupKey: mediaGroup);
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
        children: files.asMap().entries.map((entry) {
          final index = entry.key;
          final file = entry.value;
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: () => _openMediaGroupLightbox(
                groupKey: groupKey,
                initialIndex: index,
              ),
              child: Container(
                width: 74,
                height: 74,
                color: kLightGreyColor,
                child: file.isImage
                    ? _uploadedImageWidget(
                        file,
                        fit: BoxFit.cover,
                        cacheWidth: 220,
                        cacheHeight: 220,
                      )
                    : Icon(
                        file.isVideo
                            ? Icons.videocam_outlined
                            : Icons.insert_drive_file_outlined,
                        color: kGreyColor,
                      ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _summaryNoDamageMediaCard() {
    final cleanItems = <Map<String, dynamic>>[];
    for (final entry in _mediaState.entries) {
      final groupKey = entry.key;
      final state = entry.value;
      for (var index = 0; index < state.files.length; index++) {
        final file = state.files[index];
        if (_mediaItemHasIssue(file)) continue;
        cleanItems.add({'groupKey': groupKey, 'index': index, 'file': file});
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
            children: cleanItems.map((entry) {
              final file = entry['file'] as _UploadedItem;
              final groupKey = (entry['groupKey'] ?? '').toString();
              final index = entry['index'] as int? ?? 0;
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () => _openMediaGroupLightbox(
                    groupKey: groupKey,
                    initialIndex: index,
                  ),
                  child: Container(
                    width: 74,
                    height: 74,
                    color: kLightGreyColor,
                    child: file.isImage
                        ? _uploadedImageWidget(
                            file,
                            fit: BoxFit.cover,
                            cacheWidth: 220,
                            cacheHeight: 220,
                          )
                        : Icon(
                            file.isVideo
                                ? Icons.videocam_outlined
                                : Icons.insert_drive_file_outlined,
                            color: kGreyColor,
                          ),
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
    final editable = _summaryTitleToStepId.containsKey(title);

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
              if (editable)
                TextButton(
                  onPressed: () => _openSummarySectionEditor(title),
                  style: TextButton.styleFrom(
                    minimumSize: Size.zero,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'ред.',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: kSecondaryColor,
                    ),
                  ),
                ),
              if (editable) const SizedBox(width: 4),
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
    final inMediaGroupEditor = isMediaStep && _activeMediaGroupKey != null;
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
        if (!inMediaGroupEditor)
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
                      MyText(
                        text: step.title,
                        size: 15,
                        weight: FontWeight.w700,
                      ),
                      const SizedBox(height: 2),
                      MyText(
                        text: step.description,
                        size: 11,
                        color: kGreyColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        if (!inMediaGroupEditor) const SizedBox(height: 12),
        _stepContent(),
        if (!inMediaGroupEditor && isVehicleStep && !canVehicleContinue) ...[
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
        if (!inMediaGroupEditor && isMediaStep && !canMediaContinue) ...[
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
        if (!inMediaGroupEditor &&
            isTestDriveStep &&
            !canTestDriveContinue) ...[
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
        if (!inMediaGroupEditor && isSummaryStep && !canSummaryFinish) ...[
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
        if (!inMediaGroupEditor) ...[
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
          await _handleSectionBack();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () {
              if (_editingSection) {
                _handleSectionBack();
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
          controller: _pageScrollController,
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
    this.partInspection = const _MediaPartInspection(),
  });

  final _MediaGroupConfig config;
  final bool hasIssue;
  final String note;
  final String rawUrls;
  final List<_UploadedItem> files;
  final _MediaPartInspection partInspection;

  _MediaGroupState copyWith({
    bool? hasIssue,
    String? note,
    String? rawUrls,
    List<_UploadedItem>? files,
    _MediaPartInspection? partInspection,
  }) {
    return _MediaGroupState(
      config: config,
      hasIssue: hasIssue ?? this.hasIssue,
      note: note ?? this.note,
      rawUrls: rawUrls ?? this.rawUrls,
      files: files ?? this.files,
      partInspection: partInspection ?? this.partInspection,
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

class _MediaPartInspection {
  const _MediaPartInspection({
    this.noDamage = false,
    this.tags = const [],
    this.note = '',
    this.elementType,
    this.audioRecordings = const [],
    this.paintFrom,
    this.paintTo,
    this.tagPhotos = const {},
    this.isDraft = true,
  });

  final bool noDamage;
  final List<String> tags;
  final String note;
  final String? elementType;
  final List<String> audioRecordings;
  final double? paintFrom;
  final double? paintTo;
  final Map<String, List<String>> tagPhotos;
  final bool isDraft;

  _MediaPartInspection copyWith({
    bool? noDamage,
    List<String>? tags,
    String? note,
    String? elementType,
    List<String>? audioRecordings,
    double? paintFrom,
    double? paintTo,
    Map<String, List<String>>? tagPhotos,
    bool? isDraft,
  }) {
    return _MediaPartInspection(
      noDamage: noDamage ?? this.noDamage,
      tags: tags ?? this.tags,
      note: note ?? this.note,
      elementType: elementType ?? this.elementType,
      audioRecordings: audioRecordings ?? this.audioRecordings,
      paintFrom: paintFrom ?? this.paintFrom,
      paintTo: paintTo ?? this.paintTo,
      tagPhotos: tagPhotos ?? this.tagPhotos,
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
      'paintFrom': paintFrom,
      'paintTo': paintTo,
      'tagPhotos': tagPhotos,
      if (paintFrom != null && paintTo != null)
        'paintThickness': {'from': paintFrom, 'to': paintTo},
      'isDraft': isDraft,
    };
  }
}

class _MediaInspection {
  const _MediaInspection({
    this.noDamage = false,
    this.tags = const [],
    this.note = '',
    this.elementType,
    this.audioRecordings = const [],
    this.paintFrom,
    this.paintTo,
    this.isDraft = false,
  });

  final bool noDamage;
  final List<String> tags;
  final String note;
  final String? elementType;
  final List<String> audioRecordings;
  final double? paintFrom;
  final double? paintTo;
  final bool isDraft;

  _MediaInspection copyWith({
    bool? noDamage,
    List<String>? tags,
    String? note,
    String? elementType,
    List<String>? audioRecordings,
    double? paintFrom,
    double? paintTo,
    bool? isDraft,
  }) {
    return _MediaInspection(
      noDamage: noDamage ?? this.noDamage,
      tags: tags ?? this.tags,
      note: note ?? this.note,
      elementType: elementType ?? this.elementType,
      audioRecordings: audioRecordings ?? this.audioRecordings,
      paintFrom: paintFrom ?? this.paintFrom,
      paintTo: paintTo ?? this.paintTo,
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
      'paintFrom': paintFrom,
      'paintTo': paintTo,
      if (paintFrom != null && paintTo != null)
        'paintThickness': {'from': paintFrom, 'to': paintTo},
      'isDraft': isDraft,
    };
  }
}

class _UploadedItem {
  const _UploadedItem({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.dataUrl,
    this.inspection = const _MediaInspection(),
  });

  final String id;
  final String name;
  final String mimeType;
  final String dataUrl;
  final _MediaInspection inspection;

  _UploadedItem copyWith({
    String? id,
    String? name,
    String? mimeType,
    String? dataUrl,
    _MediaInspection? inspection,
  }) {
    return _UploadedItem(
      id: id ?? this.id,
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
