part of 'spark_joy_create_report_screen.dart';

Widget _buildSparkJoyLegalFilesCard(
  _SparkJoyCreateReportScreenState s, {
  required void Function(VoidCallback fn) setStateFn,
}) {
  return s._card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LegalAddDocumentZone(onTap: s._pickLegalFiles),
        if (s._legalFiles.isNotEmpty) ...[
          const SizedBox(height: SparkSpace.md),
          // Счётчик «Файлы: N» и подсказка про отложенную загрузку убраны:
          // список сам показывает количество, а зелёный чип «Готово к
          // отправке» на каждой строке говорит то же, что говорила подсказка.
          ...List.generate(s._legalFiles.length, (index) {
            final file = s._legalFiles[index];
            final displayName = sparkJoyReadableStoredName(
              rawName: file.displayName,
              mimeType: file.mimeType,
              ordinal: index,
            );
            final openMode = sparkJoyAttachmentOpenMode(
              mimeType: file.mimeType,
              displayName: displayName,
            );
            final canPreview = openMode == SparkJoyAttachmentOpenMode.media;
            final isPdf = openMode == SparkJoyAttachmentOpenMode.pdf;
            return Padding(
              padding: const EdgeInsets.only(bottom: SparkSpace.sm),
              child: Material(
                color: kInputBgColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(SparkRadius.md),
                  side: const BorderSide(color: kBorderColor),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    if (isPdf) {
                      unawaited(
                        Navigator.of(s.context).push<void>(
                          MaterialPageRoute<void>(
                            builder: (_) => SparkJoyPdfViewerScreen(
                              source: file.dataUrl,
                              title: displayName,
                            ),
                          ),
                        ),
                      );
                      return;
                    }
                    if (!canPreview) {
                      unawaited(
                        openSparkJoyExternalDocument(
                          s.context,
                          source: file.dataUrl,
                          mimeType: file.mimeType,
                        ),
                      );
                      return;
                    }
                    final mediaFiles = s._legalFiles
                        .where((item) => item.isImage || item.isVideo)
                        .toList(growable: false);
                    final initialIndex = mediaFiles.indexWhere(
                      (item) => item.id == file.id,
                    );
                    if (initialIndex < 0) return;
                    unawaited(
                      s._openFlatMediaLightbox(
                        files: mediaFiles,
                        groupKeyPerFile: List<String>.filled(
                          mediaFiles.length,
                          'legal',
                        ),
                        initialIndex: initialIndex,
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: SparkSpace.lg,
                      vertical: SparkSpace.md,
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: SparkSize.icon4xl,
                          height: SparkSize.icon4xl,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(SparkRadius.sm),
                            child: ColoredBox(
                              color: kWhiteColor,
                              child: canPreview
                                  ? s._uploadedMediaThumbWidget(
                                      file,
                                      cacheWidth: 160,
                                      cacheHeight: 160,
                                    )
                                  : Icon(
                                      isPdf
                                          ? Icons.picture_as_pdf_outlined
                                          : Icons.insert_drive_file_outlined,
                                      size: SparkTextSize.title,
                                      color: kSecondaryColor,
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(width: SparkSpace.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              MyText(
                                text: displayName,
                                size: SparkTextSize.caption,
                                maxLines: 1,
                                color: kTertiaryColor,
                              ),
                              const SizedBox(height: SparkSpace.xxs),
                              const MyText(
                                text: 'Нажмите, чтобы открыть',
                                size: SparkTextSize.chip,
                                color: kGreyColor,
                              ),
                              const SizedBox(height: SparkSpace.xxs),
                              // Per-file status pill. Files are persisted
                              // locally in the draft; the green «Готово к
                              // отправке» badge confirms they're queued for
                              // server upload at submit time.
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: SparkSpace.sm,
                                  vertical: SparkSpace.xxxs,
                                ),
                                decoration: BoxDecoration(
                                  color: kGreenColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(
                                    SparkRadius.pill,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.check_circle_outline_rounded,
                                      size: SparkTextSize.label,
                                      color: kGreenColor,
                                    ),
                                    const SizedBox(width: SparkSpace.xxs),
                                    const MyText(
                                      text: 'Готово к отправке',
                                      size: SparkTextSize.chip,
                                      color: kGreenColor,
                                      weight: FontWeight.w700,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            setStateFn(() {
                              final next = [...s._legalFiles]..removeAt(index);
                              s._legalFiles = next;
                            });
                            s._markDraftDirty();
                          },
                          borderRadius: BorderRadius.circular(SparkRadius.pill),
                          child: Container(
                            width: SparkSize.iconXxl,
                            height: SparkSize.iconXxl,
                            decoration: BoxDecoration(
                              color: kWhiteColor,
                              borderRadius: BorderRadius.circular(
                                SparkRadius.pill,
                              ),
                              border: Border.all(color: kBorderColor),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: SparkTextSize.label,
                              color: kGreyColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ],
    ),
  );
}

/// Пунктирная зона «Добавить документ» на всю ширину карточки — та же идиома,
/// что и в медиа-редакторе: пунктир читается как «сюда можно положить».
class _LegalAddDocumentZone extends StatelessWidget {
  const _LegalAddDocumentZone({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(SparkRadius.md),
        child: DottedBorder(
          borderType: BorderType.RRect,
          radius: const Radius.circular(SparkRadius.md),
          color: kSecondaryColor.withValues(alpha: 0.30),
          strokeWidth: 1.5,
          dashPattern: const [6, 4],
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: kSecondaryColor.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(SparkRadius.md),
            ),
            child: SizedBox(
              height: SparkSize.actionHeight,
              width: double.infinity,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.upload_file_rounded,
                    size: SparkTextSize.titleLg,
                    color: kSecondaryColor,
                  ),
                  const SizedBox(width: SparkSpace.sm),
                  const MyText(
                    text: 'Добавить документ',
                    size: SparkTextSize.body,
                    color: kSecondaryColor,
                    weight: FontWeight.w600,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `responseNormalized` приходит JSON-строкой (напр. `"{\"found\": false}"`),
/// реже — уже объектом. Сводим к человекочитаемой строке: готовый русский
/// `message` от бэка, иначе фраза по `found` (+кол-во записей при наличии).
/// Сырой дамп ключей (count/items/...) пользователю не показываем.
/// Провайдерские сообщения («В базе такси не найдено», сырые ошибки ApiCloud
/// вида «gosNumber% forbidden symbols present») пропускаем через
/// [sparkJoyHumanizeLegalCheckMessage].
String _legalNormalizedToText(dynamic normalized) {
  if (normalized == null) return '';
  dynamic decoded = normalized;
  if (normalized is String) {
    final s = normalized.trim();
    if (s.isEmpty) return '';
    try {
      decoded = jsonDecode(s);
    } catch (_) {
      return sparkJoyHumanizeLegalCheckMessage(s);
    }
  }
  if (decoded is! Map) {
    if (decoded is List) {
      return decoded.isEmpty ? '' : 'Записей: ${decoded.length}';
    }
    return decoded.toString();
  }
  // Такси-проверка кладёт тексты в partner_message/local_message (message у
  // неё отсутствует) — без них карточка «не найдено» оставалась немой.
  final message = sparkJoyHumanizeLegalCheckMessage(
    (decoded['message'] ??
            decoded['partner_message'] ??
            decoded['local_message'] ??
            '')
        .toString(),
  );
  final found = decoded['found'];
  final countRaw = decoded['count'] ?? decoded['properties_total'];
  final count = countRaw is int ? countRaw : int.tryParse('${countRaw ?? ''}');
  if (found == true) {
    // Значок «⚠️» из текста убран: находку теперь видно по оранжевому бейджу,
    // рамке строки и баннеру — эмодзи в подзаголовке был третьим криком.
    final base = message.isNotEmpty ? message : 'Обнаружено';
    return (count != null && count > 0) ? '$base (записей: $count)' : base;
  }
  if (found == false) {
    // Вердикт справа уже сообщает «чисто»; добавляем текст, только если
    // бэк прислал содержательный `message`.
    return message;
  }
  return message;
}

/// Подзаголовок завершённой строки: что именно ответила проверка. Пустой ответ
/// бэка не оставляем немым — подставляем фразу по тону.
String _legalRowSubtitle(Map<String, dynamic> check) {
  // ГОСТ — сводка сертификата вместо генерик-текста: у информационной
  // проверки found:true значит «данные получены», и «Обнаружено» здесь
  // читалось как находка риска, не говоря при этом ничего о машине.
  if ((check['checkType'] ?? '').toString() == 'api_cloud_gost_certificate') {
    final cert = gostCertificateFields(check['responseNormalized']);
    if (cert != null) {
      final summary = sparkJoyGostCertSummary(cert);
      if (summary.isNotEmpty) return summary;
    }
  }
  var text = _legalNormalizedToText(check['responseNormalized']);
  if (text.isEmpty) {
    // Упавший чек несёт текст только в errorMessage (responseNormalized бэк
    // при ошибке не пишет) — без этого строка «ошибка» была бы немой.
    text = sparkJoyHumanizeLegalCheckMessage(
      (check['errorMessage'] ?? '').toString(),
    );
  }
  if (text.isEmpty) {
    text = switch (sparkJoyLegalRowTone(check)) {
      SparkJoyLegalTone.clean => 'Записей не найдено',
      SparkJoyLegalTone.found => 'Найдены записи',
      SparkJoyLegalTone.data => 'Данные получены',
      SparkJoyLegalTone.error => 'Проверка не выполнилась',
    };
  }
  return text.length > 300 ? '${text.substring(0, 300)}…' : text;
}

/// Чек доехал до терминального состояния. Единый источник истины с поллингом
/// (`legalReviewBatchPending` умеет в несинхронный `status`: бэк успевает
/// положить `responseNormalized`/`executedAt` раньше, чем сменит статус).
bool _legalCheckSettled(Map<String, dynamic> check) =>
    !storage_api.legalReviewBatchPending([check]);

/// «готово N из M» — живой счётчик рядом со спиннером. Пустой список ⇒ батч
/// ещё регистрируется на бэке, считать нечего.
String _legalProgressLabel(List<Map<String, dynamic>> results) {
  if (results.isEmpty) return '';
  final done = results.where(_legalCheckSettled).length;
  return 'готово $done из ${results.length}';
}

double _legalProgressValue(List<Map<String, dynamic>> results) {
  if (results.isEmpty) return 0;
  return results.where(_legalCheckSettled).length / results.length;
}

Color _legalToneColor(SparkJoyLegalTone tone) => switch (tone) {
  SparkJoyLegalTone.clean => kGreenColor,
  SparkJoyLegalTone.found => kOrangeColor,
  SparkJoyLegalTone.data => kSecondaryColor,
  SparkJoyLegalTone.error => kRedColor,
};

IconData _legalToneIcon(SparkJoyLegalTone tone) => switch (tone) {
  SparkJoyLegalTone.clean => Icons.check_rounded,
  SparkJoyLegalTone.found => Icons.priority_high_rounded,
  SparkJoyLegalTone.data => Icons.description_outlined,
  SparkJoyLegalTone.error => Icons.error_outline_rounded,
};

/// Детали под раскрытой строкой: официальные поля ГОСТ и скелет залог/ФГИС.
List<Widget> _legalRowDetails(Map<String, dynamic> check) {
  final type = (check['checkType'] ?? '').toString();
  final normalized = check['responseNormalized'];
  final rows = <Widget>[];
  if (type == 'api_cloud_gost_certificate') {
    final cert = gostCertificateFields(normalized);
    if (cert != null) rows.addAll(_gostCertDetailRows(cert));
  }
  rows.addAll(_legalDetailScaffoldRows(type, normalized));
  return rows;
}

// Одна строка «метка — значение» детали проверки.
Widget _gostRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: SparkSpace.xxs),
    child: Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        MyText(
          text: '$label  ',
          size: SparkTextSize.chip,
          color: kGreyColor,
          weight: FontWeight.w600,
        ),
        MyText(text: value, size: SparkTextSize.caption, color: kTertiaryColor),
      ],
    ),
  );
}

bool _gostHas(String? v) => v != null && v.trim().isNotEmpty && v.trim() != '-';

/// Детали ГОСТ-сертификата (марка/модель, год, мотор, мощность, кузов, № …).
List<Widget> _gostCertDetailRows(Map<String, dynamic> cert) {
  String f(String k) => (cert[k] ?? '').toString().trim();
  final rows = <Widget>[];
  final markModel = [
    f('product'),
    f('tradename'),
  ].where((s) => s.isNotEmpty).join(' ');
  if (markModel.isNotEmpty) rows.add(_gostRow('Марка/модель:', markModel));
  if (_gostHas(f('yearofmanufacturing'))) {
    rows.add(_gostRow('Год выпуска:', f('yearofmanufacturing')));
  }
  final cc = int.tryParse(
    RegExp(r'\d+').firstMatch(f('enginecylindersusefulcapacity'))?.group(0) ??
        '',
  );
  if (cc != null && cc > 0) {
    rows.add(
      _gostRow('Объём двигателя:', '${(cc / 1000).toStringAsFixed(1)} л'),
    );
  }
  if (_gostHas(f('enginepetrol'))) {
    rows.add(_gostRow('Топливо:', f('enginepetrol')));
  }
  final tr = f('transmission');
  if (_gostHas(tr)) {
    rows.add(_gostRow('КПП:', tr.length > 60 ? '${tr.substring(0, 60)}…' : tr));
  }
  if (_gostHas(f('enginemaxpower'))) {
    rows.add(_gostRow('Мощность:', f('enginemaxpower')));
  }
  if (_gostHas(f('bodytype'))) rows.add(_gostRow('Кузов:', f('bodytype')));
  if (_gostHas(f('category'))) rows.add(_gostRow('Категория:', f('category')));
  if (_gostHas(f('fullmass'))) rows.add(_gostRow('Масса, кг:', f('fullmass')));
  if (_gostHas(f('eco'))) rows.add(_gostRow('Эко-класс:', f('eco')));
  if (_gostHas(f('numberofcertificate'))) {
    rows.add(_gostRow('№ сертификата:', f('numberofcertificate')));
  }
  return rows;
}

/// Скелет деталей залога (items[]) / ФГИС-такси (permit). Рендерится, ТОЛЬКО
/// когда бэк начнёт слать их непустыми (сейчас баг — []/null, ветки дремлют).
/// Ключи деталей финализировать по схеме бэка после фикса.
List<Widget> _legalDetailScaffoldRows(String type, dynamic normalized) {
  if (type == 'api_cloud_zalog_notary' || type == 'api_cloud_zalog_fedresurs') {
    final items = gostListField(normalized, 'items');
    if (items.isEmpty) return const [];
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final it = items[i];
      String f(String k) => (it[k] ?? '').toString().trim();
      final pledgee = f('pledgee').isNotEmpty ? f('pledgee') : f('name');
      final date = f('date').isNotEmpty ? f('date') : f('registration_date');
      final regNum = f('number').isNotEmpty ? f('number') : f('reg_number');
      if (pledgee.isNotEmpty) rows.add(_gostRow('Залогодержатель:', pledgee));
      if (date.isNotEmpty) rows.add(_gostRow('Дата:', date));
      if (regNum.isNotEmpty) rows.add(_gostRow('№ записи:', regNum));
      if (i < items.length - 1) {
        rows.add(const SizedBox(height: SparkSpace.xxs));
      }
    }
    return rows;
  }
  if (type == 'api_cloud_fgis_taxi_search') {
    final permit = gostMapField(normalized, 'permit');
    if (permit == null) return const [];
    String f(String k) => (permit[k] ?? '').toString().trim();
    final rows = <Widget>[];
    if (f('number').isNotEmpty) {
      rows.add(_gostRow('№ разрешения:', f('number')));
    }
    if (f('status').isNotEmpty) {
      rows.add(_gostRow('Статус разрешения:', f('status')));
    }
    if (f('region').isNotEmpty) rows.add(_gostRow('Регион:', f('region')));
    if (f('valid_until').isNotEmpty) {
      rows.add(_gostRow('Действует до:', f('valid_until')));
    }
    return rows;
  }
  return const [];
}

/// Состояние строки проверки в списке.
enum _LegalRowState {
  /// Проверка ещё не запускалась (или батч только регистрируется).
  queued,

  /// Батч идёт, конкретно эта проверка ещё не ответила.
  running,

  /// Ответ получен — есть вердикт.
  settled,
}

/// Строка одной проверки: бейдж состояния, название, подзаголовок и вердикт.
/// Раскрывается тапом, если у проверки есть детали.
class _LegalCheckRow extends StatelessWidget {
  const _LegalCheckRow({
    required this.title,
    required this.subtitle,
    required this.state,
    required this.tone,
    required this.expanded,
    required this.details,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final _LegalRowState state;

  /// Осмысленен только при [state] == settled.
  final SparkJoyLegalTone tone;
  final bool expanded;
  final List<Widget> details;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final settled = state == _LegalRowState.settled;
    final isFound = settled && tone == SparkJoyLegalTone.found;
    final toneColor = _legalToneColor(tone);
    final expandable = settled && details.isNotEmpty;

    return Container(
      margin: const EdgeInsets.only(top: SparkSpace.sm),
      decoration: BoxDecoration(
        border: Border.all(
          color: isFound ? kOrangeColor.withValues(alpha: 0.30) : kBorderColor,
        ),
        borderRadius: BorderRadius.circular(SparkRadius.md),
        color: isFound ? kOrangeColor.withValues(alpha: 0.04) : kWhiteColor,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: expandable ? onTap : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SparkSpace.lg,
                vertical: SparkSpace.lg,
              ),
              child: Row(
                children: [
                  _badge(settled: settled, toneColor: toneColor),
                  const SizedBox(width: SparkSpace.lg),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MyText(
                          text: title,
                          size: SparkTextSize.body,
                          weight: FontWeight.w600,
                          color: state == _LegalRowState.queued
                              ? kGreyColor
                              : kTertiaryColor,
                        ),
                        if (subtitle.isNotEmpty)
                          MyText(
                            text: subtitle,
                            size: SparkTextSize.caption,
                            maxLines: 2,
                            color: isFound ? kOrangeColor : kGreyColor,
                            weight: isFound
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                      ],
                    ),
                  ),
                  if (settled) ...[
                    const SizedBox(width: SparkSpace.sm),
                    MyText(
                      text: sparkJoyLegalVerdictLabel(tone),
                      size: SparkTextSize.caption,
                      weight: FontWeight.w700,
                      color: toneColor,
                    ),
                  ],
                  if (expandable)
                    Icon(
                      expanded
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      size: SparkTextSize.modalTitle,
                      color: kGreyColor,
                    ),
                ],
              ),
            ),
          ),
          if (expandable && expanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(
                // Отступ слева ровняет детали по названию проверки, а не по
                // бейджу: 36 бейдж + 10 зазор + 10 паддинг строки.
                56,
                SparkSpace.md,
                SparkSpace.lg,
                SparkSpace.lg,
              ),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: kBorderColor)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: details,
              ),
            ),
        ],
      ),
    );
  }

  Widget _badge({required bool settled, required Color toneColor}) {
    if (settled) {
      return Container(
        width: SparkSize.navStepBadge,
        height: SparkSize.navStepBadge,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          // Информационный тон — тише: он не про риск, а про данные.
          color: toneColor.withValues(
            alpha: tone == SparkJoyLegalTone.data ? 0.08 : 0.12,
          ),
        ),
        child: Icon(_legalToneIcon(tone), size: 16, color: toneColor),
      );
    }
    if (state == _LegalRowState.running) {
      return const SizedBox(
        width: SparkSize.navStepBadge,
        height: SparkSize.navStepBadge,
        child: Center(
          child: SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: kSecondaryColor,
            ),
          ),
        ),
      );
    }
    return CustomPaint(
      painter: SparkDashedCirclePainter(
        color: kGreyColor.withValues(alpha: 0.5),
      ),
      child: const SizedBox(
        width: SparkSize.navStepBadge,
        height: SparkSize.navStepBadge,
      ),
    );
  }
}

