import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:camerawesome/camerawesome_plugin.dart' as cam;
import 'package:camerawesome/pigeon.dart' as cam_pigeon;
import 'package:dotted_border/dotted_border.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/core/utils/profanity_moderator.dart';
import 'package:flutter_application_1/data/api/ai_queue_api.dart';
import 'package:flutter_application_1/data/api/storage_api.dart' as storage_api;
import 'package:flutter_application_1/data/preferences/user_preferences.dart';
import 'package:flutter_application_1/data/services/ai_queue_cliche_builder.dart';
import 'package:flutter_application_1/data/services/ai_queue_offline_runner.dart';
import 'package:flutter_application_1/data/services/city_repository.dart';
import 'package:flutter_application_1/data/services/spark_joy_tag_service.dart';
import 'package:flutter_application_1/state/spark_joy_report_controller.dart';
import 'package:flutter_application_1/ui/common/widgets/city_picker_bottom_sheet.dart';
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_comment_components.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_comment_utils.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_company_request_detail_screen.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_data.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_error_snackbar.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_external_link.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_i18n.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_legal_labels.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_media_note_logic.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_onboarding.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_plate_formats.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_report_context.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_share.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_storage.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_tokens.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_ui.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_upload_identity.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_vin_params_ai.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_doc_scan_ai.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/vin_ocr_service.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/vin_ocr_types.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:video_player/video_player.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

part 'spark_joy_step_vehicle.dart';
part 'spark_joy_step_params.dart';
part 'spark_joy_step_docs_check.dart';
part 'spark_joy_step_legal.dart';
part 'spark_joy_step_test_drive.dart';
part 'spark_joy_step_summary.dart';
part 'spark_joy_step_media.dart';
part 'spark_joy_section_editor.dart';
part 'spark_joy_summary_widgets.dart';
part 'spark_joy_vin_scanner.dart';
part 'spark_joy_media_editor.dart';
part 'spark_joy_media_inspection_editor.dart';
part 'spark_joy_tag_picker.dart';
part 'spark_joy_media_lightbox.dart';
part 'spark_joy_media_rules.dart';
part 'spark_joy_completion_rules.dart';
part 'spark_joy_summary_rules.dart';
part 'spark_joy_test_drive_rules.dart';
part 'spark_joy_vehicle_rules.dart';
part 'spark_joy_navigation_rules.dart';
part 'spark_joy_overview_rules.dart';
part 'spark_joy_form_helpers.dart';
part 'spark_joy_company_cards.dart';
part 'spark_joy_lkp_widgets.dart';
part 'spark_joy_test_drive_widgets.dart';
part 'spark_joy_dictation_rules.dart';
part 'spark_joy_media_helpers.dart';
part 'spark_joy_summary_adapters.dart';
part 'spark_joy_models.dart';
part 'spark_joy_vehicle_business_helpers.dart';
part 'spark_joy_storage_helpers.dart';
part 'spark_joy_data_parsers.dart';
part 'spark_joy_summary_calculation.dart';
part 'spark_joy_media_assets.dart';
part 'spark_joy_screen_helpers.dart';
part 'spark_joy_file_picker_helpers.dart';
part 'spark_joy_car_picker_helpers.dart';
part 'spark_joy_city_picker_helpers.dart';
part 'spark_joy_vin_actions_helpers.dart';
part 'spark_joy_doc_scan_helpers.dart';
part 'spark_joy_lifecycle_helpers.dart';
part 'spark_joy_media_state_helpers.dart';
part 'spark_joy_init_dispose_helpers.dart';
part 'spark_joy_draft_init_helpers.dart';
part 'spark_joy_report_editor_shell.dart';
part 'spark_joy_completed_report_view.dart';
part 'spark_joy_report_flow_controller.dart';
part 'spark_joy_step_action_controller.dart';
part 'spark_joy_overview_controller.dart';
part 'spark_joy_steps_registry.dart';
part 'spark_joy_media_groups_registry.dart';
part 'spark_joy_media_tags_registry.dart';
part 'spark_joy_summary_registry.dart';
part 'spark_joy_test_drive_registry.dart';
part 'spark_joy_summary_texts_registry.dart';
part 'spark_joy_vehicle_registry.dart';

class SparkJoyCreateReportScreen extends StatefulWidget {
  const SparkJoyCreateReportScreen({
    super.key,
    this.initialReportName,
    this.initialAssignedSpecialistId,
    this.initialAssignedSpecialistName,
    this.initialStaffInviteLink,
    this.draft,
    this.assignment,
    this.readOnly = false,
    this.initialStepIndex,
  });

  final String? initialReportName;
  final String? initialAssignedSpecialistId;
  final String? initialAssignedSpecialistName;
  final String? initialStaffInviteLink;
  final Map<String, dynamic>? draft;
  final Map<String, dynamic>? assignment;

