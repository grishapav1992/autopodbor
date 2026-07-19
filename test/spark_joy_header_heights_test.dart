import 'package:flutter/material.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_ui.dart';
import 'package:flutter_test/flutter_test.dart';

/// Хэдеры разделов/групп не должны прыгать по высоте (жалоба 2026-07-19):
/// высота шапки одинакова для любого раздела, статуса и наполнения чипов —
/// даже на узком экране с крупным системным шрифтом.
void main() {
  // Названия разделов продублированы из приватного _SparkJoyStepRegistry:
  // при изменении реестра тест сознательно требует синхронизации руками.
  const stepTitles = [
    'Автомобиль',
    'Параметры',
    'Сверка документов',
    'Материалы проверки',
    'Осмотр',
    'Тест-драйв',
    'Итог',
  ];

  Widget harness(Widget child) {
    return MaterialApp(
      home: Builder(
        builder: (context) => MediaQuery(
          // Крупный системный шрифт — раньше именно он переносил длинные
          // названия («Сверка документов») на вторую строку.
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.3)),
          child: Scaffold(
            body: Align(alignment: Alignment.topCenter, child: child),
          ),
        ),
      ),
    );
  }

  Future<void> useNarrowScreen(WidgetTester tester) async {
    tester.view.physicalSize = const Size(320 * 3, 640 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets('шапка раздела одной высоты для всех разделов и статусов', (
    tester,
  ) async {
    await useNarrowScreen(tester);

    final heights = <double>[];
    for (final title in stepTitles) {
      for (final (statusText, statusColor) in [
        ('Заполнено', Colors.green),
        ('В работе', Colors.orange),
      ]) {
        await tester.pumpWidget(
          harness(
            SparkStepHeroCard(
              icon: Icons.directions_car_outlined,
              currentStep: 3,
              totalSteps: 7,
              title: title,
              statusText: statusText,
              statusColor: statusColor,
            ),
          ),
        );
        heights.add(tester.getSize(find.byType(SparkStepHeroCard)).height);
      }
    }

    for (final height in heights) {
      expect(height, closeTo(heights.first, 0.01));
    }
    // Прогресс-бар из шапки убран (жил только на «Итоге» и делал её выше).
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('шапка группы осмотра одной высоты при любых чипах', (
    tester,
  ) async {
    await useNarrowScreen(tester);

    const variants = [
      // (title, files, noted, issues): от пустой группы до трёх широких
      // чипов, которые раньше Wrap переносил на второй ряд.
      ('Кузов', 0, 0, 0),
      ('Салон', 12, 3, 0),
      ('Подкапотное пространство', 99, 99, 99),
    ];

    final heights = <double>[];
    for (final (title, files, noted, issues) in variants) {
      await tester.pumpWidget(
        harness(
          SparkMediaGroupHeaderCard(
            title: title,
            filesCount: files,
            notedCount: noted,
            issuesCount: issues,
          ),
        ),
      );
      heights.add(
        tester.getSize(find.byType(SparkMediaGroupHeaderCard)).height,
      );
    }

    for (final height in heights) {
      expect(height, closeTo(heights.first, 0.01));
    }
  });

  testWidgets('шапка интейка держит высоту шапки редактора отчёта', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: sparkAppBar(
            title: 'Материалы автомобиля',
            subtitle: 'ИИ распределит файлы по разделам отчёта',
            toolbarHeight: SparkReportEditorAppBar.toolbarHeight,
          ),
        ),
      ),
    );

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.toolbarHeight, SparkReportEditorAppBar.toolbarHeight);
    expect(
      tester.getSize(find.byType(AppBar)).height,
      SparkReportEditorAppBar.toolbarHeight,
    );
  });
}
