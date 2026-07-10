import 'package:flutter/material.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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

    await tester.tap(titleField);
    await tester.enterText(titleField, 'Новое название');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(controller.text, 'Новое название');
    expect(focusNode.hasFocus, isFalse);
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
