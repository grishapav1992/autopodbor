part of 'spark_joy_create_report_screen.dart';

bool get _sparkJoyLiveVinCameraPreviewEnabled => false;

Uint8List _sparkCropVinGuideArea(
  _SparkJoyCreateReportScreenState state,
  Uint8List bytes,
) {
  return state._runCropVinGuideArea(bytes);
}

Future<void> _sparkOpenVinScannerSourceModal(
  _SparkJoyCreateReportScreenState state,
) {
  return state._runVinScannerSourceModal();
}

Future<void> _sparkOpenVinScannerDialog(
  _SparkJoyCreateReportScreenState state, {
  required ImageSource initialSource,
}) {
  return state._runVinScannerDialog(initialSource: initialSource);
}

extension _SparkJoyVinScannerMethods on _SparkJoyCreateReportScreenState {
  /// Opens the native iOS/Android crop UI so the user can tightly select the
  /// VIN plate area. Returns the cropped JPEG bytes, or `null` if the user
  /// cancelled. On failure falls back to [fallbackBytes] (so OCR still runs
  /// against the full uncropped photo).
  Future<Uint8List?> _cropVinWithNativeCropper({
    required String sourcePath,
    required Uint8List fallbackBytes,
    String title = 'Обрежьте VIN',
  }) async {
    try {
      final cropped = await ImageCropper().cropImage(
        sourcePath: sourcePath,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 95,
        uiSettings: [
          IOSUiSettings(
            title: title,
            aspectRatioLockEnabled: false,
            resetAspectRatioEnabled: true,
            doneButtonTitle: 'Готово',
            cancelButtonTitle: 'Отмена',
          ),
          AndroidUiSettings(
            toolbarTitle: title,
            lockAspectRatio: false,
            hideBottomControls: false,
          ),
        ],
      );
      if (cropped == null) return null;
      return await cropped.readAsBytes();
    } catch (e) {
      debugPrint('VIN cropper error: $e');
      return fallbackBytes;
    }
  }

  Uint8List _runCropVinGuideArea(Uint8List bytes) {
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return bytes;

    final oriented = img.bakeOrientation(decoded);
    final width = oriented.width;
    final height = oriented.height;
    if (width < 2 || height < 2) return bytes;

    // Mirrors live scanner guide proportions:
    // top 39%, middle 22%; left/right 7%, center 86%.
    final left = (width * 0.07).round();
    final top = (height * 0.39).round();
    final targetWidth = (width * 0.86).round();
    final targetHeight = (height * 0.22).round();

    final safeLeft = left.clamp(0, width - 1).toInt();
    final safeTop = top.clamp(0, height - 1).toInt();
    final safeWidth = math.max(1, math.min(targetWidth, width - safeLeft));
    final safeHeight = math.max(1, math.min(targetHeight, height - safeTop));

    var cropped = img.copyCrop(
      oriented,
      x: safeLeft,
      y: safeTop,
      width: safeWidth,
      height: safeHeight,
    );

    if (cropped.width < 1200) {
      final upscaleWidth = 1200;
      final upscaleHeight = math.max(
        1,
        (cropped.height * (upscaleWidth / cropped.width)).round(),
      );
      cropped = img.copyResize(
        cropped,
        width: upscaleWidth,
        height: upscaleHeight,
        interpolation: img.Interpolation.cubic,
      );
    }

    return Uint8List.fromList(img.encodeJpg(cropped, quality: 92));
  }

