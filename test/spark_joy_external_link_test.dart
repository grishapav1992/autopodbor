import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_external_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sparkNormalizeExternalUrl', () {
    test('adds https scheme when user enters a bare domain', () {
      expect(
        sparkNormalizeExternalUrl('auto.ru/cars/used/sale/123'),
        'https://auto.ru/cars/used/sale/123',
      );
    });

    test('keeps valid http and https links', () {
      expect(
        sparkNormalizeExternalUrl('https://avito.ru/item'),
        'https://avito.ru/item',
      );
      expect(
        sparkNormalizeExternalUrl('http://example.com/a'),
        'http://example.com/a',
      );
    });

    test('rejects unsupported schemes and missing host', () {
      expect(sparkNormalizeExternalUrl('tg://resolve?domain=test'), isEmpty);
      expect(sparkNormalizeExternalUrl('https://'), isEmpty);
      expect(sparkNormalizeExternalUrl(''), isEmpty);
    });

    // Regression: server-supplied URLs handed to launchUrl must never be
    // able to trigger intent:/tel:/javascript: (intent injection via a
    // compromised backend). See _openListingPdf / _openShareUrl.
    test('rejects dangerous schemes used for intent injection', () {
      expect(sparkNormalizeExternalUrl('intent://evil#Intent;package=com.evil'),
          isEmpty);
      expect(sparkNormalizeExternalUrl('tel:+79991234567'), isEmpty);
      expect(sparkNormalizeExternalUrl('javascript:alert(1)'), isEmpty);
      expect(sparkNormalizeExternalUrl('market://details?id=com.evil'), isEmpty);
      expect(sparkNormalizeExternalUrl('file:///etc/passwd'), isEmpty);
    });

    test('accepts presigned S3 and carreports share URLs', () {
      // Real shapes used by the dealer flow (listingPdfUrl / share link).
      expect(
        sparkNormalizeExternalUrl(
          'https://s3.regru.cloud/reports/abc/listing.pdf?X-Amz-Signature=xyz',
        ),
        isNot(isEmpty),
      );
      expect(
        sparkNormalizeExternalUrl('https://carreports.ru/share/abc123'),
        'https://carreports.ru/share/abc123',
      );
    });
  });
}
