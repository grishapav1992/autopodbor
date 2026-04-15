// ---------------------------------------------------------------------------
// Step & wizard config
// ---------------------------------------------------------------------------

class SjStepConfig {
  const SjStepConfig({
    required this.id,
    required this.title,
    required this.description,
  });

  final String id;
  final String title;
  final String description;
}

// ---------------------------------------------------------------------------
// Media group configuration
// ---------------------------------------------------------------------------

class SjMediaGroupConfig {
  const SjMediaGroupConfig({
    required this.key,
    required this.title,
    required this.description,
    required this.required,
    required this.severeIfIssue,
  });

  final String key;
  final String title;
  final String description;
  final bool required;
  final bool severeIfIssue;
}

// ---------------------------------------------------------------------------
// Media group runtime state
// ---------------------------------------------------------------------------

class SjMediaGroupState {
  const SjMediaGroupState({
    required this.config,
    required this.hasIssue,
    required this.note,
    required this.rawUrls,
    required this.files,
    this.partInspection = const SjMediaPartInspection(),
  });

  final SjMediaGroupConfig config;
  final bool hasIssue;
  final String note;
  final String rawUrls;
  final List<SjUploadedItem> files;
  final SjMediaPartInspection partInspection;

  SjMediaGroupState copyWith({
    bool? hasIssue,
    String? note,
    String? rawUrls,
    List<SjUploadedItem>? files,
    SjMediaPartInspection? partInspection,
  }) {
    return SjMediaGroupState(
      config: config,
      hasIssue: hasIssue ?? this.hasIssue,
      note: note ?? this.note,
      rawUrls: rawUrls ?? this.rawUrls,
      files: files ?? this.files,
      partInspection: partInspection ?? this.partInspection,
    );
  }
}

// ---------------------------------------------------------------------------
// Media element / tag options
// ---------------------------------------------------------------------------

class SjMediaOption {
  const SjMediaOption({required this.id, required this.label});

  final String id;
  final String label;
}

class SjMediaTagOption {
  const SjMediaTagOption({
    required this.label,
    required this.severity,
    this.isCustom = false,
  });

  final String label;
  final String severity;
  final bool isCustom;
}

class SjMediaTagGroup {
  const SjMediaTagGroup({
    required this.title,
    required this.severity,
    required this.options,
  });

  final String title;
  final String severity;
  final List<SjMediaTagOption> options;
}

// ---------------------------------------------------------------------------
// Media inspection (per-file and per-part)
// ---------------------------------------------------------------------------

class SjMediaPartInspection {
  const SjMediaPartInspection({
    this.noDamage = false,
    this.tags = const [],
    this.note = '',
    this.elementType,
    this.audioRecordings = const [],
    this.paintFrom,
    this.paintTo,
    this.tagPhotos = const {},
    this.isDraft = true,
  });

  final bool noDamage;
  final List<String> tags;
  final String note;
  final String? elementType;
  final List<String> audioRecordings;
  final double? paintFrom;
  final double? paintTo;
  final Map<String, List<String>> tagPhotos;
  final bool isDraft;

  SjMediaPartInspection copyWith({
    bool? noDamage,
    List<String>? tags,
    String? note,
    String? elementType,
    List<String>? audioRecordings,
    double? paintFrom,
    double? paintTo,
    Map<String, List<String>>? tagPhotos,
    bool? isDraft,
  }) {
    return SjMediaPartInspection(
      noDamage: noDamage ?? this.noDamage,
      tags: tags ?? this.tags,
      note: note ?? this.note,
      elementType: elementType ?? this.elementType,
      audioRecordings: audioRecordings ?? this.audioRecordings,
      paintFrom: paintFrom ?? this.paintFrom,
      paintTo: paintTo ?? this.paintTo,
      tagPhotos: tagPhotos ?? this.tagPhotos,
      isDraft: isDraft ?? this.isDraft,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'noDamage': noDamage,
      'tags': tags,
      'note': note,
      'elementType': elementType,
      'audioRecordings': audioRecordings,
      'paintFrom': paintFrom,
      'paintTo': paintTo,
      if (paintFrom != null && paintTo != null)
        'paintThickness': {'from': paintFrom, 'to': paintTo},
      'isDraft': isDraft,
    };
  }
}

class SjMediaInspection {
  const SjMediaInspection({
    this.noDamage = false,
    this.tags = const [],
    this.note = '',
    this.elementType,
    this.audioRecordings = const [],
    this.paintFrom,
    this.paintTo,
    this.isDraft = false,
  });

