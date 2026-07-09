part of 'spark_joy_create_report_screen.dart';

extension _SparkJoyVehicleRulesMethods on _SparkJoyCreateReportScreenState {
  bool _isVehicleReadyForContinue() {
    // «или» в карточке идентификаторов: VIN и госномер взаимозаменяемы как ключ
    // авто, поэтому валидный госномер тоже разблокирует переход (иначе надпись
    // «или» обманывает — заполнил только госномер, а «Продолжить» требует VIN).
    if (_vinUnreadable || _vinController.text.trim().isNotEmpty) return true;
    final plate = _plateController.text.trim();
    return plate.isNotEmpty && plateError(plate, _plateFormat) == null;
  }

  Future<Map<String, dynamic>?> _findDuplicateVinDraft() async {
    final normalizedVin = _sanitizeVin(_vinController.text.trim());
    if (normalizedVin.isEmpty || _vinUnreadable) return null;

    final drafts = await SparkJoyStorage.loadDrafts();
    for (final draft in drafts) {
      final draftId = (draft['id'] ?? '').toString();
      if (draftId.isEmpty || draftId == _draftId) continue;
      final draftVin = _sanitizeVin((draft['vin'] ?? '').toString());
      if (draftVin.isEmpty) continue;
      if (draftVin == normalizedVin) return draft;
    }
    return null;
  }

  Future<bool?> _showDuplicateVinDialog(Map<String, dynamic> draft) {
    final duplicateVin = (draft['vin'] ?? '').toString().trim();
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(SparkRadius.xl),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              SparkSpace.xxxl,
              SparkSpace.xxxl,
              SparkSpace.xxxl,
              SparkSpace.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const MyText(
                  text: 'Черновик с таким VIN уже есть',
                  size: SparkTextSize.title,
                  weight: FontWeight.w700,
                ),
                const SizedBox(height: SparkSpace.md),
                MyText(
                  text:
                      'Найден незавершённый отчёт с VIN $duplicateVin. Хотите продолжить его или заполнить новый?',
                  size: SparkTextSize.body,
                  color: kGreyColor,
                ),
                const SizedBox(height: SparkSpace.xl),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text('Заполнить заново'),
                      ),
                    ),
                    const SizedBox(width: SparkSpace.md),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Продолжить'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
