part of 'spark_joy_create_report_screen.dart';

extension _SparkJoyReportEditorShell on _SparkJoyCreateReportScreenState {
  Widget _buildReportEditorShell(BuildContext context) {
    final isReadOnly = widget.readOnly;
    final reportTitle = _reportTitle();
    if (!isReadOnly &&
        !_reportNameFocusNode.hasFocus &&
        _inlineReportNameController.text != reportTitle) {
      _inlineReportNameController.value = TextEditingValue(
        text: reportTitle,
        selection: TextSelection.collapsed(offset: reportTitle.length),
      );
    }
    final editingPhotoIntake = !isReadOnly && _editingPhotoIntake;
    return PopScope(
      canPop: isReadOnly ? true : !_editingSection && !editingPhotoIntake,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_editingPhotoIntake) {
          _closePhotoIntake();
          return;
        }
        if (_editingSection) {
          await _handleSectionBack();
        }
      },
      child: SparkPageScaffold(
        appBar: editingPhotoIntake
            ? _photoIntakeAppBar()
            : SparkReportEditorAppBar(
                title: reportTitle,
                titleController: isReadOnly
                    ? null
                    : _inlineReportNameController,
                titleFocusNode: isReadOnly ? null : _reportNameFocusNode,
                meta: sjFormatReportMeta(_currentReportCode(), _createdAt),
                // In read-only mode the save-status pill is meaningless
                // (nothing to save), so we swap it for a neutral
                // "Завершённый отчёт" pill that still explains what the
                // user is looking at.
                draftStatus: isReadOnly
                    ? 'Завершённый отчёт'
                    : _draftSaveStatusText(),
                draftStatusColor: isReadOnly
                    ? kGreenColor
                    : _draftSaveStatusColor(),
                draftStatusIcon: isReadOnly
                    ? Icons.task_alt_rounded
                    : _draftSaveStatusIcon(),
                draftSaving: isReadOnly ? false : _draftSaveInProgress,
                onBack: () => _handleEditorBack(context),
                onShare: isReadOnly
                    ? () => _shareCompletedReport(context)
                    : null,
                sharing: _shareInProgress,
              ),
        scrollController: editingPhotoIntake ? null : _pageScrollController,
        padding: AppSizes.listPaddingWithBottomBar(),
        bottomInset: 0,
        bottomBar: editingPhotoIntake ? _photoIntakeBottomBar() : null,
        children: [
          // ReadOnly = просмотр завершённого отчёта; используем
          // отдельный compact-вид (verdict-баннер не нужен, разделы
          // — раскрывающиеся карточки). Edit-флоу не задет.
          if (isReadOnly)
            _buildSparkJoyCompletedReportView(this)
          else if (editingPhotoIntake)
            _photoIntakeEditor()
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
    if (_editingPhotoIntake) {
      _closePhotoIntake();
      return;
    }
    if (_editingSection) {
      _handleSectionBack();
      return;
    }
    Navigator.of(context).pop();
  }
}
