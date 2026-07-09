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
    this.brandId,
    this.modelCarId,
    this.generationNumber,
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

  /// Catalog brand id (`Storage.GetBrand`) when picked from the remote
  /// catalog — null for local-fallback data. Feeds `_selectedBrandId` so the
  /// brand/model autocomplete stays consistent after a catalog pick.
  final int? brandId;

  /// Catalog model id (`Storage.GetModelCar`) when picked remotely — null for
  /// local fallback. Feeds `_selectedModelCarId`.
  final int? modelCarId;

  /// Порядковый номер поколения (`GenerationItem.generation`) — стабильный
  /// ключ пере-выбора черновика. Поле «Поколение» показывает диапазон годов,
  /// который выводится из мутабельных годов рестайлингов и может «съехать»
  /// при обновлении каталога; номер же не меняется. Feeds
  /// `_selectedGenerationNumber`. null — если поколение не выбрано.
  final int? generationNumber;
}

// _CarCatalogBrand/_CarCatalogModel удалены вместе с хардкодным
// 6-брендовым фолбэком: марки/модели теперь только из CarCatalogRepository
// (BrandItem/ModelItem). _CarCatalogGeneration/_CarCatalogRestyling остаются
// view-моделями каталог-визарда (маппинг из GenerationItem).
class _CarCatalogGeneration {
  const _CarCatalogGeneration({
    required this.name,
    required this.number,
    required this.restylings,
  });

  /// Подпись для UI: диапазон годов («2016–2020» / «с 2016»), если он известен,
  /// иначе — номер поколения. Именно это значение пишется в поле «Поколение».
  final String name;

  /// Порядковый номер поколения (`GenerationItem.generation`) — стабильный
  /// ключ пере-выбора черновика и совместимость со старыми черновиками, где
  /// сохранялся именно номер, а не диапазон годов.
  final int number;
  final List<_CarCatalogRestyling> restylings;
}

class _CarCatalogRestyling {
  const _CarCatalogRestyling({
    required this.label,
    required this.frames,
    required this.photoUrl,
    this.years = '',
    this.frameIds = const <int>[],
  });

  final String label;

  /// Чистый годовой диапазон выбранного рестайлинга («2020–2022» / «с 2020»),
  /// пустая строка — если годов нет. После выбора рестайлинга это значение
  /// уходит в поле «Поколение», чтобы там был тот же период, что выбрал юзер.
  final String years;
  final String frames;
  final String photoUrl;
  /// Server ids for every frame under this restyling (at least one when
  /// sourced from `Storage.GetModelGeneration`). The first id is what
  /// we use for persistence keyed on `modelGenerationRestylingFrameId`.
  final List<int> frameIds;
}

// Per-process cache of resolved video thumbnails: local video path → on-disk
// JPEG path. Lets the editor↔«Итог» transition and any rebuild reuse a Map
// lookup instead of re-running native extraction — a given video is decoded
// once per session total.
final Map<String, String> _sparkJoyVideoThumbDiskCache = <String, String>{};

// Strictly ONE native AVAssetImageGenerator / MediaMetadataRetriever alive at
// a time. On iOS 26 the decoder buffer (~600 MB per HEVC frame) lingers after
// the call returns; running several at once piled up GBs and OOM-killed the
// app at the 3.3 GB high-watermark before the user even reached «Выгрузить».
// The gate + the post-call delay below cap peak native memory at a single
// decoder's worth.
final _UploadConcurrencyGate _sparkJoyVideoThumbGate = _UploadConcurrencyGate(
  1,
);

// Breathing room after each extraction so iOS can drain the decoder /
// autorelease pool before the next slot starts. Cheap insurance against the
// lingering-buffer behaviour; bump it (600–1000 ms) if profiling shows memory
// climbing instead of sawtoothing.
const Duration _sparkJoyVideoThumbInterDelay = Duration(milliseconds: 350);