  /// When true the screen renders an already-submitted report without any
  /// editing affordances — inputs are read-only, autosave + dirty-flag
  /// plumbing is skipped, the action bar exposes only «Закрыть» and a
  /// share link action. Used by the reports list to surface completed
  /// reports with the exact same layout as the editor's "Итог" step.
  final bool readOnly;

  /// Optional starting step. When [readOnly] is true this defaults to the
  /// summary step so the completed report opens directly at the recap
  /// layout. Otherwise the usual "first unfilled step" flow applies.
  final int? initialStepIndex;

  @override
  State<SparkJoyCreateReportScreen> createState() =>
      _SparkJoyCreateReportScreenState();
}

class _SparkJoyCreateReportScreenState extends State<SparkJoyCreateReportScreen>
    with WidgetsBindingObserver {
  late final TextEditingController _reportNameController;
  late final TextEditingController _vinController;
  late final TextEditingController _plateController;
  late final TextEditingController _brandController;
  late final TextEditingController _modelController;
  late final TextEditingController _generationController;
  late final TextEditingController _adLinkController;
  late String _restylingLabel;
  late String _carPhotoUrl;
  late String _carFrames;
  // Presigned view URL of the generated listing PDF (resolved by the
  // completed-report hydrator from the carStep S3 key) — shown read-only
  // in the vehicle step (B14). Empty for drafts / reports without one.
  String _listingPdfUrl = '';
  int? _modelGenerationRestylingFrameId;

  // P2/каталог — автокомплит марки/модели (Storage.GetBrand / GetModelCar).
  // Серверная привязка выбранного авто: null = свободный текст (ручной ввод
  // или локальный фолбэк), не привязан к каталогу.
  int? _selectedBrandId;
  int? _selectedModelCarId;
  // Рантайм-кэши автокомплита (НЕ персистятся): каталог марок грузится один
  // раз (GetBrand) и фильтруется локально; модели — по brandId.
  List<storage_api.BrandItem> _brandCatalogCache = const [];
  final Map<int, List<storage_api.ModelItem>> _modelsByBrandId = {};
  bool _brandCatalogLoadStarted = false;

  late final TextEditingController _mileageController;
  late final TextEditingController _engineVolumeController;
  late final TextEditingController _engineTypeController;
  late final TextEditingController _gearboxTypeController;
  late final TextEditingController _driveTypeController;
  late final TextEditingController _colorController;
  late final TextEditingController _trimController;
  late final TextEditingController _ownersCountController;
  late final TextEditingController _inspectionCityController;
  late final TextEditingController _inspectionDateController;

  late final TextEditingController _docsMismatchCommentController;
  late final TextEditingController _legalNoteController;
  late final TextEditingController _tdNoteController;
  late final TextEditingController _summaryController;
  bool _summaryNoteAiBusy = false;
  bool _docsCommentAiBusy = false;
  bool _legalCommentAiBusy = false;
  bool _tdCommentAiBusy = false;
  // VIN→параметры (AiQueue) авто-дозаполнение. _vinParamsAiBusy — гард от
  // конкурентных запусков; _lastVinAutofilled — дедуп, чтобы не гонять модель
  // повторно для того же VIN (авто-триггер → стоимость вызовов под контролем).
  bool _vinParamsAiBusy = false;
  String _lastVinAutofilled = '';
  // Что ИИ записал в целевые поля (ключ→значение) для текущего VIN — чтобы при
  // смене авто очистить только НЕтронутые пользователем (см. staleVinAutofillKeys).
  final Map<String, String> _vinAutofilledValues = {};
  // VIN→идентификация (марка/модель/год) авто-резолв через платный конвертер
  // (_runConverterDeduped — ungated/дедуп/кэш). Гарды зеркалят параметры.
  // Дебаунс — общий _vinParamsAutofillDebounce (один таймер на весь конвейер).
  bool _identityResolveBusy = false;
  String _lastVinIdentityResolved = '';
  // Что авто-конвертер записал в марку/модель ('brand'/'model') — чтобы при смене
  // VIN чистить только НЕтронутое пользователем (staleVinAutofillKeys).
  final Map<String, String> _vinAutoIdentityValues = {};
  // Резолв года из конвертера (UI-поля нет) — грунтовка ИИ-параметров. '' = нет.
  String _resolvedVinYear = '';
  // B2 — ApiCloud legal-review: гейт по праву run_legal_review (читается из
  // кэша прав, который B1 сидит на старте) + однократный ленивый load
  // каталога типов проверок.
  bool _legalCanRunReview = false;
  bool _legalReviewMetaLoadStarted = false;
  // P2 — VIN↔госномер конвертер (api_cloud_converter_search) в шаге «Авто».
  bool _vinConverterBusy = false;
  // Дедуп/кэш конвертера (платный RunBatchLegalReview): один и тот же
  // vin/госномер НЕ должен порождать новый платный запрос. Кэшируем
  // терминальный результат (found/not_found) и схлопываем одновременные
  // запросы на один вход (single-flight). timedOut НЕ кэшируем — транзиентный,
  // позволяем повторить, когда воркер ApiCloud догонит.
  final Map<String, storage_api.VinPlateConverterResult> _converterResultCache =
      {};
  final Map<String, Future<storage_api.VinPlateConverterResult>>
  _converterInFlight = {};
  // Найденная по VIN/госномеру инфа (label→value) для карточки результата.
  Map<String, String> _vinLookupInfo = const <String, String>{};
  // Скан СТС/ПТС (фото → S3 temp/ → AiQueue vision → автозаполнение).
  // Busy-гард одного скана за раз + текст текущего этапа для кнопки.
  bool _docScanBusy = false;
  String _docScanStage = '';
  late final TextEditingController _inspectorController;
  late String _assignedSpecialistId;
  late String _assignedSpecialistName;
  int? _requestId;

  late final String _draftId;
  late final String _reportCode;
  late final String _createdAt;
  late final String _assignmentId;

  // ┌─ Phase 4.1 · Chunk 14: main media / inspection state map → controller ┐
  // │ 40 refs across the whole spark_joy module. Exposes the underlying     │
  // │ RxMap by reference so `_mediaState[key] = ...` keeps working; full    │
  // │ reassignment via setter goes through clear+addAll to preserve the     │
  // │ same RxMap instance (so any future Obx listeners stay subscribed).    │
  // └───────────────────────────────────────────────────────────────────────┘
  Map<String, MediaGroupState> get _mediaState => _reportController.mediaState;
  set _mediaState(Map<String, MediaGroupState> value) {
    _reportController.mediaState
      ..clear()
      ..addAll(value);
  }

  // ┌─ Phase 4.1 · Chunk 11: media-editor tag customization → controller ───┐
  // │ 53 references across 7 files. All usages are wholesale reassignment   │
  // │ (confirmed by grep) so proxying is safe.                              │
  // └───────────────────────────────────────────────────────────────────────┘
  Map<String, List<String>> get _mediaCustomTagsByScope =>
      _reportController.mediaCustomTagsByScope.value;
  set _mediaCustomTagsByScope(Map<String, List<String>> value) =>
      _reportController.mediaCustomTagsByScope.value = value;

  Map<String, List<String>> get _mediaCustomSeriousTagsByScope =>
      _reportController.mediaCustomSeriousTagsByScope.value;
  set _mediaCustomSeriousTagsByScope(Map<String, List<String>> value) =>
      _reportController.mediaCustomSeriousTagsByScope.value = value;

  Map<String, List<String>> get _mediaDisabledDefaultTagsByScope =>
      _reportController.mediaDisabledDefaultTagsByScope.value;
  set _mediaDisabledDefaultTagsByScope(Map<String, List<String>> value) =>
      _reportController.mediaDisabledDefaultTagsByScope.value = value;

  Map<String, List<String>> get _mediaTagOrderByScope =>
      _reportController.mediaTagOrderByScope.value;
  set _mediaTagOrderByScope(Map<String, List<String>> value) =>
      _reportController.mediaTagOrderByScope.value = value;
  final Map<String, Uint8List> _dataUrlImageBytesCache = {};
  // Ids видео, для которых генерация превью (`_generateVideoThumbsForGroup`)
  // завершилась без результата. Пока id здесь нет и превью отсутствует, плитка
  // показывает спиннер «загрузка»; попав сюда — серый плейсхолдер.
  final Set<String> _videoThumbsUnavailable = <String>{};
  String? _appDocumentsPath;
  // Микрофон-permission прокси удалён вместе с recording-инфраструктурой.
  // Дисктовка использует `_speechPermissionGranted` ниже.

  bool get _speechPermissionGranted =>
      _reportController.speechPermissionGranted.value;
  set _speechPermissionGranted(bool value) =>
      _reportController.speechPermissionGranted.value = value;

  final SpeechToText _tdSpeechToText = SpeechToText();

  bool get _tdSpeechInitializing =>
      _reportController.tdSpeechInitializing.value;
  set _tdSpeechInitializing(bool value) =>
      _reportController.tdSpeechInitializing.value = value;

  bool get _tdSpeechAvailable => _reportController.tdSpeechAvailable.value;
  set _tdSpeechAvailable(bool value) =>
      _reportController.tdSpeechAvailable.value = value;

  bool get _tdIsDictating => _reportController.tdIsDictating.value;
  set _tdIsDictating(bool value) =>
      _reportController.tdIsDictating.value = value;

  bool get _tdShouldDictate => _reportController.tdShouldDictate.value;
  set _tdShouldDictate(bool value) =>
      _reportController.tdShouldDictate.value = value;
  Timer? _draftAutosaveDebounce;
  // Дебаунс VIN-конвейера (идентификация + параметры) — гасит посимвольный ввод.
  Timer? _vinParamsAutofillDebounce;
  // Re-entry guard for the brand/model picker — [`_openCarPickerDialog`] is
  // async (awaits `fetchBrandCatalog` before calling `showDialog`), so
  // mashing the "Выбрать автомобиль" tile during a slow network request used
  // to kick off multiple catalogs and stack identical dialogs on top of
  // each other. Flip this while the picker is loading/open.
  bool _carPickerOpening = false;

  // Idempotency guard for the city picker bottom-sheet — same logic as
  // `_carPickerOpening` for the brand-model picker. Prevents stacking
  // duplicate sheets on rapid repeat taps while the dataset loads.
  bool _cityPickerOpening = false;

  // True iff `_inspectionCityController.text` matches an entry in the
  // bundled cities list. Set by the picker on selection (always true)
  // and recomputed against the repository after draft hydration. Read
  // by `spark_joy_completion_rules.dart` as part of the vehicle-step
  // gate — drafts with non-canonical city names cannot be submitted
  // until the inspector reselects a valid city.
  bool _isInspectionCityValid = false;

  // True while a share-link RPC is in flight on the read-only view — keeps
  // the AppBar share icon disabled + spinning so users don't double-tap
  // into duplicate `Storage.CreateSpecialistReportShareUrl` calls.
  bool _shareInProgress = false;
  // ┌─ Phase 4.1 · Chunk 7: draft autosave meta-state → controller ─────────┐
  // │ 43 references across 4 files. Timers + debounce logic remain in the   │
  // │ host widget; only the status flags move.                              │
  // └───────────────────────────────────────────────────────────────────────┘
  bool get _draftSaveInProgress => _reportController.draftSaveInProgress.value;
  set _draftSaveInProgress(bool value) =>
      _reportController.draftSaveInProgress.value = value;

  bool get _draftSaveFailed => _reportController.draftSaveFailed.value;
  set _draftSaveFailed(bool value) =>
      _reportController.draftSaveFailed.value = value;

  bool get _hasUnsavedDraftChanges =>
      _reportController.hasUnsavedDraftChanges.value;
  set _hasUnsavedDraftChanges(bool value) =>
      _reportController.hasUnsavedDraftChanges.value = value;

  bool get _autosaveRequestedWhileSaving =>
      _reportController.autosaveRequestedWhileSaving.value;
  set _autosaveRequestedWhileSaving(bool value) =>
      _reportController.autosaveRequestedWhileSaving.value = value;

  bool get _appPauseHandlingInProgress =>
      _reportController.appPauseHandlingInProgress.value;
  set _appPauseHandlingInProgress(bool value) =>
      _reportController.appPauseHandlingInProgress.value = value;
  DateTime? get _lastDraftSavedAt => _reportController.lastDraftSavedAt.value;
  set _lastDraftSavedAt(DateTime? value) =>
      _reportController.lastDraftSavedAt.value = value;
  final List<TextEditingController> _autosaveControllers = [];

  late final _SparkJoyReportFlowController _reportFlowController;
  late final _SparkJoyStepActionController _stepActionController;
  late final _SparkJoyOverviewController _overviewController;
  int get _stepIndex => _reportFlowController.stepIndex;
  set _stepIndex(int value) => _reportFlowController.stepIndex = value;
  bool get _editingSection => _reportFlowController.editingSection;
  bool get _returnToSummaryOnBack =>
      _reportFlowController.returnToSummaryOnBack;

  final ScrollController _pageScrollController = ScrollController();
  final FocusNode _vinFocusNode = FocusNode();
  final FocusNode _plateFocusNode = FocusNode();
  final FocusNode _adLinkFocusNode = FocusNode();
  final FocusNode _mileageFocusNode = FocusNode();
  final FocusNode _inspectionCityFocusNode = FocusNode();
  // Внешние FocusNode для RawAutocomplete марки/модели (виджет требует
  // передавать textEditingController + focusNode вместе). Контроллеры —
  // `_brandController`/`_modelController` остаются источником истины.
  final FocusNode _brandFocusNode = FocusNode();
  final FocusNode _modelFocusNode = FocusNode();

  // ┌─ Phase 4.1 · Chunk 4: car-step non-controller flags → SparkJoyReportController ┐
  // │ 34 references across 12 files use the old `_mileageMismatch` / `_vinUnreadable` │
  // │ names, including draft init, summary rules, VIN actions, and LKP widgets.      │
  // └─────────────────────────────────────────────────────────────────────────────────┘
  bool? get _mileageMismatch => _reportController.mileageMismatch.value;
  set _mileageMismatch(bool? value) =>
      _reportController.mileageMismatch.value = value;

  bool get _vinUnreadable => _reportController.vinUnreadable.value;
  set _vinUnreadable(bool value) =>
      _reportController.vinUnreadable.value = value;

  PlateCountry get _plateCountry => _reportController.plateCountry.value;
  set _plateCountry(PlateCountry value) =>
      _reportController.plateCountry.value = value;

  bool get _plateCountryLocked => _reportController.plateCountryLocked.value;
  set _plateCountryLocked(bool value) =>
      _reportController.plateCountryLocked.value = value;

  /// Поле было хотя бы раз потеряно фокусом — после этого валидация
  /// формата начинает показывать ошибку. До первого blur ошибку
  /// прячем чтобы не дёргать инспектора по мере набора. State
  /// эфемерный (не сохраняется в черновик).
  bool _plateBlurred = false;

  PlateFormat get _plateFormat => plateFormatFor(_plateCountry);

  bool? _docsOwnerMatch;
  bool? _docsVinMatch;
  bool? _docsEngineMatch;

  // ┌─ Phase 4.1 · Chunk 6: legal-check step state → controller ─────────────┐
  // │ 7 fields (6 bool + 1 int) driving the "Юридическая проверка" UI.       │
  // │ Together with _tdMode (below) these are 103 references across 11 files.│
  // └────────────────────────────────────────────────────────────────────────┘
  bool get _legalLoading => _reportController.legalLoading.value;
  set _legalLoading(bool value) => _reportController.legalLoading.value = value;

  bool get _legalLoaded => _reportController.legalLoaded.value;
  set _legalLoaded(bool value) => _reportController.legalLoaded.value = value;

  bool get _legalSkipped => _reportController.legalSkipped.value;
  set _legalSkipped(bool value) => _reportController.legalSkipped.value = value;

  bool get _legalTimedOut => _reportController.legalTimedOut.value;
  set _legalTimedOut(bool value) =>
      _reportController.legalTimedOut.value = value;

  bool get _legalPurchased => _reportController.legalPurchased.value;
  set _legalPurchased(bool value) =>
      _reportController.legalPurchased.value = value;

  int get _legalLoadToken => _reportController.legalLoadToken.value;
  set _legalLoadToken(int value) =>
      _reportController.legalLoadToken.value = value;

  // B2 — ApiCloud legal-review (Материалы проверки). Proxies to the
  // controller so Obx() in the legal step rebuilds on change.
  List<String> get _legalSelectedCheckTypes =>
      _reportController.legalSelectedCheckTypes;
  set _legalSelectedCheckTypes(List<String> value) =>
      _reportController.legalSelectedCheckTypes.value = value;

  String? get _legalBatchNumber => _reportController.legalBatchNumber.value;
  set _legalBatchNumber(String? value) =>
      _reportController.legalBatchNumber.value = value;

  List<Map<String, dynamic>> get _legalCheckResults =>
      _reportController.legalCheckResults;
  set _legalCheckResults(List<Map<String, dynamic>> value) =>
      _reportController.legalCheckResults.value = value;

  List<({String value, String name})> get _legalAvailableCheckTypes =>
      _reportController.legalAvailableCheckTypes;
  set _legalAvailableCheckTypes(List<({String value, String name})> value) =>
      _reportController.legalAvailableCheckTypes.value = value;
  // ┌─ Phase 4.1 · Chunk 13: uploaded file lists → controller ──────────────┐
  // │ `_UploadedItem` was renamed to `UploadedItem` so the controller can   │
  // │ type them without living in this `part of` library.                   │
  // └───────────────────────────────────────────────────────────────────────┘
  List<UploadedItem> get _legalFiles => _reportController.legalFiles.value;
  set _legalFiles(List<UploadedItem> value) =>
      _reportController.legalFiles.value = value;

  // Audio-комментарии (UI recorder + playback) полностью убраны. Поля
  // ниже остаются как пустые-по-умолчанию proxies — нужны для
  // draft serialize/hydrate путей, которые ещё знают о ключах
  // *audioFiles. UI к ним не пишет.
  List<UploadedItem> get _docsCommentAudioFiles =>
      _reportController.docsCommentAudioFiles.value;
  set _docsCommentAudioFiles(List<UploadedItem> value) =>
      _reportController.docsCommentAudioFiles.value = value;

  List<UploadedItem> get _legalCommentAudioFiles =>
      _reportController.legalCommentAudioFiles.value;
  set _legalCommentAudioFiles(List<UploadedItem> value) =>
      _reportController.legalCommentAudioFiles.value = value;

  // ┌─ Phase 4.1 · Chunk 9: per-step dictation flags → controller ──────────┐
  // └───────────────────────────────────────────────────────────────────────┘
  bool get _docsIsDictating => _reportController.docsIsDictating.value;
  set _docsIsDictating(bool value) =>
      _reportController.docsIsDictating.value = value;

  bool get _docsShouldDictate => _reportController.docsShouldDictate.value;
  set _docsShouldDictate(bool value) =>
      _reportController.docsShouldDictate.value = value;

  bool get _legalIsDictating => _reportController.legalIsDictating.value;
  set _legalIsDictating(bool value) =>
      _reportController.legalIsDictating.value = value;

  bool get _legalShouldDictate => _reportController.legalShouldDictate.value;
  set _legalShouldDictate(bool value) =>
      _reportController.legalShouldDictate.value = value;

  bool get _summaryIsDictating => _reportController.summaryIsDictating.value;
  set _summaryIsDictating(bool value) =>
      _reportController.summaryIsDictating.value = value;

  bool get _summaryShouldDictate =>
      _reportController.summaryShouldDictate.value;
  set _summaryShouldDictate(bool value) =>
      _reportController.summaryShouldDictate.value = value;

  // ┌─ Phase 4.1 · Chunk 5: paintwork thickness ranges → controller ───────┐
  // │ Body and body-reinforcement μm ranges, 24 refs across 4 files.       │
  // └──────────────────────────────────────────────────────────────────────┘
  double get _bodyPaintFrom => _reportController.bodyPaintFrom.value;
  set _bodyPaintFrom(double value) =>
      _reportController.bodyPaintFrom.value = value;

  double get _bodyPaintTo => _reportController.bodyPaintTo.value;
  set _bodyPaintTo(double value) => _reportController.bodyPaintTo.value = value;
  double get _structPaintFrom => _reportController.structPaintFrom.value;
  set _structPaintFrom(double value) =>
      _reportController.structPaintFrom.value = value;

  double get _structPaintTo => _reportController.structPaintTo.value;
  set _structPaintTo(double value) =>
      _reportController.structPaintTo.value = value;

  String? get _tdMode => _reportController.tdMode.value;
  set _tdMode(String? value) => _reportController.tdMode.value = value;
  // ┌─ Phase 4.1 · Chunk 2: test-drive booleans moved to the controller ─────┐
  // │ 65 references across 7 files read/write these via the same `_tdXxxOk`  │
  // │ field names — the getter/setter pair keeps them compiling unchanged.   │
  // └────────────────────────────────────────────────────────────────────────┘
  bool get _tdEngineOk => _reportController.tdEngineOk.value;
  set _tdEngineOk(bool value) => _reportController.tdEngineOk.value = value;

  bool get _tdGearboxOk => _reportController.tdGearboxOk.value;
  set _tdGearboxOk(bool value) => _reportController.tdGearboxOk.value = value;

  bool get _tdSteeringOk => _reportController.tdSteeringOk.value;
  set _tdSteeringOk(bool value) => _reportController.tdSteeringOk.value = value;

  bool get _tdRideOk => _reportController.tdRideOk.value;
  set _tdRideOk(bool value) => _reportController.tdRideOk.value = value;

  bool get _tdBrakeOk => _reportController.tdBrakeOk.value;
  set _tdBrakeOk(bool value) => _reportController.tdBrakeOk.value = value;
  // ┌─ Phase 4.1 · Chunk 1: test-drive tags moved to SparkJoyReportController ┐
  // │ Old direct fields are now getter/setter proxies so the 73 existing     │
  // │ `_tdEngineTags = ...` / reads across 7 files keep compiling unchanged. │
  // │ Fresh `List<String>` copies are returned on read to preserve the       │
  // │ previous `const []` / non-mutable invariant.                           │
  // └────────────────────────────────────────────────────────────────────────┘
  List<String> get _tdEngineTags =>
      List<String>.of(_reportController.tdEngineTags);
  set _tdEngineTags(List<String> value) =>
      _reportController.setTdEngineTags(value);

  List<String> get _tdGearboxTags =>
      List<String>.of(_reportController.tdGearboxTags);
  set _tdGearboxTags(List<String> value) =>
      _reportController.setTdGearboxTags(value);

  List<String> get _tdSteeringTags =>
      List<String>.of(_reportController.tdSteeringTags);
  set _tdSteeringTags(List<String> value) =>
      _reportController.setTdSteeringTags(value);

  List<String> get _tdRideTags => List<String>.of(_reportController.tdRideTags);
  set _tdRideTags(List<String> value) => _reportController.setTdRideTags(value);

  List<String> get _tdBrakeTags =>
      List<String>.of(_reportController.tdBrakeTags);
  set _tdBrakeTags(List<String> value) =>
      _reportController.setTdBrakeTags(value);
  List<UploadedItem> get _tdCommentAudioFiles =>
      _reportController.tdCommentAudioFiles.value;
  set _tdCommentAudioFiles(List<UploadedItem> value) =>
      _reportController.tdCommentAudioFiles.value = value;

  List<UploadedItem> get _expertAudioFiles =>
      _reportController.expertAudioFiles.value;
  set _expertAudioFiles(List<UploadedItem> value) =>
      _reportController.expertAudioFiles.value = value;
  // ┌─ Phase 4.1 · Chunk 3: business / staff-invite state moved to controller ┐
  // │ 28 references across 5 files (including the `??=` assign-if-null usage  │
  // │ in vehicle_business_helpers) keep working through these proxies.        │
  // └─────────────────────────────────────────────────────────────────────────┘
  String? get _accountBusinessType =>
      _reportController.accountBusinessType.value;
  set _accountBusinessType(String? value) =>
      _reportController.accountBusinessType.value = value;

  String? get _accountVerifiedInn => _reportController.accountVerifiedInn.value;
  set _accountVerifiedInn(String? value) =>
      _reportController.accountVerifiedInn.value = value;

  String get _staffInviteLink => _reportController.staffInviteLink.value;
  set _staffInviteLink(String value) =>
      _reportController.staffInviteLink.value = value;

  String? _activeMediaGroupKey;
  double? _mediaGroupListScrollOffset;
  // Контроллер скролла stepper'а группы Осмотра — нужен для auto-scroll
  // к активному шагу при переключении (иначе текущий может оказаться
  // за пределами viewport'а если он далеко в списке).
  final ScrollController _mediaGroupChipScrollController = ScrollController();
  // Ключ группы для которой auto-scroll уже отработал. Без этого stepper
  // перестраивался бы на каждый keystroke в заметке/тег/файл и каждый
  // раз планировал бы ensureVisible — конфликтуя с ручным скроллом.
  String? _mediaGroupChipLastScrolledKey;
  // Стабильные GlobalKey для каждого шага stepper'а — нужны для
  // `Scrollable.ensureVisible(stepKeyContext)` точного центрирования.
  // Создаются лениво, хранятся в state чтобы переживать rebuild'ы.
  final Map<String, GlobalKey> _mediaGroupStepKeys = <String, GlobalKey>{};
  bool _mediaGroupSelectMode = false;
  Set<int> _mediaGroupSelectedIndexes = <int>{};
  bool _mediaPickerOpening = false;
  String? _mediaPickerGroupKey;
  DateTime? _mediaPickerStartedAt;
  int? _mediaGroupPressedIndex;
  String? _mediaListPressedGroupKey;
  // ┌─ Phase 4.1 · Chunk 12: backend S3 upload progress → controller ──────┐
  // │ 75 refs across 5 files. Typed List<BackendUploadFileProgress>       │
  // │ stays in the host until the item class is made public (chunk 13).   │
  // └──────────────────────────────────────────────────────────────────────┘
  Map<String, dynamic> get _backendUploadState =>
      _reportController.backendUploadState.value;
  set _backendUploadState(Map<String, dynamic> value) =>
      _reportController.backendUploadState.value = value;

  // Transient flag — set when the user taps «Отменить выгрузку» mid-upload.
  // Checked between files and before finalizing so the report isn't
  // submitted, and open multipart sessions are aborted (B17). Reset at the
  // start of every upload run.
  bool _uploadCancelled = false;

  bool get _backendUploadInProgress =>
      _reportController.backendUploadInProgress.value;
  set _backendUploadInProgress(bool value) =>
      _reportController.backendUploadInProgress.value = value;

  bool get _backendUploadFailed => _reportController.backendUploadFailed.value;
  set _backendUploadFailed(bool value) =>
      _reportController.backendUploadFailed.value = value;

  String get _backendUploadStatusText =>
      _reportController.backendUploadStatusText.value;
  set _backendUploadStatusText(String value) =>
      _reportController.backendUploadStatusText.value = value;

  String get _backendUploadErrorText =>
      _reportController.backendUploadErrorText.value;
  set _backendUploadErrorText(String value) =>
      _reportController.backendUploadErrorText.value = value;

  int get _backendUploadCurrentFile =>
      _reportController.backendUploadCurrentFile.value;
  set _backendUploadCurrentFile(int value) =>
      _reportController.backendUploadCurrentFile.value = value;

  int get _backendUploadTotalFiles =>
      _reportController.backendUploadTotalFiles.value;
  set _backendUploadTotalFiles(int value) =>
      _reportController.backendUploadTotalFiles.value = value;

  int get _backendUploadCurrentPart =>
      _reportController.backendUploadCurrentPart.value;
  set _backendUploadCurrentPart(int value) =>
      _reportController.backendUploadCurrentPart.value = value;

  int get _backendUploadTotalParts =>
      _reportController.backendUploadTotalParts.value;
  set _backendUploadTotalParts(int value) =>
      _reportController.backendUploadTotalParts.value = value;

  List<BackendUploadFileProgress> get _backendUploadFilesProgress =>
      _reportController.backendUploadFilesProgress.value;
  set _backendUploadFilesProgress(List<BackendUploadFileProgress> value) =>
      _reportController.backendUploadFilesProgress.value = value;

  bool get _backendFileUploadLocked =>
      _reportController.backendFileUploadLocked.value;
  set _backendFileUploadLocked(bool value) =>
      _reportController.backendFileUploadLocked.value = value;
  int _uploadedItemIdCounter = 0;
  final Map<String, int> _localSavedFileNameUsages = <String, int>{};

  /// Tag RPC + cache layer. All reads/writes to the name → server-id map
  /// go through this service; the spark_joy_storage_helpers extension
  /// holds only thin wrappers that collect host-state context.
  final SparkJoyTagService _tagService = SparkJoyTagService();

  /// Reactive store for the report's domain state. Currently owns only the
  /// five test-drive tag lists (Phase 4.1 · Chunk 1); further chunks will
  /// migrate additional fields incrementally.
  final SparkJoyReportController _reportController = SparkJoyReportController();

  String _nextUploadedItemId({String prefix = 'upload'}) {
    _uploadedItemIdCounter += 1;
    return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_$_uploadedItemIdCounter';
  }

  @override
  void initState() {
    super.initState();
    _reportFlowController = _SparkJoyReportFlowController();
    _stepActionController = const _SparkJoyStepActionController();
    _overviewController = const _SparkJoyOverviewController();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_prepareStoragePaths());
    final draft = widget.draft ?? <String, dynamic>{};
    final assignment = widget.assignment ?? <String, dynamic>{};
    final isNewDraft = widget.draft == null;
    final now = DateTime.now();
    _loadDraftIntoState(draft: draft, assignment: assignment, now: now);

    _finalizeInitializationAfterDraftLoad();
    // Tag id resolution / custom-tag seeding only matters while editing — it
    // resolves name→id for newly picked/created tags and seeds editable
    // custom-tag chips. A read-only view of a completed report already carries
    // its tags from the hydrator, so skip the per-section GetUserTags fan-out
    // entirely when just viewing (B19).
    if (!widget.readOnly) {
      unawaited(_loadTagIdsFromServer());
    }

    // Jump straight to the summary step for read-only views of completed
    // reports — opening a completed report from the list should land on
    // the recap layout, not the first unfilled step of the edit flow.
    if (widget.readOnly) {
      final summaryIndex = _SparkJoyStepRegistry.indexById(
        _SparkJoyStepRegistry.idSummary,
      );
      final target = widget.initialStepIndex ?? summaryIndex;
      if (target >= 0 && target < _SparkJoyStepRegistry.steps.length) {
        _reportFlowController.openSection(
          target,
          totalSteps: _SparkJoyStepRegistry.steps.length,
        );
      }
    }

    // Persist the draft immediately on new-report entry so it shows up in
    // the "Черновики" list as soon as the user names it, even before any
    // field is filled. Without this, the draft lives only in memory until
    // the first _markDraftDirty call. Skip in read-only mode — no mutation
    // should ever reach storage when viewing a completed report.
    if (isNewDraft && !widget.readOnly) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_saveDraft(showToast: false));
      });
    }

    // First-time stepper explainer — only in edit mode (read-only viewers
    // do not need a tour of the editing flow).
    if (!widget.readOnly) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        SparkJoyOnboarding.showOnce(
          context,
          flagKey: UserSimplePreferences.sparkOnbReportEditorKey,
          titleI18nKey: 'spark.onboarding.reportEditor.title',
          titleFallback: 'Заполнение отчёта по шагам',
          bullets: const [
            SparkJoyOnboardingBullet(
              i18nKey: 'spark.onboarding.reportEditor.b1',
              fallback:
                  'Отчёт собирается по разделам: автомобиль, параметры, документы, осмотр, тест-драйв и итог.',
              icon: Icons.view_list_rounded,
            ),
            SparkJoyOnboardingBullet(
              i18nKey: 'spark.onboarding.reportEditor.b2',
              fallback:
                  'Можно заполнять разделы в любом порядке — данные сохраняются автоматически.',
              icon: Icons.save_outlined,
            ),
            SparkJoyOnboardingBullet(
              i18nKey: 'spark.onboarding.reportEditor.b3',
              fallback:
                  'Чтобы выгрузить отчёт, дойдите до раздела «Итог» и нажмите «Завершить».',
              icon: Icons.task_alt_rounded,
            ),
          ],
        );
      });
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_tdSpeechToText.stop());
    _draftAutosaveDebounce?.cancel();
    _vinParamsAutofillDebounce?.cancel();
    _detachAutosaveListeners();
    _disposeInputResources();
    _disposeRuntimeResources();
    _reportController.onClose();

    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_handleAppPausedOrInactive());
    }
  }

  void _setStateSafely(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return _buildReportEditorShell(context);
  }
}
