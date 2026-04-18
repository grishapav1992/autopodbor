part of 'spark_joy_create_report_screen.dart';

extension _SparkJoyCommentAudioHelpers on _SparkJoyCreateReportScreenState {
  Uint8List _pcm16ToWav(
    Uint8List pcmBytes, {
    required int sampleRate,
    int channels = 1,
  }) {
    final dataLength = pcmBytes.length;
    final output = Uint8List(44 + dataLength);
    final view = ByteData.sublistView(output);
    final byteRate = sampleRate * channels * 2;
    final blockAlign = channels * 2;

    void writeAscii(int offset, String value) {
      for (var i = 0; i < value.length; i++) {
        view.setUint8(offset + i, value.codeUnitAt(i));
      }
    }

    writeAscii(0, 'RIFF');
    view.setUint32(4, 36 + dataLength, Endian.little);
    writeAscii(8, 'WAVE');
    writeAscii(12, 'fmt ');
    view.setUint32(16, 16, Endian.little);
    view.setUint16(20, 1, Endian.little);
    view.setUint16(22, channels, Endian.little);
    view.setUint32(24, sampleRate, Endian.little);
    view.setUint32(28, byteRate, Endian.little);
    view.setUint16(32, blockAlign, Endian.little);
    view.setUint16(34, 16, Endian.little);
    writeAscii(36, 'data');
    view.setUint32(40, dataLength, Endian.little);
    output.setRange(44, 44 + dataLength, pcmBytes);
    return output;
  }

  bool _isCommentRecording(String key) {
    return _activeSectionCommentRecordingKey == key;
  }

  int _commentRecordingSeconds(String key) {
    return _sectionCommentRecordingSeconds[key] ?? 0;
  }

  String _commentRecordingLabel(String key) {
    return SparkJoyCommentUtils.recordingDurationLabel(
      _commentRecordingSeconds(key),
    );
  }

  Future<void> _startSectionCommentRecording(String key) async {
    if (_isCommentRecording(key)) return;
    if (_activeSectionCommentRecordingKey != null &&
        _activeSectionCommentRecordingKey != key) {
      _showErrorSnack('Сначала остановите текущую запись');
      return;
    }

    final hasPermission =
        _microphonePermissionGranted ||
        await _sectionCommentRecorder.hasPermission();
    if (!hasPermission) {
      _showErrorSnack('Нет доступа к микрофону');
      return;
    }
    _microphonePermissionGranted = true;

    try {
      _sectionCommentRecordBuffer = BytesBuilder(copy: false);
      await _sectionCommentRecordSub?.cancel();
      _sectionCommentRecordSub =
          (await _sectionCommentRecorder.startStream(
            const RecordConfig(
              encoder: AudioEncoder.pcm16bits,
              sampleRate: 16000,
              numChannels: 1,
            ),
          )).listen((chunk) {
            _sectionCommentRecordBuffer?.add(chunk);
          });
      _sectionCommentRecordTimer?.cancel();
      _sectionCommentRecordTimer = Timer.periodic(const Duration(seconds: 1), (
        _,
      ) {
        if (!mounted || _activeSectionCommentRecordingKey != key) return;
        _setStateSafely(() {
          final next = (_sectionCommentRecordingSeconds[key] ?? 0) + 1;
          _sectionCommentRecordingSeconds[key] = next;
        });
      });
      if (!mounted) return;
      _setStateSafely(() {
        _activeSectionCommentRecordingKey = key;
        _sectionCommentRecordingSeconds[key] = 0;
      });
    } catch (_) {
      _showErrorSnack('Не удалось начать запись');
    }
  }

  Future<void> _stopSectionCommentRecording({
    required String key,
    required List<UploadedItem> files,
    required ValueSetter<List<UploadedItem>> setFiles,
    bool keepResult = true,
  }) async {
    if (!_isCommentRecording(key)) return;

    try {
      await _sectionCommentRecorder.stop();
    } catch (_) {}

    _sectionCommentRecordTimer?.cancel();
    _sectionCommentRecordTimer = null;
    await _sectionCommentRecordSub?.cancel();
    _sectionCommentRecordSub = null;

    final pcmBytes = _sectionCommentRecordBuffer?.takeBytes() ?? Uint8List(0);
    _sectionCommentRecordBuffer = null;

    var nextFiles = files;
    if (keepResult && pcmBytes.isNotEmpty) {
      final wavBytes = _pcm16ToWav(pcmBytes, sampleRate: 16000);
      String? stored;
      if (kIsWeb) {
        stored = 'data:audio/wav;base64,${base64Encode(wavBytes)}';
      } else {
        stored = await _persistBytesToAppStorage(
          bytes: wavBytes,
          mimeType: 'audio/wav',
          prefix: '${key}_comment_audio',
        );
      }
      if ((stored ?? '').trim().isNotEmpty) {
        nextFiles = [
          ...files,
          UploadedItem(
            id: _nextUploadedItemId(prefix: '${key}_comment_audio'),
            name: 'Голосовое сообщение ${files.length + 1}',
            mimeType: 'audio/wav',
            dataUrl: stored!.trim(),
          ),
        ];
      } else {
        _showErrorSnack('Не удалось сохранить аудио локально');
      }
    }

    if (!mounted) return;
    _setStateSafely(() {
      setFiles(nextFiles);
      _sectionCommentRecordingSeconds[key] = 0;
      if (_activeSectionCommentRecordingKey == key) {
        _activeSectionCommentRecordingKey = null;
      }
    });
    _markDraftDirty();
  }

