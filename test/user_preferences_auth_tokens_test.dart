import 'package:flutter/services.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Транзитивная зависимость shared_preferences — нужна только чтобы
// подменить платформенный store на отказывающий (тест double-failure).
// В pubspec не добавлена: файл занят правками параллельной сессии.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';

/// Персист auth-токенов: порядок записи и честный вердикт.
///
/// Регрессия на инцидент 2026-07-18 («выкинуло со всех акков»): пара
/// писалась access-первым, а `_writeToken` молча глотал провал обоих
/// хранилищ — поэтому убитый между записями процесс или сбой стораджа
/// оставлял на диске СТАРЫЙ refresh, при этом refresh-цепочка
/// рапортовала success. Инварианты фикса:
///  1) refresh-токен пишется РАНЬШЕ access («новый refresh + старый
///     access» — единственная безопасная промежуточная комбинация);
///  2) setAuthTokens возвращает true только при записи ОБОИХ токенов;
///  3) при отказе secure-стораджа пара выживает в plaintext-фолбэке.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const secureChannel = MethodChannel(
    'plugins.it_nomads.com/flutter_secure_storage',
  );

  final secureStore = <String, String>{};
  final secureWriteOrder = <String>[];
  var secureThrows = false;

  setUp(() {
    secureStore.clear();
    secureWriteOrder.clear();
    secureThrows = false;
    SharedPreferences.setMockInitialValues({});
    UserSimplePreferences.pref = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, (call) async {
          if (secureThrows) {
            throw PlatformException(code: 'keystore-dead');
          }
          final args =
              (call.arguments as Map?)?.cast<String, dynamic>() ??
              const <String, dynamic>{};
          switch (call.method) {
            case 'write':
              secureWriteOrder.add(args['key'] as String);
              secureStore[args['key'] as String] = args['value'] as String;
              return null;
            case 'read':
              return secureStore[args['key'] as String];
            case 'delete':
              secureStore.remove(args['key'] as String);
              return null;
            case 'containsKey':
              return secureStore.containsKey(args['key'] as String);
            case 'readAll':
              return Map<String, String>.from(secureStore);
            case 'deleteAll':
              secureStore.clear();
              return null;
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureChannel, null);
  });

  group('UserSimplePreferences.setAuthTokens', () {
    test('refresh-токен пишется РАНЬШЕ access (порядок = инвариант)', () async {
      final ok = await UserSimplePreferences.setAuthTokens(
        accessToken: 'access-new',
        refreshToken: 'refresh-new',
      );
      expect(ok, isTrue);
      expect(secureWriteOrder, ['refreshToken', 'accessToken']);
      expect(await UserSimplePreferences.getRefreshToken(), 'refresh-new');
      expect(await UserSimplePreferences.getAccessToken(), 'access-new');
    });

    test('сбой secure-стораджа → plaintext-фолбэк, вердикт true', () async {
      secureThrows = true;
      final ok = await UserSimplePreferences.setAuthTokens(
        accessToken: 'access-new',
        refreshToken: 'refresh-new',
      );
      expect(ok, isTrue, reason: 'фолбэк принял значения — сессия жива');
      // Чтение обязано вернуть свежую пару через легаси-путь
      // (_readTokenWithMigration: secure read кидает → plaintext).
      expect(await UserSimplePreferences.getRefreshToken(), 'refresh-new');
      expect(await UserSimplePreferences.getAccessToken(), 'access-new');
    });

    test('отказ ОБОИХ хранилищ → false (не молчаливый success)', () async {
      secureThrows = true;
      // setMockInitialValues в setUp уже сбросил кэш SharedPreferences —
      // теперь подменяем платформенный store на отказывающий.
      SharedPreferencesStorePlatform.instance = _FailingPrefsStore();
      UserSimplePreferences.pref = null;
      final ok = await UserSimplePreferences.setAuthTokens(
        accessToken: 'access-new',
        refreshToken: 'refresh-new',
      );
      expect(
        ok,
        isFalse,
        reason: 'ничего не записано — success был бы ложью '
            '(refresh-цепочка обязана вернуть transient, не success)',
      );
    });
  });
}

/// Store, который принимает чтение (пустой набор), но отвергает записи —
/// имитация мёртвого plaintext-фолбэка при уже мёртвом secure-сторадже.
class _FailingPrefsStore extends SharedPreferencesStorePlatform {
  @override
  Future<bool> clear() async => false;

  @override
  Future<Map<String, Object>> getAll() async => <String, Object>{};

  @override
  Future<bool> remove(String key) async => false;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async =>
      false;
}
