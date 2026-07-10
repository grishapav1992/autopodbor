part of 'spark_joy_create_report_screen.dart';

Widget _buildSparkJoyLegalFilesCard(
  _SparkJoyCreateReportScreenState s, {
  required void Function(VoidCallback fn) setStateFn,
}) {
  return s._card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(
              Icons.attach_file_rounded,
              size: SparkTextSize.title,
              color: kGreyColor,
            ),
            const SizedBox(width: SparkSpace.sm),
            MyText(
              text: 'Файлы: ${s._legalFiles.length}',
              size: SparkTextSize.caption,
              color: kTertiaryColor,
              weight: FontWeight.w600,
            ),
          ],
        ),
        const SizedBox(height: SparkSpace.sm),
        OutlinedButton.icon(
          onPressed: s._pickLegalFiles,
          icon: const Icon(Icons.upload_file_rounded),
          label: const Text('Добавить документ'),
        ),
        if (s._legalFiles.isNotEmpty) ...[
          const SizedBox(height: SparkSpace.md),
          // Hint above the file list — files live locally in the draft
          // until the report is submitted; they don't reach the server
          // until then. Without this signal the user wonders whether
          // the upload happened on pick.
          const SparkHintCard(
            text: 'Файлы будут загружены при сохранении отчёта.',
            icon: Icons.cloud_upload_outlined,
          ),
          const SizedBox(height: SparkSpace.md),
          ...List.generate(s._legalFiles.length, (index) {
            final file = s._legalFiles[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: SparkSpace.sm),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: SparkSpace.lg,
                  vertical: SparkSpace.md,
                ),
                decoration: BoxDecoration(
                  color: kInputBgColor,
                  borderRadius: BorderRadius.circular(SparkRadius.md),
                  border: Border.all(color: kBorderColor),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.insert_drive_file_outlined,
                      size: SparkTextSize.title,
                      color: kSecondaryColor,
                    ),
                    const SizedBox(width: SparkSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          MyText(
                            text: file.name,
                            size: SparkTextSize.caption,
                            maxLines: 1,
                            color: kTertiaryColor,
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
                              borderRadius:
                                  BorderRadius.circular(SparkRadius.pill),
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
                          borderRadius: BorderRadius.circular(SparkRadius.pill),
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
            );
          }),
        ],
      ],
    ),
  );
}

/// Рендер результатов batch-проверок (ApiCloud) — по одной записи на
/// checkType: имя проверки, статус и нормализованный ответ (компактно).
/// Форма `responseNormalized` зависит от типа проверки, поэтому показываем
/// её обобщённо (строка как есть / JSON), а детальный рендер допилим после
/// первого live-прогона.
/// Человекочитаемый статус проверки ApiCloud.
String _legalCheckStatusLabel(String status) {
  switch (status.toLowerCase()) {
    case 'completed':
    case 'done':
    case 'success':
      return 'готово';
    case 'found':
      return 'найдено';
    case 'not_found':
      return 'не найдено';
    case 'failed':
    case 'error':
      return 'ошибка';
    case 'pending':
    case 'processing':
    case 'in_progress':
    case 'running':
      return 'в обработке';
    default:
      return status.isEmpty ? '—' : status;
  }
}

// Человекочитаемое название типа ApiCloud-проверки вынесено в общий
// `sparkJoyLegalCheckTypeLabel` (spark_joy_legal_labels.dart) — единый источник
// для этого шага и ленты уведомлений (чтобы названия не расходились).

