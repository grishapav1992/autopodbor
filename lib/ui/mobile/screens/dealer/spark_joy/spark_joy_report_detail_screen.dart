import 'dart:convert';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/data/api/storage_api.dart' as storage_api;
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:url_launcher/url_launcher.dart';

import 'spark_joy_i18n.dart';
import 'spark_joy_storage.dart';
import 'spark_joy_tokens.dart';
import 'spark_joy_ui.dart';

class SparkJoyReportDetailScreen extends StatefulWidget {
  const SparkJoyReportDetailScreen({super.key, required this.report});

  final Map<String, dynamic> report;

  @override
  State<SparkJoyReportDetailScreen> createState() =>
      _SparkJoyReportDetailScreenState();
}

class _SparkJoyReportDetailScreenState
    extends State<SparkJoyReportDetailScreen> {
  int _imageIndex = 0;
  final Map<String, Uint8List> _imageBytesCache = {};
  late Map<String, dynamic> _report;
  bool _remoteLoading = false;
  bool _shareLoading = false;

  @override
  void initState() {
    super.initState();
    _report = Map<String, dynamic>.from(widget.report);
    _loadRemoteReport();
  }

  int? _readReportId(Map<String, dynamic> report) {
    return storage_api.StorageApi.readSpecialistReportId(report);
  }

  String _readReportNumber(Map<String, dynamic> report) {
    return storage_api.StorageApi.readSpecialistReportNumber(report);
  }

  Future<int?> _ensureReportId() async {
    final directId = _readReportId(_report);
    if (directId != null) return directId;
    try {
      final resolved = await storage_api.StorageApi.resolveSpecialistReportId(
        report: _report,
      );
      if (resolved == null) return null;
      final updated = <String, dynamic>{..._report, 'id': resolved.toString()};
      await SparkJoyStorage.upsertCompleted(updated);
      if (mounted) {
        setState(() => _report = updated);
      } else {
        _report = updated;
      }
      return resolved;
    } catch (_) {
      return null;
    }
  }

  bool _hasMeaningfulValue(dynamic value) {
    if (value == null) return false;
    if (value is String) return value.trim().isNotEmpty;
    if (value is Iterable) return value.isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    return true;
  }

  Map<String, dynamic> _mergeRemoteSnapshot({
    required Map<String, dynamic> local,
    required Map<String, dynamic> remote,
  }) {
    final merged = <String, dynamic>{...local, ...remote};
    for (final key in const [
      'images',
      'mediaGroups',
      'sections',
      'checklist',
      'summaryNote',
      'expertConclusion',
      'legalFiles',
      'docsCommentAudioFiles',
      'legalCommentAudioFiles',
      'tdCommentAudioFiles',
      'expertAudioFiles',
    ]) {
      final remoteValue = remote[key];
      final localValue = local[key];
      if (!_hasMeaningfulValue(remoteValue) && _hasMeaningfulValue(localValue)) {
        merged[key] = localValue;
      }
    }
    return merged;
  }

  Future<void> _loadRemoteReport() async {
    final reportId = await _ensureReportId();
    if (reportId == null) return;
    setState(() => _remoteLoading = true);
    try {
      final remote = await storage_api.StorageApi.viewSpecialistReport(
        reportId: reportId,
      );
      if (!mounted || remote.isEmpty) return;
      setState(() {
        _report = _mergeRemoteSnapshot(local: _report, remote: remote);
      });
    } catch (_) {
      // Keep local snapshot if backend detail is temporarily unavailable.
    } finally {
      if (mounted) {
        setState(() => _remoteLoading = false);
      }
    }
  }

  Future<void> _createAndCopyShareLink() async {
    final reportId = await _ensureReportId();
    if (!mounted) return;
    if (reportId == null || _shareLoading) {
      if (reportId == null) {
        final reportNumber = _readReportNumber(_report);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              reportNumber.isEmpty
                  ? 'Не удалось определить ID отчёта'
                  : 'Не удалось определить ID отчёта для №$reportNumber',
            ),
          ),
        );
      }
      return;
    }
    setState(() => _shareLoading = true);
    try {
      final generated = await storage_api
          .StorageApi.createSpecialistReportShareUrl(reportId: reportId);
      final url = generated.url.trim();
      if (url.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ссылка не была сгенерирована')),
        );
        return;
      }
      final updated = <String, dynamic>{
        ..._report,
        'shareUrl': url,
        'shareUrlCreatedAt': DateTime.now().toIso8601String(),
      };
      await SparkJoyStorage.upsertCompleted(updated);
      if (!mounted) return;
      setState(() => _report = updated);
      await _showShareLinkSheet(url);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось сгенерировать ссылку')),
      );
    } finally {
      if (mounted) setState(() => _shareLoading = false);
    }
  }

  Future<void> _openShareUrl(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Некорректная ссылка')));
      return;
    }
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Не удалось открыть ссылку')));
  }

  Future<void> _showShareLinkSheet(String url) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Container(
            margin: const EdgeInsets.all(SparkSpace.xl),
            decoration: BoxDecoration(
              color: kWhiteColor,
              borderRadius: BorderRadius.circular(SparkRadius.xl),
              border: Border.all(color: kBorderColor),
            ),
            child: Padding(
              padding: const EdgeInsets.all(SparkSpace.xxxl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const MyText(
                    text: 'Ссылка на отчёт',
                    size: SparkTextSize.title,
                    weight: FontWeight.w700,
                  ),
                  const SizedBox(height: SparkSpace.md),
                  SparkHintCard(text: url, icon: Icons.link_rounded),
                  const SizedBox(height: SparkSpace.xl),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(ClipboardData(text: url));
                            if (!ctx.mounted) return;
                            Navigator.of(ctx).pop();
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Ссылка скопирована'),
                              ),
                            );
                          },
                          icon: const Icon(Icons.copy_rounded),
                          label: const Text('Копировать'),
                        ),
                      ),
                      const SizedBox(width: SparkSpace.md),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () async {
                            Navigator.of(ctx).pop();
                            await _openShareUrl(url);
                          },
                          icon: const Icon(Icons.open_in_new_rounded),
                          label: const Text('Открыть'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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

  Widget _reportImageWidget(String source) {
    final normalized = source.trim();
    final memoryBytes = _decodeDataUrlImageBytes(normalized);
    if (memoryBytes != null) {
      return Image.memory(
        memoryBytes,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          color: kBorderColor,
          alignment: Alignment.center,
          child: const Icon(Icons.broken_image),
        ),
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
              return Container(
                color: kBorderColor,
                alignment: Alignment.center,
                child: const Icon(Icons.broken_image),
              );
            }
            return Container(
              color: kBorderColor,
              alignment: Alignment.center,
              child: const SizedBox(
                width: SparkSize.iconXl,
                height: SparkSize.iconXl,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            );
          }
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => Container(
              color: kBorderColor,
              alignment: Alignment.center,
              child: const Icon(Icons.broken_image),
            ),
          );
        },
      );
    }

    return Image.network(
      normalized,
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => Container(
        color: kBorderColor,
        alignment: Alignment.center,
        child: const Icon(Icons.broken_image),
      ),
    );
  }

  List<String> _images() {
    final direct = _report['images'];
    if (direct is List) {
      final urls = direct
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();
      if (urls.isNotEmpty) return urls;
    }

    final mediaGroups = _report['mediaGroups'];
    if (mediaGroups is Map) {
      final urls = <String>[];
      for (final value in mediaGroups.values) {
        if (value is! List) continue;
        for (final item in value) {
          if (item is Map && item['url'] != null) {
            final url = item['url'].toString();
            if (url.isNotEmpty) urls.add(url);
          }
        }
      }
      if (urls.isNotEmpty) return urls;
    }

    return const [
      'https://images.unsplash.com/photo-1492144534655-ae79c964c9d7?w=1200&q=80&auto=format&fit=crop',
    ];
  }

  List<Map<String, dynamic>> _sections() {
    final sections = _report['sections'];
    if (sections is! List) return const <Map<String, dynamic>>[];
    return sections.whereType<Map>().map((e) {
      return Map<String, dynamic>.from(e);
    }).toList();
  }

  List<Map<String, dynamic>> _checklist() {
    final checklist = _report['checklist'];
    if (checklist is! List) return const <Map<String, dynamic>>[];
    return checklist.whereType<Map>().map((e) {
      return Map<String, dynamic>.from(e);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
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

    final sections = _sections();
    final checklist = _checklist();
    final images = _images();
    final reportId = _readReportId(report);
    final reportNumber = _readReportNumber(report);
    final createdAtLabel = sjFormatDate(
      sjRead(
        report,
        'date',
        fallback: sjRead(report, 'createdAt', fallback: '-'),
      ),
    );
    final inspector = sjRead(report, 'inspector');
    final headerSubtitle = inspector.trim().isEmpty
        ? 'Отчёт от $createdAtLabel'
        : 'Отчёт от $createdAtLabel • $inspector';

    return SparkPageScaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text('Отчёт'),
        actions: [
          IconButton(
            onPressed: _shareLoading ? null : _createAndCopyShareLink,
            tooltip: 'Поделиться',
            icon: _shareLoading
                ? const SizedBox(
                    width: SparkSize.iconSm,
                    height: SparkSize.iconSm,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.share_outlined),
          ),
        ],
      ),
      bottomInset: SparkSpace.xl,
      children: [
        if (_remoteLoading) ...[
          const LinearProgressIndicator(minHeight: SparkSize.progressThin),
          const SizedBox(height: SparkSpace.lg),
        ],
        ClipRRect(
          borderRadius: BorderRadius.circular(SparkRadius.lg),
          child: SizedBox(
            height: SparkSize.mediaPreviewHeight,
            child: Stack(
              children: [
                PageView.builder(
                  itemCount: images.length,
                  onPageChanged: (idx) => setState(() => _imageIndex = idx),
                  itemBuilder: (context, index) {
                    return _reportImageWidget(images[index]);
                  },
                ),
                if (images.length > 1)
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: SparkSpace.md,
                        vertical: SparkSpace.xs,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(SparkRadius.pill),
                      ),
                      child: MyText(
                        text: '${_imageIndex + 1}/${images.length}',
                        size: SparkTextSize.chip,
                        color: kWhiteColor,
                        weight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: SparkSpace.xl),
        SparkPageHeader(
          title: title.isEmpty ? 'Отчёт' : title,
          subtitle: headerSubtitle,
        ),
        const SizedBox(height: SparkSpace.xxl),
        Wrap(
          spacing: SparkSpace.md,
          runSpacing: SparkSpace.md,
          children: [
            SparkChip(
              text: verdictLabel,
              background: sparkVerdictColor(verdict).withValues(alpha: 0.12),
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
        const SparkSectionTitle('Общие данные', top: SparkSpace.xxl),
        SparkCard(
          child: Column(
            children: [
              if (reportId != null || reportNumber.isNotEmpty)
                SparkInfoRow(
                  label: 'ID отчёта',
                  value: reportId?.toString() ?? '-',
                ),
              if (reportNumber.isNotEmpty)
                SparkInfoRow(label: 'Номер отчёта', value: reportNumber),
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
                value: sjRead(report, 'mileage').trim().isEmpty
                    ? '-'
                    : sjFormatMileage(sjRead(report, 'mileage')),
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
              SparkInfoRow(label: 'Дата', value: createdAtLabel),
            ],
          ),
        ),
        if (sections.isNotEmpty)
          const SparkSectionTitle('Осмотр', top: SparkSpace.xxl),
        if (sections.isNotEmpty)
          ...sections.map((section) {
            final details = sjReadMapList(section['details']);
            final sectionStatus = sjRead(section, 'status');
            final hasIssue =
                sectionStatus == 'warn' ||
                sectionStatus == 'danger' ||
                sectionStatus == 'error';
            return Padding(
              padding: const EdgeInsets.only(bottom: SparkSpace.lg),
              child: SparkCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: MyText(
                            text: sjRead(section, 'title', fallback: 'Раздел'),
                            size: SparkTextSize.bodyLg,
                            weight: FontWeight.w700,
                          ),
                        ),
                        SparkChip(
                          text: hasIssue ? 'Есть замечания' : 'ОК',
                          background: hasIssue
                              ? kYellowColor.withValues(alpha: 0.16)
                              : kGreenColor.withValues(alpha: 0.14),
                          color: hasIssue ? kYellowColor : kGreenColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: SparkSpace.md),
                    if (details.isEmpty)
                      const MyText(
                        text: 'Детали не указаны',
                        size: SparkTextSize.body,
                        color: kGreyColor,
                      ),
                    ...details.map((item) {
                      final severity = sjRead(item, 'severity');
                      final color = severity == 'minor'
                          ? kYellowColor
                          : severity == 'critical'
                          ? kRedColor
                          : kGreyColor;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: SparkSpace.sm),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                top: SparkSpace.sm,
                                right: SparkSpace.md,
                              ),
                              child: Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  MyText(
                                    text: sjRead(
                                      item,
                                      'label',
                                      fallback: 'Проверка',
                                    ),
                                    size: SparkTextSize.body,
                                    weight: FontWeight.w600,
                                  ),
                                  const SizedBox(height: SparkSpace.hairline),
                                  MyText(
                                    text: sjRead(item, 'value', fallback: '-'),
                                    size: SparkTextSize.caption,
                                    color: kGreyColor,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          }),
        if (checklist.isNotEmpty)
          const SparkSectionTitle('Чеклист', top: SparkSpace.sm),
        if (checklist.isNotEmpty)
          SparkCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(checklist.length, (index) {
                final item = checklist[index];
                final isLast = index == checklist.length - 1;
                return Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : SparkSpace.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(
                          top: SparkSpace.sm,
                          right: SparkSpace.md,
                        ),
                        child: Icon(
                          Icons.check_circle_outline,
                          size: SparkTextSize.label,
                          color: kSecondaryColor,
                        ),
                      ),
                      Expanded(
                        child: MyText(
                          text: sjRead(item, 'text', fallback: '-'),
                          size: SparkTextSize.body,
                          color: kTertiaryColor,
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          ),
        if (sjRead(report, 'summaryNote').isNotEmpty)
          const SparkSectionTitle('Резюме', top: SparkSpace.xxl),
        if (sjRead(report, 'summaryNote').isNotEmpty)
          SparkCard(
            child: MyText(
              text: sjRead(report, 'summaryNote'),
              size: SparkTextSize.body,
              color: kGreyColor,
              lineHeight: 1.4,
            ),
          ),
        if (sjRead(report, 'expertConclusion').isNotEmpty)
          const SparkSectionTitle('Заключение эксперта', top: SparkSpace.xxl),
        if (sjRead(report, 'expertConclusion').isNotEmpty)
          SparkCard(
            child: MyText(
              text: sjRead(report, 'expertConclusion'),
              size: SparkTextSize.body,
              color: kGreyColor,
              lineHeight: 1.4,
            ),
          ),
      ],
    );
  }
}
