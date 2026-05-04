import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

/// Result of decoding a VIN through an open data source (currently NHTSA
/// vPIC). Kept deliberately small: only the four fields that map onto
/// `characteristicsStep` in `Storage.PrepareSpecialistReport` plus a few
/// raw values for UI hints (suggesting a brand/model pick) and debug.
///
/// The wire format produced by [toCharacteristicsStepPatch] matches the
/// payload built by `_buildCharacteristicsStepPayload` in
/// `spark_joy_storage_helpers.dart`, so the patch can be merged into
/// the draft state directly and round-trip to the server unchanged.
class VinDecodeResult {
  /// Engine displacement in litres (e.g. 1.6, 2.0). Maps to the numeric
  /// `engineVolume` field. Server-side schema accepts a decimal number.
  final double? engineVolume;

  /// Russian fuel type label, must be one of `_SparkJoyVehicleRegistry.engineTypes`:
  /// 'Бензин', 'Дизель', 'Гибрид', 'Электро', 'Газ/Бензин'.
  final String? engineType;

  /// Russian gearbox label, must be one of `_SparkJoyVehicleRegistry.gearboxTypes`:
  /// 'АКПП', 'МКПП', 'Робот', 'Вариатор'.
  final String? transmission;

  /// Russian drivetrain label, must be one of `_SparkJoyVehicleRegistry.driveTypes`:
  /// 'Передний', 'Задний', 'Полный'.
  final String? driveType;

  /// Raw make from NHTSA (e.g. 'HYUNDAI'). Useful for selecting a brand
  /// in the car catalog picker before the user confirms.
  final String? make;

  /// Raw model from NHTSA (e.g. 'Elantra'). Same use as [make].
  final String? model;

  /// Decoded model year. NHTSA may return an early-cycle year (1982 for
  /// `C` instead of 2012) — the service performs a second pass with an
  /// explicit `modelyear` derived from the VIN's 10th character to
  /// resolve this ambiguity. The final value is the one we trust.
  final int? year;

  /// Engine description from NHTSA (e.g. 'DOHC MPI GAMMA'). Useful for
  /// the document reconciliation step — comparing against the engine
  /// model written in PTS/STS.
  final String? engineModel;

  /// 'NHTSA' for now. When we add fallbacks (api-cloud, local WMI dict,
  /// learned patterns) this lets the UI annotate the data origin and
  /// the analytics layer track decode quality per source.
  final String source;

  /// Non-fatal warnings from the decoder ('NHTSA returned no make',
  /// 'check digit invalid', etc). Surfaced in `_debug` for inspection.
  final List<String> warnings;

  const VinDecodeResult({
    this.engineVolume,
    this.engineType,
    this.transmission,
    this.driveType,
    this.make,
    this.model,
    this.year,
    this.engineModel,
    this.source = 'NHTSA',
    this.warnings = const [],
  });

  /// True if at least one characteristicsStep field was decoded. If
  /// false, callers should keep the form blank rather than overwriting
  /// user input with empty strings.
  bool get hasAnyCharacteristic =>
      engineVolume != null ||
      (engineType?.isNotEmpty ?? false) ||
      (transmission?.isNotEmpty ?? false) ||
      (driveType?.isNotEmpty ?? false);

  /// True iff this result represents a transient network/parse failure
  /// (timeout, socket error, malformed JSON) rather than a legitimate
  /// "NHTSA does not know this VIN" answer.
  ///
  /// Used by callers to decide whether deduplication caches should
  /// remember this VIN. Legitimate empty answers (Russian-built VINs
  /// like X9F/Z94/XTA — NHTSA returns ErrorCode=1,7,400 with no fields)
  /// SHOULD be cached: re-asking will give the same empty result and
  /// just costs latency. Network failures should NOT be cached: the
  /// next attempt may succeed if connectivity comes back.
  ///
  /// Markers come from `_decodeViaNhtsa`'s catch blocks — keep this
  /// matcher in sync with the strings emitted there.
  bool get isNetworkFailure {
    if (warnings.isEmpty) return false;
    return warnings.any(
      (w) => w.startsWith('NHTSA timeout') || w.startsWith('NHTSA error:'),
    );
  }

