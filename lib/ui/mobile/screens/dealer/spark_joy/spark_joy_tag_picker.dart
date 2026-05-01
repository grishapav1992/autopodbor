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

  // 'serious' | 'minor'. The catalog is always scoped to one
  // severity at a time — the segmented control at the top swaps
  // between them. Does NOT affect the selected-chips row, which
  // always shows everything the user has picked across both segments.
  String _severityFilter = 'serious';

  // Settings mode is the canonical add/delete affordance: a gear
  // toggle in the header reveals the "+ Добавить" CTA at the top of
  // the list and shows the inline delete ✕ on every custom row.
  // Out of settings mode the picker reads as a clean selection-only
  // surface — no destructive icons, no extra rows.
  bool _settingsMode = false;
  final FocusNode _searchFocusNode = FocusNode();

  // Inline create flow — tapping the "+ Добавить" CTA replaces the
  // row in-place with a TextField + «Создать» action so the user
  // never gets bounced to the search bar.
  bool _addInputOpen = false;
  final TextEditingController _addController = TextEditingController();
  final FocusNode _addFocusNode = FocusNode();

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
    _searchFocusNode.dispose();
    _addController.dispose();
    _addFocusNode.dispose();
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

  void _openAddInput() {
    setState(() => _addInputOpen = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _addFocusNode.requestFocus();
    });
  }

  void _closeAddInput() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _addInputOpen = false;
      _addController.clear();
    });
  }

  /// Inline create — driven by the dedicated _addController so the
  /// search bar stays untouched. Severity is taken from the active
  /// segmented filter (the user's already in the right context).
  Future<void> _submitAdd() async {
    final raw = _addController.text.trim();
    if (raw.isEmpty || _busy) return;
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _busy = true);
    final ok = await widget.onCreateCustom(raw, _severityFilter);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось создать повреждение')),
      );
      return;
    }
    HapticFeedback.mediumImpact();
    setState(() {
      _options = [
        ..._options,
        _MediaTagOption(
          label: raw,
          severity: _severityFilter,
          isCustom: true,
        ),
      ];
      if (!_isSelected(raw)) _selected.add(raw);
      _addController.clear();
      _addInputOpen = false;
    });
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
        const SnackBar(content: Text('Не удалось создать повреждение')),
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
    setState(() => _busy = true);
    final ok = await widget.onDeleteCustom(opt.label);
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось удалить повреждение')),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('«${opt.label}» удалено'),
        duration: const Duration(seconds: 2),
      ),
    );
    _scheduleRefetch();
  }

  /// Returns options to display in the main list, applying both the
  /// active severity filter and the search query. With an empty query
  /// we honour [_order] when present (server-prioritised), otherwise
  /// the natural options order. With a query we filter by
  /// case-insensitive substring against label.
  List<_MediaTagOption> _filtered() {
    Iterable<_MediaTagOption> pool =
        _options.where((o) => o.severity == _severityFilter);
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

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets;
    final filtered = _filtered();
    // Create-row inherits the active severity from the segmented
    // control: with "Серьёзные" active, the no-match query offers
    // "Создать серьёзное повреждение" (and vice versa). Single row,
    // not a choice — the severity is already explicit above.
    final showCreateRow = _query.isNotEmpty && !_hasExactMatch();

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
              // В шапке оставлены только заголовок sheet'а и
              // шестерёнка. «Готово» переехало в фиксированный
              // bottom action bar — иначе пользователь, создавая
              // новый тег, мог тапнуть «Готово» вместо «Добавить»
              // (которые сидели рядом) и потерять введённый текст.
              child: Row(
                children: [
                  Expanded(
                    child: MyText(
                      text: widget.title,
                      size: SparkTextSize.titleLg,
                      weight: FontWeight.w800,
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _settingsMode
                          ? Icons.check_rounded
                          : Icons.tune_rounded,
                      color: _settingsMode
                          ? kSecondaryColor
                          : kGreyColor,
                    ),
                    tooltip: _settingsMode
                        ? 'Завершить настройку'
                        : 'Настройки',
                    onPressed: _busy
                        ? null
                        : () {
                            setState(() {
                              _settingsMode = !_settingsMode;
                              if (!_settingsMode) {
                                _addInputOpen = false;
                                _addController.clear();
                              }
                            });
                          },
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
                focusNode: _searchFocusNode,
                decoration: sparkInputDecoration('Поиск повреждений…').copyWith(
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
              child: Column(
                children: [
                  // Settings-mode add CTA. AnimatedSize keeps the
                  // appearance/disappearance smooth — no jarring
                  // jump when toggling the gear.
                  AnimatedSize(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    alignment: Alignment.topCenter,
                    child: _settingsMode
                        ? _buildAddCta()
                        : const SizedBox(width: double.infinity),
                  ),
                  if (_settingsMode)
                    const Divider(height: 1, indent: SparkSpace.xxxl),
                  Expanded(
                    child: filtered.isEmpty && !showCreateRow
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(SparkSpace.xxxl),
                              child: MyText(
                                text:
                                    'Ничего не найдено. Введите запрос, чтобы создать новое повреждение.',
                                size: SparkTextSize.body,
                                color: kGreyColor,
                              ),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length + (showCreateRow ? 1 : 0),
                            separatorBuilder: (_, _) => const Divider(
                              height: 1,
                              indent: SparkSpace.xxxl,
                            ),
                            itemBuilder: (_, index) {
                              if (index < filtered.length) {
                                return _buildRow(filtered[index]);
                              }
                              return _buildCreateRow(_severityFilter);
                            },
                          ),
                  ),
                ],
              ),
            ),
            // Bottom action bar — фиксированный footer с «Готово».
            // Если у пользователя в `_addController` остался не
            // закоммиченный новый тег, мы сначала молча сохраняем
            // его (auto-commit), и только потом закрываем sheet —
            // меньше трения, никакой потери введённого текста.
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                SparkSpace.xxxl,
                SparkSpace.md,
                SparkSpace.xxxl,
                SparkSpace.md,
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(SparkSize.actionHeight),
                    backgroundColor: kSecondaryColor,
                    foregroundColor: kWhiteColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(SparkRadius.lg),
                    ),
                  ),
                  onPressed: _busy
                      ? null
                      : () async {
                          final pending = _addController.text.trim();
                          final navigator = Navigator.of(context);
                          if (pending.isNotEmpty) {
                            await _submitAdd();
                            if (!mounted) return;
                          }
                          navigator.pop(_selected);
                        },
                  child: const Text(
                    'Готово',
                    style: TextStyle(
                      fontSize: SparkTextSize.label,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
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
            // Neutral chip — severity is already implied by the
            // grouping (serious-first) and irrelevant for re-tap-to-
            // remove. No coloured tint.
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
                    color: kLightGreyColor,
                    borderRadius: BorderRadius.circular(SparkRadius.pill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      MyText(
                        text: label,
                        size: SparkTextSize.label,
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
    // Material's SegmentedButton is the native pattern for a
    // mutually-exclusive two-segment switch — built-in keyboard /
    // screen-reader semantics, automatic platform tinting, no need
    // to roll our own state. Two short Russian labels ("Серьёзные" /
    // "Незначительные") fit comfortably even on iPhone SE.
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SparkSpace.xxxl,
        SparkSpace.xs,
        SparkSpace.xxxl,
        SparkSpace.sm,
      ),
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<String>(
          segments: const [
            ButtonSegment<String>(
              value: 'serious',
              label: Text('Серьёзные'),
            ),
            ButtonSegment<String>(
              value: 'minor',
              label: Text('Незначительные'),
            ),
          ],
          selected: {_severityFilter},
          showSelectedIcon: false,
          onSelectionChanged: (selection) {
            if (selection.isEmpty) return;
            final next = selection.first;
            if (next == _severityFilter) return;
            setState(() => _severityFilter = next);
            HapticFeedback.selectionClick();
          },
        ),
      ),
    );
  }

  Widget _buildRow(_MediaTagOption opt) {
    final selected = _isSelected(opt.label);
    final showDelete = _settingsMode && opt.isCustom;
    // Selection signal is intentionally minimal: bold label + leading
    // check icon. No coloured tint, no severity dot — severity is
    // already conveyed by the segmented control above the list.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _toggle(opt.label),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SparkSpace.xxxl,
              vertical: SparkSpace.xl,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: SparkSize.iconLg,
                  child: selected
                      ? const Icon(
                          Icons.check_rounded,
                          size: SparkSize.iconLg,
                          color: kSecondaryColor,
                        )
                      : null,
                ),
                const SizedBox(width: SparkSpace.xl),
                Expanded(
                  child: MyText(
                    text: opt.label,
                    size: SparkTextSize.label,
                    weight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: kTertiaryColor,
                  ),
                ),
                // Trailing slot is always reserved (32pt) so toggling
                // the gear doesn't shift the label's right edge. Only
                // the rendered widget swaps in/out.
                SizedBox(
                  width: 32,
                  height: 32,
                  child: showDelete
                      ? IconButton(
                          icon: const Icon(
                            Icons.close_rounded,
                            size: SparkSize.iconMd,
                            color: kGreyColor,
                          ),
                          onPressed: () => unawaited(_delete(opt)),
                          tooltip: 'Удалить повреждение',
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 32,
                            minHeight: 32,
                          ),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddCta() {
    return _addInputOpen ? _buildAddInput() : _buildAddCtaRow();
  }

  Widget _buildAddCtaRow() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _busy ? null : _openAddInput,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: SparkSpace.xxxl,
              vertical: SparkSpace.xl,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.add_rounded,
                  color: kSecondaryColor,
                  size: SparkSize.iconLg,
                ),
                const SizedBox(width: SparkSpace.xl),
                const Expanded(
                  child: MyText(
                    text: 'Добавить повреждение',
                    size: SparkTextSize.label,
                    color: kSecondaryColor,
                    weight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAddInput() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SparkSpace.xxxl,
        SparkSpace.md,
        SparkSpace.md,
        SparkSpace.md,
      ),
      child: Row(
        children: [
          const Icon(
            Icons.add_rounded,
            color: kSecondaryColor,
            size: SparkSize.iconLg,
          ),
          const SizedBox(width: SparkSpace.xl),
          Expanded(
            child: TextField(
              controller: _addController,
              focusNode: _addFocusNode,
              textInputAction: TextInputAction.done,
              autofocus: true,
              maxLength: 255,
              decoration: sparkInputDecoration(
                _severityFilter == 'serious'
                    ? 'Серьёзное повреждение'
                    : 'Незначительное повреждение',
              ).copyWith(
                isDense: true,
                counterText: '',
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: SparkSpace.md,
                  vertical: SparkSpace.md,
                ),
              ),
              style: const TextStyle(fontSize: SparkTextSize.label),
              onSubmitted: (_) => unawaited(_submitAdd()),
            ),
          ),
          const SizedBox(width: SparkSpace.sm),
          TextButton(
            onPressed: _busy ? null : () => unawaited(_submitAdd()),
            child: const Text('Создать'),
          ),
          IconButton(
            tooltip: 'Отмена',
            icon: const Icon(Icons.close_rounded, color: kGreyColor),
            onPressed: _busy ? null : _closeAddInput,
          ),
        ],
      ),
    );
  }

  Widget _buildCreateRow(String severity) {
    final query = _searchController.text.trim();
    final adjective = severity == 'serious' ? 'серьёзное' : 'незначительное';
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
                const Icon(
                  Icons.add_circle_outline_rounded,
                  color: kSecondaryColor,
                  size: SparkSize.iconLg,
                ),
                const SizedBox(width: SparkSpace.xl),
                Expanded(
                  child: MyText(
                    text: 'Создать $adjective повреждение: «$query»',
                    size: SparkTextSize.label,
                    color: kSecondaryColor,
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
