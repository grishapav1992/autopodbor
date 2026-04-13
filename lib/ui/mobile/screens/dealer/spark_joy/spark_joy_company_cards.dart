part of 'spark_joy_create_report_screen.dart';

extension _SparkJoyCompanyCards on _SparkJoyCreateReportScreenState {
  Widget _staffInviteCard() {
    if (!_hasBusinessStatus()) return const SizedBox.shrink();
    final link = _staffInviteLink.trim();
    final hasLink = link.isNotEmpty;

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.group_add_outlined,
                size: SparkTextSize.title,
                color: kSecondaryColor,
              ),
              SizedBox(width: SparkSpace.sm),
              MyText(
                text: 'Приглашение в штат компании',
                size: SparkTextSize.body,
                weight: FontWeight.w700,
              ),
            ],
          ),
          const SizedBox(height: SparkSpace.sm),
          MyText(
            text: 'Статус: ${_businessStatusLabel()}',
            size: SparkTextSize.caption,
            color: kGreyColor,
          ),
          const SizedBox(height: SparkSpace.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _staffInviteLinkCreating
                      ? null
                      : _generateStaffInviteLink,
                  icon: Icon(
                    hasLink ? Icons.refresh_rounded : Icons.link_rounded,
                    size: SparkTextSize.title,
                  ),
                  label: Text(
                    _staffInviteLinkCreating
                        ? 'Формируем...'
                        : hasLink
                        ? 'Обновить ссылку'
                        : 'Сформировать ссылку',
                  ),
                ),
              ),
              if (hasLink) ...[
                const SizedBox(width: SparkSpace.md),
                SizedBox(
                  height: SparkSize.actionHeightMd,
                  child: OutlinedButton.icon(
                    onPressed: _copyStaffInviteLink,
                    icon: const Icon(
                      Icons.copy_rounded,
                      size: SparkTextSize.title,
                    ),
                    label: const Text('Копия'),
                  ),
                ),
              ],
            ],
          ),
          if (hasLink) ...[
            const SizedBox(height: SparkSpace.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: SparkSpace.lg,
                vertical: SparkSpace.md,
              ),
              decoration: BoxDecoration(
                color: kInputBgColor,
                border: Border.all(color: kBorderColor),
                borderRadius: BorderRadius.circular(SparkRadius.md),
              ),
              child: MyText(
                text: link,
                size: SparkTextSize.caption,
                color: kGreyColor,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _assigneeCard() {
    if (!_hasBusinessStatus()) return const SizedBox.shrink();
    final staff = _companyStaffOptions();
    final currentId = _assignedSpecialistId.trim();
    final currentName = _assignedSpecialistName.trim();
    final hasStaff = staff.isNotEmpty;
    final selectedInList = staff.any(
      (item) => (item['id'] ?? '').toString() == currentId,
    );

    return _card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MyText(
            text: 'Исполнитель из штата',
            size: SparkTextSize.body,
            weight: FontWeight.w700,
          ),
          const SizedBox(height: SparkSpace.md),
          DropdownButtonFormField<String>(
            initialValue: selectedInList ? currentId : '',
            decoration: _fieldDecoration('Выберите сотрудника'),
            items: <DropdownMenuItem<String>>[
              const DropdownMenuItem<String>(
                value: '',
                child: Text('Без исполнителя'),
              ),
              ...staff.map((specialist) {
                final id = (specialist['id'] ?? '').toString();
                final name = (specialist['name'] ?? '').toString();
                return DropdownMenuItem<String>(value: id, child: Text(name));
              }),
            ],
            onChanged: hasStaff
                ? (value) {
                    final id = value ?? '';
                    final specialist = staff.firstWhere(
                      (item) => (item['id'] ?? '').toString() == id,
                      orElse: () => const <String, dynamic>{},
                    );
                    final name = (specialist['name'] ?? '').toString();
                    _setStateSafely(() {
                      _assignedSpecialistId = id;
                      _assignedSpecialistName = name;
                    });
                    _markDraftDirty();
                  }
                : null,
          ),
          const SizedBox(height: SparkSpace.md),
          MyText(
            text: !hasStaff
                ? 'Нет сотрудников в штате. Добавьте через ссылку приглашения ниже.'
                : currentName.isEmpty
                ? 'Исполнитель пока не назначен.'
                : 'Назначен: $currentName',
            size: SparkTextSize.caption,
            color: kGreyColor,
          ),
        ],
      ),
    );
  }

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
                            child: Image.network(
                              _carPhotoUrl.trim(),
                              width: double.infinity,
                              height: SparkSize.mediaCardThumb,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
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
