import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/ui/common/widgets/custom_app_bar_widget.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('legacy app bar keeps its original defaults unless Spark opts in', () {
    final legacy = simpleAppBar(title: 'Старый экран');
    final spark = simpleAppBar(title: 'Spark экран', sparkStyle: true);

    expect(legacy.centerTitle, isTrue);
    expect(legacy.titleSpacing, 20);
    expect(legacy.backgroundColor, isNull);
    expect(legacy.bottom, isNotNull);
    expect(legacy.shape, isNull);

    expect(spark.centerTitle, isFalse);
    expect(spark.backgroundColor, kPrimaryColor);
    expect(spark.bottom, isNull);
    expect(spark.shape, isA<Border>());
  });

  testWidgets('standard Spark header keeps the shared surface and divider', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: sparkAppBar(
            title: 'Вложенный экран',
            leading: const BackButton(),
          ),
        ),
      ),
    );

    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.centerTitle, isFalse);
    expect(appBar.backgroundColor, kPrimaryColor);
    expect(appBar.surfaceTintColor, Colors.transparent);
    expect(appBar.scrolledUnderElevation, 0);
    expect(appBar.shape, isA<Border>());
    expect(find.text('Вложенный экран'), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
  });

  testWidgets('draft report title is directly editable in the app bar', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'Старое название');
    final focusNode = FocusNode();
    addTearDown(controller.dispose);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: SparkReportEditorAppBar(
            title: 'Старое название',
            titleController: controller,
            titleFocusNode: focusNode,
            meta: 'Черновик',
            draftStatus: 'Сохранено',
            draftStatusColor: Colors.green,
            draftStatusIcon: Icons.check,
            draftSaving: false,
            onBack: () {},
          ),
        ),
      ),
    );

    // В покое шапка читается как текст: поля нет, есть заголовок и карандаш.
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Старое название'), findsOneWidget);
    expect(find.byIcon(Icons.edit_rounded), findsOneWidget);

    await tester.tap(find.byIcon(Icons.edit_rounded));
    await tester.pump();
    await tester.pump();
    final titleField = find.byType(TextField);
    expect(titleField, findsOneWidget);
    expect(focusNode.hasFocus, isTrue);
    expect(find.text('Готово'), findsOneWidget);

    await tester.enterText(titleField, 'Новое название');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(controller.text, 'Новое название');
    expect(focusNode.hasFocus, isFalse);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('Новое название'), findsOneWidget);
    expect(find.byIcon(Icons.edit_rounded), findsOneWidget);

    // Пилюля автосейва прижата к правому краю шапки и висит по центру
    // блока «заголовок + мета» (макет 2026-07-11).
    final titleCenter = tester.getCenter(find.text('Новое название'));
    final metaCenter = tester.getCenter(find.text('Черновик'));
    final statusCenter = tester.getCenter(find.text('Сохранено'));
    expect(statusCenter.dx, greaterThan(600));
    expect(statusCenter.dy, greaterThan(titleCenter.dy - 1));
    expect(statusCenter.dy, lessThan(metaCenter.dy + 1));
  });

  testWidgets('completed report title stays read-only', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: SparkReportEditorAppBar(
            title: 'Завершённый отчёт',
            meta: '№ 42',
            draftStatus: 'Завершён',
            draftStatusColor: Colors.green,
            draftStatusIcon: Icons.check,
            draftSaving: false,
            onBack: () {},
          ),
        ),
      ),
    );

    expect(find.byType(TextField), findsNothing);
    expect(find.text('Завершённый отчёт'), findsOneWidget);
  });
}
