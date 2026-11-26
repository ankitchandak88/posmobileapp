import '../../../core/utils/parse_helpers.dart';

class RiderOrderModel {
  const RiderOrderModel({
    required this.id,
    required this.invoiceNo,
    this.invoiceDate,
    this.deliveryDate,
    required this.status,
    required this.statusLabel,
    required this.totalAmount,
    required this.paymentStatus,
    this.paymentNote,
    this.startingKm,
    this.endingKm,
    this.kmTravelled,
    this.notes,
    required this.customerName,
    required this.customerPhone,
    this.streetAddress,
    this.area,
    this.postcode,
    this.googleMapLink,
    this.vehicleId,
    this.vehicleRegistration,
    this.deliveryNote,
    this.branchTitle,
    this.petName,
  });

  final int id;
  final String invoiceNo;
  final DateTime? invoiceDate;
  final DateTime? deliveryDate;
  final String status;
  final String statusLabel;
  final double totalAmount;
  final String paymentStatus;
  final String? paymentNote;
  final double? startingKm;
  final double? endingKm;
  final double? kmTravelled;
  final String? notes;
  final String? deliveryNote;
  final String customerName;
  final String customerPhone;
  final String? petName;
  final String? streetAddress;
  final String? area;
  final String? postcode;
  final String? googleMapLink;
  final int? vehicleId;
  final String? vehicleRegistration;
  final String? branchTitle;

  bool get isAssigned => status == 'assigned' || status == 'pending';
  bool get isOutForDelivery => status == 'out_for_delivery';
  bool get isDelivered => status == 'delivered' || status == 'completed';
  bool get isRescheduled => status == 'rescheduled';
  bool get isCancelled => status == 'cancelled';

  bool get isPaidOnline => paymentStatus.toLowerCase() == 'online';
  bool get isCashOnDelivery =>
      paymentStatus.toLowerCase() == 'cash' ||
      paymentStatus.toLowerCase() == 'pending';

  String get fullAddress {
    final parts = <String>[];
    if (streetAddress != null && streetAddress!.trim().isNotEmpty) {
      parts.add(streetAddress!.trim());
    }
    if (area != null && area!.trim().isNotEmpty) {
      parts.add(area!.trim());
    }
    if (postcode != null && postcode!.trim().isNotEmpty) {
      parts.add(postcode!.trim());
    }
    return parts.isEmpty ? 'Address not specified' : parts.join(', ');
  }

  factory RiderOrderModel.fromJson(Map<String, dynamic> json) {
    final customer = json['customer'] as Map<String, dynamic>?;
    final deliveryAddress = json['delivery_address'] as Map<String, dynamic>?;
    final branch = json['branch'] as Map<String, dynamic>?;
    final vehicle = json['vehicle'] as Map<String, dynamic>?;

    final street = deliveryAddress?['street_address'] as String? ??
        customer?['street_address'] as String?;
    final post = deliveryAddress?['postcode'] as String?;
    final mapLink = deliveryAddress?['google_map_link'] as String?;
    final customerArea = customer?['area'] as String?;
    final pet = customer?['pet_name'] as String? ?? json['pet_name'] as String?;

    return RiderOrderModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse(json['id'].toString()) ?? 0,
      invoiceNo: json['invoice_no'] as String? ?? '—',
      invoiceDate: json['invoice_date'] != null
          ? DateTime.tryParse(json['invoice_date'].toString())
          : null,
      deliveryDate: json['delivery_date'] != null
          ? DateTime.tryParse(json['delivery_date'].toString())
          : null,
      status: json['status'] as String? ?? 'pending',
      statusLabel: json['status_label'] as String? ?? 'Pending',
      totalAmount: parseDouble(json['total_amount']) ?? 0.0,
      paymentStatus: json['payment_status'] as String? ?? 'pending',
      paymentNote: json['payment_note'] as String?,
      startingKm: parseDouble(json['starting_km']),
      endingKm: parseDouble(json['ending_km']),
      kmTravelled: parseDouble(json['km_travelled']),
      notes: json['notes'] as String?,
      deliveryNote: json['delivery_note'] as String?,
      customerName: customer?['full_name'] as String? ?? 'Valued Customer',
      customerPhone: customer?['mobile_number'] as String? ?? '',
      petName: pet,
      streetAddress: street,
      area: customerArea,
      postcode: post,
      googleMapLink: mapLink,
      vehicleId: parseInt(vehicle?['id']) ?? parseInt(json['assigned_vehicle_id']),
      vehicleRegistration: vehicle?['registration_number'] as String?,
      branchTitle: branch?['title'] as String?,
    );
  }

  RiderOrderModel copyWith({
    int? id,
    String? invoiceNo,
    DateTime? invoiceDate,
    DateTime? deliveryDate,
    String? status,
    String? statusLabel,
    double? totalAmount,
    String? paymentStatus,
    String? paymentNote,
    double? startingKm,
    double? endingKm,
    double? kmTravelled,
    String? notes,
    String? deliveryNote,
    String? customerName,
    String? customerPhone,
    String? petName,
    String? streetAddress,
    String? area,
    String? postcode,
    String? googleMapLink,
    int? vehicleId,
    String? vehicleRegistration,
    String? branchTitle,
  }) {
    return RiderOrderModel(
      id: id ?? this.id,
      invoiceNo: invoiceNo ?? this.invoiceNo,
      invoiceDate: invoiceDate ?? this.invoiceDate,
      deliveryDate: deliveryDate ?? this.deliveryDate,
      status: status ?? this.status,
      statusLabel: statusLabel ?? this.statusLabel,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      paymentNote: paymentNote ?? this.paymentNote,
      startingKm: startingKm ?? this.startingKm,
      endingKm: endingKm ?? this.endingKm,
      kmTravelled: kmTravelled ?? this.kmTravelled,
      notes: notes ?? this.notes,
      deliveryNote: deliveryNote ?? this.deliveryNote,
      customerName: customerName ?? this.customerName,
      customerPhone: customerPhone ?? this.customerPhone,
      petName: petName ?? this.petName,
      streetAddress: streetAddress ?? this.streetAddress,
      area: area ?? this.area,
      postcode: postcode ?? this.postcode,
      googleMapLink: googleMapLink ?? this.googleMapLink,
      vehicleId: vehicleId ?? this.vehicleId,
      vehicleRegistration: vehicleRegistration ?? this.vehicleRegistration,
      branchTitle: branchTitle ?? this.branchTitle,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'invoice_no': invoiceNo,
    'invoice_date': invoiceDate?.toIso8601String(),
    'delivery_date': deliveryDate?.toIso8601String(),
    'status': status,
    'status_label': statusLabel,
    'total_amount': totalAmount,
    'payment_status': paymentStatus,
    'payment_note': paymentNote,
    'starting_km': startingKm,
    'ending_km': endingKm,
    'km_travelled': kmTravelled,
    'notes': notes,
    'delivery_note': deliveryNote,
    'pet_name': petName,
    'customer': {
      'full_name': customerName,
      'mobile_number': customerPhone,
      'pet_name': petName,
      'street_address': streetAddress,
      'area': area,
    },
    'delivery_address': {
      'street_address': streetAddress,
      'postcode': postcode,
      'google_map_link': googleMapLink,
    },
    'vehicle': vehicleRegistration != null
        ? {'registration_number': vehicleRegistration}
        : null,
    'branch': branchTitle != null ? {'title': branchTitle} : null,
  };
}

