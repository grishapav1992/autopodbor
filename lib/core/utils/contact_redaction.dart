class ContactRedactionResult {
  const ContactRedactionResult({required this.text, required this.redacted});

  final String text;
  final bool redacted;
}

class ContactValidationResult {
  const ContactValidationResult({
    required this.hasViolations,
    required this.errors,
  });

  final bool hasViolations;
  final List<String> errors;
}

enum ContactModerationDecision { allow, review, block }

enum ContactModerationField {
  about,
  description,
  serviceTitle,
  fileName,
  portfolioText,
  comment,
}

class ContactModerationResult {
  const ContactModerationResult({
    required this.decision,
    required this.reasons,
  });

  final ContactModerationDecision decision;
  final List<String> reasons;

  bool get isAllow => decision == ContactModerationDecision.allow;
  bool get isReview => decision == ContactModerationDecision.review;
  bool get isBlock => decision == ContactModerationDecision.block;
}

enum _PhoneSignal { none, review, block }

/// Hides contacts from public profile text until deal/payment is completed.
class ContactRedaction {
  static const String _placeholder = '[Контакты скрыты до оплаты]';
  static const String _blockedMessage =
      'Контакты скрыты до оплаты. Опишите опыт и подход без контактов.';

  static const String _phoneError =
      'Нельзя указывать номер телефона в разделе «О себе».';
  static const String _emailError = 'Нельзя указывать email в тексте профиля.';
  static const String _linkError =
      'Удалите ссылки на мессенджеры, соцсети и сайты.';
  static const String _handleError =
      'Удалите @ники и другие контактные идентификаторы.';
  static const String _telegramNickError =
      'Удалите ник в Telegram/телеграм из описания.';
  static const String _obfuscatedError =
      'Похоже на маскировку контакта (цифры/контакт словами).';
  static const String _obfuscatedEmailError =
      'Обнаружен email в обфусцированном виде (собака/точка).';
  static const String _reviewDigitsError =
      'Похоже на скрытый номер (цифры по одной). Нужна модерация.';
  static const String _reviewInviteError =
      'Обнаружен призыв уйти в личные контакты. Нужна модерация.';
  static const String _reviewHintError =
      'Есть намек на передачу контактов. Нужна модерация.';

  static const List<String> _contactKeywords = [
    'тел',
    'телефон',
    'номер',
    'контакт',
    'звон',
    'почта',
    'телеграм',
    'телега',
    'ватсап',
    'вотсап',
    'вайбер',
    'telegram',
    'whatsapp',
    'email',
    'tg',
    'wa',
  ];

  static const List<String> _numberWords = [
    'ноль',
    'один',
    'одна',
    'два',
    'две',
    'три',
    'четыре',
    'пять',
    'шесть',
    'семь',
    'восемь',
    'девять',
    'плюс',
  ];

  static const List<String> _solicitationKeywords = [
    'пиши',
    'пишите',
    'в личку',
    'личку',
    'скину',
    'дам',
    'тут редко',
  ];

  static const List<String> _messengerKeywords = [
    'телег',
    'тг',
    'telegram',
    'ватс',
    'вотс',
    'whatsapp',
    'wa',
  ];

  static final RegExp _emailPattern = RegExp(
    r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
    caseSensitive: false,
  );

  static final RegExp _obfuscatedEmailPattern = RegExp(
    r'\b[a-zA-Z0-9._%+-]{2,}\s*(?:собака|@)\s*[a-zA-Z0-9.-]{2,}\s*(?:точка|\.)\s*[a-zA-Z]{2,}\b',
    caseSensitive: false,
    unicode: true,
  );

  static final RegExp _contactLinkPattern = RegExp(
    r'(?:(?:https?:\/\/)?(?:t\.me|telegram\.me|wa\.me|api\.whatsapp\.com|vk\.com|instagram\.com|facebook\.com|viber\.com|ok\.ru|discord\.gg)\/[^\s,;]+)',
    caseSensitive: false,
  );

  static final RegExp _genericUrlPattern = RegExp(
    r'(?:(?:https?:\/\/|www\.)[^\s,;]+)',
    caseSensitive: false,
  );

  static final RegExp _bareDomainPattern = RegExp(
    r'(?<![@\w])(?:[a-z0-9-]+\.)+[a-z]{2,}(?:\/[^\s,;]*)?',
    caseSensitive: false,
  );

  static final RegExp _phoneLikePattern = RegExp(
    r'(?:(?:\+|00)?\d[\d\s().-]{7,}\d)',
  );

  static final RegExp _spacedDigitsPattern = RegExp(
    r'(?<!\d)(?:\d\s+){9,}\d(?!\d)',
  );

