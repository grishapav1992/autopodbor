part of 'spark_joy_create_report_screen.dart';

extension _SparkJoyReportEditorShell on _SparkJoyCreateReportScreenState {
  Widget _buildReportEditorShell(BuildContext context) {
    final isReadOnly = widget.readOnly;
    return PopScope(
      canPop: isReadOnly ? true : !_editingSection,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_editingSection) {
          await _handleSectionBack();
        }
      },
      child: SparkPageScaffold(
        appBar: SparkReportEditorAppBar(
          title: _reportTitle(),
          meta: sjFormatReportMeta(_currentReportCode(), _createdAt),
          // In read-only mode the save-status pill is meaningless (nothing
          // to save), so we swap it for a neutral "Завершённый отчёт"
          // pill that still explains what the user is looking at.
          draftStatus: isReadOnly
              ? 'Завершённый отчёт'
              : _draftSaveStatusText(),
          draftStatusColor: isReadOnly ? kGreenColor : _draftSaveStatusColor(),
          draftStatusIcon: isReadOnly
              ? Icons.task_alt_rounded
              : _draftSaveStatusIcon(),
          draftSaving: isReadOnly ? false : _draftSaveInProgress,
          onBack: () => _handleEditorBack(context),
          showEditAction: !isReadOnly && !_editingSection,
          onEdit: _editReportTitle,
          onShare: isReadOnly ? () => _shareCompletedReport(context) : null,
          sharing: _shareInProgress,
        ),
        scrollController: _pageScrollController,
        padding: AppSizes.listPaddingWithBottomBar(),
        bottomInset: 0,
        children: [
          // ReadOnly = просмотр завершённого отчёта; используем
          // отдельный compact-вид (verdict-баннер не нужен, разделы
          // — раскрывающиеся карточки). Edit-флоу не задет.
          if (isReadOnly)
            _buildSparkJoyCompletedReportView(this)
          else if (_editingSection)
            _sectionEditor()
          else
            _sectionsOverview(),
        ],
      ),
    );
  }

  void _handleEditorBack(BuildContext context) {
    // Read-only view has no overview fallback — back always pops the route
    // directly, so «Назад» behaves like a close button the way users
    // expect from a finalised report screen.
    if (widget.readOnly) {
      Navigator.of(context).pop();
      return;
    }
    if (_editingSection) {
      _handleSectionBack();
      return;
    }
    Navigator.of(context).pop();
  }
}
