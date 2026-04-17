import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:camerawesome/camerawesome_plugin.dart' as cam;
import 'package:camerawesome/pigeon.dart' as cam_pigeon;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_application_1/core/constants/app_colors.dart';
import 'package:flutter_application_1/core/constants/app_sizes.dart';
import 'package:flutter_application_1/data/api/storage_api.dart' as storage_api;
import 'package:flutter_application_1/ui/common/widgets/my_text_widget.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_comment_components.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_comment_utils.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_data.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_i18n.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_storage.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_tokens.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/spark_joy_ui.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/vin_ocr_service.dart';
import 'package:flutter_application_1/ui/mobile/screens/dealer/spark_joy/vin_ocr_types.dart';
import 'package:image/image.dart' as img;
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:video_player/video_player.dart';

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
part 'spark_joy_comment_audio_helpers.dart';
part 'spark_joy_file_picker_helpers.dart';
part 'spark_joy_car_picker_helpers.dart';
part 'spark_joy_vin_actions_helpers.dart';
part 'spark_joy_lifecycle_helpers.dart';
part 'spark_joy_media_state_helpers.dart';
part 'spark_joy_init_dispose_helpers.dart';
part 'spark_joy_draft_init_helpers.dart';
part 'spark_joy_report_editor_shell.dart';
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
  });

  final String? initialReportName;
  final String? initialAssignedSpecialistId;
  final String? initialAssignedSpecialistName;
  final String? initialStaffInviteLink;
  final Map<String, dynamic>? draft;
  final Map<String, dynamic>? assignment;

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
  late final TextEditingController _expertController;
  late final TextEditingController _inspectorController;
  late String _assignedSpecialistId;
  late String _assignedSpecialistName;

  late final String _draftId;
  late final String _reportCode;
  late final String _createdAt;
  late final String _assignmentId;

  late Map<String, _MediaGroupState> _mediaState;
  Map<String, List<String>> _mediaCustomTagsByScope = {};
  Map<String, List<String>> _mediaCustomSeriousTagsByScope = {};
  Map<String, List<String>> _mediaDisabledDefaultTagsByScope = {};
  Map<String, List<String>> _mediaTagOrderByScope = {};
  final Map<String, Uint8List> _dataUrlImageBytesCache = {};
  final Map<String, String> _resolvedAudioPlaybackSources = {};
  String? _appDocumentsPath;
  bool _microphonePermissionGranted = false;
  bool _speechPermissionGranted = false;
  final SpeechToText _tdSpeechToText = SpeechToText();
  bool _tdSpeechInitializing = false;
  bool _tdSpeechAvailable = false;
  bool _tdIsDictating = false;
  bool _tdShouldDictate = false;
  Timer? _draftAutosaveDebounce;
  bool _draftSaveInProgress = false;
  bool _draftSaveFailed = false;
  bool _hasUnsavedDraftChanges = false;
  bool _autosaveRequestedWhileSaving = false;
  bool _appPauseHandlingInProgress = false;
  DateTime? _lastDraftSavedAt;
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

  bool? _mileageMismatch;
  bool _vinUnreadable = false;

  bool? _docsOwnerMatch;
  bool? _docsVinMatch;
  bool? _docsEngineMatch;

  bool _legalLoading = false;
  bool _legalLoaded = false;
  bool _legalSkipped = false;
  bool _legalTimedOut = false;
  bool _legalPurchased = false;
  int _legalLoadToken = 0;
  List<_UploadedItem> _legalFiles = const [];
  List<_UploadedItem> _docsCommentAudioFiles = const [];
  List<_UploadedItem> _legalCommentAudioFiles = const [];
  final AudioPlayer _sectionCommentAudioPlayer = AudioPlayer();
  StreamSubscription<void>? _sectionCommentAudioCompleteSub;
  final AudioRecorder _sectionCommentRecorder = AudioRecorder();
  StreamSubscription<Uint8List>? _sectionCommentRecordSub;
  Timer? _sectionCommentRecordTimer;
  BytesBuilder? _sectionCommentRecordBuffer;
  String? _activeSectionCommentRecordingKey;
  final Map<String, int> _sectionCommentRecordingSeconds = {};
  int _docsCommentPlayingAudioIndex = -1;
  int _legalCommentPlayingAudioIndex = -1;
  int _tdCommentPlayingAudioIndex = -1;
  int _expertCommentPlayingAudioIndex = -1;
  bool _docsIsDictating = false;
  bool _docsShouldDictate = false;
  bool _legalIsDictating = false;
  bool _legalShouldDictate = false;
  bool _expertIsDictating = false;
  bool _expertShouldDictate = false;

  double _bodyPaintFrom = 80;
  double _bodyPaintTo = 200;
  double _structPaintFrom = 80;
  double _structPaintTo = 200;

  String? _tdMode;
  bool _tdEngineOk = false;
  bool _tdGearboxOk = false;
  bool _tdSteeringOk = false;
  bool _tdRideOk = false;
  bool _tdBrakeOk = false;
  List<String> _tdEngineTags = const [];
  List<String> _tdGearboxTags = const [];
  List<String> _tdSteeringTags = const [];
  List<String> _tdRideTags = const [];
  List<String> _tdBrakeTags = const [];
  final Map<String, String?> _tdManagingTagSeverityByScope = {};
  final Map<String, TextEditingController> _tdCustomTagControllersByScope = {};
  final Map<String, FocusNode> _tdCustomTagFocusNodesByScope = {};
  List<_UploadedItem> _tdCommentAudioFiles = const [];

  List<_UploadedItem> _expertAudioFiles = const [];
  String? _accountBusinessType;
  String? _accountVerifiedInn;
  String _staffInviteLink = '';
  bool _staffInviteLinkCreating = false;

  String? _activeMediaGroupKey;
  double? _mediaGroupListScrollOffset;
  bool _mediaGroupSelectMode = false;
  Set<int> _mediaGroupSelectedIndexes = <int>{};
  bool _mediaPickerOpening = false;
  String? _mediaPickerGroupKey;
  DateTime? _mediaPickerStartedAt;
  int? _mediaGroupPressedIndex;
  String? _mediaListPressedGroupKey;
  Map<String, dynamic> _backendUploadState = {};
  bool _backendUploadInProgress = false;
  bool _backendUploadFailed = false;
  String _backendUploadStatusText = '';
  String _backendUploadErrorText = '';
  int _backendUploadCurrentFile = 0;
  int _backendUploadTotalFiles = 0;
  int _backendUploadCurrentPart = 0;
  int _backendUploadTotalParts = 0;
  List<_BackendUploadFileProgress> _backendUploadFilesProgress = const [];
  bool _backendFileUploadLocked = false;
  int _uploadedItemIdCounter = 0;
  final Map<String, int> _localSavedFileNameUsages = <String, int>{};

  /// Maps tag name (lowercased) → server-side integer ID.
  /// Populated by [_loadTagIdsFromServer] during initialization.
  final Map<String, int> _tagNameToId = <String, int>{};

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
    final now = DateTime.now();
    _loadDraftIntoState(draft: draft, assignment: assignment, now: now);

    _finalizeInitializationAfterDraftLoad();
    unawaited(_loadTagIdsFromServer());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_tdSpeechToText.stop());
    _draftAutosaveDebounce?.cancel();
    _detachAutosaveListeners();
    _disposeInputResources();
    _disposeRuntimeResources();

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