  static final RegExp _atHandlePattern = RegExp(
    r'(?<!\w)@[a-zA-Z0-9_.-]{3,}',
    caseSensitive: false,
  );

  static final RegExp _trailingAtNickPattern = RegExp(
    r'(?<!\S)[a-zA-Z0-9_]{4,}@(?=\s|$)',
    caseSensitive: false,
  );

  static final RegExp _telegramKeywordPattern = RegExp(
    r'(telegram|tg|телеграм|телеге|телегу|тг)',
    caseSensitive: false,
    unicode: true,
  );

  static final RegExp _latinNickTokenPattern = RegExp(
    r'(?<![@/\w])[a-zA-Z][a-zA-Z0-9_]{4,}(?!\w)',
    caseSensitive: false,
  );

  static final RegExp _obfuscatedTelegramLinkPattern = RegExp(
    r'\bt\s*(?:\.|точка|\(\s*точка\s*\))\s*me\b',
    caseSensitive: false,
    unicode: true,
  );

  static final RegExp _hiddenContactsHintPattern = RegExp(
    r'(оставил|скинул|дам)\s+[^.!?\n]{0,30}(контакт|номер|телег|тг|почт|whatsapp|telegram)',
    caseSensitive: false,
    unicode: true,
  );

  static ContactValidationResult validateProfileText(String raw) {
    final result = moderateText(raw, field: ContactModerationField.about);
    if (!result.isBlock) {
      return const ContactValidationResult(hasViolations: false, errors: []);
    }
    return ContactValidationResult(hasViolations: true, errors: result.reasons);
  }

  static ContactModerationResult moderateText(
    String raw, {
    ContactModerationField field = ContactModerationField.about,
  }) {
    final text = raw.trim();
    if (text.isEmpty) {
      return const ContactModerationResult(
        decision: ContactModerationDecision.allow,
        reasons: [],
      );
    }

    final blockReasons = <String>{};
    final reviewReasons = <String>{};

    if (_emailPattern.hasMatch(text)) {
      blockReasons.add(_emailError);
    }

    if (_obfuscatedEmailPattern.hasMatch(text)) {
      blockReasons.add(_obfuscatedEmailError);
    }

    if (_hasLinkLike(text)) {
      blockReasons.add(_linkError);
    }

    if (_atHandlePattern.hasMatch(text)) {
      blockReasons.add(_handleError);
    }

    if (_hasTelegramNickLike(text)) {
      blockReasons.add(_telegramNickError);
    }

    final phoneSignal = _phoneSignal(text);
    if (phoneSignal == _PhoneSignal.block) {
      blockReasons.add(_phoneError);
    } else if (phoneSignal == _PhoneSignal.review) {
      reviewReasons.add(_reviewDigitsError);
    }

    if (_looksLikeObfuscatedContact(text)) {
      blockReasons.add(_obfuscatedError);
    }

    if (_obfuscatedTelegramLinkPattern.hasMatch(text)) {
      blockReasons.add(_linkError);
    }

    if (_looksLikeContactSolicitation(text)) {
      reviewReasons.add(_reviewInviteError);
    }

    if (_looksLikeHiddenContactHint(text, field)) {
      reviewReasons.add(_reviewHintError);
    }

    if (blockReasons.isNotEmpty) {
      return ContactModerationResult(
        decision: ContactModerationDecision.block,
        reasons: blockReasons.toList(growable: false),
      );
    }

    if (reviewReasons.isNotEmpty) {
      return ContactModerationResult(
        decision: ContactModerationDecision.review,
        reasons: reviewReasons.toList(growable: false),
      );
    }

    return const ContactModerationResult(
      decision: ContactModerationDecision.allow,
      reasons: [],
    );
  }

  static ContactRedactionResult redactPublicText(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      return const ContactRedactionResult(text: '', redacted: false);
    }

    var redactedText = text;
    var redacted = false;

    final emailReplaced = redactedText.replaceAll(_emailPattern, _placeholder);
    if (emailReplaced != redactedText) {
      redacted = true;
      redactedText = emailReplaced;
    }

    final obfuscatedEmailReplaced = redactedText.replaceAll(
      _obfuscatedEmailPattern,
      _placeholder,
    );
    if (obfuscatedEmailReplaced != redactedText) {
      redacted = true;
      redactedText = obfuscatedEmailReplaced;
    }

    final linksReplaced = redactedText.replaceAll(
      _contactLinkPattern,
      _placeholder,
    );
    if (linksReplaced != redactedText) {
      redacted = true;
      redactedText = linksReplaced;
    }