/// Resolves (and disk-caches) a downscaled JPEG preview for a local video
/// file. Returns the on-disk JPEG path, or null on any failure (caller falls
/// back to the static placeholder).
///
/// NEVER call this from widget `build`/`initState`. Generation is driven once,
/// off the render path, by [_generateVideoThumbsForGroup] after media is picked
/// or a draft is restored — that decoupling is the actual OOM fix, since the
/// eager media grids mount every tile at once.
Future<String?> _resolveSparkJoyVideoThumb(String videoPath) async {
  if (videoPath.isEmpty) return null;
  final cached = _sparkJoyVideoThumbDiskCache[videoPath];
  if (cached != null && await File(cached).exists()) {
    return cached;
  }
  return _sparkJoyVideoThumbGate.withSlot<String?>(() async {
    var didDecode = false;
    try {
      final videoFile = File(videoPath);
      if (!await videoFile.exists()) return null;
      final stat = await videoFile.stat();
      // Regenerable cache → Caches dir (NSCachesDirectory on iOS), NOT
      // Documents: it isn't iCloud-backed, doesn't count as user "Documents &
      // Data", and the OS may purge it under pressure. A purged thumb is cheap
      // to rebuild — the post-pick / post-restore pass regenerates it from the
      // original video (which does live in Documents) on the next miss.
      final cacheRoot = await getApplicationCacheDirectory();
      final cacheDir = Directory(
        '${cacheRoot.path}/${SparkJoyStorage.thumbsSubdirName}',
      );
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      // Deterministic key (path + size + mtime). A ".jpg" full path is honored
      // verbatim by the plugin's iOS/Android side, so re-encounters of the
      // same file short-circuit on the file-exists check below.
      final key =
          '${videoPath.hashCode.toUnsigned(32).toRadixString(16)}_'
          '${stat.size}_${stat.modified.millisecondsSinceEpoch}.jpg';
      final outPath = '${cacheDir.path}/$key';
      if (await File(outPath).exists()) {
        _sparkJoyVideoThumbDiskCache[videoPath] = outPath;
        return outPath;
      }
      // thumbnailFile writes the JPEG straight to disk (unlike thumbnailData it
      // never materialises bytes on the Dart heap). The danger was always the
      // native decoder, which the gate + the post-decode delay bound.
      didDecode = true;
      final generated = await VideoThumbnail.thumbnailFile(
        video: videoPath,
        thumbnailPath: outPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 300,
        maxHeight: 300,
        timeMs: 0,
        quality: 70,
      );
      if (generated == null || generated.isEmpty) return null;
      if (!await File(generated).exists()) return null;
      _sparkJoyVideoThumbDiskCache[videoPath] = generated;
      return generated;
    } catch (_) {
      return null;
    } finally {
      // Only after an actual native decode (success OR failure — a failed
      // decode may still have allocated the buffer): hold the slot a beat so
      // iOS can drain the decoder/autorelease pool before the next slot.
      // Cache hits and early bails allocate no decoder, so they skip the wait.
      if (didDecode) {
        await Future<void>.delayed(_sparkJoyVideoThumbInterDelay);
      }
    }
  });
}

/// Same serialized/disk-cached thumbnail path as [_resolveSparkJoyVideoThumb],
/// but for a REMOTE video (a presigned S3 URL from a completed report) — the
/// local-file variant bails because there's no file on disk, so completed
/// reports showed videos without previews. iOS' AVAssetImageGenerator streams
/// only the first frame from the URL (it doesn't download the whole file).
///
/// [cacheKey] must be STABLE per video (the filename) — the presigned URL's
/// signature changes every session, so keying by the URL would re-decode every
/// time. Goes through the same single-decoder gate + post-decode delay, so the
/// OOM guarantees of the OOM campaign still hold.
Future<String?> _resolveSparkJoyVideoThumbRemote(
  String url,
  String cacheKey,
) async {
  if (url.isEmpty || cacheKey.isEmpty) return null;
  final memo = _sparkJoyVideoThumbDiskCache[cacheKey];
  if (memo != null && await File(memo).exists()) return memo;
  return _sparkJoyVideoThumbGate.withSlot<String?>(() async {
    var didDecode = false;
    try {
      final cacheRoot = await getApplicationCacheDirectory();
      final cacheDir = Directory(
        '${cacheRoot.path}/${SparkJoyStorage.thumbsSubdirName}',
      );
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      final key =
          'remote_${cacheKey.hashCode.toUnsigned(32).toRadixString(16)}.jpg';
      final outPath = '${cacheDir.path}/$key';
      if (await File(outPath).exists()) {
        _sparkJoyVideoThumbDiskCache[cacheKey] = outPath;
        return outPath;
      }
      didDecode = true;
      // Hard timeout: this is network I/O (AVURLAsset streams the first frame).
      // Without it an expired/unreachable presigned URL would hold the single
      // shared decoder gate forever, freezing EVERY video thumbnail — local and
      // remote — for the rest of the session. On timeout the catch below
      // returns null (placeholder) and frees the slot.
      final generated = await VideoThumbnail.thumbnailFile(
        video: url,
        thumbnailPath: outPath,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 300,
        maxHeight: 300,
        timeMs: 0,
        quality: 70,
      ).timeout(const Duration(seconds: 15));
      if (generated == null || generated.isEmpty) return null;
      if (!await File(generated).exists()) return null;
      _sparkJoyVideoThumbDiskCache[cacheKey] = generated;
      return generated;
    } catch (_) {
      return null;
    } finally {
      if (didDecode) {
        await Future<void>.delayed(_sparkJoyVideoThumbInterDelay);
      }
    }
  });
}

class _SparkJoyVideoThumbnail extends StatelessWidget {
  const _SparkJoyVideoThumbnail({
    this.thumbPath,
    this.thumbUrl,
    this.loading = false,
    this.fit = BoxFit.cover,
    this.onThumbUrlError,
  });

  /// Pre-resolved on-disk JPEG path (local videos). Null → fall back to
  /// [thumbUrl], then the static play badge. This widget is deliberately dumb:
  /// it never triggers native extraction, so the eager grids can mount any
  /// number of tiles without spinning up decoders.
  final String? thumbPath;

