import 'dart:convert';

import 'package:http/http.dart' as http;

class BrandInfo {
  BrandInfo({required this.name, this.nameRus});

  final String name;
  final String? nameRus;
}

class BrandApi {
  BrandApi({
    this.endpoint = 'https://podbor-av.ru.tuna.am',
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String endpoint;
  final http.Client _client;

  Future<List<BrandInfo>> fetchBrands({String search = ''}) async {
    final uri = Uri.parse(endpoint);
    final body = {
      'id': 0,
      'method': 'Storage.GetBrand',
      'params': {'search': search},
    };

    final payload = jsonEncode(body);
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': payload.length.toString(),
      },
      body: payload,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    final list = _extractList(decoded);
    final items = <BrandInfo>[];
    for (final item in list) {
      if (item is Map && item['name'] is String) {
        final en = (item['name'] as String).trim();
        if (en.isEmpty) continue;
        final ru = item['nameRus'] is String
            ? (item['nameRus'] as String).trim()
            : null;
        items.add(BrandInfo(name: en, nameRus: ru?.isEmpty ?? true ? null : ru));
      }
    }
    items.sort((a, b) => a.name.compareTo(b.name));
    return items;
  }

  Future<List<String>> fetchModels({required String brandName}) async {
    final trimmed = brandName.trim();
    if (trimmed.isEmpty) return const [];

    final uri = Uri.parse(endpoint);
    final body = {
      'id': 0,
      'method': 'Storage.GetModelCar',
      'params': {'value': trimmed},
    };

    final payload = jsonEncode(body);
    final response = await _client.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': payload.length.toString(),
      },
      body: payload,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body);
    final list = _extractList(decoded);
    final names = <String>[];
    for (final item in list) {
      if (item is Map && item['name'] is String) {
        final en = item['name'] as String;
        if (en.trim().isNotEmpty) names.add(en);
      }
    }
    names.sort();
    return names;
  }

  List<dynamic> _extractList(dynamic decoded) {
    if (decoded is List) return decoded;
    if (decoded is Map) {
      final candidates = ['result', 'data', 'brands', 'items'];
      for (final key in candidates) {
        final value = decoded[key];
        if (value is List) return value;
      }
    }
    return const [];
  }
}