/// `responseNormalized` приходит JSON-строкой (напр. `"{\"found\": false}"`),
/// реже — уже объектом. Сводим к человекочитаемой строке: готовый русский
/// `message` от бэка, иначе фраза по `found` (+кол-во записей при наличии).
/// Сырой дамп ключей (count/items/...) пользователю не показываем.
String _legalNormalizedToText(dynamic normalized) {
  if (normalized == null) return '';
  dynamic decoded = normalized;
  if (normalized is String) {
    final s = normalized.trim();
    if (s.isEmpty) return '';
    try {
      decoded = jsonDecode(s);
    } catch (_) {
      return s;
    }
  }
  if (decoded is! Map) {
    if (decoded is List) {
      return decoded.isEmpty ? '' : 'Записей: ${decoded.length}';
    }
    return decoded.toString();
  }
  final message = (decoded['message'] ?? '').toString().trim();
  final found = decoded['found'];
  final countRaw = decoded['count'] ?? decoded['properties_total'];
  final count = countRaw is int ? countRaw : int.tryParse('${countRaw ?? ''}');
  if (found == true) {
    final base = message.isNotEmpty ? message : 'Обнаружено';
    return (count != null && count > 0) ? '⚠️ $base (записей: $count)' : '⚠️ $base';
  }
  if (found == false) {
    // Статус-строка уже сообщает «не найдено»; добавляем текст, только если
    // бэк прислал содержательный `message`.
    return message;
  }
  return message;
}

/// Подзаголовок статуса во время поллинга: живой прогресс (сколько проверок
/// уже доехало из общего числа), чтобы спиннер не был «глухим». Пустой список
/// ⇒ батч ещё регистрируется на бэке.
String _legalLoadingSubtitle(List<Map<String, dynamic>> results) {
  if (results.isEmpty) return 'Формируем материалы…';
  bool isTerminal(Map<String, dynamic> c) {
    final st = (c['status'] ?? '').toString().toLowerCase();
    return st.isNotEmpty &&
        st != 'pending' &&
        st != 'processing' &&
        st != 'in_progress' &&
        st != 'running';
  }

  final total = results.length;
  final done = results.where(isTerminal).length;
  return 'Идёт проверка: готово $done из $total…';
}

