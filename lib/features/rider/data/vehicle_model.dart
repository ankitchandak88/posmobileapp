import '../../../core/utils/parse_helpers.dart';

class VehicleModel {
  const VehicleModel({
    required this.id,
    required this.registrationNumber,
    this.make,
    this.model,
    this.type,
    this.typeLabel,
    this.status,
  });

  final int id;
  final String registrationNumber;
  final String? make;
  final String? model;
  final String? type;
  final String? typeLabel;
  final String? status;

  String get displayName {
    final details =
        [make, model].where((s) => s != null && s.trim().isNotEmpty).join(' ');
    if (details.isNotEmpty) {
      return '$registrationNumber ($details)';
    }
    return registrationNumber;
  }

  factory VehicleModel.fromJson(Map<String, dynamic> json) {
    return VehicleModel(
      id: parseInt(json['id']) ?? 0,
      registrationNumber: json['registration_number'] as String? ?? '—',
      make: json['make'] as String?,
      model: json['model'] as String?,
      type: json['type'] as String?,
      typeLabel: json['type_label'] as String?,
      status: json['status'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'registration_number': registrationNumber,
        'make': make,
        'model': model,
        'type': type,
        'type_label': typeLabel,
        'status': status,
      };
}

