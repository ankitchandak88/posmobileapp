import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import 'rider_order_model.dart';
import 'vehicle_model.dart';

class RiderOrderRepository {
  RiderOrderRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient() {
    _apiClient.setBaseUrl(ApiConstants.riderDeliveryUrl);
  }

  final ApiClient _apiClient;

  /// Fetch today's assigned deliveries for the logged-in rider.
  Future<List<RiderOrderModel>> fetchTodayDeliveries({String? status}) async {
    _apiClient.setBaseUrl(ApiConstants.riderDeliveryUrl);
    final queryParams = <String, dynamic>{
      'per_page': 100,
    };
    if (status != null && status.isNotEmpty) {
      queryParams['status'] = status;
    }

    final response = await _apiClient.request(
      ApiConstants.riderOrders,
      queryParameters: queryParams,
    );

    final raw = response.data;
    List<dynamic> items = [];

    if (raw is Map<String, dynamic>) {
      if (raw['data'] is Map<String, dynamic> &&
          raw['data']['data'] is List) {
        items = raw['data']['data'] as List<dynamic>;
      } else if (raw['data'] is List) {
        items = raw['data'] as List<dynamic>;
      }
    } else if (raw is List) {
      items = raw;
    }

    return items
        .whereType<Map<String, dynamic>>()
        .map(RiderOrderModel.fromJson)
        .toList();
  }

  /// Update the status of an assigned order.
  /// For 'out_for_delivery', [startingKm] is required.
  /// For 'delivered', [endingKm] is required.
  /// For 'rescheduled', [deliveryDate] is required (YYYY-MM-DD).
  Future<RiderOrderModel> updateStatus(
    int orderId, {
    required String status,
    double? startingKm,
    double? endingKm,
    String? deliveryDate,
    String? paymentStatus,
    String? paymentNote,
    String? notes,
  }) async {
    _apiClient.setBaseUrl(ApiConstants.riderDeliveryUrl);
    final data = <String, dynamic>{
      'status': status,
    };
    if (startingKm != null) data['starting_km'] = startingKm;
    if (endingKm != null) data['ending_km'] = endingKm;
    if (deliveryDate != null) data['delivery_date'] = deliveryDate;
    if (paymentStatus != null) data['payment_status'] = paymentStatus;
    if (paymentNote != null) data['payment_note'] = paymentNote;
    if (notes != null && notes.trim().isNotEmpty) {
      data['delivery_note'] = notes.trim();
    }

    final response = await _apiClient.request(
      ApiConstants.riderOrderStatus(orderId),
      method: 'PATCH',
      data: data,
    );

    final raw = response.data;
    Map<String, dynamic> orderJson = {};
    if (raw is Map<String, dynamic> && raw['data'] is Map<String, dynamic>) {
      orderJson = raw['data'] as Map<String, dynamic>;
    } else if (raw is Map<String, dynamic>) {
      orderJson = raw;
    }

    return RiderOrderModel.fromJson(orderJson);
  }

  /// Fetch vehicles available for assignment.
  Future<List<VehicleModel>> fetchVehicles() async {
    _apiClient.setBaseUrl(ApiConstants.riderDeliveryUrl);
    final response = await _apiClient.request(
      ApiConstants.riderVehicles,
      queryParameters: {'per_page': 100},
    );

    final raw = response.data;
    List<dynamic> items = [];

    if (raw is Map<String, dynamic>) {
      if (raw['data'] is Map<String, dynamic> &&
          raw['data']['data'] is List) {
        items = raw['data']['data'] as List<dynamic>;
      } else if (raw['data'] is List) {
        items = raw['data'] as List<dynamic>;
      }
    } else if (raw is List) {
      items = raw;
    }

    return items
        .whereType<Map<String, dynamic>>()
        .map(VehicleModel.fromJson)
        .toList();
  }

  /// Assign a vehicle to an order.
  Future<void> assignVehicle(int orderId, int vehicleId) async {
    _apiClient.setBaseUrl(ApiConstants.riderDeliveryUrl);
    await _apiClient.request(
      ApiConstants.riderAssignVehicle(orderId),
      method: 'PATCH',
      data: {'assigned_vehicle_id': vehicleId},
    );
  }
}

