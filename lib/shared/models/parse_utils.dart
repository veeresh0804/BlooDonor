import 'package:flutter/foundation.dart';

/// Lenient enum parsing for values that are NOT safety-critical.
/// An unrecognised string (e.g. a status added to the DB before the app was
/// updated) logs and falls back instead of throwing.
///
/// Do NOT use this for blood group / Rh factor: guessing a blood type is worse
/// than failing. Those stay strict (`byName`) and are handled per-row by
/// [parseRows] so one bad row can't take down a whole screen.
T parseEnumOr<T extends Enum>(
  List<T> values,
  Object? raw,
  T fallback, {
  String? field,
}) {
  final match = raw is String ? values.asNameMap()[raw] : null;
  if (match != null) return match;
  debugPrint(
    'Unknown $T value "$raw"${field != null ? ' for $field' : ''}; '
    'using ${fallback.name}',
  );
  return fallback;
}

/// Like [parseEnumOr] but yields null for null/unknown input.
T? tryParseEnum<T extends Enum>(List<T> values, Object? raw) {
  if (raw is! String) return null;
  final match = values.asNameMap()[raw];
  if (match == null) debugPrint('Unknown $T value "$raw"; treating as null');
  return match;
}

/// Parses a list of JSON rows, skipping (and logging) any row that fails
/// instead of letting one malformed row throw for the whole list.
List<T> parseRows<T>(
  Iterable<dynamic> rows,
  T Function(Map<String, dynamic>) fromJson, {
  String label = 'row',
}) {
  final out = <T>[];
  for (final row in rows) {
    try {
      out.add(fromJson(Map<String, dynamic>.from(row as Map)));
    } catch (e) {
      debugPrint('Skipping malformed $label: $e');
    }
  }
  return out;
}
