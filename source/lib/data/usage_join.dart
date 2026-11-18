/// Pure helpers for joining Android NetworkStats rows to installed packages.
/// Android reports traffic by UID while PackageManager reports package metadata;
/// the UID is the shared native key.
Map<int, Map<String, dynamic>> indexUsageByUid(
    Iterable<Map<String, dynamic>> rows) {
  final result = <int, Map<String, dynamic>>{};
  for (final row in rows) {
    final rawUid = row['uid'];
    final uid = rawUid is num ? rawUid.toInt() : int.tryParse('$rawUid');
    if (uid != null) result[uid] = row;
  }
  return result;
}

Map<String, dynamic> usageForUid(
    Map<int, Map<String, dynamic>> index, dynamic rawUid) {
  final uid = rawUid is num ? rawUid.toInt() : int.tryParse('$rawUid');
  return uid == null
      ? const <String, dynamic>{}
      : index[uid] ?? const <String, dynamic>{};
}
