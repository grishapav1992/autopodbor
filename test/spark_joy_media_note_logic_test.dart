import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_media_note_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sparkJoyDeriveGroupNote (B16)', () {
    test('explicit editor note wins over file notes', () {
      expect(
        sparkJoyDeriveGroupNote('новая заметка', const ['старая', 'другая']),
        'новая заметка',
      );
    });

    test('empty explicit note derives from the files', () {
      expect(
        sparkJoyDeriveGroupNote('', const ['', 'вмятина на двери', '']),
        'вмятина на двери',
      );
    });

    test('cleared note does NOT resurrect when no file carries one', () {
      // Add note -> clear note -> the per-file apply wiped the note, so the
      // files carry nothing and the group note must end up empty. Before the
      // fix this fell back to the stale group note and reappeared.
      expect(sparkJoyDeriveGroupNote('', const ['', '', '']), '');
    });

    test('whitespace-only values are treated as empty', () {
      expect(sparkJoyDeriveGroupNote('   ', const ['  ', '\n']), '');
      expect(sparkJoyDeriveGroupNote('  ', const ['  ', '  заметка ']), 'заметка');
    });

    test('no files at all yields an empty note', () {
      expect(sparkJoyDeriveGroupNote('', const []), '');
    });
  });
}
