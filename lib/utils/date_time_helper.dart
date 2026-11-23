const Duration gmt7Offset = Duration(hours: 7);

/// Returns the current wall-clock time in GMT+7 (WIB) as a non-UTC [DateTime].
DateTime nowGmt7() =>
    _wallClockFromUtc(DateTime.now().toUtc().add(gmt7Offset));

/// Converts [dateTime] into a non-UTC GMT+7 wall-clock [DateTime].
///
/// When [dateTime.isUtc] is true (which Dart produces when parsing ISO-8601
/// timestamps that include `Z` or an explicit offset such as `+07:00`), this
/// shifts the instant to GMT+7 and constructs a local-style [DateTime] so
/// `.year`, `.month`, `.day`, `.hour`, and `.minute` always reflect GMT+7
/// regardless of the device's OS timezone.
///
/// When [dateTime.isUtc] is false (naive ISO strings without an offset or
/// `DateTime(y, m, d, h, min)`), it is treated as already carrying GMT+7
/// wall-clock fields and returned unchanged.
DateTime toGmt7(DateTime dateTime) {
  if (!dateTime.isUtc) return dateTime;
  return _wallClockFromUtc(dateTime.add(gmt7Offset));
}

/// Parses an ISO-8601 timestamp string [raw] into a GMT+7 wall-clock [DateTime].
DateTime? parseGmt7DateTime(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final parsed = DateTime.tryParse(trimmed);
  if (parsed == null) return null;
  return toGmt7(parsed);
}

DateTime _wallClockFromUtc(DateTime utcPlus7) {
  return DateTime(
    utcPlus7.year,
    utcPlus7.month,
    utcPlus7.day,
    utcPlus7.hour,
    utcPlus7.minute,
    utcPlus7.second,
    utcPlus7.millisecond,
    utcPlus7.microsecond,
  );
}

/// Formats a GMT+7 wall-clock [DateTime] as RFC3339 with explicit `+07:00` offset.
String formatIsoGmt7(DateTime dt) {
  final wib = toGmt7(dt);
  String p2(int v) => v.toString().padLeft(2, '0');
  final y = wib.year.toString().padLeft(4, '0');
  return '$y-${p2(wib.month)}-${p2(wib.day)}T${p2(wib.hour)}:${p2(wib.minute)}:${p2(wib.second)}+07:00';
}
