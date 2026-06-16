import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter_application_1/data/api/spki_extractor.dart';
import 'package:flutter_test/flutter_test.dart';

/// Real leaf certificate for app.carreports.ru as captured on 2026-06-16
/// (CN=app.carreports.ru, issued by Let's Encrypt YE1, valid until
/// 2026-09-14). Captured via `openssl s_client ... -showcerts` and converted
/// to DER base64. Used to prove our hand-rolled SPKI extractor yields the
/// same hash as openssl's reference computation.
const _leafAppCarreportsDerBase64 =
    'MIID7TCCA3KgAwIBAgISBcVatGTOAy35u3JfMJfSqPt8MAoGCCqGSM49BAMDMDMxCzAJ'
    'BgNVBAYTAlVTMRYwFAYDVQQKEw1MZXQncyBFbmNyeXB0MQwwCgYDVQQDEwNZRTEwHhcN'
    'MjYwNjE2MDU0ODI0WhcNMjYwOTE0MDU0ODIzWjAcMRowGAYDVQQDExFhcHAuY2FycmVw'
    'b3J0cy5ydTBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABFs/IVtnjtDi1Qy30adXdJkd'
    'kifLw643iMmPyzW5XpwDpCw9lQXGHBvyQUcP8pWeFKCtXr2atVljOao4iOT5CwWjggJ7'
    'MIICdzAOBgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAwwCgYIKwYBBQUHAwEwDAYDVR0TAQH/'
    'BAIwADAdBgNVHQ4EFgQUroLKWd0XM59cTRtIw+t0h0+yuxowHwYDVR0jBBgwFoAUuyDKR'
    'wv+1+Wc+Y8JKqOMN0WxvNgwMwYIKwYBBQUHAQEEJzAlMCMGCCsGAQUFBzAChhdodHRw'
    'Oi8veWUxLmkubGVuY3Iub3JnLzB4BgNVHREEcTBvghBhaS5jYXJyZXBvcnRzLnJ1ghFh'
    'cHAuY2FycmVwb3J0cy5ydYINY2FycmVwb3J0cy5ydYIZaW50ZWdyYXRpb24uY2FycmVw'
    'b3J0cy5ydYIMdmluZGllemVsLnJ1ghB3cy5jYXJyZXBvcnRzLnJ1MBMGA1UdIAQMMAow'
    'CAYGZ4EMAQIBMC8GA1UdHwQoMCYwJKAioCCGHmh0dHA6Ly95ZTEuYy5sZW5jci5vcmcv'
    'MTI1LmNybDCCAQsGCisGAQQB1nkCBAIEgfwEgfkA9wB+AEavhj07PuWfpXfeqCRdNrDZ'
    '7SKiI/Rhd0EilFLulVBfAAABns8u2NwACAAABQAJ43aJBAMARzBFAiADkppXnpb7mBxn'
    'zUcWR+TfrVMpjciV7lfDOzDmjEgBKQIhAKAb8TWPLpzlrqbThHSn2KH9/o6l2E8aAgbc'
    '/YADFf2uAHUAr2eIO1ewTt2Pptl+9i6o64EKx3Fg8CReVdYML+eFhzoAAAGezy7ZLAAA'
    'BAMARjBEAiA9UBbw4OJ/SYgqcaG68jidYiVcW6wKEPjZcPJPItlxyQIgGJjhjxu17BzU'
    'KSKp/Rljc57lZ+oHdaKwtdrgdf3kEmMwCgYIKoZIzj0EAwMDaQAwZgIxALthSceAAq9C'
    'rnGf/cBDup54FGeRWLbM3Ov8oXrVX6xKyrWdfCOzxlM7ULbCsRAtcwIxAMaYN5mjZFtP'
    'OBzau1WzgX6CMWdNEyhzYrj5Dhj2Pgr3qbSbFyL0DmtSW1cfuCg7VQ==';

// Reference SPKI hash computed independently with openssl:
//   openssl x509 -in c1.pem -pubkey -noout \
//   | openssl pkey -pubin -outform der \
//   | openssl dgst -sha256 -binary | openssl base64
const _leafAppCarreportsSpkiSha256Base64 =
    'XCR1wYjnywKkDVarf6Y7NnE3T+AxpL4n+CqNfG3d5WE=';

void main() {
  group('extractSubjectPublicKeyInfo', () {
    test('extracts the SPKI whose SHA-256 matches openssl reference', () {
      final der = base64.decode(_leafAppCarreportsDerBase64);
      final spki = extractSubjectPublicKeyInfo(der);
      expect(spki, isNotNull,
          reason: 'SPKI extraction must succeed on a real certificate');
      final hash = crypto.sha256.convert(spki!);
      final b64 = base64.encode(hash.bytes);
      expect(b64, _leafAppCarreportsSpkiSha256Base64,
          reason:
              'the extractor must produce the exact SPKI hash openssl does');
    });

    test('returns null on malformed input (fail-closed)', () {
      expect(extractSubjectPublicKeyInfo(<int>[0x00, 0x00]), isNull);
      expect(extractSubjectPublicKeyInfo(<int>[]), isNull);
      // Truncated SEQUENCE header.
      expect(extractSubjectPublicKeyInfo(<int>[0x30]), isNull);
    });

    test('fails on a non-SEQUENCE top-level tag', () {
      // INTEGER (0x02) at the root instead of SEQUENCE (0x30).
      expect(extractSubjectPublicKeyInfo(<int>[0x02, 0x01, 0x05]), isNull);
    });
  });
}
