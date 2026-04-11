import 'package:flutter/material.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';

import 'spark_joy_create_report_screen.dart';
import 'spark_joy_data.dart';
import 'spark_joy_i18n.dart';
import 'spark_joy_new_report_name_screen.dart';
import 'spark_joy_report_detail_screen.dart';
import 'spark_joy_storage.dart';
import 'spark_joy_tokens.dart';
import 'spark_joy_ui.dart';

class SparkJoyReportsListScreen extends StatefulWidget {
  const SparkJoyReportsListScreen({super.key, this.companyMode = false});

  final bool companyMode;

  @override
  State<SparkJoyReportsListScreen> createState() =>
      _SparkJoyReportsListScreenState();
}

class _SparkJoyReportsListScreenState extends State<SparkJoyReportsListScreen> {
  late final _SparkJoyReportsListController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _SparkJoyReportsListController(
      companyMode: widget.companyMode,
    );
    _controller.load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() => _controller.load();

  Future<void> _openNewReport() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            SparkJoyNewReportNameScreen(companyMode: widget.companyMode),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _openDraft(Map<String, dynamic> draft) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SparkJoyCreateReportScreen(draft: draft),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  Future<void> _openCompleted(Map<String, dynamic> report) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SparkJoyReportDetailScreen(report: report),
      ),
    );
  }

  Future<void> _deleteDraft(String id) async {
    await SparkJoyStorage.deleteDraft(id);
    await _load();
  }

  Widget _buildStatTile({
    required String title,
    required String value,
    required IconData icon,
  }) {
    return Expanded(
      child: SparkStatTile(title: title, value: value, icon: icon),
    );
  }

  Widget _buildDraftCard(Map<String, dynamic> draft) {
    final title = [
      sjRead(draft, 'reportName'),
      sjRead(draft, 'car'),
      sjRead(draft, 'vin'),
    ].firstWhere((e) => e.trim().isNotEmpty, orElse: () => 'Новый отчёт');

    final step = int.tryParse(sjRead(draft, 'currentStep')) ?? 1;
    final total = int.tryParse(sjRead(draft, 'totalSteps')) ?? 7;

    return SparkListCard(
      onTap: () => _openDraft(draft),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                MyText(
                  text: title,
                  size: SparkTextSize.bodyLg,
                  weight: FontWeight.w700,
                ),
                if (sjRead(draft, 'car').isNotEmpty &&
                    sjRead(draft, 'car') != title)
                  MyText(
                    text: sjRead(draft, 'car'),
                    size: SparkTextSize.caption,
                    color: kGreyColor,
                    paddingTop: SparkSpace.xxs,
                  ),
                if (sjRead(draft, 'vin').isNotEmpty)
                  MyText(
                    text: sjRead(draft, 'vin'),
                    size: SparkTextSize.caption,
                    color: kGreyColor,
                    paddingTop: SparkSpace.xxs,
                  ),
                MyText(
                  text: 'Шаг $step из $total',
                  size: SparkTextSize.caption,
                  color: kGreyColor,
                  paddingTop: SparkSpace.xs,
                ),
                if (sjRead(draft, 'assignedSpecialistName').isNotEmpty)
                  MyText(
                    text:
                        'Исполнитель: ${sjRead(draft, 'assignedSpecialistName')}',
                    size: SparkTextSize.caption,
                    color: kGreyColor,
                    paddingTop: SparkSpace.xxs,
                  ),
              ],
            ),
          ),
          const SizedBox(width: SparkSpace.md),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              MyText(
                text: sjFormatDate(sjRead(draft, 'updatedAt')),
                size: SparkTextSize.chip,
                color: kGreyColor,
              ),
              const SizedBox(height: SparkSpace.xs),
              SparkChip(
                text: 'Продолжить',
                background: kSecondaryColor.withValues(alpha: 0.1),
                color: kSecondaryColor,
              ),
              const SizedBox(height: SparkSpace.md),
              OutlinedButton.icon(
                onPressed: () => _deleteDraft(sjRead(draft, 'id')),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, SparkSize.actionCompactHeight),
                  padding: const EdgeInsets.symmetric(
                    horizontal: SparkSpace.lg,
                    vertical: SparkSpace.xs,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  side: const BorderSide(color: kBorderColor),
                  foregroundColor: kGreyColor,
                  backgroundColor: kInputBgColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(SparkRadius.pill),
                  ),
                ),
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  size: SparkTextSize.title,
                ),
                label: const Text('Удалить'),
              ),
              const SizedBox(height: SparkSpace.xs),
              const Icon(
                Icons.chevron_right_rounded,
                size: SparkSize.iconMd,
                color: kGreyColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedCard(Map<String, dynamic> report) {
    final car = [
      sjRead(report, 'car'),
      [
        sjRead(report, 'make'),
        sjRead(report, 'model'),
      ].where((e) => e.isNotEmpty).join(' '),
    ].firstWhere((e) => e.trim().isNotEmpty, orElse: () => 'Отчёт');

    final title = sjRead(report, 'reportName', fallback: car);
    final verdict = sjRead(report, 'verdict');

    return SparkListCard(
      onTap: () => _openCompleted(report),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MyText(
                      text: title,
                      size: SparkTextSize.bodyLg,
                      weight: FontWeight.w700,
                    ),
                    if (car != title)
                      MyText(
                        text: car,
                        size: SparkTextSize.caption,
                        color: kGreyColor,
                        paddingTop: SparkSpace.xxs,
                      ),
                    if (sjRead(report, 'vin').isNotEmpty)
                      MyText(
                        text: sjRead(report, 'vin'),
                        size: SparkTextSize.caption,
                        color: kGreyColor,
                        paddingTop: SparkSpace.xxs,
                      ),
                    if (sjRead(report, 'mileage').isNotEmpty)
                      MyText(
                        text: sjFormatMileage(sjRead(report, 'mileage')),
                        size: SparkTextSize.caption,
                        color: kGreyColor,
                        paddingTop: SparkSpace.xxs,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: SparkSpace.md),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  MyText(
                    text: sjFormatDate(sjRead(report, 'createdAt')),
                    size: SparkTextSize.chip,
                    color: kGreyColor,
                  ),
                  const SizedBox(height: SparkSpace.sm),
                  const Icon(
                    Icons.chevron_right_rounded,
                    size: SparkSize.iconMd,
                    color: kGreyColor,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: SparkSpace.md),
          Wrap(
            spacing: SparkSpace.md,
            runSpacing: SparkSpace.md,
            children: [
              SparkChip(
                text: sjRead(report, 'score', fallback: '—'),
                background: kSecondaryColor.withValues(alpha: 0.08),
                color: kSecondaryColor,
              ),
              SparkChip(
                text: sparkVerdictLabel(verdict),
                background: sparkVerdictColor(verdict).withValues(alpha: 0.12),
                color: sparkVerdictColor(verdict),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final drafts = _controller.filteredDrafts;
        final completed = _controller.filteredCompleted;
        final activeCount = _controller.tab == 'drafts'
            ? drafts.length
            : completed.length;

        return SparkScreenList(
          bottomInset: 56,
          children: [
            SparkPrimaryActionButton(
              label: 'Создать новый отчёт',
              onTap: _openNewReport,
            ),
            const SizedBox(height: SparkSpace.xl),
            Row(
              children: [
                _buildStatTile(
                  title: 'Черновики',
                  value: '${_controller.drafts.length}',
                  icon: Icons.edit_note_rounded,
                ),
                const SizedBox(width: SparkSpace.md),
                _buildStatTile(
                  title: 'Завершённые',
                  value: '${_controller.completed.length}',
                  icon: Icons.task_alt_rounded,
                ),
              ],
            ),
            const SizedBox(height: SparkSpace.xl),
            SparkSearchField(
              hint: 'Поиск по марке, модели, VIN...',
              onChanged: _controller.setSearch,
            ),
            const SizedBox(height: SparkSpace.xl),
            SparkSegmentedTabs(
              items: [
                SparkSegmentedTabItem(
                  value: 'drafts',
                  label: 'Черновики',
                  count: drafts.length,
                ),
                SparkSegmentedTabItem(
                  value: 'completed',
                  label: 'Завершённые',
                  count: completed.length,
                ),
              ],
              value: _controller.tab,
              onChanged: _controller.setTab,
            ),
            const SizedBox(height: SparkSpace.lg),
            MyText(
              text: _controller.tab == 'drafts'
                  ? 'Черновики • $activeCount'
                  : 'Завершённые • $activeCount',
              size: SparkTextSize.title,
              weight: FontWeight.w700,
            ),
            const SizedBox(height: SparkSpace.xl),
            if (_controller.loading)
              SparkLoadingState(
                message: sjT(
                  'spark.state.loading.reports',
                  fallback: 'Загрузка отчётов...',
                ),
              )
            else if (_controller.loadError != null)
              SparkErrorState(
                title: sjT(
                  'spark.state.error.title',
                  fallback: 'Ошибка загрузки',
                ),
                subtitle: _controller.loadError!,
                onRetry: _load,
              )
            else if (_controller.tab == 'drafts')
              if (drafts.isEmpty)
                SparkEmptyState(
                  icon: Icons.edit_note,
                  title: sjT(
                    'spark.empty.noDrafts.title',
                    fallback: 'Нет черновиков',
                  ),
                  subtitle: sjT(
                    'spark.empty.noDrafts.subtitle',
                    fallback: 'Начните новый отчёт, чтобы увидеть его здесь',
                  ),
                )
              else
                ...drafts.map(_buildDraftCard)
            else if (completed.isEmpty)
              SparkEmptyState(
                icon: Icons.check_circle_outline,
                title: sjT(
                  'spark.empty.noCompleted.title',
                  fallback: 'Нет завершённых отчётов',
                ),
                subtitle: sjT(
                  'spark.empty.noCompleted.subtitle',
                  fallback: 'Завершите осмотр, чтобы увидеть результат',
                ),
              )
            else
              ...completed.map(_buildCompletedCard),
          ],
        );
      },
    );
  }
}

class _SparkJoyReportsListController extends ChangeNotifier {
  _SparkJoyReportsListController({required this.companyMode});

  final bool companyMode;
  String _search = '';
  String _tab = 'drafts';
  bool _loading = true;
  String? _loadError;
  int _loadToken = 0;
  bool _disposed = false;

  List<Map<String, dynamic>> _drafts = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _completed = <Map<String, dynamic>>[];

  String get tab => _tab;
  bool get loading => _loading;
  String? get loadError => _loadError;
  List<Map<String, dynamic>> get drafts => _drafts;
  List<Map<String, dynamic>> get completed => _completed;

  List<Map<String, dynamic>> get filteredDrafts {
    if (_search.trim().isEmpty) return _drafts;
    final query = _search.toLowerCase();
    return _drafts.where((d) {
      final text = [
        sjRead(d, 'reportName'),
        sjRead(d, 'car'),
        sjRead(d, 'brand'),
        sjRead(d, 'model'),
        sjRead(d, 'vin'),
      ].join(' ').toLowerCase();
      return text.contains(query);
    }).toList();
  }

  List<Map<String, dynamic>> get filteredCompleted {
    if (_search.trim().isEmpty) return _completed;
    final query = _search.toLowerCase();
    return _completed.where((r) {
      final text = [
        sjRead(r, 'reportName'),
        sjRead(r, 'car'),
        sjRead(r, 'make'),
        sjRead(r, 'model'),
        sjRead(r, 'vin'),
        sjRead(r, 'plate'),
      ].join(' ').toLowerCase();
      return text.contains(query);
    }).toList();
  }

  void setSearch(String value) {
    if (_search == value) return;
    _search = value;
    _safeNotify();
  }

  void setTab(String value) {
    if (_tab == value) return;
    _tab = value;
    _safeNotify();
  }

  Future<void> load() async {
    final token = ++_loadToken;
    _loading = true;
    _loadError = null;
    _safeNotify();
    try {
      final allDraftsFuture = SparkJoyStorage.loadDrafts();
      final completedFuture = SparkJoyStorage.loadCompleted();
      final allDrafts = await allDraftsFuture;
      final completed = await completedFuture;
      if (_disposed || token != _loadToken) return;
      _drafts = allDrafts.where(_isVisibleDraft).toList();
      _completed = completed;
      _loading = false;
      _safeNotify();
    } catch (_) {
      if (_disposed || token != _loadToken) return;
      _loading = false;
      _loadError = sjT(
        'spark.state.error.reports',
        fallback:
            'Не удалось загрузить отчёты. Проверьте локальные данные и повторите.',
      );
      _safeNotify();
    }
  }

  bool _isVisibleDraft(Map<String, dynamic> draft) {
    if (companyMode) {
      final companyId = sjRead(draft, 'companyId');
      final businessType = sjRead(draft, 'businessType');
      if (companyId.isNotEmpty) return companyId == kSparkCompanyId;
      return businessType == 'company' || businessType == 'ip';
    }

    final assignedSpecialistId = sjRead(
      draft,
      'assignedSpecialistId',
      fallback: sjRead(draft, 'specialistId'),
    );
    if (assignedSpecialistId.isEmpty) return true;
    return assignedSpecialistId == kSparkSpecialistId;
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
