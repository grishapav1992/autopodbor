class SparkJoyReportRequestContext {
  const SparkJoyReportRequestContext({
    this.requestId,
    this.specialistId,
    this.requestNumber = '',
    this.specialistName = '',
    this.specialistPhone = '',
    this.specialistAvatarUrl = '',
  });

  final int? requestId;
  final int? specialistId;
  final String requestNumber;
  final String specialistName;
  final String specialistPhone;
  final String specialistAvatarUrl;

  bool get hasRequest => requestNumber.trim().isNotEmpty;

  bool get canOpenRequest => requestId != null;

  bool get hasSpecialist =>
      specialistName.trim().isNotEmpty ||
      specialistPhone.trim().isNotEmpty ||
      specialistAvatarUrl.trim().isNotEmpty;

  bool get hasAny => hasRequest || hasSpecialist;

  String get requestLabel {
    final number = requestNumber.trim();
    if (number.isNotEmpty) return 'Заявка №$number';
    return 'Заявка';
  }

  String get specialistLabel {
    final name = specialistName.trim();
    if (name.isNotEmpty) return name;
    final phone = specialistPhone.trim();
    if (phone.isNotEmpty) return phone;
    final id = specialistId;
    return id == null ? '' : 'Специалист #$id';
  }

  List<String> get searchTokens => <String>[
    if (requestId != null) requestId.toString(),
    requestNumber,
    specialistId?.toString() ?? '',
    specialistName,
    specialistPhone,
  ].where((value) => value.trim().isNotEmpty).toList(growable: false);
}

SparkJoyReportRequestContext sparkJoyReportRequestContext(
  Map<String, dynamic> source,
) {
  final request = _firstMap(source, const [
    'request',
    'companyRequest',
    'storageRequest',
  ]);
  final directSpecialist = _firstMap(source, const [
    'assignedSpecialist',
    'specialist',
    'executor',
    'performer',
  ]);
  final requestSpecialist = _firstMap(request, const [
    'assignedSpecialist',
    'specialist',
    'executor',
    'performer',
  ]);
  final specialist = directSpecialist.isNotEmpty
      ? directSpecialist
      : requestSpecialist;

  final requestId =
      _readInt(source, const ['requestId', 'request_id', 'companyRequestId']) ??
      _readInt(request, const ['id', 'requestId', 'request_id']);
  // Do not read top-level `requestNumber` here: completed report payloads
  // also use that key for the report number. Request number is trustworthy
  // only when it comes from an explicit request object or request-specific
  // aliases.
  final explicitRequestNumber = _readString(
    request,
    const ['requestNumber', 'request_number', 'number', 'code'],
    fallback: _readString(source, const [
      'companyRequestNumber',
      'linkedRequestNumber',
      'sourceRequestNumber',
      'taskRequestNumber',
    ]),
  );
  final requestNumber = explicitRequestNumber.isNotEmpty
      ? explicitRequestNumber
      : _readRequestNumberFromTitle(
          _readString(source, const ['reportName', 'title', 'name']),
        );

  final specialistId =
      _readInt(source, const [
        'assignedSpecialistId',
        'assignedSpecialistUserId',
        'specialistId',
        'specialistUserId',
      ]) ??
      _readInt(request, const [
        'assignedSpecialistId',
        'assignedSpecialistUserId',
        'specialistId',
        'specialistUserId',
      ]) ??
      _readInt(specialist, const ['id', 'userId', 'specialistId']);
  final specialistName = _readString(
    source,
    const [
      'assignedSpecialistName',
      'specialistName',
      'expertName',
      'inspector',
    ],
    fallback: _readString(request, const [
      'assignedSpecialistName',
      'specialistName',
      'expertName',
      'inspector',
    ], fallback: _specialistDisplayName(specialist)),
  );
  final specialistPhone = _readString(
    source,
    const ['assignedSpecialistPhone', 'specialistPhone'],
    fallback: _readString(request, const [
      'assignedSpecialistPhone',
      'specialistPhone',
    ], fallback: _readString(specialist, const ['phone', 'contactPhone'])),
  );
  final specialistAvatarUrl = _readString(
    source,
    const [
      'assignedSpecialistAvatarUrl',
      'specialistAvatarUrl',
      'specialistUrlAvatar',
    ],
    fallback: _readString(
      request,
      const [
        'assignedSpecialistAvatarUrl',
        'specialistAvatarUrl',
        'specialistUrlAvatar',
      ],
      fallback: _readString(specialist, const [
        'urlAvatar',
        'avatarUrl',
        'photoUrl',
        'imageUrl',
      ]),
    ),
  );

  return SparkJoyReportRequestContext(
    requestId: requestId,
    requestNumber: requestNumber,
    specialistId: specialistId,
    specialistName: specialistName == 'Специалист' ? '' : specialistName,
    specialistPhone: specialistPhone,
    specialistAvatarUrl: specialistAvatarUrl,
  );
}

String _readRequestNumberFromTitle(String title) {
  final match = RegExp(
    r'заявк[аи]\s*(?:№|N|#)?\s*([A-Za-zА-Яа-я0-9-]+)',
    caseSensitive: false,
  ).firstMatch(title.trim());
  return match?.group(1)?.trim() ?? '';
}

Map<String, dynamic> sparkJoyRequestInitialFromReport(
  Map<String, dynamic> report,
) {
  final context = sparkJoyReportRequestContext(report);
  final initial = <String, dynamic>{};
  if (context.requestId != null) initial['id'] = context.requestId;
  if (context.requestNumber.trim().isNotEmpty) {
    initial['requestNumber'] = context.requestNumber.trim();
  }
  if (context.specialistId != null) {
    initial['assignedSpecialistId'] = context.specialistId;
  }
  if (context.hasSpecialist) {
    initial['assignedSpecialist'] = <String, dynamic>{
      if (context.specialistId != null) 'id': context.specialistId,
      if (context.specialistName.trim().isNotEmpty)
        'fullName': context.specialistName.trim(),
      if (context.specialistPhone.trim().isNotEmpty)
        'phone': context.specialistPhone.trim(),
      if (context.specialistAvatarUrl.trim().isNotEmpty)
        'urlAvatar': context.specialistAvatarUrl.trim(),
    };
  }
  return initial;
}

Map<String, dynamic> _firstMap(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final value = source[key];
    if (value is Map) return Map<String, dynamic>.from(value);
  }
  return const <String, dynamic>{};
}

String _specialistDisplayName(Map<String, dynamic> source) {
  final direct = _readString(source, const ['fullName', 'name', 'displayName']);
  if (direct.isNotEmpty) return direct;
  return <String>[
    _readString(source, const ['lastName']),
    _readString(source, const ['firstName']),
    _readString(source, const ['middleName']),
  ].where((value) => value.trim().isNotEmpty).join(' ');
}

String _readString(
  Map<String, dynamic> source,
  List<String> keys, {
  String fallback = '',
}) {
  for (final key in keys) {
    final raw = source[key];
    if (raw == null) continue;
    if (raw is String && raw.trim().isNotEmpty) return raw.trim();
    if (raw is num || raw is bool) {
      final value = raw.toString().trim();
      if (value.isNotEmpty) return value;
    }
  }
  return fallback.trim();
}

int? _readInt(Map<String, dynamic> source, List<String> keys) {
  for (final key in keys) {
    final raw = source[key];
    if (raw is int && raw > 0) return raw;
    if (raw is num && raw > 0) return raw.toInt();
    if (raw is String) {
      final parsed = int.tryParse(raw.trim());
      if (parsed != null && parsed > 0) return parsed;
    }
  }
  return null;
}