  /// Returns the subset of `characteristicsStep` fields that the VIN
  /// decoder was able to fill. Keys exactly match the JSON sent to the
  /// server in `Storage.PrepareSpecialistReport`. Fields the decoder
  /// could not determine are **omitted entirely** so the merge does not
  /// blow away whatever the user already typed (color, equipment,
  /// modelGenerationRestylingFrameId).
  Map<String, dynamic> toCharacteristicsStepPatch() {
    final patch = <String, dynamic>{};
    if (engineVolume != null) patch['engineVolume'] = engineVolume;
    if (engineType != null && engineType!.isNotEmpty) {
      patch['engineType'] = engineType;
    }
    if (transmission != null && transmission!.isNotEmpty) {
      patch['transmission'] = transmission;
    }
    if (driveType != null && driveType!.isNotEmpty) {
      patch['driveType'] = driveType;
    }
    return patch;
  }

  /// Full snapshot for caching (Hive/SharedPreferences/draft JSON).
  /// Symmetric with [fromJson]. Both characteristicsStep fields and
  /// raw NHTSA hints are preserved so the UI can later show "decoded
  /// from VIN as Hyundai Elantra 2012" without re-hitting the network.
  Map<String, dynamic> toJson() => <String, dynamic>{
    if (engineVolume != null) 'engineVolume': engineVolume,
    if (engineType != null) 'engineType': engineType,
    if (transmission != null) 'transmission': transmission,
    if (driveType != null) 'driveType': driveType,
    if (make != null) 'make': make,
    if (model != null) 'model': model,
    if (year != null) 'year': year,
    if (engineModel != null) 'engineModel': engineModel,
    'source': source,
    if (warnings.isNotEmpty) 'warnings': warnings,
  };

  factory VinDecodeResult.fromJson(Map<String, dynamic> json) {
    return VinDecodeResult(
      engineVolume: (json['engineVolume'] as num?)?.toDouble(),
      engineType: json['engineType'] as String?,
      transmission: json['transmission'] as String?,
      driveType: json['driveType'] as String?,
      make: json['make'] as String?,
      model: json['model'] as String?,
      year: (json['year'] as num?)?.toInt(),
      engineModel: json['engineModel'] as String?,
      source: (json['source'] as String?) ?? 'NHTSA',
      warnings: (json['warnings'] as List?)?.cast<String>() ?? const [],
    );
  }

  @override
  String toString() => 'VinDecodeResult(${toJson()})';
}

/// Decodes VINs against open data sources without going through the
/// backend. Two-pass NHTSA call, in-memory cache per app session.
///
/// Architecture note: when the server-side `DecodeVin` is reactivated
/// (it is currently a stub), callers should switch to
/// `StorageApi.decodeVin(vin: ...)` and delete this file's HTTP path.
/// The result model and the `toCharacteristicsStepPatch` contract stay
/// the same — only the data source moves server-side.
class VinDecoderService {
  VinDecoderService._();

  /// NHTSA's free, no-key vPIC endpoint. Returns 130+ fields per VIN;
  /// we keep only what maps to characteristicsStep + a few hints.
  static const String _nhtsaEndpoint =
      'https://vpic.nhtsa.dot.gov/api/vehicles/DecodeVinValues';

  /// Allowed VIN characters per ISO 3779 (no I, O, Q to avoid ambiguity
  /// with 1, 0, and similar). 17 chars total.
  static final RegExp _validVinPattern = RegExp(r'^[A-HJ-NPR-Z0-9]{17}$');

  /// Memoization keyed by the canonical (uppercased, trimmed) VIN. NHTSA
  /// has no rate limit for sane usage but we still cache to keep the
  /// VIN→form latency near-zero on second views of the same draft.
  static final Map<String, VinDecodeResult> _cache = {};

  /// Test seam: lets unit tests inject a mock client without booting
  /// the network. In production, [http.Client] is created per call.
  static http.Client Function() clientFactory = http.Client.new;

  /// Decode [vin] and return characteristicsStep-compatible fields.
  /// Returns `null` if the VIN is malformed (caller can show a hint
  /// rather than a network error). Network failures and partial decodes
  /// return a non-null result with [VinDecodeResult.warnings] populated.
  static Future<VinDecodeResult?> decode(
    String vin, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final canonical = vin.trim().toUpperCase();
    if (!_validVinPattern.hasMatch(canonical)) {
      developer.log(
        'VinDecoderService.decode: invalid VIN shape, skipping',
        name: 'VinDecoderService',
      );
      return null;
    }
    final cached = _cache[canonical];
    if (cached != null) return cached;

    final result = await _decodeViaNhtsa(canonical, timeout: timeout);
    if (result != null) _cache[canonical] = result;
    return result;
  }

