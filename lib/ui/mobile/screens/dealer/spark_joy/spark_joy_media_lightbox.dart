part of 'spark_joy_create_report_screen.dart';

extension _SparkJoyMediaLightboxMethods on _SparkJoyCreateReportScreenState {
  Future<void> _runOpenMediaGroupLightbox({
    required String groupKey,
    required int initialIndex,
    List<UploadedItem>? filesOverride,
    List<String>? groupKeyPerFile,
  }) async {
    // Two modes:
    //   (a) Group mode (default): files come from _mediaState[groupKey];
    //       element labels / no-damage copy / tag colors all reference
    //       that single group; "Edit note" button jumps back to it.
    //   (b) Flat mode: caller passes `filesOverride` (and optionally a
    //       parallel `groupKeyPerFile` list). Used from "Обзор авто" on
    //       the summary step where the thumbnail strip flattens several
    //       sections — swiping must keep working across the whole set.
    //       Edit-note is hidden (a flat list has no single group to
    //       return to).
    final isFlatMode = filesOverride != null;
    final initialFiles = filesOverride ??
        (_mediaState[groupKey]?.files ?? const <UploadedItem>[]);
    if (initialFiles.isEmpty) return;
    String groupKeyFor(int index) {
      if (!isFlatMode) return groupKey;
      if (groupKeyPerFile == null ||
          index < 0 ||
          index >= groupKeyPerFile.length) {
        return groupKey;
      }
      return groupKeyPerFile[index];
    }

    var currentIndex = initialIndex.clamp(0, initialFiles.length - 1);
    final controller = PageController(initialPage: currentIndex);
    final audioPlayer = AudioPlayer();
    StreamSubscription<void>? playerCompleteSubscription;
    var playingAudioIndex = -1;
    var dialogActive = true;
    VideoPlayerController? videoController;
    String? videoSourceUrl;
    var videoInitializing = false;
    String? videoErrorMessage;

    Future<void> disposeVideoController() async {
      final previous = videoController;
      videoController = null;
      videoSourceUrl = null;
      videoInitializing = false;
      videoErrorMessage = null;
      if (previous == null) return;
      try {
        await previous.pause();
      } catch (_) {}
      await previous.dispose();
    }

    Future<void> prepareVideo(
      UploadedItem file,
      StateSetter setLocalState,
    ) async {
      if (!file.isVideo) {
        await disposeVideoController();
        if (!dialogActive) return;
        setLocalState(() {});
        return;
      }

      final source = file.dataUrl;
      if (videoSourceUrl == source &&
          videoController != null &&
          videoController!.value.isInitialized) {
        return;
      }
      if (videoInitializing && videoSourceUrl == source) return;

      videoInitializing = true;
      videoErrorMessage = null;
      videoSourceUrl = source;
      if (dialogActive) setLocalState(() {});

      final previous = videoController;
      videoController = null;
      if (previous != null) {
        try {
          await previous.pause();
        } catch (_) {}
        await previous.dispose();
      }

      try {
        final nextController = VideoPlayerController.networkUrl(
          _mediaSourceUri(source),
        );
        await nextController.initialize();
        await nextController.setLooping(true);
        await nextController.play();
        if (!dialogActive) {
          await nextController.dispose();
          return;
        }
        videoController = nextController;
        videoInitializing = false;
        setLocalState(() {});
      } catch (_) {
        videoInitializing = false;
        videoErrorMessage = 'Не удалось воспроизвести видео';
        if (!dialogActive) return;
        setLocalState(() {});
      }
    }

    int? editIndex;
    try {
      editIndex = await showDialog<int>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setLocalState) {
              playerCompleteSubscription ??= audioPlayer.onPlayerComplete
                  .listen((_) {
                    if (!dialogActive) return;
                    setLocalState(() => playingAudioIndex = -1);
                  });

              // In flat mode we take the caller-supplied snapshot as a
              // stable source of truth — editor mutations aren't possible
              // so there's nothing to live-reconcile. In group mode we
              // re-read _mediaState on every rebuild so removing / editing
              // a file updates the lightbox instantly.
              final files = isFlatMode
                  ? initialFiles
                  : (_mediaState[groupKey]?.files ?? initialFiles);
              if (files.isEmpty) {
                return Dialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(SparkRadius.xl),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      SparkSpace.xxxl,
                      SparkSpace.xxxl,
                      SparkSpace.xxxl,
                      SparkSpace.xxl,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const MyText(
                          text: 'Файлы отсутствуют',
                          size: SparkTextSize.title,
                          weight: FontWeight.w700,
                        ),
                        const SizedBox(height: SparkSpace.xs),
                        const MyText(
                          text: 'Добавьте фото или видео в разделе осмотра.',
                          size: SparkTextSize.caption,
                          color: kGreyColor,
                        ),
                        const SizedBox(height: SparkSpace.xl),
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            child: const Text('Закрыть'),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (currentIndex >= files.length) {
                currentIndex = files.length - 1;
              }
              if (currentIndex < 0) currentIndex = 0;

              final item = files[currentIndex];
              final note = item.inspection.note.trim();
              final itemGroupKey = groupKeyFor(currentIndex);
              final elementLabel = _mediaElementLabel(
                itemGroupKey,
                item.inspection.elementType,
              );
              final hasInspection = _mediaInspectionHasData(item.inspection);
              final tags = item.inspection.tags;
              final hasNoDamage = item.inspection.noDamage;
              final audioNotes = item.inspection.audioRecordings;
              final paintFrom = item.inspection.paintFrom;
              final paintTo = item.inspection.paintTo;
              final noteDisplay = note.isEmpty
                  ? 'Заметка не добавлена'
                  : (elementLabel.isEmpty ? note : '[$elementLabel] $note');

              return Dialog.fullscreen(
                child: Scaffold(
                  backgroundColor: Colors.black,
                  appBar: AppBar(
                    centerTitle: false,
                    backgroundColor: Colors.black,
                    foregroundColor: kWhiteColor,
                    elevation: 0,
                    leading: IconButton(
                      onPressed: () async {
                        await audioPlayer.stop();
                        await disposeVideoController();
                        if (!dialogContext.mounted) return;
                        Navigator.of(dialogContext).pop();
                      },
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    title: Text(
                      '${currentIndex + 1}/${files.length}',
                      style: const TextStyle(fontSize: SparkTextSize.label),
                    ),
                    actions: [
                      // Edit-note is only offered in group mode — a flat
                      // list from "Обзор авто" has no single group to
                      // open the inspection editor against. Also hidden
                      // in read-only: completed reports are viewable
                      // only, mutations don't belong there.
                      if (!isFlatMode && !widget.readOnly)
                        TextButton.icon(
                          onPressed: () async {
                            await audioPlayer.stop();
                            await disposeVideoController();
                            if (!dialogContext.mounted) return;
                            Navigator.of(dialogContext).pop(currentIndex);
                          },
                          icon: const Icon(
                            Icons.edit_note_rounded,
                            size: SparkTextSize.titleLg,
                            color: kWhiteColor,
                          ),
                          label: Text(
                            hasInspection ? 'Заметка' : 'Добавить заметку',
                            style: const TextStyle(
                              color: kWhiteColor,
                              fontSize: SparkTextSize.body,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                  body: PageView.builder(
                    controller: controller,
                    itemCount: files.length,
                    onPageChanged: (index) {
                      unawaited(audioPlayer.stop());
                      unawaited(prepareVideo(files[index], setLocalState));
                      setLocalState(() {
                        currentIndex = index;
                        playingAudioIndex = -1;
                      });
                    },
                    itemBuilder: (context, index) {
                      final file = files[index];
                      if (file.isImage) {
                        if (index == currentIndex && videoController != null) {
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!dialogActive) return;
                            unawaited(disposeVideoController());
                          });
                        }
                        return InteractiveViewer(
                          minScale: 1,
                          maxScale: 4,
                          child: Center(
                            child: _uploadedImageWidget(
                              file,
                              fit: BoxFit.contain,
                              errorColor: kWhiteColor,
                              errorSize: 44,
                            ),
                          ),
                        );
                      }
                      if (index != currentIndex) {
                        return const Center(
                          child: Icon(
                            Icons.videocam_outlined,
                            color: kWhiteColor,
                            size: SparkSize.icon5xl,
                          ),
                        );
                      }
                      if ((videoController == null ||
                              videoSourceUrl != file.dataUrl ||
                              !videoController!.value.isInitialized) &&
                          !videoInitializing) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!dialogActive) return;
                          unawaited(prepareVideo(file, setLocalState));
                        });
                      }
                      if (videoInitializing &&
                          videoSourceUrl == file.dataUrl &&
                          (videoController == null ||
                              !videoController!.value.isInitialized)) {
                        return const Center(
                          child: CircularProgressIndicator(color: kWhiteColor),
                        );
                      }
                      if (videoErrorMessage != null &&
                          videoSourceUrl == file.dataUrl) {
                        return Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                color: kWhiteColor,
                                size: SparkSize.icon4xl,
                              ),
                              const SizedBox(height: SparkSpace.md),
                              Text(
                                videoErrorMessage!,
                                style: const TextStyle(color: kWhiteColor),
                              ),
                              const SizedBox(height: SparkSpace.lg),
                              OutlinedButton(
                                onPressed: () =>
                                    prepareVideo(file, setLocalState),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: kWhiteColor,
                                  side: BorderSide(
                                    color: kWhiteColor.withValues(alpha: 0.35),
                                  ),
                                ),
                                child: const Text('Повторить'),
                              ),
                            ],
                          ),
                        );
                      }
                      final activeVideo = videoController;
                      if (activeVideo == null ||
                          !activeVideo.value.isInitialized ||
                          videoSourceUrl != file.dataUrl) {
                        return const Center(
                          child: CircularProgressIndicator(color: kWhiteColor),
                        );
                      }
                      final ratio = activeVideo.value.aspectRatio;
                      return GestureDetector(
                        onTap: () async {
                          if (activeVideo.value.isPlaying) {
                            await activeVideo.pause();
                          } else {
                            await activeVideo.play();
                          }
                          if (!dialogActive) return;
                          setLocalState(() {});
                        },
                        child: Center(
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              AspectRatio(
                                aspectRatio: ratio <= 0 ? 16 / 9 : ratio,
                                child: VideoPlayer(activeVideo),
                              ),
                              AnimatedOpacity(
                                opacity: activeVideo.value.isPlaying ? 0 : 1,
                                duration: const Duration(milliseconds: 140),
                                child: Container(
                                  width: SparkSize.mediaLightboxFab,
                                  height: SparkSize.mediaLightboxFab,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.45),
                                    shape: BoxShape.circle,
                                  ),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    color: kWhiteColor,
                                    size: SparkSize.icon3xl,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  bottomNavigationBar: Container(
                    padding: const EdgeInsets.fromLTRB(
                      SparkSpace.xxl,
                      SparkSpace.lg,
                      SparkSpace.xxl,
                      SparkSpace.chipX,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.82),
                      border: Border(
                        top: BorderSide(
                          color: kWhiteColor.withValues(alpha: 0.16),
                          width: 0.8,
                        ),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (files.length > 1) ...[
                          Center(
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: List.generate(files.length, (dotIndex) {
                                final active = dotIndex == currentIndex;
                                return InkWell(
                                  onTap: () async {
                                    await controller.animateToPage(
                                      dotIndex,
                                      duration: const Duration(
                                        milliseconds: 220,
                                      ),
                                      curve: Curves.easeOut,
                                    );
                                    if (!dialogActive) return;
                                    setLocalState(
                                      () => currentIndex = dotIndex,
                                    );
                                  },
                                  borderRadius: BorderRadius.circular(
                                    SparkRadius.pill,
                                  ),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    width: active ? 18 : 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: active
                                          ? kWhiteColor
                                          : kWhiteColor.withValues(alpha: 0.35),
                                      borderRadius: BorderRadius.circular(
                                        SparkRadius.pill,
                                      ),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          ),
                          const SizedBox(height: SparkSpace.md),
                        ],
                        if (elementLabel.isNotEmpty)
                          Text(
                            elementLabel,
                            style: const TextStyle(
                              color: kWhiteColor,
                              fontSize: SparkTextSize.body,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        if (elementLabel.isNotEmpty)
                          const SizedBox(height: SparkSpace.xs),
                        if (hasNoDamage)
                          Container(
                            margin: const EdgeInsets.only(
                              bottom: SparkSpace.sm,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: SparkSpace.lg,
                              vertical: SparkSpace.sm,
                            ),
                            decoration: BoxDecoration(
                              color: kGreenColor.withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(
                                SparkRadius.pill,
                              ),
                            ),
                            child: Text(
                              _mediaNoDamageLabel(itemGroupKey),
                              style: const TextStyle(
                                color: kWhiteColor,
                                fontSize: SparkTextSize.caption,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        if (tags.isNotEmpty) ...[
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: tags.map((tag) {
                              final color = _mediaTagColor(
                                _mediaTagSeverity(
                                  itemGroupKey,
                                  tag,
                                  elementType: item.inspection.elementType,
                                ),
                              );
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.24),
                                  borderRadius: BorderRadius.circular(
                                    SparkRadius.pill,
                                  ),
                                ),
                                child: Text(
                                  tag,
                                  style: const TextStyle(
                                    color: kWhiteColor,
                                    fontSize: SparkTextSize.caption,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: SparkSpace.sm),
                        ],
                        if (!hasNoDamage &&
                            paintFrom != null &&
                            paintTo != null) ...[
                          Row(
                            children: [
                              Icon(
                                Icons.brush_outlined,
                                size: SparkTextSize.label,
                                color: kWhiteColor.withValues(alpha: 0.8),
                              ),
                              const SizedBox(width: SparkSpace.sm),
                              Text(
                                '${paintFrom.round()}–${paintTo.round()} мкм',
                                style: TextStyle(
                                  color: kWhiteColor.withValues(alpha: 0.8),
                                  fontSize: SparkTextSize.caption,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: SparkSpace.sm),
                        ],
                        Text(
                          noteDisplay,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: note.isEmpty
                                ? kWhiteColor.withValues(alpha: 0.68)
                                : kWhiteColor,
                            fontSize: SparkTextSize.caption,
                            height: 1.3,
                          ),
                        ),
                        if (audioNotes.isNotEmpty) ...[
                          const SizedBox(height: SparkSpace.md),
                          ...List.generate(audioNotes.length, (audioIndex) {
                            final playing = playingAudioIndex == audioIndex;
                            return Padding(
                              padding: const EdgeInsets.only(
                                bottom: SparkSpace.sm,
                              ),
                              child: InkWell(
                                onTap: () async {
                                  try {
                                    if (playing) {
                                      await audioPlayer.stop();
                                      if (!dialogActive) return;
                                      setLocalState(
                                        () => playingAudioIndex = -1,
                                      );
                                    } else {
                                      await audioPlayer.stop();
                                      await _playAudioSource(
                                        audioPlayer,
                                        audioNotes[audioIndex],
                                      );
                                      if (!dialogActive) return;
                                      setLocalState(
                                        () => playingAudioIndex = audioIndex,
                                      );
                                    }
                                  } catch (_) {
                                    if (!context.mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Не удалось воспроизвести аудио',
                                        ),
                                      ),
                                    );
                                  }
                                },
                                borderRadius: BorderRadius.circular(
                                  SparkRadius.md,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                      SparkRadius.md,
                                    ),
                                    color: kWhiteColor.withValues(alpha: 0.08),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        playing
                                            ? Icons.pause_circle_outline
                                            : Icons.play_circle_outline,
                                        size: SparkSize.iconLg,
                                        color: kWhiteColor,
                                      ),
                                      const SizedBox(width: SparkSpace.md),
                                      Text(
                                        'Аудиозапись ${audioIndex + 1}',
                                        style: TextStyle(
                                          color: kWhiteColor.withValues(
                                            alpha: 0.88,
                                          ),
                                          fontSize: SparkTextSize.caption,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      dialogActive = false;
      await playerCompleteSubscription?.cancel();
      try {
        await audioPlayer.stop();
      } catch (_) {}
      await disposeVideoController();
      await audioPlayer.dispose();
      controller.dispose();
    }

    // Flat mode hides the edit button entirely, so editIndex is only
    // ever non-null in group mode — safe to route back to the editor.
    if (editIndex == null || isFlatMode || !mounted) return;
    await _openMediaInspectionEditor(groupKey: groupKey, index: editIndex);
  }
}
