part of 'spark_joy_create_report_screen.dart';

extension _SparkJoyCompanyCards on _SparkJoyCreateReportScreenState {
  Widget _carSelectionCard() {
    final carButtonTitle = _carButtonName();
    final carTitle = _carName();
    final carMeta = _carMetaLabel();

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: _openCarPickerDialog,
            borderRadius: BorderRadius.circular(SparkRadius.lg),
            child: Container(
              height: SparkSize.inputHeightLg,
              padding: const EdgeInsets.symmetric(horizontal: SparkSpace.xl),
              decoration: BoxDecoration(
                border: Border.all(color: kBorderColor),
                borderRadius: BorderRadius.circular(SparkRadius.lg),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: MyText(
                      text: carButtonTitle.isEmpty
                          ? 'Выбрать автомобиль'
                          : carButtonTitle,
                      size: SparkTextSize.bodyLg,
                      color: carButtonTitle.isEmpty
                          ? kGreyColor
                          : kTertiaryColor,
                      maxLines: 1,
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: kGreyColor),
                ],
              ),
            ),
          ),
          if (carTitle.isNotEmpty) ...[
            const SizedBox(height: SparkSpace.md),
            _card(
              padding: const EdgeInsets.symmetric(
                horizontal: SparkSpace.lg,
                vertical: SparkSpace.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_carPhotoUrl.trim().isNotEmpty) ...[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(SparkRadius.sm),
                            child: CachedNetworkImage(
                              imageUrl: _carPhotoUrl.trim(),
                              width: double.infinity,
                              height: SparkSize.mediaCardThumb,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) {
                                return Container(
                                  width: double.infinity,
                                  height: SparkSize.mediaCardThumb,
                                  color: kLightGreyColor,
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.directions_car_outlined,
                                    color: kGreyColor,
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: SparkSpace.md),
                        ],
                        MyText(
                          text: carTitle,
                          size: SparkTextSize.body,
                          weight: FontWeight.w700,
                        ),
                        if (carMeta.isNotEmpty) ...[
                          const SizedBox(height: SparkSpace.xxs),
                          MyText(
                            text: carMeta,
                            size: SparkTextSize.caption,
                            color: kGreyColor,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