/// Баннер над списком: что нашли. Рисуется только при реальной находке.
class _LegalFoundBanner extends StatelessWidget {
  const _LegalFoundBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: SparkSpace.lg),
      padding: const EdgeInsets.symmetric(
        horizontal: SparkSpace.lg,
        vertical: SparkSpace.md,
      ),
      decoration: BoxDecoration(
        color: kOrangeColor.withValues(alpha: 0.06),
        border: Border.all(color: kOrangeColor.withValues(alpha: 0.30)),
        borderRadius: BorderRadius.circular(SparkRadius.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: SparkTextSize.titleLg,
            color: kOrangeColor,
          ),
          const SizedBox(width: SparkSpace.md),
          Expanded(
            child: MyText(
              text: text,
              size: SparkTextSize.caption,
              weight: FontWeight.w700,
              color: kOrangeColor,
              lineHeight: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

/// Главная кнопка шага. Градиент — единственный акцент такого веса на экране,
/// поэтому живёт только пока материалы не сформированы.
class _LegalRunButton extends StatelessWidget {
  const _LegalRunButton({required this.onTap, required this.enabled});

  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(SparkRadius.xl),
          child: Container(
            height: SparkSize.inputHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [kSecondaryColor, kBlueColor],
              ),
              borderRadius: BorderRadius.circular(SparkRadius.xl),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.gavel_rounded,
                  size: SparkTextSize.titleLg,
                  color: kWhiteColor,
                ),
                SizedBox(width: SparkSpace.md),
                MyText(
                  text: 'Сформировать материалы',
                  size: SparkTextSize.bodyLg,
                  color: kWhiteColor,
                  weight: FontWeight.w700,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Шапка карточки во время прогона: спиннер, счётчик и полоса.
class _LegalRunningHeader extends StatelessWidget {
  const _LegalRunningHeader({required this.progressLabel, required this.value});

  final String progressLabel;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: kSecondaryColor,
              ),
            ),
            const SizedBox(width: SparkSpace.md),
            const Expanded(
              child: MyText(
                text: 'Проверяем автомобиль по базам…',
                size: SparkTextSize.body,
                weight: FontWeight.w700,
                color: kSecondaryColor,
              ),
            ),
            if (progressLabel.isNotEmpty)
              MyText(
                text: progressLabel,
                size: SparkTextSize.caption,
                color: kGreyColor,
              ),
          ],
        ),
        const SizedBox(height: SparkSpace.md),
        ClipRRect(
          borderRadius: BorderRadius.circular(SparkRadius.pill),
          child: LinearProgressIndicator(
            minHeight: SparkSize.progressThin,
            // Пока батч регистрируется, доли ещё нет — крутим неопределённую
            // полосу вместо честного нуля, который читается как «зависло».
            value: value > 0 ? value : null,
            backgroundColor: kLightGreyColor,
            color: kSecondaryColor,
          ),
        ),
      ],
    );
  }
}