  /// Presigned poster URL (completed-report remote videos). Used only when
  /// [thumbPath] is absent: the poster was uploaded alongside the video, so the
  /// tile loads a small network image instead of decoding the remote video —
  /// which iOS can't do from a presigned URL anyway.
  final String? thumbUrl;

  /// True while a preview for this video could still appear (its thumbnail is
  /// queued / being generated). When there's no [thumbPath] or [thumbUrl] yet,
  /// this picks the spinner over the grey "missing" placeholder — so a video
  /// that's still loading never reads as absent.
  final bool loading;
  final BoxFit fit;

  /// Notified (once per failure, post-frame) when [thumbUrl] fails to load —
  /// presigned poster URLs are signed without checking the key exists, so a
  /// 404 means "no poster was ever uploaded", not a transient glitch. The
  /// owner reacts by falling back to frame extraction; while it hasn't
  /// rebuilt yet the error branch renders the loading spinner, not the
  /// placeholder. Null → the old behavior (straight to placeholder).
  final VoidCallback? onThumbUrlError;

  @override
  Widget build(BuildContext context) {
    final path = thumbPath;
    final url = thumbUrl;
    final Widget image;
    if (path != null) {
      image = Image.file(
        File(path),
        fit: fit,
        cacheWidth: 300,
        cacheHeight: 300,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => const _SparkJoyVideoPlaceholder(),
      );
    } else if (url != null && url.isNotEmpty) {
      image = Image.network(
        url,
        fit: fit,
        cacheWidth: 300,
        cacheHeight: 300,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) {
          final onError = onThumbUrlError;
          if (onError == null) return const _SparkJoyVideoPlaceholder();
          // errorBuilder runs during build — defer the callback a frame. It
          // re-fires on every rebuild while the image stays errored; the owner
          // guards against duplicates.
          WidgetsBinding.instance.addPostFrameCallback((_) => onError());
          return const _SparkJoyVideoThumbLoading();
        },
        // While the poster streams in, show a spinner (not the grey play-badge
        // placeholder) so "loading" reads differently from "missing/empty" —
        // the placeholder is reserved for the error branch above.
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : const _SparkJoyVideoThumbLoading(),
      );
    } else {
      // No preview yet: spinner while it could still resolve (queued / being
      // generated), grey placeholder only once generation has given up.
      return loading
          ? const _SparkJoyVideoThumbLoading()
          : const _SparkJoyVideoPlaceholder();
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        image,
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
}

class _SparkJoyVideoPlaceholder extends StatelessWidget {
  const _SparkJoyVideoPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kLightGreyColor,
      alignment: Alignment.center,
      child: const Icon(
        Icons.play_circle_fill_rounded,
        size: SparkSize.iconXl,
        color: Color(0xD9000000),
      ),
    );
  }
}

/// Shown while a remote poster is still streaming in — distinct from the
/// play-badge placeholder so a loading tile never looks like a missing one.
class _SparkJoyVideoThumbLoading extends StatelessWidget {
  const _SparkJoyVideoThumbLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kLightGreyColor,
      alignment: Alignment.center,
      child: const SizedBox(
        width: SparkSize.spinner,
        height: SparkSize.spinner,
        child: CircularProgressIndicator(strokeWidth: 2),
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
    this.videoThumbPath,
    this.videoThumbUrl,
  });

  final String id;
  final String name;
  final String mimeType;
  final String dataUrl;
  final MediaInspection inspection;

  /// On-disk JPEG path of a pre-generated video preview. Null for images and
  /// for videos whose thumbnail hasn't been resolved yet (the background pass
  /// fills it in — see [_resolveSparkJoyVideoThumb]). Only ever assigned a
  /// non-null path, so [copyWith]'s `?? this` idiom never needs to clear it.
  final String? videoThumbPath;

  /// Presigned GET URL of a video's poster (preview JPEG) on S3, for completed
  /// reports whose videos are remote — set by the hydrator from
  /// [sparkJoyVideoPosterFilename]. iOS can't extract a frame from the remote
  /// video URL, so the tile renders this network image instead. Null for local
  /// videos (those use [videoThumbPath]) and for reports uploaded before the
  /// poster-on-upload feature shipped.
  final String? videoThumbUrl;

  UploadedItem copyWith({
    String? id,
    String? name,
    String? mimeType,
    String? dataUrl,
    MediaInspection? inspection,
    String? videoThumbPath,
    String? videoThumbUrl,
  }) {
    return UploadedItem(
      id: id ?? this.id,
      name: name ?? this.name,
      mimeType: mimeType ?? this.mimeType,
      dataUrl: dataUrl ?? this.dataUrl,
      inspection: inspection ?? this.inspection,
      videoThumbPath: videoThumbPath ?? this.videoThumbPath,
      videoThumbUrl: videoThumbUrl ?? this.videoThumbUrl,
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
