part of 'spark_joy_create_report_screen.dart';

extension _SparkJoyMediaHelpersMethods on _SparkJoyCreateReportScreenState {
  Widget _chip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    required Color selectedColor,
  }) {
    return SparkSelectableChip(
      text: label,
      selected: selected,
      selectedColor: selectedColor,
      onTap: () {
        onTap();
        _markDraftDirty();
      },
    );
  }

  Widget _tagReorderProxyDecorator(
    Widget child,
    int index,
    Animation<double> animation,
  ) {
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, proxyChild) {
        final t = Curves.easeOutCubic.transform(animation.value);
        return Transform.scale(
          scale: 1 + (0.035 * t),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(SparkRadius.md),
              border: Border.all(
                color: kSecondaryColor.withValues(alpha: 0.32),
              ),
              boxShadow: [
                BoxShadow(
                  color: kSecondaryColor.withValues(alpha: 0.12 + (0.12 * t)),
                  blurRadius: 10 + (4 * t),
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(SparkRadius.md),
              child: Material(color: Colors.transparent, child: proxyChild),
            ),
          ),
        );
      },
    );
  }

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

  Widget _mediaGroupListRow(MediaGroupState state) =>
      _runMediaGroupListRow(state);

  Widget _mediaMetaPill({
    required IconData icon,
    required String text,
    required Color color,
  }) => _runMediaMetaPill(icon: icon, text: text, color: color);

  Widget _mediaGroupEditor() => _runMediaGroupEditor();
}
