part of 'spark_joy_create_report_screen.dart';

class _SparkJoyVehicleRegistry {
  const _SparkJoyVehicleRegistry._();

  static const List<String> engineTypes = [
    'Бензин',
    'Дизель',
    'Гибрид',
    'Электро',
    'Газ/Бензин',
  ];

  static const List<String> gearboxTypes = [
    'АКПП',
    'МКПП',
    'Робот',
    'Вариатор',
  ];

  static const List<String> driveTypes = ['Передний', 'Задний', 'Полный'];

  static const List<String> colors = [
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

  static const List<String> ownersCounts = ['1', '2', '3', '4+'];

  /// Опции дропдауна объёма двигателя (0.8…5.0 л, шаг 0.1) — единый
  /// источник для UI (`_stepParams`) и нормализатора AI-вывода
  /// (`parseVinParamsAiResult`), чтобы списки не разъезжались (иначе
  /// валидный объём молча отбрасывается при несовпадении).
  static final List<String> engineVolumeOptions = List<String>.generate(
    43,
    (i) => (0.8 + i * 0.1).toStringAsFixed(1),
  );

  static const List<_CarCatalogBrand> carCatalog = [
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
}
