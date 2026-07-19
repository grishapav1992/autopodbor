part of 'spark_joy_create_report_screen.dart';

/// Карточка «Материалы автомобиля» на обзоре разделов (макет «Отчёт - разделы -
/// редизайн», экраны 1a/2b): точка входа в массовую ИИ-загрузку материалов.
/// Три состояния из снапшота [SparkJoyIntakeUploadService]:
///  - пусто — призыв загрузить все материалы одной пачкой + кнопка;
///  - идёт загрузка — «Загрузка файлов · N из M» + процент + прогресс-бар;
///  - загружено/добавлено — счётчик + подсказка о будущей ИИ-раскладке.
extension _SparkJoyPhotoIntakeCard on _SparkJoyCreateReportScreenState {
  Widget _photoIntakeCard() {
    return ValueListenableBuilder<SparkIntakeSnapshot>(
      valueListenable: SparkJoyIntakeUploadService.instance.watch(_draftId),
      builder: (context, snapshot, _) {
        final Widget body = switch (snapshot.phase) {
          SparkIntakePhase.idle => _photoIntakeEmptyBody(),
          SparkIntakePhase.uploading => _photoIntakeProgressBody(snapshot),
          SparkIntakePhase.classifying => _photoIntakeAiProgressBody(snapshot),
          _ => _photoIntakeSummaryBody(snapshot),
        };
        return SparkCard(
          radius: SparkRadius.md,
          onTap: snapshot.phase == SparkIntakePhase.idle
              ? null
              : _openPhotoIntake,
          child: body,
        );
      },
    );
  }

