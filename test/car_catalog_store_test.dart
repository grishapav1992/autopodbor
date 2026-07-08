import 'dart:convert';
import 'dart:io';

import 'package:flutter_application_1/data/api/storage_api_models.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter_application_1/data/services/car_catalog_store_io.dart';
import 'package:flutter_application_1/data/services/car_catalog_store_web.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('IoCarCatalogStore', () {
    late Directory root;
    late IoCarCatalogStore store;

    setUp(() async {
      root = await Directory.systemTemp.createTemp('car_catalog_store_test_');
      store = IoCarCatalogStore(rootOverride: root);
    });

    tearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    test('round-trip брендов сохраняет порядок бэка', () async {
      final items = [
        BrandItem(id: 2, name: 'Lada', nameRus: 'Лада'),
        BrandItem(id: 1, name: 'Audi', nameRus: 'Ауди'),
      ];
      expect(await store.saveBrands(items), isTrue);
      final entry = await store.loadBrands();
      expect(entry, isNotNull);
      expect(entry!.savedAtMs, greaterThan(0));
      expect(entry.items.map((b) => b.name).toList(), ['Lada', 'Audi']);
    });

    test('round-trip моделей и поколений по id', () async {
      await store.saveModels(7, [
        ModelItem(id: 71, brandId: 7, model: 'Vesta', modelRus: 'Веста'),
      ]);
      await store.saveGenerations(71, [
        GenerationItem(
          id: 1,
          modelCarId: 71,
          generation: 2,
          frames: const [],
          restylings: [
            RestylingItem(
              id: 5,
              restyling: '',
              yearStart: 2022,
              yearEnd: null,
              frames: [FrameItem(id: 9, frame: 'GFL')],
              photos: const [],
            ),
          ],
        ),
      ]);

      expect((await store.loadModels(7))!.items.single.model, 'Vesta');
      expect(await store.loadModels(8), isNull);
      final gens = await store.loadGenerations(71);
      expect(gens!.items.single.restylings.single.frames.single.frame, 'GFL');
      expect(store.supportsGenerations, isTrue);
    });

    test('пустой список — валидный кэш (модель без поколений)', () async {
      await store.saveGenerations(42, const []);
      final entry = await store.loadGenerations(42);
      expect(entry, isNotNull);
      expect(entry!.items, isEmpty);
    });

    test('битый JSON удаляется и считается отсутствующим', () async {
      await store.saveModels(5, [
        ModelItem(id: 51, brandId: 5, model: 'X', modelRus: ''),
      ]);
      final file = File(
        '${root.path}/${IoCarCatalogStore.dirName}/models_5.json',
      );
      await file.writeAsString('{оборванный json');

      expect(await store.loadModels(5), isNull);
      expect(
        await file.exists(),
        isFalse,
        reason: 'битый файл должен удаляться',
      );
    });

    test('недописанный .tmp не мешает и перезаписывается', () async {
      final dir = Directory('${root.path}/${IoCarCatalogStore.dirName}');
      await dir.create(recursive: true);
      await File('${dir.path}/brands.json.tmp').writeAsString('{мусор');

      await store.saveBrands([BrandItem(id: 1, name: 'Kia', nameRus: '')]);
      final entry = await store.loadBrands();
      expect(entry!.items.single.name, 'Kia');
    });

    test('каталоги старых версий схемы сметаются', () async {
      final old = Directory('${root.path}/car_catalog_v0');
      await old.create(recursive: true);
      await File('${old.path}/brands.json').writeAsString('[]');

      await store.saveBrands([BrandItem(id: 1, name: 'Kia', nameRus: '')]);

      expect(await old.exists(), isFalse);
      expect(
        await Directory('${root.path}/${IoCarCatalogStore.dirName}').exists(),
        isTrue,
      );
    });

    test('savedAtMs читается из файла, а не из момента чтения', () async {
      final dir = Directory('${root.path}/${IoCarCatalogStore.dirName}');
      await dir.create(recursive: true);
      await File('${dir.path}/brands.json').writeAsString(
        jsonEncode({
          'v': 1,
          'savedAtMs': 123456,
          'items': [
            {'id': 1, 'name': 'Kia', 'nameRus': ''},
          ],
        }),
      );
      final entry = await store.loadBrands();
      expect(entry!.savedAtMs, 123456);
    });
  });

  group('WebCarCatalogStore (prefs-only)', () {
    late WebCarCatalogStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      UserSimplePreferences.pref = null;
      await UserSimplePreferences.init();
      store = WebCarCatalogStore();
    });

    test('round-trip брендов и моделей', () async {
      expect(
        await store.saveBrands([BrandItem(id: 1, name: 'Kia', nameRus: 'Киа')]),
        isTrue,
      );
      expect((await store.loadBrands())!.items.single.nameRus, 'Киа');

      await store.saveModels(1, [
        ModelItem(id: 11, brandId: 1, model: 'Rio', modelRus: 'Рио'),
      ]);
      await store.saveModels(2, [
        ModelItem(id: 21, brandId: 2, model: 'Polo', modelRus: ''),
      ]);
      expect((await store.loadModels(1))!.items.single.model, 'Rio');
      expect((await store.loadModels(2))!.items.single.model, 'Polo');
      expect(await store.loadModels(3), isNull);
    });

    test('поколения не персистятся', () async {
      expect(store.supportsGenerations, isFalse);
      expect(
        await store.saveGenerations(1, [
          GenerationItem(
            id: 1,
            modelCarId: 1,
            generation: 1,
            frames: const [],
            restylings: const [],
          ),
        ]),
        isFalse,
      );
      expect(await store.loadGenerations(1), isNull);
    });

    test('без инициализированных prefs — тихий no-op', () async {
      UserSimplePreferences.pref = null;
      expect(await store.loadBrands(), isNull);
      expect(
        await store.saveBrands([BrandItem(id: 1, name: 'Kia', nameRus: '')]),
        isFalse,
      );
    });
  });
}
