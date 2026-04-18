import 'dart:async';
import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:video_player/video_player.dart';

import 'spark_joy_ui.dart';

// ---------------------------------------------------------------------------
// Report detail screen — read-only view of a completed report.
// Mirrors the Summary ("Итог") step layout from the create-report flow.
// ---------------------------------------------------------------------------

/// Inspection section labels → icons mapping (mirrors summary step).
///
/// Used by the report detail UI to show an appropriate icon next to each
/// section header, matching the create-report flow's summary step.
// ignore: unused_element
const Map<String, IconData> _sectionIcons = {
  'Автомобиль': Icons.directions_car_outlined,
  'Параметры': Icons.tune_outlined,
  'Сверка документов': Icons.fact_check_outlined,
  'Юр. проверка': Icons.gavel_outlined,
  'Кузов': Icons.car_repair_outlined,
  'Остекление': Icons.window_outlined,
  'Силовые элементы кузова': Icons.build_outlined,
  'Светотехника': Icons.lightbulb_outlined,
  'Подкапотное пространство': Icons.settings_outlined,
  'Салон': Icons.airline_seat_recline_normal_outlined,
  'Колёса и тормозные механизмы': Icons.circle_outlined,
  'Колёса и шины': Icons.circle_outlined,
  'Компьютерная диагностика': Icons.computer_outlined,
  'Диагностика': Icons.computer_outlined,
  'Тест-драйв': Icons.speed_outlined,
};

/// Maps human-readable section titles to the JSON-RPC `inspectionStep`
/// keys defined in the OpenRPC Doc schema. Used when the UI needs to
/// drill from a section card into the underlying media array on the
/// server payload (e.g. for rendering attached photos/videos).
// ignore: unused_element
const Map<String, String> _sectionToInspectionKey = {
  'Кузов': 'bodySection',
  'Силовые элементы кузова': 'bodyReinforcementElementsSection',
  'Остекление': 'glassSection',
  'Салон': 'interiorSection',
  'Подкапотное пространство': 'underHoodSpaceSection',
  'Колёса и тормозные механизмы': 'wheelsAndBrakesSection',
  'Колёса и шины': 'wheelsAndBrakesSection',
  'Светотехника': 'lightningSection',
  'Компьютерная диагностика': 'computerDiagnosticsSection',
  'Диагностика': 'computerDiagnosticsSection',
};

class SparkJoyReportDetailScreen extends StatefulWidget {
  const SparkJoyReportDetailScreen({super.key, required this.report});

  final Map<String, dynamic> report;

  @override
  State<SparkJoyReportDetailScreen> createState() =>
      _SparkJoyReportDetailScreenState();
}

