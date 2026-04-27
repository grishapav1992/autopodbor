part of 'spark_joy_create_report_screen.dart';

/// Bottom-sheet picker that supersedes the old chip-wrap +
/// management-mode for inspection tags. One virtualized list mixes
/// system + custom tags (severity shown via a leading dot, custom
/// tags carry an inline delete button). Sticky search filters; if
/// the query has no exact match, two "create" rows appear at the
/// bottom of the list (serious / non-serious).
///
/// Why a sheet instead of inline chips:
///   * Scales to 1000+ tags via `ListView.separated` virtualization.
///   * Re-prioritisation of unselected tags happens out of sight
///     (selected zone is sticky and never reorders).
///   * 56pt rows give finger-friendly tap targets.
///
/// Returns the final selected names on Готово, or `null` if the user
/// dismisses the sheet without confirming. Selection changes also
/// stream out via [onSelectionChanged] on every toggle so the host
/// can fire the co-occurrence-learning refetch in real time.
Future<List<String>?> _showSparkJoyTagPicker(
  BuildContext context, {
  required String title,
  required List<_MediaTagOption> options,
  required List<String> initialSelected,
  List<String> initialOrder = const <String>[],
  required Future<bool> Function(String name, String severity) onCreateCustom,
  required Future<bool> Function(String name) onDeleteCustom,
  required Future<List<String>?> Function(List<String> selected)
  onRefreshOrder,
}) {
  return showModalBottomSheet<List<String>>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => _SparkJoyTagPickerSheet(
      title: title,
      options: options,
      initialSelected: initialSelected,
      initialOrder: initialOrder,
      onCreateCustom: onCreateCustom,
      onDeleteCustom: onDeleteCustom,
      onRefreshOrder: onRefreshOrder,
    ),
  );
}

class _SparkJoyTagPickerSheet extends StatefulWidget {
  const _SparkJoyTagPickerSheet({
    required this.title,
    required this.options,
    required this.initialSelected,
    required this.initialOrder,
    required this.onCreateCustom,
    required this.onDeleteCustom,
    required this.onRefreshOrder,
  });

  final String title;
  final List<_MediaTagOption> options;
  final List<String> initialSelected;
  final List<String> initialOrder;
  final Future<bool> Function(String name, String severity) onCreateCustom;
  final Future<bool> Function(String name) onDeleteCustom;

  /// Fired (debounced inside the sheet) on every selection change.
  /// Caller hits `Storage.GetUserTags` with the current `selectedTagIds`;
  /// the returned list is the new prioritised order of unselected
  /// tags. Returning `null` means "keep current order" (network
  /// failure or no signal). The sheet applies the result to its own
  /// state so the catalog re-orders live during a single session.
  final Future<List<String>?> Function(List<String> selected) onRefreshOrder;

  @override
  State<_SparkJoyTagPickerSheet> createState() =>
      _SparkJoyTagPickerSheetState();
}

class _SparkJoyTagPickerSheetState extends State<_SparkJoyTagPickerSheet> {
  late List<_MediaTagOption> _options;
  late List<String> _selected;
  late List<String> _order;
  final _searchController = TextEditingController();
  String _query = '';
  bool _busy = false;

  // Server-priority refetch is debounced inside the sheet — quick
  // multi-tap shouldn't fan out into N concurrent GetUserTags calls.
  // The seq counter discards stale responses if the user keeps tapping
  // while one fetch is in flight.
  Timer? _refetchDebounce;
  int _refetchSeq = 0;

  // null = "all", otherwise 'serious' | 'minor'. Filters the catalog
  // list (and the create-rows below it) by severity. Does NOT affect
  // the selected-chips row at the top — that one always shows
  // everything the user has picked.
  String? _severityFilter;

  @override
  void initState() {
    super.initState();
    _options = [...widget.options];
    _selected = [...widget.initialSelected];
    _order = [...widget.initialOrder];
    _searchController.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _refetchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    final next = _searchController.text.trim().toLowerCase();
    if (next == _query) return;
    setState(() => _query = next);
  }

  bool _isSelected(String label) {
    final lower = label.toLowerCase();
    return _selected.any((l) => l.toLowerCase() == lower);
  }

  /// Fires the host's `onRefreshOrder` after a 200ms quiet period
  /// since the last toggle. Stale responses (a later tap superseded
  /// this one) are dropped via the seq counter.
  void _scheduleRefetch() {
    _refetchDebounce?.cancel();
    final mySeq = ++_refetchSeq;
    _refetchDebounce = Timer(const Duration(milliseconds: 200), () async {
      final next = await widget.onRefreshOrder(
        List<String>.from(_selected),
      );
      if (!mounted || mySeq != _refetchSeq || next == null) return;
      setState(() => _order = next);
    });
  }

  void _toggle(String label) {
    setState(() {
      final lower = label.toLowerCase();
      if (_isSelected(label)) {
        _selected.removeWhere((l) => l.toLowerCase() == lower);
      } else {
        _selected.add(label);
      }
    });
    HapticFeedback.selectionClick();
    _scheduleRefetch();
  }