Widget _buildSparkJoyStepLegal(
  _SparkJoyCreateReportScreenState s, {
  required void Function(VoidCallback fn) setStateFn,
}) {
  // Однократно подтянуть право run_legal_review + каталог типов проверок
  // (guard внутри метода; setState только после await, не во время build).
  unawaited(s._ensureLegalReviewMeta());

  final results = s._legalCheckResults;
  final loading = s._legalLoading;
  final loaded = s._legalLoaded;
  final types = s._legalAvailableCheckTypes;

  // Без VIN и госномера проверки уходят в ApiCloud без идентификатора и
  // гарантированно возвращают ошибку — а вызов платный (BACKEND_REQUESTS.md,
  // P1 баг 1). Единственный гейт после снятия галок выбора проверок.
  final hasIdentifier =
      s._sanitizeVin(s._vinController.text).isNotEmpty ||
      s._sanitizePlate(s._plateController.text.trim()).isNotEmpty;

  void runChecks() {
    setStateFn(() {
      // Выбор проверок пользователю больше не показываем — гоняем весь
      // каталог. Поле остаётся: оно персистится в черновике и уезжает в
      // payload отчёта.
      s._legalSelectedCheckTypes = types
          .map((t) => t.value)
          .toList(growable: false);
      // Раскрытие строк — от прошлого прогона; иначе свёрнутая тогда находка
      // приедет свёрнутой и в новом результате.
      s._legalExpandedOverride.clear();
    });
    unawaited(s._startLegalLoading());
  }

  final banner = loaded ? sparkJoyLegalFoundBanner(results) : null;
  // Без каталога запускать нечего: `runChecks` отправил бы пустой список и
  // упёрся в «Выберите хотя бы одну проверку» — сообщение-абсурд, ведь выбор
  // из UI убран. Уже приехавшие результаты рендерятся выше независимо.
  final catalogUnavailable = types.isEmpty;
  final canRun = hasIdentifier && !catalogUnavailable;

  return Column(
    children: [
      s._card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (loading)
              _LegalRunningHeader(
                progressLabel: _legalProgressLabel(results),
                value: _legalProgressValue(results),
              )
            else if (loaded)
              Row(
                children: [
                  Expanded(
                    child: MyText(
                      text: sparkJoyLegalCheckedSummary(results.length),
                      size: SparkTextSize.caption,
                      color: kGreyColor,
                    ),
                  ),
                  // Тот же гейт, что у «Сформировать материалы»: без
                  // идентификатора или без каталога повтор упрётся в тупик.
                  if (s._legalCanRunReview)
                    InkWell(
                      onTap: canRun ? runChecks : null,
                      borderRadius: BorderRadius.circular(SparkRadius.sm),
                      child: Padding(
                        padding: const EdgeInsets.all(SparkSpace.xs),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.refresh_rounded,
                              size: SparkTextSize.sectionTitle,
                              color: canRun ? kSecondaryColor : kGreyColor,
                            ),
                            const SizedBox(width: SparkSpace.xs),
                            MyText(
                              text: 'Обновить',
                              size: SparkTextSize.caption,
                              weight: FontWeight.w700,
                              color: canRun ? kSecondaryColor : kGreyColor,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              )
            else
              MyText(
                text: s._legalTimedOut
                    ? 'ApiCloud ещё обрабатывает запросы — результаты '
                          'подтянутся при повторном открытии отчёта'
                    : 'Материалы ещё не сформированы',
                size: SparkTextSize.caption,
                color: kGreyColor,
                lineHeight: 1.35,
              ),

            if (banner != null) _LegalFoundBanner(text: banner),

            // Список проверок: пока результатов нет — превью по каталогу.
            if (results.isNotEmpty)
              ...results.map((check) {
                final type = (check['checkType'] ?? '').toString();
                final settled = _legalCheckSettled(check);
                final tone = sparkJoyLegalRowTone(check);
                final details = settled
                    ? _legalRowDetails(check)
                    : const <Widget>[];
                // Находку раскрываем сразу — ради неё сюда и смотрят;
                // остальное по тапу. Считаем один раз: рассинхрон между
                // отрисовкой и обработчиком дал бы строку, не реагирующую
                // на первый тап.
                final expanded =
                    s._legalExpandedOverride[type] ??
                    (tone == SparkJoyLegalTone.found);
                return _LegalCheckRow(
                  title: type.isEmpty
                      ? 'Проверка'
                      : sparkJoyLegalCheckTypeLabel(type),
                  subtitle: settled
                      ? _legalRowSubtitle(check)
                      : sparkJoyLegalCheckTypeHint(type),
                  // Спиннер только пока батч реально идёт. После таймаута
                  // поллинга неответивший чек не «выполняется» — крутящийся
                  // кружок врал бы, что осталось подождать.
                  state: settled
                      ? _LegalRowState.settled
                      : (loading
                            ? _LegalRowState.running
                            : _LegalRowState.queued),
                  tone: tone,
                  expanded: expanded,
                  details: details,
                  onTap: () => setStateFn(() {
                    s._legalExpandedOverride[type] = !expanded;
                  }),
                );
              })
            else
              ...types.map(
                (t) => _LegalCheckRow(
                  title: sparkJoyLegalCheckTypeLabel(t.value),
                  subtitle: sparkJoyLegalCheckTypeHint(t.value),
                  state: _LegalRowState.queued,
                  tone: SparkJoyLegalTone.clean,
                  expanded: false,
                  details: const [],
                  onTap: () {},
                ),
              ),

            if (!s._legalCanRunReview) ...[
              const SizedBox(height: SparkSpace.lg),
              const SparkHintCard(
                text:
                    'Недостаточно прав для запуска проверок. Обратитесь к '
                    'администратору компании (право run_legal_review).',
              ),
            ] else if (catalogUnavailable) ...[
              const SizedBox(height: SparkSpace.lg),
              // Пока запрос в полёте — спиннер-текст; если попытка провалилась
              // (нет сети/холодный бэк/CORS на web) и повтор не идёт — даём
              // явную кнопку «Повторить», чтобы не висеть вечно.
              if (s._legalReviewMetaInFlight)
                const MyText(
                  text: 'Загрузка списка проверок…',
                  size: SparkTextSize.caption,
                  color: kGreyColor,
                )
              else
                Row(
                  children: [
                    const Expanded(
                      child: MyText(
                        text:
                            'Не удалось загрузить список проверок — '
                            'проверьте соединение',
                        size: SparkTextSize.caption,
                        color: kGreyColor,
                      ),
                    ),
                    const SizedBox(width: SparkSpace.sm),
                    TextButton.icon(
                      onPressed: () {
                        // Сброс кулдауна → немедленный повтор.
                        s._legalReviewMetaLastTry = null;
                        unawaited(s._ensureLegalReviewMeta());
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Повторить'),
                    ),
                  ],
                ),
            ] else if (!loading && !loaded) ...[
              const SizedBox(height: SparkSpace.lg),
              _LegalRunButton(onTap: runChecks, enabled: canRun),
              if (!hasIdentifier) ...[
                const SizedBox(height: SparkSpace.md),
                const MyText(
                  text: 'Заполните VIN или госномер в шаге «Автомобиль»',
                  size: SparkTextSize.caption,
                  color: kGreyColor,
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ],
        ),
      ),
      const SizedBox(height: SparkSpace.xl),
      s._sectionHeading('Файлы специалиста', icon: Icons.folder_open_outlined),
      const SizedBox(height: SparkSpace.lg),
      _buildSparkJoyLegalFilesCard(s, setStateFn: setStateFn),
      // Заголовок «Комментарий специалиста» убран (2026-07-10) — панель
      // комментария самодостаточна, идёт сразу за файлами.
      const SizedBox(height: SparkSpace.xl),
      // Без обёрточной `_card` — _commentInputPanel сам по себе уже
      // декорирован, дополнительная карточка дублировала рамку.
      s._commentInputPanel(
        controller: s._legalNoteController,
        isDictating: s._legalIsDictating,
        aiBusy: s._legalCommentAiBusy,
        onToggleDictation: () async {
          if (s._legalIsDictating) {
            await s._stopLegalDictation();
          } else {
            await s._startLegalDictation();
          }
        },
        // Real AiQueue call over the legal-check facts and typed comment.
        // Attached file contents/names are intentionally not sent here.
        onAiFormat: () => unawaited(s._generateLegalCommentWithAi()),
      ),
    ],
  );
}
