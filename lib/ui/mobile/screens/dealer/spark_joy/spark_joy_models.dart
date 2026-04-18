part of 'spark_joy_create_report_screen.dart';

enum _CarPickerStep { brand, model, generation, restyling }

class _CarPickerSelection {
  const _CarPickerSelection({
    required this.brand,
    required this.model,
    required this.generation,
    required this.restyling,
    required this.frames,
    required this.photoUrl,
  });

  final String brand;
  final String model;
  final String generation;
  final String restyling;
  final String frames;
  final String photoUrl;
}

class _CarCatalogBrand {
  const _CarCatalogBrand({required this.name, required this.models});

  final String name;
  final List<_CarCatalogModel> models;
}

class _CarCatalogModel {
  const _CarCatalogModel({required this.name, required this.generations});

  final String name;
  final List<_CarCatalogGeneration> generations;
}

class _CarCatalogGeneration {
  const _CarCatalogGeneration({required this.name, required this.restylings});

  final String name;
  final List<_CarCatalogRestyling> restylings;
}

class _CarCatalogRestyling {
  const _CarCatalogRestyling({
    required this.label,
    required this.frames,
    required this.photoUrl,
  });

  final String label;
  final String frames;
  final String photoUrl;
}

class _SparkJoyVideoThumbnail extends StatefulWidget {
  const _SparkJoyVideoThumbnail({required this.uri, this.fit = BoxFit.cover});

  final Uri uri;
  final BoxFit fit;

  @override
  State<_SparkJoyVideoThumbnail> createState() =>
      _SparkJoyVideoThumbnailState();
}