  Future<void> _create(String severity) async {
    final raw = _searchController.text.trim();
    if (raw.isEmpty || _busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _busy = true);
    final ok = await widget.onCreateCustom(raw, severity);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось создать тег')),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _options = [
        ..._options,
        _MediaTagOption(label: raw, severity: severity, isCustom: true),
      ];
      if (!_isSelected(raw)) _selected.add(raw);
      _searchController.clear();
      _query = '';
    });
    _scheduleRefetch();
  }

  Future<void> _delete(_MediaTagOption opt) async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить тег?'),
        content: Text('«${opt.label}» будет удалён из вашего каталога.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    final ok = await widget.onDeleteCustom(opt.label);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось удалить тег')),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    final lower = opt.label.toLowerCase();
    setState(() {
      _options = _options
          .where((o) => o.label.toLowerCase() != lower)
          .toList(growable: false);
      _selected.removeWhere((l) => l.toLowerCase() == lower);
    });
    _scheduleRefetch();
  }

  /// Returns options to display in the main list, applying both the
  /// active severity filter and the search query. With an empty query
  /// we honour [_order] when present (server-prioritised), otherwise
  /// the natural options order. With a query we filter by
  /// case-insensitive substring against label.
  List<_MediaTagOption> _filtered() {
    Iterable<_MediaTagOption> pool = _options;
    final severity = _severityFilter;
    if (severity != null) {
      pool = pool.where((o) => o.severity == severity);
    }
    if (_query.isNotEmpty) {
      return pool
          .where((o) => o.label.toLowerCase().contains(_query))
          .toList(growable: false);
    }
    final filtered = pool.toList(growable: false);
    if (_order.isEmpty) return filtered;
    final byLower = <String, _MediaTagOption>{
      for (final o in filtered) o.label.toLowerCase(): o,
    };
    final placed = <String>{};
    final ordered = <_MediaTagOption>[];
    for (final name in _order) {
      final lower = name.toLowerCase();
      final opt = byLower[lower];
      if (opt != null && placed.add(lower)) ordered.add(opt);
    }
    for (final o in filtered) {
      if (placed.add(o.label.toLowerCase())) ordered.add(o);
    }
    return ordered;
  }

  bool _hasExactMatch() {
    if (_query.isEmpty) return true;
    return _options.any((o) => o.label.toLowerCase() == _query);
  }

  /// Selected names sorted serious-first, preserving tap order within
  /// each severity bucket. The underlying [_selected] list keeps the
  /// raw tap order so the host receives it unchanged on Готово — only
  /// the chip-row presentation is regrouped.
  List<({String label, _MediaTagOption opt})> _selectedForDisplay() {
    final byLower = <String, _MediaTagOption>{
      for (final o in _options) o.label.toLowerCase(): o,
    };
    final serious = <({String label, _MediaTagOption opt})>[];
    final minor = <({String label, _MediaTagOption opt})>[];
    for (final label in _selected) {
      final opt = byLower[label.toLowerCase()] ??
          _MediaTagOption(label: label, severity: 'minor');
      if (opt.severity == 'serious') {
        serious.add((label: label, opt: opt));
      } else {
        minor.add((label: label, opt: opt));
      }
    }
    return [...serious, ...minor];
  }

  Color _severityColor(String severity) =>
      severity == 'serious' ? kRedColor : kYellowColor;

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    final filtered = _filtered();
    // Create-rows reflect the active severity filter — if the user
    // scoped the catalog to "Серьёзные", we don't offer to create a
    // non-serious tag below it (and vice versa). With no filter we
    // surface both rows so the user explicitly picks severity.
    final showCreateRows = _query.isNotEmpty && !_hasExactMatch();
    final createSeverities = _severityFilter == null
        ? const <String>['serious', 'minor']
        : <String>[_severityFilter!];

    return FractionallySizedBox(
      heightFactor: 0.9,
      child: Padding(
        padding: EdgeInsets.only(bottom: viewInsets.bottom),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SparkSpace.xl,
                SparkSpace.xs,
                SparkSpace.xs,
                SparkSpace.sm,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: MyText(
                      text: widget.title,
                      size: SparkTextSize.titleLg,
                      weight: FontWeight.w800,
                    ),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => Navigator.of(context).pop(_selected),
                    child: const Text('Готово'),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SparkSpace.xxxl,
                SparkSpace.md,
                SparkSpace.xxxl,
                SparkSpace.sm,
              ),
              child: TextField(
                controller: _searchController,
                decoration: sparkInputDecoration('Поиск тегов…').copyWith(
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: _searchController.clear,
                          tooltip: 'Очистить',
                        ),
                ),
              ),
            ),
            if (_selected.isNotEmpty) _buildSelectedRow(),
            _buildSeverityFilter(),
            const Divider(height: 1),
            Expanded(
              child: filtered.isEmpty && !showCreateRows
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(SparkSpace.xxxl),
                        child: MyText(
                          text:
                              'Ничего не найдено. Введите запрос, чтобы создать новый тег.',
                          size: SparkTextSize.body,
                          color: kGreyColor,
                        ),
                      ),
                    )
                  : ListView.separated(
                      itemCount: filtered.length +
                          (showCreateRows ? createSeverities.length : 0),
                      separatorBuilder: (_, _) =>
                          const Divider(height: 1, indent: 56),
                      itemBuilder: (_, index) {
                        if (index < filtered.length) {
                          return _buildRow(filtered[index]);
                        }
                        return _buildCreateRow(
                          createSeverities[index - filtered.length],
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedRow() {
    // Selected chips are displayed serious-first (then minor). The
    // underlying _selected stays in tap order — only this view sorts.
    final display = _selectedForDisplay();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SparkSpace.xxxl,
        SparkSpace.xs,
        SparkSpace.xxxl,
        SparkSpace.sm,
      ),
      child: SizedBox(
        height: 32,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: EdgeInsets.zero,
          itemCount: display.length,
          separatorBuilder: (_, _) => const SizedBox(width: 6),
          itemBuilder: (_, i) {
            final label = display[i].label;
            final opt = display[i].opt;
            final color = _severityColor(opt.severity);
            return Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(SparkRadius.pill),
                onTap: () => _toggle(label),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SparkSpace.xl,
                    vertical: SparkSpace.xs,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(SparkRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MyText(
                        text: label,
                        size: SparkTextSize.body,
                        weight: FontWeight.w600,
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.close_rounded,
                        size: 14,
                        color: kGreyColor,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSeverityFilter() {
    // Horizontal scroll keeps the row safe when locale-translated
    // labels (or future filter additions) push past the available
    // width. Russian "Незначительные" alone is long enough that on
    // iPhone SE / split-view widths a plain Row overflows.
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        0,
        SparkSpace.xs,
        0,
        SparkSpace.sm,
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: SparkSpace.xxxl),
        child: Row(
          children: [
            _filterPill(label: 'Все', value: null),
            const SizedBox(width: SparkSpace.sm),
            _filterPill(label: 'Серьёзные', value: 'serious'),
            const SizedBox(width: SparkSpace.sm),
            _filterPill(label: 'Незначительные', value: 'minor'),
          ],
        ),
      ),
    );
  }

  Widget _filterPill({required String label, required String? value}) {
    final active = _severityFilter == value;
    final color = value == null ? kSecondaryColor : _severityColor(value);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(SparkRadius.pill),
        onTap: () {
          if (_severityFilter == value) return;
          setState(() => _severityFilter = value);
          HapticFeedback.selectionClick();
        },
        child: ConstrainedBox(
          // ≥36pt — chip-style minimum; below that fingers slip onto
          // the neighbouring pill on quick taps.
          constraints: const BoxConstraints(minHeight: 36),
          child: Container(
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(
              horizontal: SparkSpace.xl,
              vertical: SparkSpace.sm,
            ),
            decoration: BoxDecoration(
              color: active
                  ? color.withValues(alpha: 0.18)
                  : Colors.transparent,
              border: Border.all(
                color: active ? color : kBorderColor,
              ),
              borderRadius: BorderRadius.circular(SparkRadius.pill),
            ),
            child: MyText(
              text: label,
              size: SparkTextSize.caption,
              weight: active ? FontWeight.w700 : FontWeight.w500,
              // Use the regular tertiary text colour (not kGreyColor)
              // so inactive pills read as a real control rather than
              // a passive label.
              color: active ? color : kTertiaryColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(_MediaTagOption opt) {
    final selected = _isSelected(opt.label);
    final color = _severityColor(opt.severity);
    return Material(
      color: selected ? color.withValues(alpha: 0.10) : Colors.transparent,
      child: InkWell(
        onTap: () => _toggle(opt.label),
        onLongPress: opt.isCustom ? () => unawaited(_delete(opt)) : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SparkSpace.xxxl,
              vertical: SparkSpace.xl,
            ),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: SparkSpace.xxxl),
                Expanded(
                  child: MyText(
                    text: opt.label,
                    size: SparkTextSize.body,
                    weight:
                        selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_rounded,
                    size: SparkSize.iconLg,
                  ),
                if (opt.isCustom) ...[
                  const SizedBox(width: SparkSpace.sm),
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: SparkSize.iconMd,
                      color: kGreyColor,
                    ),
                    onPressed: () => unawaited(_delete(opt)),
                    tooltip: 'Удалить тег',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCreateRow(String severity) {
    final query = _searchController.text.trim();
    final color = _severityColor(severity);
    final label = severity == 'serious'
        ? 'Создать как серьёзный: «$query»'
        : 'Создать как незначительный: «$query»';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _busy ? null : () => unawaited(_create(severity)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SparkSpace.xxxl,
              vertical: SparkSpace.xl,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.add_circle_outline_rounded,
                  color: color,
                  size: SparkSize.iconLg,
                ),
                const SizedBox(width: SparkSpace.xxxl),
                Expanded(
                  child: MyText(
                    text: label,
                    size: SparkTextSize.body,
                    color: color,
                    weight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