    final urlsReplaced = redactedText.replaceAll(
      _genericUrlPattern,
      _placeholder,
    );
    if (urlsReplaced != redactedText) {
      redacted = true;
      redactedText = urlsReplaced;
    }

    final domainsReplaced = redactedText.replaceAll(
      _bareDomainPattern,
      _placeholder,
    );
    if (domainsReplaced != redactedText) {
      redacted = true;
      redactedText = domainsReplaced;
    }

    final handlesReplaced = redactedText.replaceAll(
      _atHandlePattern,
      _placeholder,
    );
    if (handlesReplaced != redactedText) {
      redacted = true;
      redactedText = handlesReplaced;
    }

    final trailingNickReplaced = redactedText.replaceAll(
      _trailingAtNickPattern,
      _placeholder,
    );
    if (trailingNickReplaced != redactedText) {
      redacted = true;
      redactedText = trailingNickReplaced;
    }

    final lowerSource = text.toLowerCase();
    if (_telegramKeywordPattern.hasMatch(lowerSource)) {
      redactedText = redactedText.replaceAllMapped(_latinNickTokenPattern, (m) {
        final token = m.group(0) ?? '';
        if (!token.contains('_')) return token;
        redacted = true;
        return _placeholder;
      });
    }

    redactedText = redactedText.replaceAllMapped(_phoneLikePattern, (m) {
      final chunk = m.group(0) ?? '';
      if (_phoneSignal(chunk) == _PhoneSignal.none) return chunk;
      redacted = true;
      return _placeholder;
    });

    if (!redacted && _looksLikeObfuscatedContact(text)) {
      return const ContactRedactionResult(
        text: _blockedMessage,
        redacted: true,
      );
    }

    return ContactRedactionResult(text: redactedText, redacted: redacted);
  }

  static bool _hasLinkLike(String text) {
    if (_contactLinkPattern.hasMatch(text)) return true;
    if (_genericUrlPattern.hasMatch(text)) return true;
    return _bareDomainPattern.hasMatch(text);
  }

  static _PhoneSignal _phoneSignal(String text) {
    var hasNormalPhone = false;
    var hasSpacedDigitsPhone = false;

    for (final m in _phoneLikePattern.allMatches(text)) {
      final chunk = m.group(0) ?? '';
      final digits = chunk.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length < 10 || digits.length > 15) {
        continue;
      }

      if (_looksSeparatedSingleDigits(chunk)) {
        hasSpacedDigitsPhone = true;
      } else {
        hasNormalPhone = true;
      }
    }

    if (hasNormalPhone) return _PhoneSignal.block;
    if (hasSpacedDigitsPhone) return _PhoneSignal.review;

    if (_spacedDigitsPattern.hasMatch(text)) {
      return _PhoneSignal.review;
    }

    return _PhoneSignal.none;
  }

  static bool _looksSeparatedSingleDigits(String chunk) {
    final normalized = chunk.replaceAll(RegExp(r'[().-]'), ' ');
    final parts = normalized
        .split(RegExp(r'\s+'))
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);

    if (parts.length < 10) return false;
    return parts.every((p) => RegExp(r'^\d$').hasMatch(p));
  }

  static bool _hasTelegramNickLike(String text) {
    if (_trailingAtNickPattern.hasMatch(text)) return true;
    if (!_telegramKeywordPattern.hasMatch(text)) return false;

    for (final m in _latinNickTokenPattern.allMatches(text)) {
      final token = m.group(0) ?? '';
      if (token.contains('_')) return true;
    }
    return false;
  }

  static bool _looksLikeObfuscatedContact(String text) {
    final lower = text.toLowerCase();
    if (!_contactKeywords.any(lower.contains)) return false;

    final tokens = RegExp(
      r'[a-zA-Z\u0400-\u04FF]+',
      unicode: true,
    ).allMatches(lower).map((m) => m.group(0)!);

    var count = 0;
    for (final token in tokens) {
      if (_numberWords.contains(token)) count++;
      if (count >= 2) return true;
    }
    return false;
  }

  static bool _looksLikeContactSolicitation(String text) {
    final lower = text.toLowerCase();
    final hasSolicitationKeyword = _solicitationKeywords.any(lower.contains);
    if (!hasSolicitationKeyword) return false;
    return _messengerKeywords.any(lower.contains);
  }

  static bool _looksLikeHiddenContactHint(
    String text,
    ContactModerationField field,
  ) {
    final lower = text.toLowerCase();
    if (_hiddenContactsHintPattern.hasMatch(lower)) return true;

    if (field == ContactModerationField.comment) {
      if (lower.contains('оставил контакты')) return true;
      if (lower.contains('контакты в отчете')) return true;
      if (lower.contains('контакты в отчёте')) return true;
    }

    return false;
  }
}