  Future<void> _runVinScannerSourceModal() async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: SparkSpace.xxxl,
            vertical: SparkSpace.xxl,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SparkRadius.xl),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: SparkSize.modalNarrow),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                SparkSpace.xxxl,
                SparkSpace.xxxl,
                SparkSpace.xxxl,
                SparkSpace.xl,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const MyText(
                    text: 'Сканирование VIN',
                    size: SparkTextSize.titleLg,
                    weight: FontWeight.w700,
                  ),
                  const SizedBox(height: SparkSpace.xs),
                  const MyText(
                    text: 'Выберите источник для распознавания номера',
                    size: SparkTextSize.caption,
                    color: kGreyColor,
                  ),
                  const SizedBox(height: SparkSpace.xl),
                  FilledButton.icon(
                    onPressed: () =>
                        Navigator.of(dialogContext).pop(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Открыть камеру'),
                  ),
                  const SizedBox(height: SparkSpace.md),
                  OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.of(dialogContext).pop(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Из галереи'),
                  ),
                  const SizedBox(height: SparkSpace.sm),
                  TextButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('Отмена'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (source == null || !mounted) return;
    await _openVinScannerDialog(initialSource: source);
  }

  Future<void> _runVinScannerDialog({
    required ImageSource initialSource,
  }) async {
    final picker = ImagePicker();
    final controller = TextEditingController(text: _vinController.text);

    Uint8List? previewBytes;
    Uint8List? pendingOcrBytes;
    Uint8List? pendingOcrFallbackBytes;
    var processing = false;
    String? error;
    var currentVin = _sanitizeVin(controller.text);
    cam.CameraState? liveCameraState;
    var cameraLive = false;
    var cameraError = '';
    var cameraReady = false;
    var cameraWatchdogStarted = false;
    Timer? cameraWatchdogTimer;
    var recognitionAttempted = false;
    var selectedSource = initialSource == ImageSource.gallery
        ? 'gallery'
        : 'camera';
    // Temporarily disabled through a runtime flag: using the system camera
    // (ImagePicker) gives access to iOS macro mode and auto-switching between
    // lenses, which fixes close-up focus issues on VIN plates.
    final supportsLiveCameraPreview =
        !kIsWeb && _sparkJoyLiveVinCameraPreviewEnabled;
    var dialogActive = true;
    var initialActionLaunched = false;
    var focusAdjusting = false;
    Offset? focusPoint;
    Timer? focusPointTimer;
    Timer? focusAssistPulseTimer;
    var liveCaptureInFlight = false;
    cam_pigeon.PreviewSize? lastFlutterPreviewSize;
    cam_pigeon.PreviewSize? lastPixelPreviewSize;

    void safeSetLocalState(StateSetter setLocalState, VoidCallback fn) {
      if (!mounted || !dialogActive) return;
      setLocalState(fn);
    }

    void resetCameraWatchdog() {
      cameraWatchdogTimer?.cancel();
      cameraWatchdogTimer = null;
      cameraWatchdogStarted = false;
    }

    void hideFocusPoint(StateSetter setLocalState) {
      focusPointTimer?.cancel();
      focusPointTimer = null;
      safeSetLocalState(setLocalState, () {
        focusPoint = null;
      });
    }

    void showFocusPoint(StateSetter setLocalState, Offset point) {
      focusPointTimer?.cancel();
      safeSetLocalState(setLocalState, () {
        focusPoint = point;
      });
      focusPointTimer = Timer(const Duration(milliseconds: 850), () {
        hideFocusPoint(setLocalState);
      });
    }

    void beginCameraWatchdog(StateSetter setLocalState) {
      if (!supportsLiveCameraPreview ||
          cameraWatchdogStarted ||
          previewBytes != null) {
        return;
      }
      cameraWatchdogStarted = true;
      cameraWatchdogTimer = Timer(const Duration(seconds: 8), () {
        if (!dialogActive || cameraReady) return;
        safeSetLocalState(setLocalState, () {
          cameraError =
              'Камера не ответила вовремя. Нажмите «Системная камера» или попробуйте снова.';
          cameraLive = false;
        });
      });
    }

    /// Attempts to focus on a specific [point] using known preview sizes.
    /// Falls back to generic autofocus if sizes are unknown or the call fails.
    Future<void> focusAt({
      required cam.PhotoCameraState cameraState,
      Offset? point,
    }) async {
      if (!dialogActive || !cameraLive) return;
      final flutterPreview = lastFlutterPreviewSize;
      final pixelPreview = lastPixelPreviewSize;

      // Try point-based focus only if we have valid sizes.
      if (flutterPreview != null &&
          pixelPreview != null &&
          flutterPreview.width > 10 &&
          flutterPreview.height > 10 &&
          pixelPreview.width > 10 &&
          pixelPreview.height > 10) {
        final target =
            point ??
            Offset(flutterPreview.width / 2, flutterPreview.height * 0.50);
        final safeTarget = Offset(
          target.dx.clamp(1.0, flutterPreview.width - 1),
          target.dy.clamp(1.0, flutterPreview.height - 1),
        );
        try {
          await cameraState.focusOnPoint(
            flutterPosition: safeTarget,
            pixelPreviewSize: pixelPreview,
            flutterPreviewSize: flutterPreview,
          );
          return;
        } catch (e) {
          debugPrint('VIN focusOnPoint error: $e');
        }
      }

      // Fallback: trigger generic autofocus (no coordinates needed).
      try {
        cameraState.focus();
      } catch (e) {
        debugPrint('VIN generic focus error: $e');
      }
    }

    Future<void> startFocusAssist(StateSetter setLocalState) async {
      if (!cameraLive || processing) return;
      final state = liveCameraState;
      if (state is! cam.PhotoCameraState) return;

      safeSetLocalState(setLocalState, () {
        focusAdjusting = true;
      });
      focusAssistPulseTimer?.cancel();

      // Initial focus — use generic autofocus (safe, no sizes needed).
      try {
        state.focus();
      } catch (_) {}

      // Periodic re-focus with point-based focus once sizes are known.
      focusAssistPulseTimer = Timer.periodic(
        const Duration(milliseconds: 2000),
        (_) {
          if (!dialogActive || !cameraLive || processing) return;
          final nextState = liveCameraState;
          if (nextState is! cam.PhotoCameraState) return;
          unawaited(focusAt(cameraState: nextState));
        },
      );
      if (!dialogActive) return;
      await Future<void>.delayed(const Duration(milliseconds: 600));
    }

    Future<void> stopFocusAssist(StateSetter setLocalState) async {
      focusAssistPulseTimer?.cancel();
      focusAssistPulseTimer = null;
      safeSetLocalState(setLocalState, () {
        focusAdjusting = false;
      });
    }

    Future<void> stopLiveCamera() async {
      focusAdjusting = false;
      focusAssistPulseTimer?.cancel();
      focusAssistPulseTimer = null;
      liveCameraState = null;
      cameraReady = false;
      cameraLive = false;
      resetCameraWatchdog();
    }

    Future<void> recognizeBytes({
      required Uint8List bytes,
      required StateSetter setLocalState,
      Uint8List? fallbackBytes,
      Uint8List? displayPreviewBytes,
    }) async {
      await stopLiveCamera();
      safeSetLocalState(setLocalState, () {
        recognitionAttempted = true;
        processing = true;
        previewBytes = displayPreviewBytes ?? bytes;
        error = null;
      });

      final firstResult = await scanVinFromImageBytes(bytes);
      var finalVin = _extractVinFromOcrResult(firstResult);
      var finalError = firstResult.error;

      if (finalVin.isEmpty && fallbackBytes != null) {
        final secondResult = await scanVinFromImageBytes(fallbackBytes);
        final secondVin = _extractVinFromOcrResult(secondResult);
        final secondVinValid = secondVin.isNotEmpty;

        if (secondVinValid) {
          finalVin = secondVin;
          finalError = secondResult.error;
        } else {
          finalError = secondResult.error ?? firstResult.error;
        }
      }

      safeSetLocalState(setLocalState, () {
        processing = false;
        error = finalError;
        if (_isStrictVin(finalVin)) {
          controller.text = finalVin;
          currentVin = finalVin;
        } else if (error == null || error!.trim().isEmpty) {
          error =
              'Не удалось распознать валидный VIN (17 символов). Попробуйте снять VIN ещё раз.';
        }
      });
    }

    Future<void> pickAndRecognize(
      ImageSource source,
      StateSetter setLocalState,
    ) async {
      await stopLiveCamera();
      safeSetLocalState(setLocalState, () {
        selectedSource = source == ImageSource.gallery ? 'gallery' : 'camera';
        cameraReady = false;
        cameraError = '';
      });

      Uint8List? bytes;
      if (kIsWeb) {
        bytes = await pickVinImageBytes(
          preferCamera: source == ImageSource.camera,
        );
        if (bytes == null) {
          safeSetLocalState(setLocalState, () {
            error = source == ImageSource.camera
                ? 'Не удалось открыть камеру. Проверьте разрешение камеры в браузере и попробуйте снова.'
                : 'Не удалось открыть галерею.';
          });
          return;
        }
      } else {
        XFile? file;
        try {
          file = await picker.pickImage(source: source, imageQuality: 95);
        } catch (_) {
          safeSetLocalState(setLocalState, () {
            error = source == ImageSource.camera
                ? 'Не удалось открыть системную камеру. Проверьте разрешение камеры.'
                : 'Не удалось открыть галерею.';
          });
          return;
        }
        if (file == null) {
          // User cancelled the system camera / gallery picker. If we had no
          // prior photo in this dialog, there's nothing useful to show —
          // close the whole VIN dialog so they return to the form, instead
          // of leaving them on a stale "Запуск камеры..." screen.
          if (previewBytes == null && mounted && dialogActive) {
            Navigator.of(context).pop();
          }
          return;
        }

        // Let the user crop to just the VIN strip. A tight crop around the
        // plate dramatically increases OCR recognition rate — MLKit doesn't
        // get distracted by other dashboard/engine-bay text, and the VIN
        // characters occupy a larger portion of the resized input.
        final originalBytes = await file.readAsBytes();
        final croppedBytes = await _cropVinWithNativeCropper(
          sourcePath: file.path,
          fallbackBytes: originalBytes,
        );
        if (croppedBytes == null) {
          // User cancelled cropping. Same logic as camera cancel — if we
          // have no previous photo to fall back to, close the dialog.
          if (previewBytes == null && mounted && dialogActive) {
            Navigator.of(context).pop();
          }
          return;
        }
        bytes = croppedBytes;
      }
      pendingOcrBytes = null;
      pendingOcrFallbackBytes = null;
      await recognizeBytes(
        bytes: bytes,
        setLocalState: setLocalState,
        displayPreviewBytes: bytes,
      );
    }

    String mapLiveCameraError(Object error) {
      if (error is TimeoutException) {
        return 'Камера не ответила вовремя. Нажмите «Системная камера» или попробуйте снова.';
      }
      if (error is PlatformException &&
          (error.code.contains('permission') ||
              error.code.contains('PERMISSION') ||
              error.code.contains('denied'))) {
        return 'Нет доступа к камере. Разрешите камеру в настройках устройства.';
      }
      return 'Не удалось открыть камеру. Используйте фото.';
    }

    Future<void> retryPhoto(StateSetter setLocalState) async {
      await stopLiveCamera();
      safeSetLocalState(setLocalState, () {
        previewBytes = null;
        pendingOcrBytes = null;
        pendingOcrFallbackBytes = null;
        error = null;
        processing = false;
        recognitionAttempted = false;
        cameraReady = false;
        cameraLive = false;
        cameraError = '';
        liveCameraState = null;
        resetCameraWatchdog();
      });
      hideFocusPoint(setLocalState);

      if (!supportsLiveCameraPreview) {
        await pickAndRecognize(ImageSource.camera, setLocalState);
      }
    }

    Future<void> recognizeCapturedPhoto(StateSetter setLocalState) async {
      final primary = pendingOcrBytes;
      final fallback = pendingOcrFallbackBytes;
      final display = previewBytes;
      if (primary == null || processing) return;
      await recognizeBytes(
        bytes: primary,
        setLocalState: setLocalState,
        fallbackBytes: fallback,
        displayPreviewBytes: display,
      );
    }

    Future<void> captureFromLiveCamera(
      StateSetter setLocalState, {
      bool focusBeforeShot = true,
    }) async {
      if (liveCaptureInFlight || processing) return;
      final live = liveCameraState;
      if (live is! cam.PhotoCameraState) return;
      liveCaptureInFlight = true;
      try {
        if (focusBeforeShot) {
          // Stop periodic timer, do a single focus before the shot.
          focusAssistPulseTimer?.cancel();
          focusAssistPulseTimer = null;
          safeSetLocalState(setLocalState, () {
            focusAdjusting = true;
          });
          await focusAt(cameraState: live);
          await Future<void>.delayed(const Duration(milliseconds: 500));
        }
        final shotRequest = await live.takePhoto();
        final shotPath = shotRequest.path;
        if (shotPath == null || shotPath.isEmpty) {
          throw StateError('VIN live capture returned empty image path');
        }
        final fullFrame = await XFile(shotPath).readAsBytes();
        final croppedVinArea = _cropVinGuideArea(fullFrame);
        hideFocusPoint(setLocalState);
        await stopLiveCamera();
        safeSetLocalState(setLocalState, () {
          previewBytes = fullFrame;
          pendingOcrBytes = croppedVinArea;
          pendingOcrFallbackBytes = fullFrame;
          recognitionAttempted = false;
          processing = false;
          error = null;
          cameraError = '';
        });
      } catch (e, st) {
        debugPrint('VIN live capture error: $e');
        debugPrint(st.toString());
        var openedSystemCamera = false;
        try {
          await pickAndRecognize(ImageSource.camera, setLocalState);
          openedSystemCamera = true;
        } catch (_) {}
        if (!openedSystemCamera) {
          safeSetLocalState(setLocalState, () {
            error =
                'Не удалось снять VIN через live-камеру. Попробуйте системную камеру или галерею.';
          });
        }
      } finally {
        liveCaptureInFlight = false;
        if (focusBeforeShot) {
          await stopFocusAssist(setLocalState);
        }
      }
    }

    final resultVin = await Navigator.of(context)
        .push<String>(
          MaterialPageRoute<String>(
            builder: (context) {
              return StatefulBuilder(
                builder: (context, setLocalState) {
                  final sanitized = _sanitizeVin(currentVin);
                  final valid = _isStrictVin(sanitized);
                  final isCameraMode = selectedSource == 'camera';
                  final hasPendingCapture =
                      previewBytes != null && pendingOcrBytes != null;
                  final canCapture =
                      cameraReady &&
                      liveCameraState is cam.PhotoCameraState &&
                      !processing;
                  final stageHint = processing
                      ? 'Распознаю VIN...'
                      : hasPendingCapture && !recognitionAttempted
                      ? 'Проверьте фото и нажмите «Распознать VIN»'
                      : (isCameraMode && previewBytes == null)
                      ? (cameraReady
                            ? 'Наведите камеру на VIN и сделайте фото'
                            : 'Запуск камеры...')
                      : 'Проверьте VIN перед сохранением';

                  if (!initialActionLaunched) {
                    initialActionLaunched = true;
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (!dialogActive) return;
                      if (initialSource == ImageSource.camera) {
                        if (!supportsLiveCameraPreview) {
                          unawaited(
                            pickAndRecognize(ImageSource.camera, setLocalState),
                          );
                        }
                      } else {
                        unawaited(
                          pickAndRecognize(ImageSource.gallery, setLocalState),
                        );
                      }
                    });
                  }

                  if (isCameraMode &&
                      supportsLiveCameraPreview &&
                      previewBytes == null &&
                      !processing) {
                    beginCameraWatchdog(setLocalState);
                  }

                  return Scaffold(
                    appBar: AppBar(
                      title: const Text('Сканирование VIN'),
                      leading: IconButton(
                        tooltip: 'Закрыть',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ),
                    body: SafeArea(
                      top: false,
                      left: true,
                      right: true,
                      bottom: false,
                      child: Column(
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                              keyboardDismissBehavior:
                                  ScrollViewKeyboardDismissBehavior.onDrag,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  MyText(
                                    text: stageHint,
                                    size: 11,
                                    color: processing ? kBlueColor : kGreyColor,
                                  ),
                                  const SizedBox(height: 8),
                                  if (isCameraMode &&
                                      supportsLiveCameraPreview &&
                                      previewBytes == null &&
                                      !processing) ...[
                                    Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black,
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      clipBehavior: Clip.antiAlias,
                                      child: AspectRatio(
                                        aspectRatio: 3 / 4,
                                        child: Stack(
                                          fit: StackFit.expand,
                                          children: [
                                            cam.CameraAwesomeBuilder.custom(
                                              saveConfig:
                                                  cam.SaveConfig.photo(),
                                              sensorConfig:
                                                  cam.SensorConfig.single(
                                                    sensor: cam.Sensor.position(
                                                      cam.SensorPosition.back,
                                                    ),
                                                    flashMode:
                                                        cam.FlashMode.none,
                                                    aspectRatio: cam
                                                        .CameraAspectRatios
                                                        .ratio_4_3,
                                                    zoom: 0.0,
                                                  ),
                                              previewFit:
                                                  cam.CameraPreviewFit.cover,
                                              progressIndicator: const Center(
                                                child:
                                                    CircularProgressIndicator(),
                                              ),
                                              onPreviewTapBuilder: (state) => cam.OnPreviewTap(
                                                onTap:
                                                    (
                                                      position,
                                                      flutterPreviewSize,
                                                      pixelPreviewSize,
                                                    ) {
                                                      if (state
                                                          is! cam.PhotoCameraState) {
                                                        return;
                                                      }
                                                      // Stop continuous
                                                      // autofocus — user took
                                                      // manual control.
                                                      focusAssistPulseTimer
                                                          ?.cancel();
                                                      focusAssistPulseTimer =
                                                          null;
                                                      showFocusPoint(
                                                        setLocalState,
                                                        position,
                                                      );
                                                      lastFlutterPreviewSize =
                                                          flutterPreviewSize;
                                                      lastPixelPreviewSize =
                                                          pixelPreviewSize;
                                                      safeSetLocalState(
                                                        setLocalState,
                                                        () {
                                                          focusAdjusting = true;
                                                        },
                                                      );
                                                      unawaited(() async {
                                                        try {
                                                          await state.focusOnPoint(
                                                            flutterPosition:
                                                                position,
                                                            pixelPreviewSize:
                                                                pixelPreviewSize,
                                                            flutterPreviewSize:
                                                                flutterPreviewSize,
                                                          );
                                                        } catch (_) {
                                                        } finally {
                                                          safeSetLocalState(
                                                            setLocalState,
                                                            () {
                                                              focusAdjusting =
                                                                  false;
                                                            },
                                                          );
                                                        }
                                                      }());
                                                    },
                                              ),
                                              onMediaCaptureEvent: (event) {
                                                if (event.status ==
                                                    cam
                                                        .MediaCaptureStatus
                                                        .failure) {
                                                  safeSetLocalState(
                                                    setLocalState,
                                                    () {
                                                      cameraError =
                                                          mapLiveCameraError(
                                                            event.exception ??
                                                                Exception(
                                                                  'VIN live camera failed',
                                                                ),
                                                          );
                                                    },
                                                  );
                                                }
                                              },
                                              builder: (state, preview) {
                                                liveCameraState = state;
                                                // Capture preview sizes for
                                                // focus on every build — the
                                                // preview may resize.
                                                if (preview.previewSize !=
                                                        Size.zero &&
                                                    preview.nativePreviewSize !=
                                                        Size.zero) {
                                                  lastFlutterPreviewSize =
                                                      cam_pigeon.PreviewSize(
                                                        width: preview
                                                            .previewSize
                                                            .width,
                                                        height: preview
                                                            .previewSize
                                                            .height,
                                                      );
                                                  lastPixelPreviewSize =
                                                      cam_pigeon.PreviewSize(
                                                        width: preview
                                                            .nativePreviewSize
                                                            .width,
                                                        height: preview
                                                            .nativePreviewSize
                                                            .height,
                                                      );
                                                }
                                                if (!cameraReady) {
                                                  WidgetsBinding.instance
                                                      .addPostFrameCallback((
                                                        _,
                                                      ) {
                                                        safeSetLocalState(
                                                          setLocalState,
                                                          () {
                                                            cameraReady = true;
                                                            cameraLive = true;
                                                            cameraError = '';
                                                            resetCameraWatchdog();
                                                          },
                                                        );
                                                        // Start continuous
                                                        // autofocus after a
                                                        // short delay to let
                                                        // the camera stabilize.
                                                        if (state
                                                            is cam.PhotoCameraState) {
                                                          unawaited(() async {
                                                            try {
                                                              await Future<
                                                                void
                                                              >.delayed(
                                                                const Duration(
                                                                  milliseconds:
                                                                      800,
                                                                ),
                                                              );
                                                              if (!dialogActive ||
                                                                  !cameraLive) {
                                                                return;
                                                              }
                                                              await startFocusAssist(
                                                                setLocalState,
                                                              );
                                                            } catch (_) {}
                                                          }());
                                                        }
                                                      });
                                                }
                                                return const SizedBox.expand();
                                              },
                                            ),
                                            IgnorePointer(
                                              child: Column(
                                                children: [
                                                  Expanded(
                                                    flex: 39,
                                                    child: Container(
                                                      color: Colors.black54,
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 22,
                                                    child: Row(
                                                      children: [
                                                        Expanded(
                                                          flex: 7,
                                                          child: Container(
                                                            color:
                                                                Colors.black54,
                                                          ),
                                                        ),
                                                        Expanded(
                                                          flex: 86,
                                                          child: _VinGuideFrame(
                                                            animate:
                                                                cameraLive &&
                                                                cameraError
                                                                    .isEmpty,
                                                          ),
                                                        ),
                                                        Expanded(
                                                          flex: 7,
                                                          child: Container(
                                                            color:
                                                                Colors.black54,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Expanded(
                                                    flex: 39,
                                                    child: Container(
                                                      color: Colors.black54,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            if (focusPoint != null)
                                              Positioned(
                                                left: focusPoint!.dx - 22,
                                                top: focusPoint!.dy - 22,
                                                child: IgnorePointer(
                                                  child: _VinFocusIndicator(
                                                    active: focusAdjusting,
                                                  ),
                                                ),
                                              ),
                                            if (cameraError.isNotEmpty)
                                              Center(
                                                child: Padding(
                                                  padding: const EdgeInsets.all(
                                                    24,
                                                  ),
                                                  child: MyText(
                                                    text: cameraError,
                                                    size: 12,
                                                    color: kWhiteColor,
                                                    textAlign: TextAlign.center,
                                                  ),
                                                ),
                                              ),
                                            if (cameraLive &&
                                                cameraError.isEmpty)
                                              const Align(
                                                alignment: Alignment(0, -0.34),
                                                child: _VinGuideBadge(),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    GestureDetector(
                                      onTap: canCapture
                                          ? () => captureFromLiveCamera(
                                              setLocalState,
                                            )
                                          : null,
                                      onLongPressStart: canCapture
                                          ? (_) {
                                              unawaited(
                                                startFocusAssist(setLocalState),
                                              );
                                            }
                                          : null,
                                      onLongPressEnd: canCapture
                                          ? (_) {
                                              unawaited(() async {
                                                await stopFocusAssist(
                                                  setLocalState,
                                                );
                                                await captureFromLiveCamera(
                                                  setLocalState,
                                                  focusBeforeShot: true,
                                                );
                                              }());
                                            }
                                          : null,
                                      onLongPressCancel: canCapture
                                          ? () {
                                              unawaited(
                                                stopFocusAssist(setLocalState),
                                              );
                                            }
                                          : null,
                                      child: AbsorbPointer(
                                        child: FilledButton.icon(
                                          onPressed: canCapture ? () {} : null,
                                          icon: Icon(
                                            focusAdjusting
                                                ? Icons
                                                      .center_focus_strong_rounded
                                                : Icons.camera_alt_outlined,
                                          ),
                                          label: Text(
                                            focusAdjusting
                                                ? 'Фокусировка... отпустите'
                                                : 'Сделать фото',
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                  if (previewBytes != null) ...[
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      // Preserve the VIN crop's native aspect
                                      // ratio so the user can visually compare
                                      // the characters on the photo with the
                                      // recognized VIN text below.
                                      // BoxFit.contain + no fixed height lets
                                      // wide/short crops render as a natural
                                      // horizontal strip without distortion or
                                      // center-cropping.
                                      child: Container(
                                        color: kLightGreyColor,
                                        constraints: const BoxConstraints(
                                          minHeight: 80,
                                          maxHeight: 320,
                                        ),
                                        width: double.infinity,
                                        alignment: Alignment.center,
                                        child: Image.memory(
                                          previewBytes!,
                                          fit: BoxFit.contain,
                                          width: double.infinity,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    if (!processing) ...[
                                      if (hasPendingCapture) ...[
                                        FilledButton.icon(
                                          onPressed: () =>
                                              recognizeCapturedPhoto(
                                                setLocalState,
                                              ),
                                          icon: const Icon(
                                            Icons.document_scanner_outlined,
                                          ),
                                          label: const Text('Распознать VIN'),
                                        ),
                                        const SizedBox(height: 8),
                                        OutlinedButton(
                                          onPressed: () {
                                            safeSetLocalState(
                                              setLocalState,
                                              () {
                                                recognitionAttempted = true;
                                                error = null;
                                              },
                                            );
                                          },
                                          child: const Text('Ввести вручную'),
                                        ),
                                        const SizedBox(height: 8),
                                      ],
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          if (isCameraMode) {
                                            retryPhoto(setLocalState);
                                          } else {
                                            pickAndRecognize(
                                              ImageSource.gallery,
                                              setLocalState,
                                            );
                                          }
                                        },
                                        icon: const Icon(Icons.replay_rounded),
                                        label: Text(
                                          isCameraMode
                                              ? 'Сфотографировать заново'
                                              : 'Выбрать другое фото',
                                        ),
                                      ),
                                      const SizedBox(height: 10),
                                    ],
                                  ],
                                  if (!isCameraMode &&
                                      previewBytes == null &&
                                      !processing) ...[
                                    OutlinedButton.icon(
                                      onPressed: () => pickAndRecognize(
                                        ImageSource.gallery,
                                        setLocalState,
                                      ),
                                      icon: const Icon(
                                        Icons.photo_library_outlined,
                                      ),
                                      label: const Text(
                                        'Выбрать фото из галереи',
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                  if (isCameraMode &&
                                      supportsLiveCameraPreview &&
                                      cameraError.isNotEmpty &&
                                      !processing) ...[
                                    MyText(
                                      text: cameraError,
                                      size: 11,
                                      color: kRedColor,
                                    ),
                                    const SizedBox(height: 8),
                                    OutlinedButton.icon(
                                      onPressed: () => pickAndRecognize(
                                        ImageSource.camera,
                                        setLocalState,
                                      ),
                                      icon: const Icon(
                                        Icons.photo_camera_outlined,
                                      ),
                                      label: const Text('Системная камера'),
                                    ),
                                    const SizedBox(height: 8),
                                    OutlinedButton.icon(
                                      onPressed: () =>
                                          retryPhoto(setLocalState),
                                      icon: const Icon(Icons.replay),
                                      label: const Text(
                                        'Повторить запуск камеры',
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                  if (processing) ...[
                                    const Row(
                                      children: [
                                        SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: MyText(
                                            text: 'Распознаю VIN...',
                                            size: 11,
                                            color: kGreyColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                  if (!vinOcrSupported) ...[
                                    const MyText(
                                      text:
                                          'OCR недоступен. Можно вставить VIN вручную.',
                                      size: 11,
                                      color: kGreyColor,
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  if (recognitionAttempted) ...[
                                    TextField(
                                      controller: controller,
                                      maxLength: 17,
                                      onTapOutside: (_) => _dismissKeyboard(),
                                      onChanged: (value) {
                                        final sanitizedValue = _sanitizeVin(
                                          value,
                                        );
                                        if (sanitizedValue != value) {
                                          controller.value = TextEditingValue(
                                            text: sanitizedValue,
                                            selection: TextSelection.collapsed(
                                              offset: sanitizedValue.length,
                                            ),
                                          );
                                        }
                                        setLocalState(() {
                                          currentVin = sanitizedValue;
                                        });
                                      },
                                      decoration: _fieldDecoration(
                                        'Распознанный VIN (можно исправить)',
                                      ).copyWith(counterText: ''),
                                    ),
                                    if (sanitized.isNotEmpty && !valid)
                                      MyText(
                                        text:
                                            '${sanitized.length} из 17 символов',
                                        size: 11,
                                        color: kYellowColor,
                                      ),
                                  ],
                                  if (error != null &&
                                      error!.trim().isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    MyText(
                                      text: error!,
                                      size: 11,
                                      color: kRedColor,
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                ],
                              ),
                            ),
                          ),
                          SafeArea(
                            top: false,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      child: const Text('Отмена'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: !valid
                                          ? null
                                          : () => Navigator.of(
                                              context,
                                            ).pop(sanitized),
                                      child: const Text('Применить'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        )
        .whenComplete(() {
          dialogActive = false;
          focusPointTimer?.cancel();
          focusAssistPulseTimer?.cancel();
          cameraWatchdogTimer?.cancel();
        });

    await stopLiveCamera();
    controller.dispose();

    if (resultVin == null || resultVin.isEmpty || !mounted) return;
    _applyVinScannerResult(resultVin);
  }
}

class _VinGuideFrame extends StatelessWidget {
  const _VinGuideFrame({required this.animate});

  final bool animate;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: kWhiteColor, width: 2),
            borderRadius: BorderRadius.circular(SparkRadius.lg),
          ),
        ),
        if (animate) const _VinGuideScanLine(),
        const _VinGuideCorners(),
      ],
    );
  }
}

class _VinGuideCorners extends StatelessWidget {
  const _VinGuideCorners();

  @override
  Widget build(BuildContext context) {
    return const IgnorePointer(
      child: Stack(
        children: [
          _VinGuideCorner(top: true, left: true),
          _VinGuideCorner(top: true, left: false),
          _VinGuideCorner(top: false, left: true),
          _VinGuideCorner(top: false, left: false),
        ],
      ),
    );
  }
}

class _VinGuideCorner extends StatelessWidget {
  const _VinGuideCorner({required this.top, required this.left});

  final bool top;
  final bool left;

  @override
  Widget build(BuildContext context) {
    const size = 18.0;
    const stroke = 3.0;
    final alignment = Alignment(left ? -1 : 1, top ? -1 : 1);

    return Align(
      alignment: alignment,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          border: Border(
            top: top
                ? const BorderSide(color: kWhiteColor, width: stroke)
                : BorderSide.none,
            bottom: top
                ? BorderSide.none
                : const BorderSide(color: kWhiteColor, width: stroke),
            left: left
                ? const BorderSide(color: kWhiteColor, width: stroke)
                : BorderSide.none,
            right: left
                ? BorderSide.none
                : const BorderSide(color: kWhiteColor, width: stroke),
          ),
          borderRadius: BorderRadius.only(
            topLeft: top && left ? const Radius.circular(6) : Radius.zero,
            topRight: top && !left ? const Radius.circular(6) : Radius.zero,
            bottomLeft: !top && left ? const Radius.circular(6) : Radius.zero,
            bottomRight: !top && !left ? const Radius.circular(6) : Radius.zero,
          ),
        ),
      ),
    );
  }
}

class _VinGuideScanLine extends StatefulWidget {
  const _VinGuideScanLine();

  @override
  State<_VinGuideScanLine> createState() => _VinGuideScanLineState();
}

class _VinGuideScanLineState extends State<_VinGuideScanLine>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2100),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final start = -width * 0.35;
              final end = width * 1.25;
              final left = start + (end - start) * _controller.value;

              return Stack(
                children: [
                  Positioned(
                    left: left,
                    top: 8,
                    bottom: 8,
                    child: Container(
                      width: 64,
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            Color(0xCC6EE7B7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _VinFocusIndicator extends StatelessWidget {
  const _VinFocusIndicator({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: active ? 44 : 40,
      height: active ? 44 : 40,
      decoration: BoxDecoration(
        border: Border.all(
          color: active ? const Color(0xFF6EE7B7) : kWhiteColor,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(SparkRadius.md),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: active ? const Color(0xFF6EE7B7) : kWhiteColor,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _VinGuideBadge extends StatelessWidget {
  const _VinGuideBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SparkSpace.xl,
        vertical: SparkSpace.xs,
      ),
      decoration: BoxDecoration(
        color: kWhiteColor.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(SparkRadius.pill),
      ),
      child: const MyText(
        text: 'VIN',
        size: SparkTextSize.caption,
        color: kSecondaryColor,
        weight: FontWeight.w700,
      ),
    );
  }
}
