import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class BrandCatalog {
  final List<BrandItem> items;
  final List<String> names;
  final Map<String, String> rusByName;
  final Map<String, int> idByName;

  BrandCatalog({
    required this.items,
    required this.names,
    required this.rusByName,
    required this.idByName,
  });
}

class BrandItem {
  final int id;
  final String name;
  final String nameRus;

  BrandItem({required this.id, required this.name, required this.nameRus});
}

class ModelItem {
  final int id;
  final int brandId;
  final String model;
  final String modelRus;

  ModelItem({
    required this.id,
    required this.brandId,
    required this.model,
    required this.modelRus,
  });
}

class FrameItem {
  final int id;
  final String frame;

  FrameItem({required this.id, required this.frame});
}

class PhotoItem {
  final int id;
  final String size;
  final String urlX1;
  final String urlX2;

  PhotoItem({
    required this.id,
    required this.size,
    required this.urlX1,
    required this.urlX2,
  });
}

class RestylingItem {
  final int id;
  final String restyling;
  final int? yearStart;
  final int? yearEnd;
  final List<FrameItem> frames;
  final List<PhotoItem> photos;

  RestylingItem({
    required this.id,
    required this.restyling,
    required this.yearStart,
    required this.yearEnd,
    required this.frames,
    required this.photos,
  });
}

class GenerationItem {
  final int id;
  final int modelCarId;
  final int generation;
  final List<FrameItem> frames;
  final List<RestylingItem> restylings;

  GenerationItem({
    required this.id,
    required this.modelCarId,
    required this.generation,
    required this.frames,
    required this.restylings,
  });

  String get label => 'Поколение $generation';
}

class StorageApi {
  static const String _endpoint = 'https://podbor-av.ru.tuna.am';

  static Future<BrandCatalog> fetchBrandCatalog({
    String search = '',
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final payload = <String, dynamic>{
      'id': 0,
      'method': 'Storage.GetBrand',
      'params': {'search': search},
    };
    final bytes = utf8.encode(json.encode(payload));

    final response = await http
        .post(
          Uri.parse(_endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Content-Length': bytes.length.toString(),
          },
          body: bytes,
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    if (data['response'] != 'ok') {
      throw Exception('Bad response');
    }

    final result = data['result'];
    if (result is! List) {
      return BrandCatalog(
        items: const [],
        names: const [],
        rusByName: const {},
        idByName: const {},
      );
    }

    final names = <String>{};
    final items = <BrandItem>[];
    final rusByName = <String, String>{};
    final idByName = <String, int>{};
    for (final item in result) {
      if (item is Map && item['name'] is String && item['id'] is int) {
        final name = item['name'] as String;
        final id = item['id'] as int;
        final nameRus = item['nameRus'] is String
            ? item['nameRus'] as String
            : '';
        names.add(name);
        idByName[name] = id;
        if (nameRus.isNotEmpty) {
          rusByName[name] = nameRus;
        }
        items.add(BrandItem(id: id, name: name, nameRus: nameRus));
      }
    }
    final list = names.toList()..sort();
    return BrandCatalog(
      items: items,
      names: list,
      rusByName: rusByName,
      idByName: idByName,
    );
  }

  static Future<List<String>> fetchBrands({
    String search = '',
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final catalog = await fetchBrandCatalog(search: search, timeout: timeout);
    return catalog.names;
  }

  static Future<List<ModelItem>> fetchModels({
    required int brandId,
    String search = '',
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final payload = <String, dynamic>{
      'id': 0,
      'method': 'Storage.GetModelCar',
      'params': {'brandId': brandId, 'search': search},
    };
    final bytes = utf8.encode(json.encode(payload));
    final response = await http
        .post(
          Uri.parse(_endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Content-Length': bytes.length.toString(),
          },
          body: bytes,
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    if (data['response'] != 'ok') {
      throw Exception('Bad response');
    }

    final result = data['result'];
    if (result is! List) return [];
    final items = <ModelItem>[];
    for (final item in result) {
      if (item is Map &&
          item['id'] is int &&
          item['brandId'] is int &&
          item['model'] is String) {
        items.add(
          ModelItem(
            id: item['id'] as int,
            brandId: item['brandId'] as int,
            model: item['model'] as String,
            modelRus: item['modelRus'] is String
                ? item['modelRus'] as String
                : '',
          ),
        );
      }
    }
    items.sort((a, b) => a.model.compareTo(b.model));
    return items;
  }

  static Future<List<GenerationItem>> fetchGenerations({
    required int modelCarId,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final payload = <String, dynamic>{
      'id': 0,
      'method': 'Storage.GetModelGeneration',
      'params': {'modelCarId': modelCarId},
    };
    final bytes = utf8.encode(json.encode(payload));
    final response = await http
        .post(
          Uri.parse(_endpoint),
          headers: {
            'Content-Type': 'application/json',
            'Content-Length': bytes.length.toString(),
          },
          body: bytes,
        )
        .timeout(timeout);

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final data = json.decode(response.body) as Map<String, dynamic>;
    if (data['response'] != 'ok') {
      throw Exception('Bad response');
    }

    final result = data['result'];
    if (result is! List) return [];
    final items = <GenerationItem>[];
    for (final item in result) {
      if (item is! Map || item['id'] is! int) continue;
      final frames = _parseFrames(item['frames']);
      final restylings = _parseRestylings(item['restylings']);
      items.add(
        GenerationItem(
          id: item['id'] as int,
          modelCarId: item['modelCarId'] is int ? item['modelCarId'] as int : 0,
          generation: item['generation'] is int ? item['generation'] as int : 0,
          frames: frames,
          restylings: restylings,
        ),
      );
    }
    items.sort((a, b) => b.generation.compareTo(a.generation));
    return items;
  }

  static List<FrameItem> _parseFrames(dynamic raw) {
    if (raw is! List) return [];
    final items = <FrameItem>[];
    for (final item in raw) {
      if (item is Map && item['id'] is int && item['frame'] is String) {
        items.add(FrameItem(id: item['id'] as int, frame: item['frame']));
      }
    }
    return items;
  }

  static int? _parseYear(dynamic raw) {
    if (raw is Map && raw['date'] is String) {
      final date = raw['date'] as String;
      if (date.length >= 4) {
        return int.tryParse(date.substring(0, 4));
      }
    }
    return null;
  }

  static List<PhotoItem> _parsePhotos(dynamic raw) {
    if (raw is! List) return [];
    final items = <PhotoItem>[];
    for (final item in raw) {
      if (item is Map &&
          item['id'] is int &&
          item['size'] is String &&
          item['urlX1'] is String &&
          item['urlX2'] is String) {
        items.add(
          PhotoItem(
            id: item['id'] as int,
            size: item['size'] as String,
            urlX1: item['urlX1'] as String,
            urlX2: item['urlX2'] as String,
          ),
        );
      }
    }
    return items;
  }

  static List<RestylingItem> _parseRestylings(dynamic raw) {
    if (raw is! List) return [];
    final items = <RestylingItem>[];
    for (final item in raw) {
      if (item is! Map || item['id'] is! int || item['restyling'] == null) {
        continue;
      }
      final frames = _parseFrames(item['frames']);
      final photos = _parsePhotos(item['photos']);
      items.add(
        RestylingItem(
          id: item['id'] as int,
          restyling: item['restyling'].toString(),
          yearStart: _parseYear(item['yearStart']),
          yearEnd: _parseYear(item['yearEnd']),
          frames: frames,
          photos: photos,
        ),
      );
    }
    return items;
  }
}