  Future<void> _toggleDocsCommentRecording() async {
    if (_isCommentRecording('docs_comment')) {
      await _stopSectionCommentRecording(
        key: 'docs_comment',
        files: _docsCommentAudioFiles,
        setFiles: (next) => _docsCommentAudioFiles = next,
      );
      return;
    }
    await _startSectionCommentRecording('docs_comment');
  }

  Future<void> _toggleLegalCommentRecording() async {
    if (_isCommentRecording('legal_comment')) {
      await _stopSectionCommentRecording(
        key: 'legal_comment',
        files: _legalCommentAudioFiles,
        setFiles: (next) => _legalCommentAudioFiles = next,
      );
      return;
    }
    await _startSectionCommentRecording('legal_comment');
  }

  Future<void> _toggleTdCommentRecording() async {
    if (_isCommentRecording('td_comment')) {
      await _stopSectionCommentRecording(
        key: 'td_comment',
        files: _tdCommentAudioFiles,
        setFiles: (next) => _tdCommentAudioFiles = next,
      );
      return;
    }
    await _startSectionCommentRecording('td_comment');
  }

  Future<void> _toggleExpertCommentRecording() async {
    if (_isCommentRecording('expert_comment')) {
      await _stopSectionCommentRecording(
        key: 'expert_comment',
        files: _expertAudioFiles,
        setFiles: (next) => _expertAudioFiles = next,
      );
      return;
    }
    await _startSectionCommentRecording('expert_comment');
  }

  void _resetCommentAudioPlayingIndexes() {
    _docsCommentPlayingAudioIndex = -1;
    _legalCommentPlayingAudioIndex = -1;
    _tdCommentPlayingAudioIndex = -1;
    _expertCommentPlayingAudioIndex = -1;
  }

  Future<void> _toggleSharedCommentAudioPlayback({
    required List<UploadedItem> files,
    required int index,
    required bool currentlyPlaying,
    required VoidCallback activateIndex,
  }) async {
    if (index < 0 || index >= files.length) return;
    try {
      if (currentlyPlaying) {
        await _sectionCommentAudioPlayer.stop();
        if (!mounted) return;
        _setStateSafely(_resetCommentAudioPlayingIndexes);
        return;
      }
      await _sectionCommentAudioPlayer.stop();
      await _playAudioSource(_sectionCommentAudioPlayer, files[index].dataUrl);
      if (!mounted) return;
      _setStateSafely(() {
        _resetCommentAudioPlayingIndexes();
        activateIndex();
      });
    } catch (_) {
      _showErrorSnack('Не удалось воспроизвести аудио');
    }
  }

  Future<void> _toggleCommentAudioPlayback({
    required bool docsComment,
    required int index,
  }) async {
    final list = docsComment ? _docsCommentAudioFiles : _legalCommentAudioFiles;
    await _toggleSharedCommentAudioPlayback(
      files: list,
      index: index,
      currentlyPlaying: docsComment
          ? _docsCommentPlayingAudioIndex == index
          : _legalCommentPlayingAudioIndex == index,
      activateIndex: () {
        if (docsComment) {
          _docsCommentPlayingAudioIndex = index;
        } else {
          _legalCommentPlayingAudioIndex = index;
        }
      },
    );
  }

  Future<void> _toggleTdCommentAudioPlayback(int index) async {
    await _toggleSharedCommentAudioPlayback(
      files: _tdCommentAudioFiles,
      index: index,
      currentlyPlaying: _tdCommentPlayingAudioIndex == index,
      activateIndex: () => _tdCommentPlayingAudioIndex = index,
    );
  }

  Future<void> _toggleExpertCommentAudioPlayback(int index) async {
    await _toggleSharedCommentAudioPlayback(
      files: _expertAudioFiles,
      index: index,
      currentlyPlaying: _expertCommentPlayingAudioIndex == index,
      activateIndex: () => _expertCommentPlayingAudioIndex = index,
    );
  }
}
