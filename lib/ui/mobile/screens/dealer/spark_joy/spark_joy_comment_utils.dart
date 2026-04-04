class SparkJoyCommentUtils {
  const SparkJoyCommentUtils._();

  static const List<String> _audioExtensions = <String>[
    '.wav',
    '.mp3',
    '.m4a',
    '.aac',
    '.ogg',
    '.oga',
    '.webm',
    '.caf',
  ];

  static bool isLikelyAudioFileName(String name) {
    final lower = name.trim().toLowerCase();
    if (lower.isEmpty) return false;
    for (final extension in _audioExtensions) {
      if (lower.endsWith(extension)) return true;
    }
    return false;
  }

  static String appendRecognizedTranscript({
    required String previous,
    required String transcript,
  }) {
    final text = transcript.trim();
    if (text.isEmpty) return previous;

    final safePrevious = previous.trimRight();
    final separator =
        safePrevious.isEmpty ||
            safePrevious.endsWith(' ') ||
            safePrevious.endsWith('\n')
        ? ''
        : ' ';
    return '$safePrevious$separator$text';
  }

  static String recordingDurationLabel(int totalSeconds) {
    final safeSeconds = totalSeconds < 0 ? 0 : totalSeconds;
    final minutes = (safeSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (safeSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}