  Widget _photoIntakeCardHeader({Widget? trailing, required String subtitle}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: SparkSize.avatarSm,
          height: SparkSize.avatarSm,
          decoration: BoxDecoration(
            color: kSecondaryColor,
            borderRadius: BorderRadius.circular(SparkRadius.md),
          ),
          alignment: Alignment.center,
          child: const Icon(
            Icons.auto_awesome,
            color: kWhiteColor,
            size: SparkSize.iconLg,
          ),
        ),
        const SizedBox(width: SparkSpace.xl),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MyText(
                text: 'Материалы автомобиля',
                size: SparkTextSize.sectionTitle,
                weight: FontWeight.w700,
                color: kTertiaryColor,
              ),
              const SizedBox(height: SparkSpace.xxs),
              MyText(
                text: subtitle,
                size: SparkTextSize.body,
                color: kGreyColor,
                lineHeight: 1.35,
              ),
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: SparkSpace.md),
          trailing,
        ],
      ],
    );
  }

  Widget _photoIntakeEmptyBody() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _photoIntakeCardHeader(
          subtitle:
              'Загрузите фото, видео и документы одной пачкой — '
              'ИИ распределит их по разделам отчёта',
        ),
        const SizedBox(height: SparkSpace.xl),
        _sparkIntakeDashedButton(
          icon: Icons.add_photo_alternate_outlined,
          label: 'Загрузить материалы',
          height: 44,
          onTap: _openPhotoIntake,
        ),
      ],
    );
  }

  Widget _photoIntakeProgressBody(SparkIntakeSnapshot snapshot) {
    final percent = (snapshot.progress * 100).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _photoIntakeCardHeader(
          subtitle:
              'Загрузка файлов · ${snapshot.uploadedCount} из ${snapshot.total}',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              MyText(
                text: '$percent%',
                size: SparkTextSize.bodyLg,
                weight: FontWeight.w700,
                color: kSecondaryColor,
              ),
              const SizedBox(width: SparkSpace.md),
              _photoIntakeCardCancelIcon(),
            ],
          ),
        ),
        const SizedBox(height: SparkSpace.md),
        ClipRRect(
          borderRadius: BorderRadius.circular(SparkRadius.pill),
          child: LinearProgressIndicator(
            value: snapshot.progress,
            minHeight: 6,
            backgroundColor: kLightGreyColor,
            valueColor: const AlwaysStoppedAnimation<Color>(kSecondaryColor),
          ),
        ),
        const SizedBox(height: SparkSpace.md),
        MyText(
          text:
              'Загрузка идёт в фоне — можно заполнять другие разделы. '
              'После загрузки ИИ распределит материалы по разделам отчёта',
          size: SparkTextSize.caption,
          color: kGreyColor,
          lineHeight: 1.4,
        ),
      ],
    );
  }

  Widget _photoIntakeSummaryBody(SparkIntakeSnapshot snapshot) {
    final failed = snapshot.failedCount;
    final String subtitle;
    final String hint;
    if (snapshot.phase == SparkIntakePhase.done) {
      subtitle = 'Загружено · ${sparkIntakeFilesCountLabel(snapshot.total)}';
      hint = snapshot.total == 0
          ? 'Все оригиналы распределены по отчёту'
          : 'Неуверенно распознанные файлы остались здесь';
    } else if (snapshot.phase == SparkIntakePhase.failed) {
      subtitle =
          'Загружено ${snapshot.uploadedCount} из ${snapshot.total} · '
          '$failed с ошибкой';
      hint = 'Продолжим автоматически, когда появится сеть';
    } else {
      // staged: файлы добавлены, «Распределить файлы» ещё не нажимали.
      subtitle = 'Файлы добавлены · ${snapshot.total}';
      hint = 'Откройте, чтобы загрузить их в облако';
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _photoIntakeCardHeader(
          subtitle: subtitle,
          trailing: snapshot.phase == SparkIntakePhase.failed
              ? const Icon(
                  Icons.error_outline_rounded,
                  color: kRedColor,
                  size: SparkSize.iconLg,
                )
              : const Icon(
                  Icons.chevron_right_rounded,
                  color: kGreyColor,
                  size: SparkSize.iconLg,
                ),
        ),
        const SizedBox(height: SparkSpace.md),
        MyText(
          text: hint,
          size: SparkTextSize.caption,
          color: kGreyColor,
          lineHeight: 1.4,
        ),
      ],
    );
  }

  Widget _photoIntakeAiProgressBody(SparkIntakeSnapshot snapshot) {
    final total = snapshot.aiTotal;
    final completed = snapshot.aiClassified;
    final progress = total == 0 ? null : completed / total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _photoIntakeCardHeader(
          subtitle: 'ИИ распределяет · $completed из $total',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: SparkSize.iconLg,
                height: SparkSize.iconLg,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
              const SizedBox(width: SparkSpace.md),
              _photoIntakeCardCancelIcon(),
            ],
          ),
        ),
        const SizedBox(height: SparkSpace.md),
        ClipRRect(
          borderRadius: BorderRadius.circular(SparkRadius.pill),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 6,
            backgroundColor: kLightGreyColor,
            valueColor: const AlwaysStoppedAnimation<Color>(kSecondaryColor),
          ),
        ),
        const SizedBox(height: SparkSpace.md),
        const MyText(
          text:
              'Можно продолжать заполнять отчёт — оригиналы добавятся в '
              '«Материалы проверки» и элементы «Осмотра» автоматически.',
          size: SparkTextSize.caption,
          color: kGreyColor,
          lineHeight: 1.4,
        ),
      ],
    );
  }

  /// Компактный крестик «прервать» в шапке прогресс-состояний карточки.
  /// Вложенный IconButton выигрывает жест у InkWell карточки, так что тап
  /// по крестику не открывает интейк.
  Widget _photoIntakeCardCancelIcon() {
    return IconButton(
      onPressed: () => unawaited(_confirmAndCancelIntake()),
      icon: const Icon(
        Icons.close_rounded,
        color: kRedColor,
        size: SparkSize.iconLg,
      ),
      tooltip: 'Прервать загрузку',
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
    );
  }
}

/// Пунктирная кнопка-зона в стиле макета (dashed border, лёгкая заливка).
Widget _sparkIntakeDashedButton({
  required IconData icon,
  required String label,
  required VoidCallback onTap,
  double height = 64,
  bool vertical = false,
}) {
  final content = vertical
      ? Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: kSecondaryColor, size: SparkSize.iconXl),
            const SizedBox(height: SparkSpace.xs),
            MyText(
              text: label,
              size: SparkTextSize.body,
              weight: FontWeight.w700,
              color: kSecondaryColor,
            ),
          ],
        )
      : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: kSecondaryColor, size: SparkSize.iconLg),
            const SizedBox(width: SparkSpace.md),
            MyText(
              text: label,
              size: SparkTextSize.label,
              weight: FontWeight.w700,
              color: kSecondaryColor,
            ),
          ],
        );
  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(SparkRadius.md),
      child: DottedBorder(
        borderType: BorderType.RRect,
        radius: const Radius.circular(SparkRadius.md),
        color: kSecondaryColor.withValues(alpha: 0.35),
        strokeWidth: 1.5,
        dashPattern: const [6, 4],
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: kSecondaryColor.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(SparkRadius.md),
          ),
          child: Center(child: content),
        ),
      ),
    ),
  );
}