class _SparkJoyReportDetailScreenState
    extends State<SparkJoyReportDetailScreen> {
  // -- Image byte cache (per caching skill: in-memory for current session) --
  final Map<String, Uint8List> _imageBytesCache = {};

  // -----------------------------------------------------------------------
  // Helpers — image source detection
  // -----------------------------------------------------------------------

  static bool _isVideoUrl(String url) {
    final lower = url.toLowerCase();
    const videoExtensions = [
      '.mp4',
      '.mov',
      '.m4v',
      '.avi',
      '.mkv',
      '.webm',
    ];
    for (final ext in videoExtensions) {
      if (lower.endsWith(ext) || lower.contains('$ext?')) return true;
    }
    if (lower.contains('video/') || lower.contains('mime=video')) return true;
    return false;
  }

  Uint8List? _decodeDataUrlImageBytes(String source) {
    if (!source.trimLeft().startsWith('data:')) return null;
    final commaIndex = source.indexOf(',');
    if (commaIndex <= 0 || commaIndex >= source.length - 1) return null;
    final header = source.substring(0, commaIndex).toLowerCase();
    if (!header.contains('image/') || !header.contains(';base64')) return null;
    try {
      return base64Decode(source.substring(commaIndex + 1));
    } catch (_) {
      return null;
    }
  }

  String? _extractLocalImagePath(String source) {
    final normalized = source.trim();
    if (normalized.isEmpty || normalized.startsWith('data:')) return null;
    final uri = Uri.tryParse(normalized);
    if (uri == null) return normalized;
    if (!uri.hasScheme) return normalized;
    if (uri.scheme == 'file') return uri.toFilePath();
    return null;
  }

  Future<Uint8List?> _loadImageBytes(String source) async {
    final normalized = source.trim();
    if (normalized.isEmpty) return null;
    final cached = _imageBytesCache[normalized];
    if (cached != null) return cached;
    final decoded = _decodeDataUrlImageBytes(normalized);
    if (decoded != null) {
      _imageBytesCache[normalized] = decoded;
      return decoded;
    }
    final localPath = _extractLocalImagePath(normalized);
    if (localPath == null) return null;
    try {
      final bytes = await XFile(localPath).readAsBytes();
      if (bytes.isEmpty) return null;
      _imageBytesCache[normalized] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  // -----------------------------------------------------------------------
  // Image / video widget builders
  // -----------------------------------------------------------------------

  Widget _reportImageWidget(String source) {
    final normalized = source.trim();
    final memoryBytes = _decodeDataUrlImageBytes(normalized);
    if (memoryBytes != null) {
      return Image.memory(
        memoryBytes,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _brokenImagePlaceholder(),
      );
    }

    final localPath = _extractLocalImagePath(normalized);
    if (!kIsWeb && localPath != null) {
      return FutureBuilder<Uint8List?>(
        future: _loadImageBytes(normalized),
        builder: (context, snapshot) {
          final bytes = snapshot.data;
          if (bytes == null) {
            if (snapshot.connectionState == ConnectionState.done) {
              return _brokenImagePlaceholder();
            }
            return _loadingPlaceholder();
          }
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => _brokenImagePlaceholder(),
          );
        },
      );
    }

    return Image.network(
      normalized,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _brokenImagePlaceholder(),
    );
  }

  Widget _brokenImagePlaceholder() {
    return Container(
      color: kBorderColor,
      alignment: Alignment.center,
      child: const Icon(Icons.broken_image),
    );
  }

  Widget _loadingPlaceholder() {
    return Container(
      color: kBorderColor,
      alignment: Alignment.center,
      child: const SizedBox(
        width: 22,
        height: 22,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Data extraction — media URLs from report map
  // -----------------------------------------------------------------------

  List<_MediaItem> _allMedia() {
    final items = <_MediaItem>[];

    // Direct images list
    final direct = widget.report['images'];
    if (direct is List) {
      for (final e in direct) {
        final url = e.toString().trim();
        if (url.isNotEmpty) {
          items.add(_MediaItem(url: url, isVideo: _isVideoUrl(url)));
        }
      }
    }

    // Media groups (grouped by section)
    final mediaGroups = widget.report['mediaGroups'];
    if (mediaGroups is Map) {
      for (final value in mediaGroups.values) {
        if (value is! List) continue;
        for (final item in value) {
          if (item is Map && item['url'] != null) {
            final url = item['url'].toString().trim();
            if (url.isNotEmpty) {
              items.add(_MediaItem(url: url, isVideo: _isVideoUrl(url)));
            }
          }
        }
      }
    }

    // Fallback placeholder
    if (items.isEmpty) {
      items.add(const _MediaItem(
        url:
            'https://images.unsplash.com/photo-1492144534655-ae79c964c9d7?w=1200&q=80&auto=format&fit=crop',
        isVideo: false,
      ));
    }

    return items;
  }

  /// Extract media URLs grouped by section title.
  Map<String, List<_MediaItem>> _sectionMedia() {
    final mediaGroups = widget.report['mediaGroups'];
    if (mediaGroups is! Map) return {};
    final result = <String, List<_MediaItem>>{};
    for (final entry in mediaGroups.entries) {
      final key = entry.key.toString();
      final list = entry.value;
      if (list is! List) continue;
      final items = <_MediaItem>[];
      for (final item in list) {
        if (item is Map && item['url'] != null) {
          final url = item['url'].toString().trim();
          if (url.isNotEmpty) {
            items.add(_MediaItem(url: url, isVideo: _isVideoUrl(url)));
          }
        }
      }
      if (items.isNotEmpty) result[key] = items;
    }
    return result;
  }

  // -----------------------------------------------------------------------
  // Data extraction — sections, checklist from report map
  // -----------------------------------------------------------------------

  List<Map<String, dynamic>> _sections() {
    final sections = widget.report['sections'];
    if (sections is! List) return const <Map<String, dynamic>>[];
    return sections.whereType<Map>().map((e) {
      return Map<String, dynamic>.from(e);
    }).toList();
  }

  List<Map<String, dynamic>> _checklist() {
    final checklist = widget.report['checklist'];
    if (checklist is! List) return const <Map<String, dynamic>>[];
    return checklist.whereType<Map>().map((e) {
      return Map<String, dynamic>.from(e);
    }).toList();
  }

  // -----------------------------------------------------------------------
  // Media lightbox — opens fullscreen viewer with video support
  // -----------------------------------------------------------------------

  Future<void> _openMediaLightbox(List<_MediaItem> items, int index) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _ReportMediaLightbox(
          items: items,
          initialIndex: index,
        ),
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Section status color (matches Summary step)
  // -----------------------------------------------------------------------

  Color _sectionStatusColor(String status) {
    switch (status) {
      case 'ok':
        return kGreenColor;
      case 'bad':
      case 'danger':
      case 'error':
      case 'critical':
        return kRedColor;
      case 'warn':
      case 'minor':
        return kYellowColor;
      default:
        return kGreyColor;
    }
  }

  String _sectionStatusLabel(String status) {
    switch (status) {
      case 'ok':
        return 'ОК';
      case 'bad':
      case 'danger':
      case 'error':
      case 'critical':
        return 'Критично';
      default:
        return 'Есть замечания';
    }
  }

  Color _detailSeverityColor(String severity) {
    switch (severity) {
      case 'ok':
        return kGreenColor;
      case 'serious':
      case 'critical':
        return kRedColor;
      case 'minor':
        return kYellowColor;
      default:
        return kGreyColor;
    }
  }

  // -----------------------------------------------------------------------
  // BUILD
  // -----------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final report = widget.report;
    final title = sjRead(
      report,
      'reportName',
      fallback: sjRead(
        report,
        'car',
        fallback: [
          sjRead(report, 'make'),
          sjRead(report, 'model'),
        ].where((e) => e.isNotEmpty).join(' '),
      ),
    );

    final verdict = sjRead(report, 'verdict');
    final verdictLabel = sjRead(
      report,
      'verdictLabel',
      fallback: sparkVerdictLabel(verdict),
    );

    final allMedia = _allMedia();
    final sectionMedia = _sectionMedia();
    final sections = _sections();
    final checklist = _checklist();
    final reportCode = sjRead(report, 'reportCode');
    final createdAt = sjRead(
      report,
      'createdAt',
      fallback: sjRead(report, 'date'),
    );
    final metaLine = [
      if (reportCode.isNotEmpty) reportCode,
      if (createdAt.isNotEmpty) 'от $createdAt',
    ].join(' ');

    final imageCount = allMedia.where((m) => !m.isVideo).length;
    final videoCount = allMedia.where((m) => m.isVideo).length;

    return Scaffold(
      appBar: AppBar(title: Text(title.isEmpty ? 'Отчёт' : title)),
      body: ListView(
        padding: AppSizes.DEFAULT.copyWith(bottom: 28),
        children: [
          // -- Header card (matches Summary step header) --
          _buildHeaderCard(title, metaLine),
          const SizedBox(height: 10),

          // -- Media overview card with thumbnails --
          _buildMediaOverviewCard(allMedia, imageCount, videoCount),
          const SizedBox(height: 10),

          // -- Verdict chips --
          if (verdict.isNotEmpty || sjRead(report, 'score').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (verdictLabel.isNotEmpty)
                    SparkChip(
                      text: verdictLabel,
                      background:
                          sparkVerdictColor(verdict).withValues(alpha: 0.12),
                      color: sparkVerdictColor(verdict),
                    ),
                  if (sjRead(report, 'score').isNotEmpty)
                    SparkChip(
                      text: 'Оценка ${sjRead(report, 'score')}',
                      background: kSecondaryColor.withValues(alpha: 0.08),
                      color: kSecondaryColor,
                    ),
                ],
              ),
            ),

          // -- General data card --
          const SparkSectionTitle('Общие данные'),
          SparkCard(
            child: Column(
              children: [
                SparkInfoRow(
                  label: 'Авто',
                  value: sjRead(report, 'car', fallback: '-'),
                ),
                SparkInfoRow(
                  label: 'VIN',
                  value: sjRead(report, 'vin', fallback: '-'),
                ),
                SparkInfoRow(
                  label: 'Госномер',
                  value: sjRead(report, 'plate', fallback: '-'),
                ),
                SparkInfoRow(
                  label: 'Пробег',
                  value: sjRead(report, 'mileage', fallback: '-'),
                ),
                SparkInfoRow(
                  label: 'Двигатель',
                  value: sjRead(report, 'engine', fallback: '-'),
                ),
                SparkInfoRow(
                  label: 'КПП',
                  value: sjRead(report, 'transmission', fallback: '-'),
                ),
                SparkInfoRow(
                  label: 'Привод',
                  value: sjRead(report, 'drive', fallback: '-'),
                ),
                SparkInfoRow(
                  label: 'Эксперт',
                  value: sjRead(report, 'inspector', fallback: '-'),
                ),
                SparkInfoRow(
                  label: 'Дата',
                  value: sjRead(
                    report,
                    'date',
                    fallback: sjRead(report, 'createdAt', fallback: '-'),
                  ),
                ),
              ],
            ),
          ),

          // -- Sections list (matches Summary step section cards) --
          if (sections.isNotEmpty) const SparkSectionTitle('Осмотр', top: 14),
          ...sections.map((section) {
            final sTitle = sjRead(section, 'title', fallback: 'Раздел');
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildSectionCard(section, sTitle, sectionMedia),
            );
          }),

          // -- Checklist --
          if (checklist.isNotEmpty) const SparkSectionTitle('Чеклист', top: 6),
          if (checklist.isNotEmpty)
            SparkCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: checklist.map((item) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 6, right: 8),
                          child: Icon(
                            Icons.check_circle_outline,
                            size: 14,
                            color: kSecondaryColor,
                          ),
                        ),
                        Expanded(
                          child: MyText(
                            text: sjRead(item, 'text', fallback: '-'),
                            size: 12,
                            color: kTertiaryColor,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),

          // -- Summary note card --
          if (sjRead(report, 'summaryNote').isNotEmpty) ...[
            const SparkSectionTitle('Сводка по данным осмотра', top: 14),
            _buildSummaryNoteCard(sjRead(report, 'summaryNote')),
          ],

          // -- Expert conclusion card --
          if (sjRead(report, 'expertConclusion').isNotEmpty) ...[
            const SparkSectionTitle('Итог специалиста', top: 14),
            _buildExpertConclusionCard(sjRead(report, 'expertConclusion')),
          ],
        ],
      ),
    );
  }

  // -----------------------------------------------------------------------
  // Widget builders — header, media overview, sections, notes
  // -----------------------------------------------------------------------

  Widget _buildHeaderCard(String title, String meta) {
    return SparkCard(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.description_outlined, size: 16, color: kGreyColor),
              SizedBox(width: 6),
              Expanded(
                child: MyText(
                  text: 'Название отчёта',
                  size: 12,
                  color: kGreyColor,
                  weight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: kInputBgColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kBorderColor),
            ),
            child: MyText(
              text: title.isEmpty ? 'Без названия' : title,
              size: 20,
              weight: FontWeight.w700,
              maxLines: 2,
              textOverflow: TextOverflow.ellipsis,
            ),
          ),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 14,
                  color: kGreyColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: MyText(text: meta, size: 13, color: kGreyColor),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMediaOverviewCard(
    List<_MediaItem> items,
    int imageCount,
    int videoCount,
  ) {
    if (items.isEmpty || (items.length == 1 && items.first.url.contains('unsplash'))) {
      return const SizedBox.shrink();
    }

    final countParts = <String>[
      if (imageCount > 0) '$imageCount фото',
      if (videoCount > 0) '$videoCount видео',
    ];

    return SparkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('\u2705', style: TextStyle(fontSize: 14)),
              const SizedBox(width: 6),
              const Expanded(
                child: MyText(
                  text: 'Обзор авто',
                  size: 15,
                  weight: FontWeight.w700,
                ),
              ),
              if (countParts.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: kGreenColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: MyText(
                    text: countParts.join(', '),
                    size: 11,
                    weight: FontWeight.w700,
                    color: kGreenColor,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: items.asMap().entries.map((entry) {
              final index = entry.key;
              final media = entry.value;
              return ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: () => _openMediaLightbox(items, index),
                  child: Container(
                    width: 74,
                    height: 74,
                    color: kLightGreyColor,
                    child: media.isVideo
                        ? Stack(
                            fit: StackFit.expand,
                            children: [
                              Container(
                                color: kTertiaryColor.withValues(alpha: 0.15),
                              ),
                              const Center(
                                child: Icon(
                                  Icons.play_circle_fill_rounded,
                                  size: 28,
                                  color: Color(0xD9FFFFFF),
                                ),
                              ),
                            ],
                          )
                        : _reportImageWidget(media.url),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(
    Map<String, dynamic> section,
    String title,
    Map<String, List<_MediaItem>> sectionMedia,
  ) {
    final status = sjRead(section, 'status');
    final statusColor = _sectionStatusColor(status);

    final detailLines = <String>[];
    final detailMaps = <Map<String, dynamic>>[];
    final detailsRaw = section['details'];
    if (detailsRaw is List) {
      for (final detail in detailsRaw) {
        if (detail is String) {
          if (detail.trim().isNotEmpty) detailLines.add(detail.trim());
          continue;
        }
        if (detail is Map) {
          detailMaps.add(
            detail.map((key, value) => MapEntry(key.toString(), value)),
          );
        }
      }
    }

    final mediaItems = sectionMedia[title] ?? const [];

    return SparkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Expanded(
                child: MyText(
                  text: title,
                  size: 15,
                  weight: FontWeight.w700,
                ),
              ),
            ],
          ),

          // Status chip (matches Summary step)
          if (status.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: MyText(
                text: _sectionStatusLabel(status),
                size: 11,
                weight: FontWeight.w700,
                color: statusColor,
              ),
            ),
          ],

          if (detailLines.isNotEmpty || detailMaps.isNotEmpty)
            const SizedBox(height: 8),

          // Plain text details
          ...detailLines.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: MyText(text: '\u2022 $line', size: 12, color: kGreyColor),
            ),
          ),

          // Structured detail maps (label: value with severity color)
          ...detailMaps.map((detail) {
            final label = (detail['label'] ?? '').toString().trim();
            final value = (detail['value'] ?? '').toString().trim();
            final severity = (detail['severity'] ?? '').toString().trim();
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 12),
                  children: [
                    TextSpan(
                      text:
                          '\u2022 ${label.isEmpty ? 'Пункт' : label}: ',
                      style: const TextStyle(color: kGreyColor),
                    ),
                    TextSpan(
                      text: value.isEmpty ? '-' : value,
                      style: TextStyle(
                        color: _detailSeverityColor(severity),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),

          // Inline section media thumbnails
          if (mediaItems.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: mediaItems.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final media = entry.value;
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      onTap: () => _openMediaLightbox(mediaItems, idx),
                      child: Container(
                        width: 74,
                        height: 74,
                        color: kLightGreyColor,
                        child: media.isVideo
                            ? Stack(
                                fit: StackFit.expand,
                                children: [
                                  Container(
                                    color: kTertiaryColor.withValues(
                                      alpha: 0.15,
                                    ),
                                  ),
                                  const Center(
                                    child: Icon(
                                      Icons.play_circle_fill_rounded,
                                      size: 28,
                                      color: Color(0xD9FFFFFF),
                                    ),
                                  ),
                                ],
                              )
                            : _reportImageWidget(media.url),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryNoteCard(String note) {
    return SparkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MyText(
            text: 'Сводка по данным осмотра',
            size: 15,
            weight: FontWeight.w700,
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kBorderColor),
              color: kInputBgColor,
            ),
            child: MyText(
              text: note,
              size: 13,
              color: kTertiaryColor,
              lineHeight: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpertConclusionCard(String conclusion) {
    return SparkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Text('\u270d\ufe0f', style: TextStyle(fontSize: 16)),
              SizedBox(width: 6),
              MyText(
                text: 'Итог специалиста',
                size: 15,
                weight: FontWeight.w700,
              ),
            ],
          ),
          const SizedBox(height: 8),
          MyText(
            text: conclusion,
            size: 13,
            color: kTertiaryColor,
            lineHeight: 1.35,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Data model for a media item (image or video)
// ---------------------------------------------------------------------------

class _MediaItem {
  const _MediaItem({required this.url, required this.isVideo});
  final String url;
  final bool isVideo;
}

// ---------------------------------------------------------------------------
// Full-screen media lightbox with video player support.
// Uses StatefulWidget with proper VideoPlayerController lifecycle
// management per flutter-managing-state and flutter-handling-concurrency skills.
// ---------------------------------------------------------------------------

class _ReportMediaLightbox extends StatefulWidget {
  const _ReportMediaLightbox({
    required this.items,
    required this.initialIndex,
  });

  final List<_MediaItem> items;
  final int initialIndex;

  @override
  State<_ReportMediaLightbox> createState() => _ReportMediaLightboxState();
}

class _ReportMediaLightboxState extends State<_ReportMediaLightbox> {
  late final PageController _pageController;
  late int _currentIndex;

  // Video player state — ephemeral, managed via setState
  VideoPlayerController? _videoController;
  bool _videoInitializing = false;
  String? _videoError;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.items.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _prepareIfVideo(widget.items[_currentIndex]);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _disposeVideoController();
    super.dispose();
  }

  void _disposeVideoController() {
    final controller = _videoController;
    _videoController = null;
    if (controller != null) {
      unawaited(controller.pause());
      unawaited(controller.dispose());
    }
  }

  Future<void> _prepareIfVideo(_MediaItem item) async {
    _disposeVideoController();
    _videoError = null;

    if (!item.isVideo) {
      _videoInitializing = false;
      if (mounted) setState(() {});
      return;
    }

    _videoInitializing = true;
    if (mounted) setState(() {});

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(item.url));
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      _videoController = controller;
      _videoInitializing = false;
      setState(() {});
    } catch (_) {
      _videoInitializing = false;
      _videoError = 'Не удалось воспроизвести видео';
      if (mounted) setState(() {});
    }
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    _prepareIfVideo(widget.items[index]);
  }

  void _togglePlayPause() {
    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          '${_currentIndex + 1} / ${widget.items.length}',
          style: const TextStyle(fontSize: 14),
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.items.length,
        onPageChanged: _onPageChanged,
        itemBuilder: (context, index) {
          final item = widget.items[index];
          if (item.isVideo && index == _currentIndex) {
            return _buildVideoPage();
          }
          if (item.isVideo) {
            // Not the active page — show placeholder
            return const Center(
              child: Icon(
                Icons.play_circle_outline,
                size: 64,
                color: Colors.white54,
              ),
            );
          }
          // Image page
          return InteractiveViewer(
            child: Center(
              child: CachedNetworkImage(
                imageUrl: item.url,
                fit: BoxFit.contain,
                errorWidget: (_, _, _) => const Icon(
                  Icons.broken_image,
                  size: 48,
                  color: Colors.white54,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVideoPage() {
    if (_videoInitializing) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_videoError != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.white54),
            const SizedBox(height: 12),
            Text(
              _videoError!,
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () =>
                  _prepareIfVideo(widget.items[_currentIndex]),
              child: const Text('Повторить'),
            ),
          ],
        ),
      );
    }

    final controller = _videoController;
    if (controller == null || !controller.value.isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    final size = controller.value.size;
    final aspectRatio =
        size.width > 0 && size.height > 0 ? size.width / size.height : 16 / 9;

    return GestureDetector(
      onTap: _togglePlayPause,
      child: Center(
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(controller),
              if (!controller.value.isPlaying)
                const Icon(
                  Icons.play_circle_fill_rounded,
                  size: 64,
                  color: Color(0xBBFFFFFF),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
