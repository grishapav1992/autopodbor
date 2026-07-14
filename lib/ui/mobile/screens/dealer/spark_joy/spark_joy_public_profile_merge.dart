/// Merges the authoritative public specialist response over a compact card.
///
/// Request/report payloads may contain supplemental fields which the public
/// RPC intentionally omits (phone, email, city, rating). Those survive. Field
/// groups owned by the public RPC are replaced as a whole, including null and
/// empty values, so deleted descriptions and avatars cannot reappear through
/// an older alias from the compact payload.
Map<String, dynamic> mergeSparkJoySpecialistPublicProfile(
  Map<String, dynamic>? compact,
  Map<String, dynamic> fetched,
) {
  final merged = Map<String, dynamic>.from(compact ?? const {});

  const authoritativeGroups = <List<String>>[
    ['description', 'specialization', 'about', 'servicesDescription'],
    ['urlAvatar', 'avatarUrl', 'avatar_url', 'photoUrl'],
    ['firstName', 'lastName', 'middleName', 'name', 'displayName', 'fullName'],
  ];
  for (final group in authoritativeGroups) {
    if (!group.any(fetched.containsKey)) continue;
    for (final key in group) {
      merged.remove(key);
    }
  }

  // Do not filter null or empty strings: for authoritative fields they mean
  // that the user deliberately cleared the value.
  merged.addAll(fetched);

  final hasStructuredName = const [
    'firstName',
    'lastName',
    'middleName',
  ].any(fetched.containsKey);
  if (hasStructuredName) {
    final composedName =
        [fetched['lastName'], fetched['firstName'], fetched['middleName']]
            .map((value) => value?.toString().trim() ?? '')
            .where((value) => value.isNotEmpty)
            .join(' ');
    if (composedName.isNotEmpty) {
      // Staff-list screens use the compact `name` key, while public profile
      // screens compose the structured fields directly.
      merged['name'] = composedName;
    }
  }

  return merged;
}
