part of 'spark_joy_create_report_screen.dart';

extension _SparkJoyMediaHelpersMethods on _SparkJoyCreateReportScreenState {
  Future<bool> _openMediaInspectionEditor({
    required String groupKey,
    required int index,
    List<int>? applyToIndexes,
    bool saveDraftOnClose = true,
  }) => _runOpenMediaInspectionEditor(
    groupKey: groupKey,
    index: index,
    applyToIndexes: applyToIndexes,
    saveDraftOnClose: saveDraftOnClose,
  );

  Future<void> _openMediaGroupLightbox({
    required String groupKey,
    required int initialIndex,
  }) => _runOpenMediaGroupLightbox(
    groupKey: groupKey,
    initialIndex: initialIndex,
  );

  /// Opens the lightbox with a pre-flattened list of files that may span
  /// several media groups. Each `groupKeyPerFile[i]` provides the section
  /// context used for element labels / no-damage copy / tag colors for
  /// the i-th file. The edit-note affordance is hidden because a flat
  /// list has no single group to route back to.
  Future<void> _openFlatMediaLightbox({
    required List<UploadedItem> files,
    required List<String> groupKeyPerFile,
    required int initialIndex,
  }) => _runOpenMediaGroupLightbox(
    groupKey: groupKeyPerFile.isNotEmpty ? groupKeyPerFile.first : '',
    initialIndex: initialIndex,
    filesOverride: files,
    groupKeyPerFile: groupKeyPerFile,
  );

  Widget _mediaGroupListRow(MediaGroupState state) =>
      _runMediaGroupListRow(state);

  Widget _mediaMetaPill({
    required IconData icon,
    required String text,
    required Color color,
  }) => _runMediaMetaPill(icon: icon, text: text, color: color);

  Widget _mediaGroupEditor() => _runMediaGroupEditor();
}