List<Widget> _buildSparkJoyLegalResults(_SparkJoyCreateReportScreenState s) {
  final results = s._legalCheckResults;
  if (results.isEmpty) return const <Widget>[];
  return <Widget>[
    const SizedBox(height: SparkSpace.md),
    s._sectionHeading('Результаты проверок', icon: Icons.fact_check_outlined),
    const SizedBox(height: SparkSpace.sm),
    ...results.map((c) {
      final type = (c['checkType'] ?? '').toString();
      final title = type.isEmpty
          ? 'Проверка'
          : sparkJoyLegalCheckTypeLabel(type);
      final status = (c['status'] ?? '').toString();
      final summary = _legalNormalizedToText(c['responseNormalized']);
      final cert = type == 'api_cloud_gost_certificate'
          ? gostCertificateFields(c['responseNormalized'])
          : null;
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: SparkSpace.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            MyText(
              text: title,
              size: SparkTextSize.caption,
              weight: FontWeight.w600,
            ),
            MyText(
              text: 'Статус: ${_legalCheckStatusLabel(status)}',
              size: SparkTextSize.caption,
              color: kGreyColor,
            ),
            if (summary.isNotEmpty)
              MyText(
                text: summary.length > 300
                    ? '${summary.substring(0, 300)}…'
                    : summary,
                size: SparkTextSize.caption,
                color: kGreyColor,
              ),
            // ГОСТ-сертификат: официальные поля авто (бэк отдаёт certificate[]).
            if (cert != null) ..._gostCertDetailRows(cert),
            // Скелет залог/ФГИС: items[]/permit — дремлет, пока бэк не наполнит.
            ..._legalDetailScaffoldRows(type, c['responseNormalized']),
          ],
        ),
      );
    }),
  ];
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
    rows.add(_gostRow('Объём двигателя:', '${(cc / 1000).toStringAsFixed(1)} л'));
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
      if (i < items.length - 1) rows.add(const SizedBox(height: SparkSpace.xxs));
    }
    return rows;
  }
  if (type == 'api_cloud_fgis_taxi_search') {
    final permit = gostMapField(normalized, 'permit');
    if (permit == null) return const [];
    String f(String k) => (permit[k] ?? '').toString().trim();
    final rows = <Widget>[];
    if (f('number').isNotEmpty) rows.add(_gostRow('№ разрешения:', f('number')));
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

Widget _buildSparkJoyStepLegal(
  _SparkJoyCreateReportScreenState s, {
  required void Function(VoidCallback fn) setStateFn,
}) {
  // Однократно подтянуть право run_legal_review + каталог типов проверок
  // (guard внутри метода; setState только после await, не во время build).
  unawaited(s._ensureLegalReviewMeta());

  final statusColor = s._legalLoading
      ? kSecondaryColor
      : (s._legalLoaded
            ? kGreenColor
            : (s._legalTimedOut ? kSecondaryColor : kGreyColor));
  final statusSubtitle = s._legalLoading
      ? _legalLoadingSubtitle(s._legalCheckResults)
      : (s._legalLoaded
            ? 'Материалы сформированы'
            : (s._legalTimedOut
                  ? 'ApiCloud ещё обрабатывает запросы — результаты подтянутся при повторном открытии отчёта'
                  : 'Материалы ещё не сформированы'));

  final selected = s._legalSelectedCheckTypes;

  return Column(
    children: [
      s._card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: MyText(
                    text: 'Автопроверки ApiCloud',
                    size: SparkTextSize.caption,
                    color: kTertiaryColor,
                    weight: FontWeight.w700,
                  ),
                ),
                Container(
                  width: SparkSize.iconSm,
                  height: SparkSize.iconSm,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.16),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
            const SizedBox(height: SparkSpace.sm),
            MyText(
              text: statusSubtitle,
              size: SparkTextSize.caption,
              color: kGreyColor,
            ),
            const SizedBox(height: SparkSpace.md),
            if (!s._legalCanRunReview)
              SparkHintCard(
                text:
                    'Недостаточно прав для запуска проверок. Обратитесь к '
                    'администратору компании (право run_legal_review).',
              )
            else ...[
              if (s._legalAvailableCheckTypes.isEmpty)
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
                  )
              else
                ...s._legalAvailableCheckTypes.map(
                  (t) => CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: selected.contains(t.value),
                    title: MyText(
                      text: sparkJoyLegalCheckTypeLabel(t.value),
                      size: SparkTextSize.caption,
                    ),
                    onChanged: s._legalLoading
                        ? null
                        : (checked) {
                            setStateFn(() {
                              final next = selected.toList();
                              if (checked == true) {
                                if (!next.contains(t.value)) next.add(t.value);
                              } else {
                                next.remove(t.value);
                              }
                              s._legalSelectedCheckTypes = next;
                            });
                          },
                  ),
                ),
              if (s._legalLoading) ...[
                const SizedBox(height: SparkSpace.sm),
                ClipRRect(
                  borderRadius: BorderRadius.circular(SparkRadius.pill),
                  child: const LinearProgressIndicator(
                    minHeight: SparkSize.progressThin,
                  ),
                ),
              ],
              const SizedBox(height: SparkSpace.md),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: (s._legalLoading || selected.isEmpty)
                      ? null
                      : s._startLegalLoading,
                  icon: Icon(
                    s._legalLoaded
                        ? Icons.refresh_rounded
                        : Icons.gavel_rounded,
                    size: SparkSize.iconSm,
                  ),
                  label: Text(
                    s._legalLoading
                        ? 'Формирование…'
                        : (s._legalLoaded ? 'Обновить' : 'Сформировать'),
                  ),
                ),
              ),
            ],
            // Результаты показываем ВНЕ permission-гейта: просмотр уже
            // сохранённых материалов не требует права на запуск (гидратор
            // подтянул их и для зрителя без run_legal_review).
            ..._buildSparkJoyLegalResults(s),
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
        // Real AiQueue call — bakes attached file names into the cliche
        // so the model can reference them. Replaces the old local
        // regex-based reflow which wasn't actually AI.
        onAiFormat: () => unawaited(s._generateLegalCommentWithAi()),
      ),
    ],
  );
}
