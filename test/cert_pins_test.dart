import 'dart:convert';

import 'package:flutter_application_1/core/config/cert_pins.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CertPins.byHost', () {
    test('every pinned host has at least one pin', () {
      for (final entry in CertPins.byHost.entries) {
        expect(entry.value, isNotEmpty,
            reason: '${entry.key} must have at least one SPKI pin');
      }
    });

    test('all three carreports hosts are registered', () {
      // Fail-closed: the pinning callback rejects ANY unlisted host, so a
      // missing host here means the corresponding endpoint stops working
      // in release. These three mirror AppEndpoints.
      expect(CertPins.byHost.keys, containsAll(<String>[
        'app.carreports.ru',
        'ai.carreports.ru',
        'ws.carreports.ru',
      ]));
    });

    test('every pin is a 44-char base64 SHA-256 (no prefix)', () {
      // SHA-256 digest = 32 bytes → base64 = 44 chars ending in '='.
      // Reject accidental "sha256/" prefixes (that's HPKP wire format, not
      // our internal form) and malformed/short values.
      final pattern = RegExp(r'^[A-Za-z0-9+/]{43}=$');
      for (final entry in CertPins.byHost.entries) {
        for (final pin in entry.value) {
          expect(pin, matches(pattern),
              reason:
                  '${entry.key}: pin "$pin" is not valid base64 SHA-256');
          // And must round-trip through base64 decode to 32 bytes.
          final decoded = base64.decode(pin);
          expect(decoded.length, 32,
              reason: '${entry.key}: pin "$pin" is not 32 bytes');
        }
      }
    });

    test('app.carreports.ru keeps the previous leaf pin as backup', () {
      // Rotation safety net: the previous leaf SPKI must remain pinned for
      // one cycle so a server-side rollback or a second renewal doesn't
      // break already-shipped release builds. Remove this assertion only
      // after a new pin is confirmed stable in production.
      const previousLeaf = 'yq74wyn28jTDXpEfFimpWRng2BxD6LuR2lDQHOO75IA=';
      expect(CertPins.byHost['app.carreports.ru']!, contains(previousLeaf));
    });

    test('intermediate CA reference is documented and well-formed', () {
      final pin = CertPins.intermediateYe1Pin;
      expect(pin, matches(RegExp(r'^[A-Za-z0-9+/]{43}=$')));
      expect(base64.decode(pin).length, 32);
    });
  });

  group('CertPins.pinsFor', () {
    test('returns the pin set for a known host', () {
      final pins = CertPins.pinsFor('app.carreports.ru');
      expect(pins, isNotNull);
      expect(pins!, isNotEmpty);
    });

    test('returns null for an unknown host (fail-closed)', () {
      expect(CertPins.pinsFor('evil.example.com'), isNull);
      expect(CertPins.pinsFor('carreports.ru'), isNull,
          reason: 'bare apex must not match — only the pinned subdomains');
    });
  });
}
