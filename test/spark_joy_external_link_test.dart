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
  });
}