  /// Force-refresh: bypass the cache and re-query the source. Useful
  /// when the user explicitly hits "повторить" after a network failure.
  static Future<VinDecodeResult?> refresh(
    String vin, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    _cache.remove(vin.trim().toUpperCase());
    return decode(vin, timeout: timeout);
  }

  /// Drops the entire in-memory cache. Called from logout flows.
  static void clearCache() => _cache.clear();

  /// Two-pass NHTSA call: first without `modelyear`, then — if NHTSA
  /// guessed a year before 2000 (early ISO cycle) — with the year
  /// derived from the VIN's 10th character. The second pass is what
  /// makes NHTSA actually return Make/Model/Engine for modern cars
  /// whose WMI is registered in the US (KMH, WBA, JTD, etc.).
  static Future<VinDecodeResult?> _decodeViaNhtsa(
    String vin, {
    required Duration timeout,
  }) async {
    final client = clientFactory();
    try {
      Map<String, dynamic>? row = await _fetchNhtsaRow(
        client,
        vin,
        modelYear: null,
        timeout: timeout,
      );
      if (row == null) {
        // Non-200 HTTP, malformed body, missing `Results` array — all
        // funnel here. We surface them as `isNetworkFailure=true` so
        // UI callers can rollback dedup caches and let the user retry.
        return const VinDecodeResult(
          warnings: ['NHTSA error: empty or malformed response'],
        );
      }

      final initialYear = _asInt(row['ModelYear']);
      // NHTSA falls back to the early-cycle year (1982 for code C) when
      // it cannot positively identify the manufacturer. Re-query with
      // the late-cycle year if we suspect ambiguity.
      final guessedYear = _yearFromVinPosition10(vin);
      final shouldRetry =
          guessedYear != null &&
          (initialYear == null || initialYear < 2000) &&
          guessedYear >= 2000;

      if (shouldRetry) {
        final retried = await _fetchNhtsaRow(
          client,
          vin,
          modelYear: guessedYear,
          timeout: timeout,
        );
        if (retried != null) row = retried;
      }

      return _mapNhtsaRow(row);
    } on TimeoutException {
      developer.log(
        'VinDecoderService: NHTSA timeout for $vin',
        name: 'VinDecoderService',
      );
      return const VinDecodeResult(warnings: ['NHTSA timeout']);
    } catch (e, st) {
      developer.log(
        'VinDecoderService: NHTSA error for $vin',
        name: 'VinDecoderService',
        error: e,
        stackTrace: st,
      );
      return VinDecodeResult(warnings: ['NHTSA error: $e']);
    } finally {
      client.close();
    }
  }

