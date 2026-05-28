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
    this.frameId,
  });

  final String brand;
  final String model;
  final String generation;
  final String restyling;
  final String frames;
  final String photoUrl;
  /// Server id of the first `RestylingItem.frames[].id` entry (or null
  /// when the catalog didn't carry one, e.g. local fallback data).
  /// Used by the completed-report hydrator to restore brand/model/photo
  /// from `Storage.ViewSpecialistReport` responses that only echo
  /// `characteristicsStep.modelGenerationRestylingFrameId`.
  final int? frameId;
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
    this.frameIds = const <int>[],
  });

  final String label;
  final String frames;
  final String photoUrl;
  /// Server ids for every frame under this restyling (at least one when
  /// sourced from `Storage.GetModelGeneration`). The first id is what
  /// we use for persistence keyed on `modelGenerationRestylingFrameId`.
  final List<int> frameIds;
}

// Per-process cache of resolved video thumbnails: video file path → on-disk
// JPEG path. Lets repeated rebuilds (re-layout, scroll, navigation back to
// «Итог») hit a Map lookup instead of re-running native extraction.
final Map<String, String> _sparkJoyVideoThumbDiskCache = <String, String>{};

// Serializes concurrent thumbnail extractions so we never spin up more than
// a couple of AVAssetImageGenerator / MediaMetadataRetriever instances at
// once. Without this, mounting a «Итог» with 10 video tiles would fire 10
// parallel native decoders — exactly the memory pressure we're killing.
final List<Future<void>> _sparkJoyVideoThumbQueue = <Future<void>>[];
const int _sparkJoyVideoThumbMaxConcurrent = 2;

Future<String?> _resolveSparkJoyVideoThumb(String videoPath) async {
  if (videoPath.isEmpty) return null;
  final cached = _sparkJoyVideoThumbDiskCache[videoPath];
  if (cached != null && await File(cached).exists()) {
    return cached;
  }

  // Cheap counting semaphore — we just wait for an in-flight slot to
  // drain before kicking off our own native call.
  while (_sparkJoyVideoThumbQueue.length >= _sparkJoyVideoThumbMaxConcurrent) {
    await _sparkJoyVideoThumbQueue.first;
  }
  final slot = Completer<void>();
  _sparkJoyVideoThumbQueue.add(slot.future);
  try {
    final videoFile = File(videoPath);
    if (!await videoFile.exists()) return null;
    final stat = await videoFile.stat();
    final cacheRoot = await getTemporaryDirectory();
    final cacheDir = Directory('${cacheRoot.path}/spark_joy_thumbs');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    final key =
        '${videoPath.hashCode.toUnsigned(32).toRadixString(16)}_'
        '${stat.size}_${stat.modified.millisecondsSinceEpoch}.jpg';
    final outPath = '${cacheDir.path}/$key';
    final outFile = File(outPath);
    if (await outFile.exists()) {
      _sparkJoyVideoThumbDiskCache[videoPath] = outPath;
      return outPath;
    }
    final Uint8List? bytes = await VideoThumbnail.thumbnailData(
      video: videoPath,
      imageFormat: ImageFormat.JPEG,
      maxWidth: 240,
      quality: 60,
    );
    if (bytes == null || bytes.isEmpty) return null;
    await outFile.writeAsBytes(bytes, flush: false);
    _sparkJoyVideoThumbDiskCache[videoPath] = outPath;
    return outPath;
  } catch (_) {
    return null;
  } finally {
    _sparkJoyVideoThumbQueue.remove(slot.future);
    slot.complete();
  }
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
  // Resolved on-disk JPEG path. null + !_loading + !_failed → network URI
  // case where we deliberately don't pre-fetch and just show the play
  // badge over a neutral background.
  String? _thumbPath;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant _SparkJoyVideoThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.uri != widget.uri) {
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final uri = widget.uri;
    if (mounted) {
      setState(() {
        _thumbPath = null;
        _failed = false;
        _loading = uri.scheme == 'file';
      });
    }
    // For non-file (http/https) URIs we deliberately do NOT trigger a
    // download or VideoPlayerController init from the thumbnail. Full
    // playback lives in the lightbox which mounts at most one decoder
    // on user tap.
    if (uri.scheme != 'file') return;

    String? path;
    try {
      path = await _resolveSparkJoyVideoThumb(uri.toFilePath());
    } catch (_) {
      path = null;
    }
    if (!mounted) return;
    setState(() {
      _thumbPath = path;
      _loading = false;
      _failed = path == null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Container(
        color: kLightGreyColor,
        alignment: Alignment.center,
        child: const SizedBox(
          width: SparkSize.iconSm,
          height: SparkSize.iconSm,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    final path = _thumbPath;
    if (path != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          Image.file(
            File(path),
            fit: widget.fit,
            errorBuilder: (_, _, _) =>
                const _SparkJoyVideoPlaceholder(failed: true),
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
    }
    return _SparkJoyVideoPlaceholder(failed: _failed);
  }
}

class _SparkJoyVideoPlaceholder extends StatelessWidget {
  const _SparkJoyVideoPlaceholder({this.failed = false});

  final bool failed;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kLightGreyColor,
      alignment: Alignment.center,
      child: Icon(
        failed ? Icons.videocam_off_outlined : Icons.play_circle_fill_rounded,
        size: failed ? SparkSize.iconSm : SparkSize.iconXl,
        color: failed ? kGreyColor : const Color(0xD9000000),
      ),
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

class MediaGroupConfig {
  const MediaGroupConfig({
    required this.key,
    required this.title,
    required this.description,
    required this.required,
    required this.severeIfIssue,
    String? shortLabel,
  }) : shortLabel = shortLabel ?? title;

  final String key;
  final String title;
  final String description;
  final bool required;
  final bool severeIfIssue;

  /// Короткое название для компактных UI — stepper, breadcrumbs.
  /// Если не задано в registry — fallback на полный [title].
  final String shortLabel;
}

class MediaGroupState {
  const MediaGroupState({
    required this.config,
    required this.hasIssue,
    required this.note,
    required this.rawUrls,
    required this.files,
    this.partInspection = const MediaPartInspection(),
  });

  final MediaGroupConfig config;
  final bool hasIssue;
  final String note;
  final String rawUrls;
  final List<UploadedItem> files;
  final MediaPartInspection partInspection;

  MediaGroupState copyWith({
    bool? hasIssue,
    String? note,
    String? rawUrls,
    List<UploadedItem>? files,
    MediaPartInspection? partInspection,
  }) {
    return MediaGroupState(
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

class MediaPartInspection {
  const MediaPartInspection({
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

  MediaPartInspection copyWith({
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
    return MediaPartInspection(
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
