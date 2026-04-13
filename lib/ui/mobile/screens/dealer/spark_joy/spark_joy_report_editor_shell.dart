part of 'spark_joy_create_report_screen.dart';

extension _SparkJoyReportEditorShell on _SparkJoyCreateReportScreenState {
  Widget _buildReportEditorShell(BuildContext context) {
    return PopScope(
      canPop: !_editingSection,
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
          draftStatus: _draftSaveStatusText(),
          draftStatusColor: _draftSaveStatusColor(),
          onBack: () => _handleEditorBack(context),
          showEditAction: !_editingSection,
          onEdit: _editReportTitle,
        ),
        scrollController: _pageScrollController,
        padding: AppSizes.listPaddingWithBottomBar(),
        bottomInset: 0,
        children: [_editingSection ? _sectionEditor() : _sectionsOverview()],
      ),
    );
  }

  void _handleEditorBack(BuildContext context) {
    if (_editingSection) {
      _handleSectionBack();
      return;
    }
    Navigator.of(context).pop();
  }
}
