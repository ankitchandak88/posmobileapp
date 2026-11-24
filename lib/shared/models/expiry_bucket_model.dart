import '../../core/utils/parse_helpers.dart';

/// GET /v1/expiry-buckets row: {id, label, min_days, max_days, severity, sort_order}.
/// Also used as the PUT /v1/expiry-buckets/settings request/response shape
/// (Manager/Owner editable — business rule, 2026-10-10).
class ExpiryBucketModel {
  ExpiryBucketModel({
    this.id,
    required this.label,
    required this.minDays,
    required this.maxDays,
    required this.severity,
    this.sortOrder = 0,
  });

  final String? id;
  final String label;
  final int minDays;
  final int maxDays;
  final String severity; // info | warning | critical
  final int sortOrder;

  factory ExpiryBucketModel.fromJson(Map<String, dynamic> json) {
    return ExpiryBucketModel(
      id: json['id']?.toString(),
      label: json['label'] as String? ?? '',
      minDays: parseInt(json['min_days']) ?? 0,
      maxDays: parseInt(json['max_days']) ?? 0,
      severity: json['severity'] as String? ?? 'info',
      sortOrder: parseInt(json['sort_order']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': int.tryParse(id!) ?? id,
    'label': label,
    'min_days': minDays,
    'max_days': maxDays,
    'severity': severity,
    'sort_order': sortOrder,
  };

  ExpiryBucketModel copyWith({
    String? label,
    int? minDays,
    int? maxDays,
    String? severity,
    int? sortOrder,
  }) => ExpiryBucketModel(
    id: id,
    label: label ?? this.label,
    minDays: minDays ?? this.minDays,
    maxDays: maxDays ?? this.maxDays,
    severity: severity ?? this.severity,
    sortOrder: sortOrder ?? this.sortOrder,
  );

  /// Classifies a day-count into this bucket's range (inclusive).
  bool matches(int daysUntilExpiry) =>
      daysUntilExpiry >= minDays && daysUntilExpiry <= maxDays;
}
