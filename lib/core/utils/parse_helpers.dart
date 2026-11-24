library;

/// Safe parsing helpers for numbers, doubles, and ints from JSON payloads.
///
/// In Laravel / MySQL, decimals (e.g. `decimal:2`) are frequently serialized
/// as JSON strings (e.g. `"250.00"`), and count / aggregate queries can also
/// arrive as strings or ints. Casting directly with `as num?` or `as double?`
/// causes runtime TypeError exceptions: `type 'String' is not a subtype of type 'num?'`.

num? parseNum(dynamic value) {
  if (value == null) return null;
  if (value is num) return value;
  if (value is String) return num.tryParse(value);
  return null;
}

double? parseDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

int? parseInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) {
    return int.tryParse(value) ?? double.tryParse(value)?.toInt();
  }
  return null;
}