class _SparkJoyVideoThumbnailState extends State<_SparkJoyVideoThumbnail> {
  VideoPlayerController? _controller;
  Future<void>? _initializeFuture;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(covariant _SparkJoyVideoThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uri != widget.uri) {
      _initialize();
    }
  }

  Future<void> _initialize() async {
    final previous = _controller;
    _controller = null;
    if (mounted) setState(() {});
    if (previous != null) {
      try {
        await previous.pause();
      } catch (_) {}
      await previous.dispose();
    }

    final controller = VideoPlayerController.networkUrl(widget.uri);
    _controller = controller;
    _initializeFuture = () async {
      await controller.initialize();
      await controller.setLooping(false);
      await controller.setVolume(0);
      await controller.seekTo(Duration.zero);
      await controller.pause();
    }();
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      unawaited(controller.pause());
      unawaited(controller.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final future = _initializeFuture;
    if (controller == null || future == null) {
      return const Center(
        child: SizedBox(
          width: SparkSize.iconSm,
          height: SparkSize.iconSm,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return FutureBuilder<void>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            !controller.value.isInitialized) {
          if (snapshot.hasError) {
            return const Icon(Icons.videocam_off_outlined, color: kGreyColor);
          }
          return const Center(
            child: SizedBox(
              width: SparkSize.iconSm,
              height: SparkSize.iconSm,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        final size = controller.value.size;
        final width = size.width <= 0 ? 16.0 : size.width;
        final height = size.height <= 0 ? 9.0 : size.height;

        return Stack(
          fit: StackFit.expand,
          children: [
            ClipRect(
              child: FittedBox(
                fit: widget.fit,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: width,
                  height: height,
                  child: VideoPlayer(controller),
                ),
              ),
            ),
            const Align(
              alignment: Alignment.center,
              child: Icon(
                Icons.play_circle_fill_rounded,
                size: SparkSize.iconXl,
                color: Color(0xD9FFFFFF),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StepConfig {
  const _StepConfig({
    required this.id,
    required this.title,
    required this.description,
  });

  final String id;
  final String title;
  final String description;
}

class _MediaGroupConfig {
  const _MediaGroupConfig({
    required this.key,
    required this.title,
    required this.description,
    required this.required,
    required this.severeIfIssue,
  });

  final String key;
  final String title;
  final String description;
  final bool required;
  final bool severeIfIssue;
}

class _MediaGroupState {
  const _MediaGroupState({
    required this.config,
    required this.hasIssue,
    required this.note,
    required this.rawUrls,
    required this.files,
    this.partInspection = const _MediaPartInspection(),
  });

  final _MediaGroupConfig config;
  final bool hasIssue;
  final String note;
  final String rawUrls;
  final List<UploadedItem> files;
  final _MediaPartInspection partInspection;

  _MediaGroupState copyWith({
    bool? hasIssue,
    String? note,
    String? rawUrls,
    List<UploadedItem>? files,
    _MediaPartInspection? partInspection,
  }) {
    return _MediaGroupState(
      config: config,
      hasIssue: hasIssue ?? this.hasIssue,
      note: note ?? this.note,
      rawUrls: rawUrls ?? this.rawUrls,
      files: files ?? this.files,
      partInspection: partInspection ?? this.partInspection,
    );
  }
}

class _MediaOption {
  const _MediaOption({required this.id, required this.label});

  final String id;
  final String label;
}

class _MediaTagOption {
  const _MediaTagOption({
    required this.label,
    required this.severity,
    this.isCustom = false,
  });

  final String label;
  final String severity;
  final bool isCustom;
}

class _MediaTagGroup {
  const _MediaTagGroup({
    required this.title,
    required this.severity,
    required this.options,
  });

  final String title;
  final String severity;
  final List<_MediaTagOption> options;
}

class _MediaPartInspection {
  const _MediaPartInspection({
    this.noDamage = false,
    this.tags = const [],
    this.note = '',
    this.elementType,
    this.audioRecordings = const [],
    this.paintFrom,
    this.paintTo,
    this.tagPhotos = const {},
    this.isDraft = true,
  });

  final bool noDamage;
  final List<String> tags;
  final String note;
  final String? elementType;
  final List<String> audioRecordings;
  final double? paintFrom;
  final double? paintTo;
  final Map<String, List<String>> tagPhotos;
  final bool isDraft;

  _MediaPartInspection copyWith({
    bool? noDamage,
    List<String>? tags,
    String? note,
    String? elementType,
    List<String>? audioRecordings,
    double? paintFrom,
    double? paintTo,
    Map<String, List<String>>? tagPhotos,
    bool? isDraft,
  }) {
    return _MediaPartInspection(
      noDamage: noDamage ?? this.noDamage,
      tags: tags ?? this.tags,
      note: note ?? this.note,
      elementType: elementType ?? this.elementType,
      audioRecordings: audioRecordings ?? this.audioRecordings,
      paintFrom: paintFrom ?? this.paintFrom,
      paintTo: paintTo ?? this.paintTo,
      tagPhotos: tagPhotos ?? this.tagPhotos,
      isDraft: isDraft ?? this.isDraft,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'noDamage': noDamage,
      'tags': tags,
      'note': note,
      'elementType': elementType,
      'audioRecordings': audioRecordings,
      'paintFrom': paintFrom,
      'paintTo': paintTo,
      'tagPhotos': tagPhotos,
      if (paintFrom != null && paintTo != null)
        'paintThickness': {'from': paintFrom, 'to': paintTo},
      'isDraft': isDraft,
    };
  }
}

class MediaInspection {
  const MediaInspection({
    this.noDamage = false,
    this.tags = const [],
    this.note = '',
    this.elementType,
    this.audioRecordings = const [],
    this.paintFrom,
    this.paintTo,
    this.isDraft = false,
  });

  final bool noDamage;
  final List<String> tags;
  final String note;
  final String? elementType;
  final List<String> audioRecordings;
  final double? paintFrom;
  final double? paintTo;
  final bool isDraft;

  MediaInspection copyWith({
    bool? noDamage,
    List<String>? tags,
    String? note,
    String? elementType,
    List<String>? audioRecordings,
    double? paintFrom,
    double? paintTo,
    bool? isDraft,
  }) {
    return MediaInspection(
      noDamage: noDamage ?? this.noDamage,
      tags: tags ?? this.tags,
      note: note ?? this.note,
      elementType: elementType ?? this.elementType,
      audioRecordings: audioRecordings ?? this.audioRecordings,
      paintFrom: paintFrom ?? this.paintFrom,
      paintTo: paintTo ?? this.paintTo,
      isDraft: isDraft ?? this.isDraft,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'noDamage': noDamage,
      'tags': tags,
      'note': note,
      'elementType': elementType,
      'audioRecordings': audioRecordings,
      'paintFrom': paintFrom,
      'paintTo': paintTo,
      if (paintFrom != null && paintTo != null)
        'paintThickness': {'from': paintFrom, 'to': paintTo},
      'isDraft': isDraft,
    };
  }
}

class UploadedItem {
  const UploadedItem({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.dataUrl,
    this.inspection = const MediaInspection(),
  });

  final String id;
  final String name;
  final String mimeType;
  final String dataUrl;
  final MediaInspection inspection;

  UploadedItem copyWith({
    String? id,
    String? name,
    String? mimeType,
    String? dataUrl,
    MediaInspection? inspection,
  }) {
    return UploadedItem(
      id: id ?? this.id,
      name: name ?? this.name,
      mimeType: mimeType ?? this.mimeType,
      dataUrl: dataUrl ?? this.dataUrl,
      inspection: inspection ?? this.inspection,
    );
  }

  bool get isImage => mimeType.startsWith('image/');
  bool get isVideo => mimeType.startsWith('video/');
  bool get isAudio => mimeType.startsWith('audio/');
}

enum BackendUploadFileStatus { pending, uploading, uploaded, failed }

class BackendUploadFileProgress {
  const BackendUploadFileProgress({
    required this.sourceKey,
    required this.fileName,
    required this.index,
    required this.total,
    this.progress = 0,
    this.status = BackendUploadFileStatus.pending,
    this.uploadedParts = 0,
    this.totalParts = 0,
    this.errorText = '',
  });

  final String sourceKey;
  final String fileName;
  final int index;
  final int total;
  final double progress;
  final BackendUploadFileStatus status;
  final int uploadedParts;
  final int totalParts;
  final String errorText;

  BackendUploadFileProgress copyWith({
    String? sourceKey,
    String? fileName,
    int? index,
    int? total,
    double? progress,
    BackendUploadFileStatus? status,
    int? uploadedParts,
    int? totalParts,
    String? errorText,
  }) {
    return BackendUploadFileProgress(
      sourceKey: sourceKey ?? this.sourceKey,
      fileName: fileName ?? this.fileName,
      index: index ?? this.index,
      total: total ?? this.total,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      uploadedParts: uploadedParts ?? this.uploadedParts,
      totalParts: totalParts ?? this.totalParts,
      errorText: errorText ?? this.errorText,
    );
  }
}

class _SummaryAttachmentStats {
  const _SummaryAttachmentStats({
    required this.total,
    required this.imageCount,
    required this.videoCount,
    required this.audioCount,
    required this.fileCount,
    required this.brokenCount,
  });

  final int total;
  final int imageCount;
  final int videoCount;
  final int audioCount;
  final int fileCount;
  final int brokenCount;
}

class _CalculatedSummary {
  const _CalculatedSummary({
    required this.score,
    required this.verdict,
    required this.verdictLabel,
    required this.sections,
    required this.checklist,
    required this.fullInspection,
  });

  final int score;
  final String verdict;
  final String verdictLabel;
  final List<Map<String, dynamic>> sections;
  final List<String> checklist;
  final bool fullInspection;
}
