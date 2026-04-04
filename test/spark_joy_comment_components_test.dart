import 'package:flutter/material.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_comment_components.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SparkJoyCommentInputPanel', () {
    testWidgets('renders hint and actions', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SparkJoyCommentInputPanel(
              controller: controller,
              isDictating: false,
              onToggleDictation: () {},
              onAiFormat: () {},
              onDismissKeyboard: () {},
            ),
          ),
        ),
      );

      expect(find.text('Добавьте комментарий'), findsOneWidget);
      expect(find.text('Голос'), findsOneWidget);
      expect(find.text('ИИ'), findsOneWidget);
    });

    testWidgets('shows dictation state', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SparkJoyCommentInputPanel(
              controller: controller,
              isDictating: true,
              onToggleDictation: () {},
              onAiFormat: () {},
              onDismissKeyboard: () {},
            ),
          ),
        ),
      );

      expect(find.text('Идёт надиктовка...'), findsOneWidget);
      expect(find.text('Стоп'), findsOneWidget);
    });
  });

  group('SparkJoyCommentAudioBlock', () {
    testWidgets('invokes callbacks for controls', (tester) async {
      var recordTapped = 0;
      var addTapped = 0;
      var playedIndex = -1;
      var removedIndex = -1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SparkJoyCommentAudioBlock(
              items: const [
                SparkJoyCommentAudioItemView(name: 'note_1.wav', isPlaying: false),
              ],
              isRecording: false,
              recordingLabel: '00:00',
              onToggleRecording: () async {
                recordTapped += 1;
              },
              onAddAudio: () async {
                addTapped += 1;
              },
              onTogglePlay: (index) async {
                playedIndex = index;
              },
              onRemoveAt: (index) {
                removedIndex = index;
              },
            ),
          ),
        ),
      );

      await tester.tap(find.text('Записать голосовое'));
      await tester.pump();
      expect(recordTapped, 1);

      await tester.tap(find.text('Приложить аудиофайл'));
      await tester.pump();
      expect(addTapped, 1);

      await tester.tap(find.byIcon(Icons.play_circle_outline));
      await tester.pump();
      expect(playedIndex, 0);

      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pump();
      expect(removedIndex, 0);
    });

    testWidgets('renders stop label in recording state', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SparkJoyCommentAudioBlock(
              items: const [],
              isRecording: true,
              recordingLabel: '00:07',
              onToggleRecording: () async {},
              onAddAudio: () async {},
              onTogglePlay: (_) async {},
              onRemoveAt: (_) {},
            ),
          ),
        ),
      );

      expect(find.text('Стоп (00:07)'), findsOneWidget);
    });
  });
}
