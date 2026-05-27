// Unit tests for [ProfanityModerator]. We deliberately avoid hard-
// coding profanity strings into the test source — instead we pull
// the first canonical root from the (otherwise private) root file
// and exercise behaviour around it. This keeps the test file readable
// to anyone reviewing the diff and means future updates to the root
// list don't break the suite as long as the API contract holds.

import 'package:flutter_application_1/core/utils/_profanity_roots.dart';
import 'package:flutter_application_1/core/utils/profanity_moderator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ProfanityModerator.isClean — neutral input always allowed', () {
    test('null / empty / whitespace', () {
      expect(ProfanityModerator.isClean(null), isTrue);
      expect(ProfanityModerator.isClean(''), isTrue);
      expect(ProfanityModerator.isClean('   \n\t  '), isTrue);
    });

    test('typical inspector report sentences', () {
      expect(ProfanityModerator.isClean('Машина в хорошем состоянии'), isTrue);
      expect(
        ProfanityModerator.isClean('VIN считывается, пробег родной 120000 км'),
        isTrue,
      );
      expect(
        ProfanityModerator.isClean(
          'Кузов без значимых повреждений, ЛКП ровный',
        ),
        isTrue,
      );
    });

    test('typical user request prose', () {
      expect(
        ProfanityModerator.isClean(
          'Хочу автомобиль не старше 2018 года, бензин, автомат',
        ),
        isTrue,
      );
    });

    test('English brand and city names — no false positive', () {
      expect(ProfanityModerator.isClean('Toyota Camry'), isTrue);
      expect(ProfanityModerator.isClean('Krasnodar Krai'), isTrue);
      expect(ProfanityModerator.isClean('Москва, Тверская улица'), isTrue);
    });
  });

  group('ProfanityModerator.moderateText — block', () {
    test('canonical Russian root triggers block', () {
      // Pull the first root and use it directly. We don't print the
      // root itself in the assertion — the contract is that ANY token
      // containing a known root (with allowed prefix) is blocked.
      final root = kProfanityRootsRu.first;
      final result = ProfanityModerator.moderateText('Привет $root');
      expect(result.isBlock, isTrue);
      expect(result.matchedRoots, contains(root));
    });

    test('inflected form with prefix triggers block', () {
      // "не" is in [kProfanityPrefixes]; "не" + root is a valid
      // morphological form that must still match.
      final root = kProfanityRootsRu.first;
      final result = ProfanityModerator.moderateText(
        'не$root'
        'какой',
      );
      expect(result.isBlock, isTrue);
      expect(result.matchedRoots, contains(root));
    });

    test('lookalike substitutions still match', () {
      final root = kProfanityRootsRu.first;
      // Replace 'а' → '@' and 'о' → '0' in the root before injecting.
      final obfuscated = root.replaceAll('а', '@').replaceAll('о', '0');
      // Only meaningful if the root actually contained one of those
      // letters; otherwise we fall back to verifying the plain form.
      final input = obfuscated == root
          ? 'тест $root'
          : 'тест $obfuscated конец';
      expect(ProfanityModerator.moderateText(input).isBlock, isTrue);
    });

    test('Latin-twin substitution catches transliterated mat', () {
      // Build the root using Latin characters that visually match
      // their Cyrillic counterparts (a→а, o→о, e→е, c→с, x→х, p→р,
      // y→у, k→к, m→м, n→н, t→т, b→б, h→н). For roots without any
      // such letter the result is identical and we skip; the
      // assertion still verifies the mapping path runs cleanly.
      final root = kProfanityRootsRu.first;
      final transliterated = root
          .replaceAll('а', 'a')
          .replaceAll('о', 'o')
          .replaceAll('е', 'e')
          .replaceAll('с', 'c')
          .replaceAll('х', 'x')
          .replaceAll('р', 'p')
          .replaceAll('у', 'y')
          .replaceAll('к', 'k')
          .replaceAll('м', 'm')
          .replaceAll('н', 'n')
          .replaceAll('т', 't')
          .replaceAll('б', 'b');
      final input = 'attempt $transliterated end';
      expect(ProfanityModerator.moderateText(input).isBlock, isTrue);
    });

    test('multiple matches reported in matchedRoots', () {
      final r1 = kProfanityRootsRu.first;
      final r2 = kProfanityRootsRu.last;
      final result = ProfanityModerator.moderateText('а $r1 и ещё $r2 .');
      expect(result.isBlock, isTrue);
      expect(result.matchedRoots, contains(r1));
      expect(result.matchedRoots, contains(r2));
    });

    test('English profanity in plain Latin caught by EN root', () {
      // Use the first English root; we know it triggers regardless
      // of context.
      final enRoot = kProfanityRootsEn.first;
      expect(
        ProfanityModerator.moderateText('this is $enRoot, fix it').isBlock,
        isTrue,
      );
    });

    test('short exact Russian profanity is blocked', () {
      final shortRoot = kProfanityShortWordsRu.first;
      final result = ProfanityModerator.moderateText('текст $shortRoot');
      expect(result.isBlock, isTrue);
      expect(result.matchedRoots, contains(shortRoot));
    });
  });

  group('ProfanityModerator — false positives must remain clean', () {
    test('whitelist words pass even when they overlap a root', () {
      // The whitelist guards against well-known overlaps. Each entry
      // here is one a real user might type in an inspection report.
      expect(ProfanityModerator.isClean('лохматый ковёр в багажнике'), isTrue);
      expect(ProfanityModerator.isClean('Хирург приехал на осмотр'), isTrue);
      expect(ProfanityModerator.isClean('Мудрость владельца'), isTrue);
      expect(ProfanityModerator.isClean('Подаёт блюдо к столу'), isTrue);
      expect(
        ProfanityModerator.isClean('Охапка инструментов в багажнике'),
        isTrue,
      );
    });

    test('tokens shorter than 4 characters never match', () {
      // Boundary check — three-letter tokens that contain a profanity
      // substring (no real example, but ensure the gate holds).
      expect(ProfanityModerator.isClean('кот'), isTrue);
      expect(ProfanityModerator.isClean('я он мы вы'), isTrue);
    });

    test('mid-token alignment outside the prefix list is rejected', () {
      // Construct a synthetic token: 6 random Cyrillic letters + root.
      // None of "абвгде" is in [kProfanityPrefixes], so the alignment
      // must fail and the token must NOT block.
      final root = kProfanityRootsRu.first;
      final synthetic = 'абвгде$root';
      expect(ProfanityModerator.isClean(synthetic), isTrue);
    });
  });

  group('ProfanityModerator.moderateText — userMessage', () {
    test('default message uses generic "поле" when no label provided', () {
      final root = kProfanityRootsRu.first;
      final result = ProfanityModerator.moderateText('test $root');
      expect(result.userMessage, isNotNull);
      expect(result.userMessage, contains('«поле»'));
    });

    test('custom field label is interpolated', () {
      final root = kProfanityRootsRu.first;
      final result = ProfanityModerator.moderateText(
        'test $root',
        fieldLabel: 'Заключение специалиста',
      );
      expect(result.userMessage, contains('«Заключение специалиста»'));
    });

    test('whitespace-only label falls back to generic wording', () {
      final root = kProfanityRootsRu.first;
      final result = ProfanityModerator.moderateText(
        'test $root',
        fieldLabel: '   ',
      );
      expect(result.userMessage, contains('«поле»'));
    });

    test('allow result has null userMessage and empty matchedRoots', () {
      final result = ProfanityModerator.moderateText('Хорошее состояние');
      expect(result.isAllow, isTrue);
      expect(result.userMessage, isNull);
      expect(result.matchedRoots, isEmpty);
    });
  });

  group('ProfanityModerator.debugFindMatches', () {
    test('returns empty list for clean input', () {
      expect(ProfanityModerator.debugFindMatches('Хорошая машина'), isEmpty);
    });

    test('returns the offending root', () {
      final root = kProfanityRootsRu.first;
      final matches = ProfanityModerator.debugFindMatches('hi $root bye');
      expect(matches, contains(root));
    });

    test('returns roots in deterministic order across runs', () {
      final root = kProfanityRootsRu.first;
      final input = 'a $root b';
      expect(
        ProfanityModerator.debugFindMatches(input),
        ProfanityModerator.debugFindMatches(input),
      );
    });
  });
}
