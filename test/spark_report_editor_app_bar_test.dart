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

    final titleField = find.byType(TextField);
    expect(titleField, findsOneWidget);
    expect(find.text('Изменить'), findsOneWidget);

    await tester.tap(find.text('Изменить'));
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);
    expect(find.text('Готово'), findsOneWidget);

    await tester.enterText(titleField, 'Новое название');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(controller.text, 'Новое название');
    expect(focusNode.hasFocus, isFalse);
    expect(find.text('Изменить'), findsOneWidget);

    final metaCenter = tester.getCenter(find.text('Черновик'));
    final statusCenter = tester.getCenter(find.text('Сохранено'));
    expect((metaCenter.dy - statusCenter.dy).abs(), lessThan(6));
    expect(statusCenter.dx, lessThan(400));
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
