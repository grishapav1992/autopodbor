import 'dart:typed_data';

import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_comment_audio_picker_port.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCommentAudioPickerPort implements SparkJoyCommentAudioPickerPort {
  _FakeCommentAudioPickerPort(this.items);

  final List<SparkJoyPickedMediaFile> items;
  bool called = false;
  bool? lastIsMobileNative;

  @override
  Future<List<SparkJoyPickedMediaFile>> pickCommentAudioFiles({
    required bool isMobileNative,
  }) async {
    called = true;
    lastIsMobileNative = isMobileNative;
    return items;
  }
}

void main() {
  test('fake picker port returns provided items and captures arguments', () async {
    final expected = <SparkJoyPickedMediaFile>[
      SparkJoyPickedMediaFile(
        name: 'voice_1.m4a',
        bytes: Uint8List.fromList(<int>[1, 2, 3]),
        mimeType: 'audio/mp4',
      ),
    ];
    final fake = _FakeCommentAudioPickerPort(expected);

    final actual = await fake.pickCommentAudioFiles(isMobileNative: true);

    expect(fake.called, isTrue);
    expect(fake.lastIsMobileNative, isTrue);
    expect(actual.length, 1);
    expect(actual.first.name, 'voice_1.m4a');
    expect(actual.first.mimeType, 'audio/mp4');
  });
}
