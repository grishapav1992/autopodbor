import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:flutter_application_1/data/preferences/user_preferences.dart';

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

class AuthStartResult {
  final String callPhone;
  final String? sessionId;

  const AuthStartResult({required this.callPhone, this.sessionId});
}

class AuthVerifyResult {
  final String? accessToken;
  final String? refreshToken;

  const AuthVerifyResult({this.accessToken, this.refreshToken});

  bool get hasTokens =>
      accessToken != null &&
      accessToken!.isNotEmpty &&
      refreshToken != null &&
      refreshToken!.isNotEmpty;
}

class CreateRequestResult {
  final int id;
  final String requestNumber;

  const CreateRequestResult({required this.id, required this.requestNumber});
}

class StorageApi {
  static const String _endpoint = 'https://podbor-av.ru.tuna.am';

  static int? _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  static String _extractString(
    Map<String, dynamic> source,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = source[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }

  static Map<String, dynamic> _asMap(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((key, value) => MapEntry(key.toString(), value));
    }
    return const <String, dynamic>{};
  }

  static Future<Map<String, dynamic>> _postRpc({
    required String method,
    required Map<String, dynamic> params,
    Duration timeout = const Duration(seconds: 12),
    bool includeAuth = true,
    bool allowRefresh = true,
  }) async {
    final requestParams = Map<String, dynamic>.from(params);
    final payload = <String, dynamic>{
      'id': 0,
      'method': method,
      'params': requestParams,
    };
    final bytes = utf8.encode(json.encode(payload));
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Content-Length': bytes.length.toString(),
    };
    if (includeAuth) {
      final accessToken = await UserSimplePreferences.getAccessToken();
      if (accessToken != null && accessToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $accessToken';
      }
    }
    final response = await http
        .post(
          Uri.parse(_endpoint),
          headers: headers,
          body: bytes,
        )
        .timeout(timeout);
    if (response.statusCode == 401 && includeAuth && allowRefresh) {
      final refreshed = await _tryRefreshTokens();
      if (refreshed) {
        return _postRpc(
          method: method,
          params: params,
          timeout: timeout,
          includeAuth: includeAuth,
          allowRefresh: false,
        );
      }
    }
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }
    final data = _asMap(json.decode(response.body));
    final responseFlag = data['response']?.toString().toLowerCase() ?? '';
    if (responseFlag != 'ok') {
      if (includeAuth &&
          allowRefresh &&
          responseFlag.contains('unauthor')) {
        final refreshed = await _tryRefreshTokens();
        if (refreshed) {
          return _postRpc(
            method: method,
            params: params,
            timeout: timeout,
            includeAuth: includeAuth,
            allowRefresh: false,
          );
        }
      }
      throw Exception('Bad response');
    }
    return data;
  }

  static Future<bool> _tryRefreshTokens() async {
    try {
      final refreshToken = await UserSimplePreferences.getRefreshToken();
      if (refreshToken == null || refreshToken.isEmpty) return false;
      final data = await _postRpc(
        method: 'RefreshToken',
        params: {'refreshToken': refreshToken},
        includeAuth: false,
        allowRefresh: false,
      );
      final result = _asMap(data['result']);
      final accessToken = _extractString(result, [
        'accessToken',
        'access_token',
        'token',
        'access',
      ]);
      final newRefreshToken = _extractString(result, [
        'refreshToken',
        'refresh_token',
        'refresh',
      ]);
      if (accessToken.isEmpty || newRefreshToken.isEmpty) return false;
      await UserSimplePreferences.setAuthTokens(
        accessToken: accessToken,
        refreshToken: newRefreshToken,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<AuthStartResult> auth({
    required String phone,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final data = await _postRpc(
      method: 'storage.auth',
      params: {'phone': phone},
      timeout: timeout,
      includeAuth: false,
    );
    final result = _asMap(data['result']);
    final callPhone = _extractString(result, [
      'callToPhone',
      'callPhone',
      'phoneForCall',
      'authPhone',
      'targetPhone',
      'phone',
    ]);
    if (callPhone.isEmpty) {
      throw Exception('Call phone is empty');
    }
    final sessionId = _extractString(result, ['sessionId', 'authId', 'id']);
    return AuthStartResult(
      callPhone: callPhone,
      sessionId: sessionId.isEmpty ? null : sessionId,
    );
  }

  static Future<AuthVerifyResult> authVerify({
    required String phone,
    String? sessionId,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final params = <String, dynamic>{'phone': phone};
    if (sessionId != null && sessionId.isNotEmpty) {
      params['sessionId'] = sessionId;
    }
    final data = await _postRpc(
      method: 'storage.authVerify',
      params: params,
      timeout: timeout,
      includeAuth: false,
    );
    final result = _asMap(data['result']);
    final accessToken = _extractString(result, [
      'accessToken',
      'access_token',
      'token',
      'access',
    ]);
    final refreshToken = _extractString(result, [
      'refreshToken',
      'refresh_token',
      'refresh',
    ]);
    return AuthVerifyResult(
      accessToken: accessToken.isEmpty ? null : accessToken,
      refreshToken: refreshToken.isEmpty ? null : refreshToken,
    );
  }

  static Future<CreateRequestResult> createRequest({
    required String requestType,
    required List<Map<String, dynamic>> requestCars,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final data = await _postRpc(
      method: 'Storage.CreateRequest',
      params: {
        'requestType': requestType,
        'requestCars': requestCars,
      },
      timeout: timeout,
    );
    final result = _asMap(data['result']);
    final id = _asInt(result['id']) ?? 0;
    final requestNumber = _extractString(result, [
      'requestNumber',
      'request_number',
      'number',
    ]);
    return CreateRequestResult(id: id, requestNumber: requestNumber);
  }

  static Future<List<Map<String, dynamic>>> getRequests({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final data = await _postRpc(
      method: 'Storage.GetRequest',
      params: const {},
      timeout: timeout,
    );
    final result = data['result'];
    if (result is List) {
      return result
          .whereType<Map>()
          .map((e) => _asMap(e))
          .toList();
    }
    if (result is Map) {
      final map = _asMap(result);
      final list = map['items'] ??
          map['requests'] ??
          map['data'] ??
          map['list'];
      if (list is List) {
        return list
            .whereType<Map>()
            .map((e) => _asMap(e))
            .toList();
      }
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getRequestCars({
    required int requestId,
    Duration timeout = const Duration(seconds: 12),
  }) async {
    final data = await _postRpc(
      method: 'Storage.GetRequestCar',
      params: {'requestId': requestId},
      timeout: timeout,
    );
    final result = data['result'];
    if (result is List) {
      return result
          .whereType<Map>()
          .map((e) => _asMap(e))
          .toList();
    }
    if (result is Map) {
      final map = _asMap(result);
      final list = map['items'] ??
          map['cars'] ??
          map['requestCars'] ??
          map['data'] ??
          map['list'];
      if (list is List) {
        return list
            .whereType<Map>()
            .map((e) => _asMap(e))
            .toList();
      }
    }
    return [];
  }

  static Future<BrandCatalog> fetchBrandCatalog({
    String search = '',
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final data = await _postRpc(
      method: 'Storage.GetBrand',
      params: {'search': search},
      timeout: timeout,
    );

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
      if (item is Map && item['name'] is String) {
        final name = item['name'] as String;
        final id = _asInt(item['id']);
        if (id == null) continue;
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
    final data = await _postRpc(
      method: 'Storage.GetModelCar',
      params: {'brandId': brandId, 'search': search},
      timeout: timeout,
    );

    final result = data['result'];
    if (result is! List) return [];
    final items = <ModelItem>[];
    for (final item in result) {
      if (item is Map && item['model'] is String) {
        final id = _asInt(item['id']);
        final brand = _asInt(item['brandId']);
        if (id == null || brand == null) continue;
        items.add(
          ModelItem(
            id: id,
            brandId: brand,
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
    final data = await _postRpc(
      method: 'Storage.GetModelGeneration',
      params: {'modelCarId': modelCarId},
      timeout: timeout,
    );

    final result = data['result'];
    if (result is! List) return [];
    final items = <GenerationItem>[];
    for (final item in result) {
      if (item is! Map) continue;
      final id = _asInt(item['id']);
      if (id == null) continue;
      final frames = _parseFrames(item['frames']);
      final restylings = _parseRestylings(item['restylings']);
      items.add(
        GenerationItem(
          id: id,
          modelCarId: _asInt(item['modelCarId']) ?? 0,
          generation: _asInt(item['generation']) ?? 0,
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
      if (item is Map && item['frame'] is String) {
        final id = _asInt(item['id']);
        if (id == null) continue;
        items.add(FrameItem(id: id, frame: item['frame']));
      }
    }
    return items;
  }

  static int? _parseYear(dynamic raw) {
    if (raw is int) return raw;
    if (raw is String && raw.length >= 4) {
      return int.tryParse(raw.substring(0, 4));
    }
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
          item['size'] is String &&
          item['urlX1'] is String &&
          item['urlX2'] is String) {
        final id = _asInt(item['id']);
        if (id == null) continue;
        items.add(
          PhotoItem(
            id: id,
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
      if (item is! Map || item['restyling'] == null) {
        continue;
      }
      final id = _asInt(item['id']);
      if (id == null) continue;
      final frames = _parseFrames(item['frames']);
      final photos = _parsePhotos(item['photos']);
      items.add(
        RestylingItem(
          id: id,
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

