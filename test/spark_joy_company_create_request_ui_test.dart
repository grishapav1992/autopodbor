import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/data/api/storage_api_models.dart';
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_company_create_request_screen.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    UserSimplePreferences.pref = null;
    await UserSimplePreferences.init();
  });

  testWidgets(
    'форма заявки использует брендовый прогресс и короткий URL hint',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: SparkJoyCompanyCreateRequestScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('drive.google.com'), findsNothing);
      expect(find.text('auto.ru, avito.ru/…'), findsOneWidget);

      final fill = tester.widget<DecoratedBox>(
        find.byKey(const ValueKey('company-request-progress-fill')),
      );
      final decoration = fill.decoration as BoxDecoration;
      final gradient = decoration.gradient! as LinearGradient;
      expect(gradient.colors, const <Color>[kSecondaryColor, kBlueColor]);
    },
  );

  testWidgets('фото автомобиля сохраняет пропорции как в шаге отчёта', (
    tester,
  ) async {
    final restyling = RestylingItem(
      id: 4,
      restyling: 'Рестайлинг',
      yearStart: 2022,
      yearEnd: null,
      frames: const <FrameItem>[],
      photos: <PhotoItem>[
        PhotoItem(
          id: 5,
          size: '2x',
          urlX1: '',
          urlX2: 'https://example.invalid/car.png',
        ),
      ],
    );
    await SparkJoyStorage.saveCompanyRequestDraft(<String, dynamic>{
      'brand': BrandItem(id: 1, name: 'BMW', nameRus: 'БМВ').toJson(),
      'model': ModelItem(
        id: 2,
        brandId: 1,
        model: 'X5',
        modelRus: 'X5',
      ).toJson(),
      'generation': GenerationItem(
        id: 3,
        modelCarId: 2,
        generation: 4,
        frames: const <FrameItem>[],
        restylings: <RestylingItem>[restyling],
      ).toJson(),
      'restyling': restyling.toJson(),
    });

    await tester.pumpWidget(
      const MaterialApp(home: SparkJoyCompanyCreateRequestScreen()),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final image = tester.widget<CachedNetworkImage>(
      find.byType(CachedNetworkImage),
    );
    expect(image.fit, BoxFit.fitWidth);
    expect(image.height, isNull, reason: 'не зажимаем фото в баннер 158 px');
  });
}