  final bool noDamage;
  final List<String> tags;
  final String note;
  final String? elementType;
  final List<String> audioRecordings;
  final double? paintFrom;
  final double? paintTo;
  final bool isDraft;

  SjMediaInspection copyWith({
    bool? noDamage,
    List<String>? tags,
    String? note,
    String? elementType,
    List<String>? audioRecordings,
    double? paintFrom,
    double? paintTo,
    bool? isDraft,
  }) {
    return SjMediaInspection(
      noDamage: noDamage ?? this.noDamage,
      tags: tags ?? this.tags,
      note: note ?? this.note,
      elementType: elementType ?? this.elementType,
      audioRecordings: audioRecordings ?? this.audioRecordings,
      paintFrom: paintFrom ?? this.paintFrom,
      paintTo: paintTo ?? this.paintTo,
      isDraft: isDraft ?? this.isDraft,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'noDamage': noDamage,
      'tags': tags,
      'note': note,
      'elementType': elementType,
      'audioRecordings': audioRecordings,
      'paintFrom': paintFrom,
      'paintTo': paintTo,
      if (paintFrom != null && paintTo != null)
        'paintThickness': {'from': paintFrom, 'to': paintTo},
      'isDraft': isDraft,
    };
  }
}

// ---------------------------------------------------------------------------
// Uploaded file item
// ---------------------------------------------------------------------------

class SjUploadedItem {
  const SjUploadedItem({
    required this.id,
    required this.name,
    required this.mimeType,
    required this.dataUrl,
    this.inspection = const SjMediaInspection(),
  });

  final String id;
  final String name;
  final String mimeType;
  final String dataUrl;
  final SjMediaInspection inspection;

  SjUploadedItem copyWith({
    String? id,
    String? name,
    String? mimeType,
    String? dataUrl,
    SjMediaInspection? inspection,
  }) {
    return SjUploadedItem(
      id: id ?? this.id,
      name: name ?? this.name,
      mimeType: mimeType ?? this.mimeType,
      dataUrl: dataUrl ?? this.dataUrl,
      inspection: inspection ?? this.inspection,
    );
  }

  bool get isImage => mimeType.startsWith('image/');
  bool get isVideo => mimeType.startsWith('video/');
  bool get isAudio => mimeType.startsWith('audio/');
}

// ---------------------------------------------------------------------------
// Summary
// ---------------------------------------------------------------------------

class SjSummaryAttachmentStats {
  const SjSummaryAttachmentStats({
    required this.total,
    required this.imageCount,
    required this.videoCount,
    required this.audioCount,
    required this.fileCount,
    required this.brokenCount,
  });

  final int total;
  final int imageCount;
  final int videoCount;
  final int audioCount;
  final int fileCount;
  final int brokenCount;
}

class SjCalculatedSummary {
  const SjCalculatedSummary({
    required this.score,
    required this.verdict,
    required this.verdictLabel,
    required this.sections,
    required this.checklist,
    required this.fullInspection,
  });

  final int score;
  final String verdict;
  final String verdictLabel;
  final List<Map<String, dynamic>> sections;
  final List<String> checklist;
  final bool fullInspection;
}

// ---------------------------------------------------------------------------
// Car catalog / picker
// ---------------------------------------------------------------------------

enum SjCarPickerStep { brand, model, generation, restyling }

class SjCarPickerSelection {
  const SjCarPickerSelection({
    required this.brand,
    required this.model,
    required this.generation,
    required this.restyling,
    required this.frames,
    required this.photoUrl,
  });

  final String brand;
  final String model;
  final String generation;
  final String restyling;
  final String frames;
  final String photoUrl;
}

class SjCarCatalogBrand {
  const SjCarCatalogBrand({required this.name, required this.models});

  final String name;
  final List<SjCarCatalogModel> models;
}

class SjCarCatalogModel {
  const SjCarCatalogModel({required this.name, required this.generations});

  final String name;
  final List<SjCarCatalogGeneration> generations;
}

class SjCarCatalogGeneration {
  const SjCarCatalogGeneration({required this.name, required this.restylings});

  final String name;
  final List<SjCarCatalogRestyling> restylings;
}

class SjCarCatalogRestyling {
  const SjCarCatalogRestyling({
    required this.label,
    required this.frames,
    required this.photoUrl,
  });

  final String label;
  final String frames;
  final String photoUrl;
}
