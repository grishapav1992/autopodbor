import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:share_plus/share_plus.dart';

/// Открывает нативное системное окно «Поделиться» (на web — Web Share API)
/// для [url] отчёта.
///
/// Фолбэк: если платформа не может показать share-sheet (десктоп-браузер без
/// Web Share API → [ShareResultStatus.unavailable]) или вызов бросил
/// исключение — копируем [url] в буфер и показываем snackbar «Ссылка
/// скопирована» (прежнее поведение).
///
/// [subject] — название отчёта; используется как заголовок/тема там, где ОС
/// это поддерживает (Android-чузер, тема письма). URL всегда уходит как `text`,
/// чтобы мессенджеры рендерили кликабельную ссылку.
///
/// Состояние загрузки НЕ трогает — спиннеры остаются на стороне вызывающих.
Future<void> shareSpecialistReportUrl(
  BuildContext context, {
  required String url,
  String? subject,
}) async {
  // Захватываем messenger ДО первого await — переживёт перестройку/анмаунт
  // виджета и не нарушает use_build_context_synchronously.
  final messenger = ScaffoldMessenger.of(context);
  final trimmedUrl = url.trim();
  if (trimmedUrl.isEmpty) {
    messenger.showSnackBar(
      const SnackBar(content: Text('Ссылка не была сгенерирована')),
    );
    return;
  }

  final trimmedSubject = subject?.trim();
  final params = ShareParams(
    text: trimmedUrl,
    subject: (trimmedSubject == null || trimmedSubject.isEmpty)
        ? null
        : trimmedSubject,
  );

  try {
    final result = await SharePlus.instance.share(params);
    // unavailable — платформа не смогла показать окно (десктоп-браузер без
    // navigator.share). success/dismissed — терминальны (пользователь увидел
    // окно), копировать не нужно.
    if (result.status == ShareResultStatus.unavailable) {
      await _copyShareFallback(messenger, trimmedUrl);
    }
  } catch (_) {
    await _copyShareFallback(messenger, trimmedUrl);
  }
}

Future<void> _copyShareFallback(
  ScaffoldMessengerState messenger,
  String url,
) async {
  await Clipboard.setData(ClipboardData(text: url));
  messenger.showSnackBar(
    SnackBar(
      content: Text('Ссылка скопирована: $url'),
      duration: const Duration(seconds: 6),
    ),
  );
}