  static Future<Map<String, dynamic>?> _fetchNhtsaRow(
    http.Client client,
    String vin, {
    int? modelYear,
    required Duration timeout,
  }) async {
    final query = <String, String>{'format': 'json'};
    if (modelYear != null) query['modelyear'] = '$modelYear';
    final uri = Uri.parse(
      '$_nhtsaEndpoint/$vin',
    ).replace(queryParameters: query);

    final response = await client.get(uri).timeout(timeout);
    if (response.statusCode != 200) {
      developer.log(
        'VinDecoderService: NHTSA HTTP ${response.statusCode}',
        name: 'VinDecoderService',
      );
      return null;
    }
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic>) return null;
    final results = body['Results'];
    if (results is! List || results.isEmpty) return null;
    final row = results.first;
    if (row is! Map<String, dynamic>) return null;
    return row;
  }

  /// Pulls only the fields we care about and normalises them into the
  /// Russian enum vocabulary expected by `_buildCharacteristicsStepPayload`.
  static VinDecodeResult _mapNhtsaRow(Map<String, dynamic> row) {
    final warnings = <String>[];

    final errorCode = (row['ErrorCode'] as String?)?.trim() ?? '';
    if (errorCode.isNotEmpty && errorCode != '0') {
      // NHTSA encodes per-VIN warnings in `ErrorCode` as a comma list
      // (1=check digit, 7=manufacturer not registered, 8=no detail,
      // 12=year mismatch, 14=partial data, 400=invalid chars). We
      // surface the codes verbatim so callers can decide what to show.
      warnings.add('NHTSA ErrorCode=$errorCode');
    }

    return VinDecodeResult(
      engineVolume: _asDouble(row['DisplacementL']),
      engineType: _mapFuelType(row['FuelTypePrimary'] as String?),
      transmission: _mapTransmission(row['TransmissionStyle'] as String?),
      driveType: _mapDriveType(row['DriveType'] as String?),
      make: _nonEmpty(row['Make'] as String?),
      model: _nonEmpty(row['Model'] as String?),
      year: _asInt(row['ModelYear']),
      engineModel: _nonEmpty(row['EngineModel'] as String?),
      warnings: warnings,
    );
  }

  // ---------- enum mappers (NHTSA → spark_joy_vehicle_registry) ----------

  /// Maps NHTSA `FuelTypePrimary` to one of `engineTypes`. Returns null
  /// for empty / unknown — callers leave the field blank.
  static String? _mapFuelType(String? raw) {
    if (raw == null) return null;
    final v = raw.trim().toLowerCase();
    if (v.isEmpty) return null;
    if (v.contains('gasoline') || v.contains('petrol')) return 'Бензин';
    if (v.contains('diesel')) return 'Дизель';
    if (v.contains('electric') || v == 'bev' || v.contains('battery')) {
      return 'Электро';
    }
    if (v.contains('hybrid') || v == 'hev' || v == 'phev') return 'Гибрид';
    if (v.contains('cng') ||
        v.contains('lpg') ||
        v.contains('natural gas') ||
        v.contains('flexible') ||
        v.contains('flex fuel')) {
      return 'Газ/Бензин';
    }
    return null;
  }

  /// Maps NHTSA `TransmissionStyle` to one of `gearboxTypes`. NHTSA's
  /// strings vary ('Automatic', 'Manual/Standard', 'Continuously
  /// Variable Transmission (CVT)', 'Dual-Clutch Transmission (DCT)',
  /// 'Automated Manual Transmission (AMT)') so we match on substrings.
  static String? _mapTransmission(String? raw) {
    if (raw == null) return null;
    final v = raw.trim().toLowerCase();
    if (v.isEmpty) return null;
    if (v.contains('cvt') || v.contains('continuously variable')) {
      return 'Вариатор';
    }
    if (v.contains('dct') ||
        v.contains('dual-clutch') ||
        v.contains('amt') ||
        v.contains('automated manual')) {
      return 'Робот';
    }
    if (v.contains('automatic')) return 'АКПП';
    if (v.contains('manual')) return 'МКПП';
    return null;
  }

  /// Maps NHTSA `DriveType` to one of `driveTypes`. NHTSA returns
  /// values like 'FWD/Front-Wheel Drive', 'RWD/Rear-Wheel Drive',
  /// 'AWD/All-Wheel Drive', '4WD/4-Wheel Drive'.
  static String? _mapDriveType(String? raw) {
    if (raw == null) return null;
    final v = raw.trim().toLowerCase();
    if (v.isEmpty) return null;
    if (v.contains('fwd') || v.contains('front')) return 'Передний';
    if (v.contains('rwd') || v.contains('rear')) return 'Задний';
    if (v.contains('awd') ||
        v.contains('4wd') ||
        v.contains('all-wheel') ||
        v.contains('4-wheel') ||
        v.contains('four-wheel')) {
      return 'Полный';
    }
    return null;
  }

  /// ISO 3779: position 10 of a VIN encodes the model year on a
  /// 30-year cycle. We map only the post-2000 slice — older cars in
  /// our flow are rare enough that ambiguity is acceptable, and NHTSA
  /// itself defaults to the early-cycle year so leaving these out
  /// makes the second-pass retry skip cleanly.
  static int? _yearFromVinPosition10(String vin) {
    if (vin.length < 10) return null;
    const yearMap = <String, int>{
      '1': 2001, '2': 2002, '3': 2003, '4': 2004, '5': 2005,
      '6': 2006, '7': 2007, '8': 2008, '9': 2009,
      'A': 2010, 'B': 2011, 'C': 2012, 'D': 2013, 'E': 2014,
      'F': 2015, 'G': 2016, 'H': 2017, 'J': 2018, 'K': 2019,
      'L': 2020, 'M': 2021, 'N': 2022, 'P': 2023, 'R': 2024,
      'S': 2025, 'T': 2026, 'V': 2027, 'W': 2028, 'X': 2029,
      'Y': 2030,
    };
    return yearMap[vin[9].toUpperCase()];
  }

  // ---------- tiny coercion helpers ----------

  static double? _asDouble(Object? v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return double.tryParse(s);
  }

  static int? _asInt(Object? v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    return int.tryParse(s);
  }

  static String? _nonEmpty(String? s) {
    if (s == null) return null;
    final t = s.trim();
    return t.isEmpty ? null : t;
  }
}
