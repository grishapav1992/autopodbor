import 'dart:convert';

import 'package:flutter_application_1/data/services/vin_decoder_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Builds a minimal NHTSA-shaped response with only the fields the
/// decoder reads. Anything not provided is empty, mirroring the real
/// API's behaviour for fields it does not have data on.
Map<String, dynamic> _nhtsa({
  String? make,
  String? model,
  String? modelYear,
  String? fuel,
  String? trans,
  String? drive,
  String? displacementL,
  String? engineModel,
  String? errorCode,
}) {
  return {
    'Count': 1,
    'Message': 'Results returned successfully.',
    'Results': [
      {
        'Make': make ?? '',
        'Model': model ?? '',
        'ModelYear': modelYear ?? '',
        'FuelTypePrimary': fuel ?? '',
        'TransmissionStyle': trans ?? '',
        'DriveType': drive ?? '',
        'DisplacementL': displacementL ?? '',
        'EngineModel': engineModel ?? '',
        'ErrorCode': errorCode ?? '0',
      },
    ],
  };
}

void main() {
  setUp(() {
    VinDecoderService.clearCache();
  });
  tearDown(() {
    VinDecoderService.clientFactory = http.Client.new;
    VinDecoderService.clearCache();
  });

  group('VinDecoderService.decode — input validation', () {
    test('returns null for VIN shorter than 17 chars', () async {
      final result = await VinDecoderService.decode('SHORT123');
      expect(result, isNull);
    });

    test('returns null for VIN containing forbidden letters I, O, Q',
        () async {
      // ISO 3779 disallows I/O/Q to avoid confusion with 1/0.
      final result = await VinDecoderService.decode('IIIIIIIIIIIIIIIII');
      expect(result, isNull);
    });

    test('uppercases and trims input before validation', () async {
      // Force a successful mock so we know validation passed.
      VinDecoderService.clientFactory = () => MockClient((req) async {
        return http.Response(
          jsonEncode(_nhtsa(make: 'TEST', model: 'X', modelYear: '2020')),
          200,
        );
      });

      final result =
          await VinDecoderService.decode('  kmhdh41cbcu372329  ');
      expect(result, isNotNull);
      expect(result!.make, 'TEST');
    });
  });

  group('VinDecoderService.decode — Hyundai Elantra (KMHDH41CBCU372329)', () {
    test('two-pass: first call gives year 1982, retry with 2012 fills fields',
        () async {
      var callCount = 0;
      final responses = [
        // First call: NHTSA's default behaviour for ambiguous year
        // codes — early cycle year, no detailed fields.
        _nhtsa(modelYear: '1982', errorCode: '1,8,400'),
        // Second call: with explicit modelyear=2012, NHTSA returns
        // the full decode (mirrors what we observed in production).
        _nhtsa(
          make: 'HYUNDAI',
          model: 'Elantra',
          modelYear: '2012',
          fuel: 'Gasoline',
          trans: 'Automatic',
          drive: 'FWD/Front-Wheel Drive',
          displacementL: '1.6',
          engineModel: 'DOHC MPI GAMMA',
          errorCode: '12',
        ),
      ];

      VinDecoderService.clientFactory = () => MockClient((req) async {
        final body = jsonEncode(responses[callCount]);
        callCount++;
        return http.Response(body, 200);
      });

      final result = await VinDecoderService.decode('KMHDH41CBCU372329');

      expect(callCount, 2, reason: 'should retry with explicit year');
      expect(result, isNotNull);
      expect(result!.engineVolume, 1.6);
      expect(result.engineType, 'Бензин');
      expect(result.transmission, 'АКПП');
      expect(result.driveType, 'Передний');
      expect(result.year, 2012);
      expect(result.make, 'HYUNDAI');
      expect(result.model, 'Elantra');
      expect(result.engineModel, 'DOHC MPI GAMMA');
    });

    test('toCharacteristicsStepPatch matches PrepareSpecialistReport keys',
        () async {
      VinDecoderService.clientFactory = () => MockClient((req) async {
        return http.Response(
          jsonEncode(_nhtsa(
            make: 'HYUNDAI',
            model: 'Elantra',
            modelYear: '2012',
            fuel: 'Gasoline',
            trans: 'Automatic',
            drive: 'FWD/Front-Wheel Drive',
            displacementL: '1.6',
          )),
          200,
        );
      });

      final result = await VinDecoderService.decode('KMHDH41CBCU372329');
      final patch = result!.toCharacteristicsStepPatch();

      // Same key set as `_buildCharacteristicsStepPayload` in
      // spark_joy_storage_helpers.dart — minus fields we cannot fill.
      expect(patch, {
        'engineVolume': 1.6,
        'engineType': 'Бензин',
        'transmission': 'АКПП',
        'driveType': 'Передний',
      });
      // Crucially: we do NOT include color / equipment /
      // modelGenerationRestylingFrameId. Those must stay user-driven.
      expect(patch.containsKey('color'), isFalse);
      expect(patch.containsKey('equipment'), isFalse);
      expect(patch.containsKey('modelGenerationRestylingFrameId'), isFalse);
    });
  });

  group('VinDecoderService.decode — Russian-built (X9F, Z94)', () {
    test('Ford Russia X9FKXXEEBKDB21399 returns empty result without throwing',
        () async {
      VinDecoderService.clientFactory = () => MockClient((req) async {
        // Real NHTSA response for X9F: ErrorCode=1,7,400 with all
        // descriptive fields blank.
        return http.Response(
          jsonEncode(_nhtsa(errorCode: '1,7,400')),
          200,
        );
      });

      final result = await VinDecoderService.decode('X9FKXXEEBKDB21399');
      expect(result, isNotNull);
      expect(result!.hasAnyCharacteristic, isFalse);
      expect(result.toCharacteristicsStepPatch(), isEmpty);
      expect(result.warnings, contains('NHTSA ErrorCode=1,7,400'));
    });

    test('Hyundai Russia Z94CT41DAHR494208 also empty (Z94 not in NHTSA)',
        () async {
      VinDecoderService.clientFactory = () => MockClient((req) async {
        return http.Response(
          jsonEncode(_nhtsa(errorCode: '1,7,400')),
          200,
        );
      });

      final result = await VinDecoderService.decode('Z94CT41DAHR494208');
      expect(result, isNotNull);
      expect(result!.hasAnyCharacteristic, isFalse);
    });
  });

  group('VinDecoderService — enum mappers', () {
    test('maps Diesel and CNG fuel variants', () async {
      VinDecoderService.clientFactory = () => MockClient((req) async {
        // Pick a VIN where year code yields a post-2000 year so the
        // single-pass succeeds (no retry needed).
        return http.Response(
          jsonEncode(_nhtsa(
            make: 'X',
            model: 'Y',
            modelYear: '2020',
            fuel: 'Diesel',
            trans: 'Manual',
            drive: 'AWD/All-Wheel Drive',
            displacementL: '2.0',
          )),
          200,
        );
      });

      final result = await VinDecoderService.decode('WAUZZZ8V0LA000001');
      expect(result!.engineType, 'Дизель');
      expect(result.transmission, 'МКПП');
      expect(result.driveType, 'Полный');
    });

    test('maps CVT and DCT to correct gearbox labels', () async {
      var i = 0;
      final fuels = ['Hybrid', 'Electric'];
      final trans = [
        'Continuously Variable Transmission (CVT)',
        'Dual-Clutch Transmission (DCT)',
      ];

      VinDecoderService.clientFactory = () => MockClient((req) async {
        final body = _nhtsa(
          make: 'X',
          model: 'Y',
          modelYear: '2022',
          fuel: fuels[i],
          trans: trans[i],
          drive: 'RWD/Rear-Wheel Drive',
        );
        i++;
        return http.Response(jsonEncode(body), 200);
      });

      final r1 = await VinDecoderService.decode('JTDKARFU3M0123456');
      expect(r1!.engineType, 'Гибрид');
      expect(r1.transmission, 'Вариатор');
      expect(r1.driveType, 'Задний');

      VinDecoderService.clearCache();
      final r2 = await VinDecoderService.decode('WBAJB0C50JB123456');
      expect(r2!.engineType, 'Электро');
      expect(r2.transmission, 'Робот');
    });
  });

  group('VinDecoderService — caching', () {
    test('subsequent calls for the same VIN do not re-hit the network',
        () async {
      var callCount = 0;
      VinDecoderService.clientFactory = () => MockClient((req) async {
        callCount++;
        return http.Response(
          jsonEncode(_nhtsa(
            make: 'X',
            model: 'Y',
            modelYear: '2020',
            fuel: 'Gasoline',
            displacementL: '1.5',
          )),
          200,
        );
      });

      final a = await VinDecoderService.decode('WAUZZZ8V0LA000001');
      final b = await VinDecoderService.decode('WAUZZZ8V0LA000001');
      expect(callCount, 1);
      expect(a!.engineVolume, b!.engineVolume);
    });

    test('refresh() bypasses the cache', () async {
      var callCount = 0;
      VinDecoderService.clientFactory = () => MockClient((req) async {
        callCount++;
        return http.Response(
          jsonEncode(_nhtsa(make: 'X', model: 'Y', modelYear: '2020')),
          200,
        );
      });

      await VinDecoderService.decode('WAUZZZ8V0LA000001');
      await VinDecoderService.refresh('WAUZZZ8V0LA000001');
      expect(callCount, 2);
    });
  });

  group('VinDecoderService — error handling', () {
    test('non-200 from NHTSA returns isNetworkFailure result', () async {
      VinDecoderService.clientFactory = () => MockClient((req) async {
        return http.Response('error', 503);
      });

      final result = await VinDecoderService.decode('WAUZZZ8V0LA000001');
      // After the rollback fix: non-200 funnels through the same
      // empty-row branch as a malformed body, surfacing as a non-null
      // result with isNetworkFailure=true so UI dedup caches can
      // distinguish it from a legitimate empty NHTSA answer.
      expect(result, isNotNull);
      expect(result!.isNetworkFailure, isTrue);
      expect(result.hasAnyCharacteristic, isFalse);
    });

    test('malformed JSON body surfaces as isNetworkFailure', () async {
      VinDecoderService.clientFactory = () => MockClient((req) async {
        return http.Response('not json', 200);
      });

      final result = await VinDecoderService.decode('WAUZZZ8V0LA000001');
      expect(result, isNotNull);
      expect(result!.isNetworkFailure, isTrue);
      expect(result.warnings.first, startsWith('NHTSA error:'));
    });
  });

  group('VinDecodeResult — isNetworkFailure semantics', () {
    test('legitimate empty NHTSA answer is NOT a network failure', () {
      // X9F/Z94/XTA scenario — NHTSA returns ErrorCode=1,7,400 with
      // every descriptive field blank. Not a failure, just "we don't
      // know this manufacturer". Caller must keep this in dedup cache.
      const result = VinDecodeResult(warnings: ['NHTSA ErrorCode=1,7,400']);
      expect(result.isNetworkFailure, isFalse);
      expect(result.hasAnyCharacteristic, isFalse);
    });

    test('NHTSA timeout is a network failure', () {
      const result = VinDecodeResult(warnings: ['NHTSA timeout']);
      expect(result.isNetworkFailure, isTrue);
    });

    test('catch-block error string is a network failure', () {
      const result = VinDecodeResult(
        warnings: ['NHTSA error: SocketException: Failed host lookup'],
      );
      expect(result.isNetworkFailure, isTrue);
    });

    test('empty warnings means no network failure', () {
      const result = VinDecodeResult(
        engineVolume: 1.6,
        engineType: 'Бензин',
      );
      expect(result.isNetworkFailure, isFalse);
    });

    test('mixed warnings — recognizes failure even alongside ErrorCode',
        () {
      // Defensive: if NHTSA somehow surfaces both a partial response
      // and a downstream error, we still treat the whole thing as
      // unreliable.
      const result = VinDecodeResult(
        warnings: ['NHTSA ErrorCode=12', 'NHTSA error: parse failed'],
      );
      expect(result.isNetworkFailure, isTrue);
    });
  });

  group('VinDecodeResult — JSON round-trip', () {
    test('toJson/fromJson are symmetric', () {
      const original = VinDecodeResult(
        engineVolume: 1.6,
        engineType: 'Бензин',
        transmission: 'АКПП',
        driveType: 'Передний',
        make: 'HYUNDAI',
        model: 'Elantra',
        year: 2012,
        engineModel: 'DOHC MPI GAMMA',
        warnings: ['NHTSA ErrorCode=12'],
      );
      final restored = VinDecodeResult.fromJson(original.toJson());
      expect(restored.toJson(), original.toJson());
    });
  });
}
