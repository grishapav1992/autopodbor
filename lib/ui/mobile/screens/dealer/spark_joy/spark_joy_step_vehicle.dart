part of 'spark_joy_create_report_screen.dart';

Widget _buildSparkJoyStepVehicle(
  _SparkJoyCreateReportScreenState s, {
  required void Function(VoidCallback fn) setStateFn,
  required List<String> ownersCounts,
}) {
  final vinError = s._vinError();
  final plateError = s._plateError();

  // P2: один раз подтянуть право run_legal_review (для кнопок «Определить»).
  unawaited(s._ensureLegalReviewMeta());

  return Column(
    children: [
      // Единая карточка идентификаторов: VIN + «или» + госномер.
      // Заголовок секции и легенда обязательности убраны (2026-07-10) —
      // шаг начинается сразу с карточки, смысл полей ясен из лейблов.
      s._card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MyText(
              text: 'VIN-номер',
              size: SparkTextSize.body,
              weight: FontWeight.w700,
              requiredMark: true,
            ),
            const SizedBox(height: SparkSpace.md),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: s._vinController,
                    focusNode: s._vinFocusNode,
                    maxLength: 17,
                    // Моноширинный: в КАПС-VIN цифры и буквы становятся одной
                    // высоты (у системного SF цифры ниже заглавных букв).
                    style: TextStyle(
                      fontFamily: AppFonts.MONOSPACE,
                      fontSize: 16,
                      letterSpacing: 0.5,
                      color: kTertiaryColor,
                    ),
                    textInputAction: TextInputAction.next,
                    onSubmitted: (_) {
                      FocusScope.of(s.context).requestFocus(s._plateFocusNode);
                    },
                    onTapOutside: (_) => s._dismissKeyboard(),
                    onChanged: (value) {
                      final sanitized = s._sanitizeVin(value);
                      // Ручной ввод VIN гасит legacy-флаг «нечитаемый»
                      // (галочки в UI больше нет, но флаг мог приехать из
                      // старого черновика и отображаться в сводке).
                      if (sanitized.isNotEmpty && s._vinUnreadable) {
                        s._vinUnreadable = false;
                      }
                      if (sanitized == value) {
                        setStateFn(() {});
                        return;
                      }
                      s._vinController.value = TextEditingValue(
                        text: sanitized,
                        selection: TextSelection.collapsed(
                          offset: sanitized.length,
                        ),
                      );
                      setStateFn(() {});
                    },
                    decoration: s
                        ._fieldDecoration('XW7BF4FK10S012345')
                        .copyWith(counterText: ''),
                  ),
                ),
                const SizedBox(width: SparkSpace.md),
                SizedBox(
                  width: 52,
                  height: 52,
                  child: OutlinedButton(
                    // Объединённое автозаполнение: одно фото СТС/ПТС → OCR +
                    // ИИ (VIN, госномер, марка/модель и пр.).
                    onPressed: (s._docScanBusy || s.widget.readOnly)
                        ? null
                        : () => unawaited(s._openAutofillScan()),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      side: const BorderSide(color: kBorderColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(SparkRadius.lg),
                      ),
                    ),
                    child: s._docScanBusy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.document_scanner_outlined),
                  ),
                ),
              ],
            ),
            // Галочка «Нечитабельный VIN» убрана (2026-07-10, решение
            // Григория): VIN всегда обязателен. Поле _vinUnreadable живёт
            // только для совместимости со старыми черновиками.
            if (vinError != null) ...[
              const SizedBox(height: SparkSpace.sm),
              MyText(
                text: vinError,
                size: SparkTextSize.caption,
                color: kRedColor,
              ),
            ],
            // Поле госномера идёт сразу за VIN — без разделителя «или» и
            // без лейбла (2026-07-10). Страна — отдельной кнопкой справа
            // от поля, в одном стиле с кнопкой скана у VIN.
            const SizedBox(height: SparkSpace.lg),
            Row(
              children: [
                Expanded(
                  child: Focus(
                    onFocusChange: (hasFocus) {
                      // Помечаем blur — после первого ухода с поля включается
                      // показ ошибки валидации формата (для известных стран).
                      if (!hasFocus && !s._plateBlurred) {
                        setStateFn(() => s._plateBlurred = true);
                      }
                    },
                    child: TextField(
                      controller: s._plateController,
                      focusNode: s._plateFocusNode,
                      // 14 = max formatted length across all formats
                      // (UA "АА 1234 АА" = 10 / BY "1234АА-7" = 8; РФ теперь
                      // слитно, максимум 9).
                      maxLength: 14,
                      textInputAction: TextInputAction.next,
                      onSubmitted: (_) {
                        FocusScope.of(
                          s.context,
                        ).requestFocus(s._adLinkFocusNode);
                      },
                      onTapOutside: (_) => s._dismissKeyboard(),
                      onChanged: (value) {
                        // Auto-mode: permissive sanitize (Cyr+Lat+digits, до 14)
                        // → детект страны → если матч, переключаемся на формат
                        // и применяем его раскладку. Если не определилось —
                        // остаёмся в `other` (без раскладки), кнопка страны
                        // покажет «?».
                        // Locked-mode: sanitize/format строго под выбранную
                        // страну (RU→KZ выкидывает кириллицу и т.п.).
                        String formatted;
                        if (s._plateCountryLocked) {
                          final sanitized = s._sanitizePlate(value);
                          formatted = s._formatPlate(sanitized);
                        } else {
                          final permissive = sanitizePlatePermissive(value);
                          final detected = detectPlateCountry(permissive);
                          final nextCountry = detected ?? PlateCountry.other;
                          if (nextCountry != s._plateCountry) {
                            s._plateCountry = nextCountry;
                          }
                          if (detected != null) {
                            final fmt = plateFormatFor(detected);
                            final sanitized = sanitizePlate(permissive, fmt);
                            formatted = formatPlate(sanitized, fmt);
                          } else {
                            formatted = permissive;
                          }
                        }
                        if (formatted != value) {
                          s._plateController.value = TextEditingValue(
                            text: formatted,
                            selection: TextSelection.collapsed(
                              offset: formatted.length,
                            ),
                            composing: TextRange.empty,
                          );
                        }
                        setStateFn(() {});
                      },
                      textCapitalization: TextCapitalization.characters,
                      autocorrect: false,
                      enableSuggestions: false,
                      textAlign: TextAlign.center,
                      decoration: s
                          ._fieldDecoration(_plateInputHint(s))
                          .copyWith(
                            counterText: '',
                            fillColor: kLightGreyColor,
                            // Компактный hint: дефолтные 16px в узком поле
                            // обрезались в «…».
                            hintStyle: const TextStyle(
                              fontSize: SparkTextSize.bodyLg,
                              color: kGreyColor,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                    ),
                  ),
                ),
                const SizedBox(width: SparkSpace.md),
                // Кнопка страны: флаг + chevron, тап → bottom sheet со
                // списком стран и пунктом «Автоматически». Когда детектор
                // не определил страну — «?».
                SizedBox(
                  width: 52,
                  height: 52,
                  child: OutlinedButton(
                    onPressed: () => unawaited(
                      s._showPlateCountryPicker(s.context, setStateFn),
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      side: const BorderSide(color: kBorderColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(SparkRadius.lg),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _plateInputFlag(s),
                          style: const TextStyle(fontSize: 18),
                        ),
                        const Icon(
                          Icons.expand_more_rounded,
                          size: 14,
                          color: kTertiaryColor,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (plateError != null) ...[
              const SizedBox(height: SparkSpace.sm),
              MyText(
                text: plateError,
                size: SparkTextSize.caption,
                color: kRedColor,
              ),
            ],
            if (s._vinLookupInfo.isNotEmpty) ...[
              const SizedBox(height: SparkSpace.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(SparkSpace.md),
                decoration: BoxDecoration(
                  color: kLightGreyColor,
                  borderRadius: BorderRadius.circular(SparkRadius.md),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const MyText(
                      text: 'Найденная информация',
                      size: SparkTextSize.caption,
                      weight: FontWeight.w700,
                    ),
                    const SizedBox(height: SparkSpace.sm),
                    ...s._vinLookupInfo.entries.map(
                      (e) => Padding(
                        padding: const EdgeInsets.only(bottom: SparkSpace.xxs),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 116,
                              child: MyText(
                                text: e.key,
                                size: SparkTextSize.caption,
                                color: kGreyColor,
                              ),
                            ),
                            Expanded(
                              child: MyText(
                                text: e.value,
                                size: SparkTextSize.caption,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      // Единый секционный ритм шага: между всеми крупными блоками xl.
      // Заголовки «Модель» и «Состояние» убраны (2026-07-10) — карточки
      // самодостаточны, блоки идут подряд.
      const SizedBox(height: SparkSpace.xl),
      // Brand/model picker — перенесён сюда со шага «Параметры», чтобы вся
      // идентификация была рядом с VIN и госномером.
      s._carSelectionCard(),
      const SizedBox(height: SparkSpace.xl),
      // Состояние — пробег + соответствие. Раньше блок жил в шаге
      // «Осмотр» рядом с медиа-группами; перенесён сюда чтобы базовые
      // данные о машине были собраны на одном экране.
      s._mediaMileageBlock(),
      const SizedBox(height: SparkSpace.xl),
      // Заголовок «Дополнительно» убран (2026-07-10) — карточки «Ссылка на
      // объявление» / «Количество владельцев» / «Город осмотра» идут подряд,
      // их лейблы самодостаточны.
      s._card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MyText(
              text: 'Ссылка на объявление',
              size: SparkTextSize.body,
              weight: FontWeight.w700,
            ),
            const SizedBox(height: SparkSpace.md),
            s._input(
              s._adLinkController,
              'https://auto.ru/...',
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
              focusNode: s._adLinkFocusNode,
              onSubmitted: (_) {
                FocusScope.of(
                  s.context,
                ).requestFocus(s._inspectionCityFocusNode);
              },
            ),
            // PDF-снимок объявления (carStep listing file/pdf, резолвится
            // гидратором из S3-ключа) — доступен при просмотре отчёта (B14).
            if (s._listingPdfUrl.trim().isNotEmpty) ...[
              const SizedBox(height: SparkSpace.md),
              InkWell(
                borderRadius: BorderRadius.circular(SparkRadius.md),
                onTap: () => s._openListingPdf(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: SparkSpace.md,
                    vertical: SparkSpace.sm,
                  ),
                  decoration: BoxDecoration(
                    color: kSecondaryColor.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(SparkRadius.md),
                    border: Border.all(
                      color: kSecondaryColor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.picture_as_pdf_rounded,
                        color: kSecondaryColor,
                        size: SparkSize.iconMd,
                      ),
                      SizedBox(width: SparkSpace.sm),
                      MyText(
                        text: 'Открыть PDF объявления',
                        size: SparkTextSize.body,
                        weight: FontWeight.w700,
                        color: kSecondaryColor,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: SparkSpace.lg),
      s._card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MyText(
              text: 'Количество владельцев',
              size: SparkTextSize.body,
              weight: FontWeight.w700,
            ),
            const SizedBox(height: SparkSpace.md),
            s._dropdownField(
              s._ownersCountController,
              'Выберите количество',
              ownersCounts,
            ),
          ],
        ),
      ),
      const SizedBox(height: SparkSpace.lg),
      s._card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const MyText(
              text: 'Город осмотра',
              size: SparkTextSize.body,
              weight: FontWeight.w700,
              requiredMark: true,
            ),
            const SizedBox(height: SparkSpace.md),
            // Tap-to-open city picker. The controller is the source
            // of truth for the value (so autosave + payload
            // serialisation work unchanged); the field itself is
            // read-only — manual typing is intentionally disabled per
            // product decision (см. план 2026-05-05).
            s._input(
              s._inspectionCityController,
              'Город осмотра',
              readOnly: true,
              focusNode: s._inspectionCityFocusNode,
              onTap: () => s._openCityPicker(),
            ),
          ],
        ),
      ),
    ],
  );
}

// ── Plate country display helpers ──────────────────────────────────────
//
// Что показать на кнопке страны справа от инпута госномера:
// - locked → флаг выбранной страны
// - auto + детектор сработал → флаг определённой страны
// - auto + детектор НЕ сработал (PlateCountry.other) → «?»

String _plateInputFlag(_SparkJoyCreateReportScreenState s) {
  if (!s._plateCountryLocked && s._plateCountry == PlateCountry.other) {
    return '❓';
  }
  return s._plateFormat.flag;
}

String _plateInputHint(_SparkJoyCreateReportScreenState s) {
  if (!s._plateCountryLocked && s._plateCountry == PlateCountry.other) {
    return 'Введите номер';
  }
  return s._plateFormat.placeholder;
}

/// Результат выбора в picker-bottom-sheet:
/// - `auto: true` + `country: null` → инспектор выбрал «Автоматически»
///   (lock снимается, детектор снова рулит).
/// - `auto: false` + `country: SOME` → конкретная страна (lock включается).
typedef _PlatePicked = ({bool auto, PlateCountry? country});

/// Modal bottom sheet со списком стран + пункт «Автоматически» сверху.
/// Текущий выбор подсвечивается галочкой (либо «Авто» если lock=false).
class _PlateCountryPickerSheet extends StatelessWidget {
  const _PlateCountryPickerSheet({required this.current, required this.locked});

  /// Текущая страна (для подсветки в locked-mode).
  final PlateCountry current;

  /// Если false → подсвечен пункт «Автоматически», иначе — [current].
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SparkSpace.lg,
        0,
        SparkSpace.lg,
        SparkSpace.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const MyText(
            text: 'Страна регистрации',
            size: SparkTextSize.title,
            weight: FontWeight.w700,
          ),
          const SizedBox(height: SparkSpace.md),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Авто-режим первым пунктом — детектор пытается
                  // определить страну по номеру; работает для
                  // РФ / Беларусь / Украина / Казахстан / Армения /
                  // Киргизия / Узбекистан / Абхазия. Если не
                  // определилось — prefix покажет «Не определено»,
                  // инспектор может вручную выбрать страну ниже.
                  InkWell(
                    onTap: () => Navigator.of(
                      context,
                    ).pop<_PlatePicked>((auto: true, country: null)),
                    borderRadius: BorderRadius.circular(SparkRadius.md),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: SparkSpace.sm,
                        vertical: SparkSpace.md,
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.auto_awesome_rounded,
                            size: 22,
                            color: kSecondaryColor,
                          ),
                          const SizedBox(width: SparkSpace.md),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                MyText(
                                  text: 'Автоматически',
                                  size: SparkTextSize.body,
                                  weight: FontWeight.w600,
                                  color: kTertiaryColor,
                                ),
                                SizedBox(height: 2),
                                MyText(
                                  text: 'Определить страну по номеру',
                                  size: SparkTextSize.caption,
                                  color: kBorderColor,
                                ),
                              ],
                            ),
                          ),
                          if (!locked)
                            const Icon(
                              Icons.check_rounded,
                              color: kSecondaryColor,
                              size: 22,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(color: kBorderColor, height: SparkSpace.md),
                  ...kPlateFormats.map((fmt) {
                    final selected = locked && fmt.country == current;
                    return InkWell(
                      onTap: () => Navigator.of(
                        context,
                      ).pop<_PlatePicked>((auto: false, country: fmt.country)),
                      borderRadius: BorderRadius.circular(SparkRadius.md),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: SparkSpace.sm,
                          vertical: SparkSpace.md,
                        ),
                        child: Row(
                          children: [
                            Text(
                              fmt.flag,
                              style: const TextStyle(fontSize: 22),
                            ),
                            const SizedBox(width: SparkSpace.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  MyText(
                                    text: fmt.name,
                                    size: SparkTextSize.body,
                                    weight: FontWeight.w600,
                                    color: kTertiaryColor,
                                  ),
                                  const SizedBox(height: 2),
                                  MyText(
                                    text: fmt.placeholder,
                                    size: SparkTextSize.caption,
                                    color: kBorderColor,
                                  ),
                                ],
                              ),
                            ),
                            if (selected)
                              const Icon(
                                Icons.check_rounded,
                                color: kSecondaryColor,
                                size: 22,
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension _SparkJoyListingPdf on _SparkJoyCreateReportScreenState {
  /// Opens the presigned listing-PDF URL externally (B14).
  Future<void> _openListingPdf() async {
    final raw = _listingPdfUrl.trim();
    if (raw.isEmpty) return;
    // The URL comes from server data (presigned S3 link) — reject anything
    // that isn't http/https with a real host, so a compromised/hijacked
    // backend can't trigger intent:/tel:/javascript: via launchUrl.
    final normalized = sparkNormalizeExternalUrl(raw);
    if (normalized.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Некорректная ссылка на PDF')),
      );
      return;
    }
    final uri = Uri.parse(normalized);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Не удалось открыть PDF')));
    }
  }
}
