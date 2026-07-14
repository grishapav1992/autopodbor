// Продление жизни процесса после сворачивания (только iOS).
//
// iOS замораживает процесс через считанные секунды после ухода в фон, и
// Dart-конвейер интейка (сжатие → presigned URL → enqueue, vision-вызовы
// ИИ-раскладки) встаёт на месте. beginBackgroundTask даёт ~30 секунд
// гарантированного выполнения — этого хватает, чтобы дожать хвост в
// нативный транспорт или довершить текущий vision-вызов.
//
// Android не трогаем: процесс в фоне не замораживается мгновенно, а заливку
// держит WorkManager с групповой нотификацией.
//
// Нативная сторона — канал `app/background_time` в AppDelegate.swift.
// Держится один assertion на процесс: hold идемпотентен, release без
// активного assertion — no-op. Если система забрала время в фоне
// (expiration handler), нативная сторона отпускает assertion сама —
// поэтому на resume hold нужно перевзять, что делает вызывающий.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

abstract final class AppBackgroundTime {
  @visibleForTesting
  static const MethodChannel channel = MethodChannel('app/background_time');

  static bool get _supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Просит систему не замораживать процесс сразу после сворачивания.
  static Future<void> hold() async {
    if (!_supported) return;
    try {
      await channel.invokeMethod<void>('hold');
    } catch (_) {
      // Канала нет (билд без нативной части) — деградируем до прежнего
      // поведения «замерзаем сразу», это не ошибка приложения.
    }
  }

  /// Отпускает assertion, когда фоновой работы не осталось.
  static Future<void> release() async {
    if (!_supported) return;
    try {
      await channel.invokeMethod<void>('release');
    } catch (_) {}
  }
}
