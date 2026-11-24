import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../auth/state/auth_providers.dart';
import '../data/rider_order_model.dart';
import '../data/rider_order_repository.dart';
import '../data/vehicle_model.dart';

final riderOrderRepositoryProvider = Provider<RiderOrderRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return RiderOrderRepository(apiClient: apiClient);
});

class RiderOrdersState {
  const RiderOrdersState({
    this.isLoading = false,
    this.isUpdating = false,
    this.orders = const [],
    this.selectedTab = 'all',
    this.errorMessage,
  });

  final bool isLoading;
  final bool isUpdating;
  final List<RiderOrderModel> orders;
  final String selectedTab; // 'all', 'assigned', 'out_for_delivery', 'delivered'
  final String? errorMessage;

  int get totalCount => orders.length;
  int get assignedCount => orders.where((o) => o.isAssigned).length;
  int get outForDeliveryCount => orders.where((o) => o.isOutForDelivery).length;
  int get deliveredCount => orders.where((o) => o.isDelivered).length;

  List<RiderOrderModel> get filteredOrders {
    switch (selectedTab) {
      case 'assigned':
        return orders.where((o) => o.isAssigned).toList();
      case 'out_for_delivery':
        return orders.where((o) => o.isOutForDelivery).toList();
      case 'delivered':
        return orders.where((o) => o.isDelivered).toList();
      case 'all':
      default:
        return orders;
    }
  }

  RiderOrdersState copyWith({
    bool? isLoading,
    bool? isUpdating,
    List<RiderOrderModel>? orders,
    String? selectedTab,
    String? errorMessage,
  }) {
    return RiderOrdersState(
      isLoading: isLoading ?? this.isLoading,
      isUpdating: isUpdating ?? this.isUpdating,
      orders: orders ?? this.orders,
      selectedTab: selectedTab ?? this.selectedTab,
      errorMessage: errorMessage,
    );
  }
}

class RiderOrdersNotifier extends StateNotifier<RiderOrdersState> {
  RiderOrdersNotifier(this._repository) : super(const RiderOrdersState()) {
    loadDeliveries();
  }

  final RiderOrderRepository _repository;

  Future<void> loadDeliveries() async {
    state = state.copyWith(isLoading: true, errorMessage: null);
    try {
      final orders = await _repository.fetchTodayDeliveries();
      state = state.copyWith(isLoading: false, orders: orders);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  void setTab(String tab) {
    state = state.copyWith(selectedTab: tab);
  }

  RiderOrderModel _mergeOrderUpdate(
    RiderOrderModel existing,
    RiderOrderModel updated,
  ) {
    return updated.copyWith(
      vehicleId: updated.vehicleId ?? existing.vehicleId,
      vehicleRegistration:
          updated.vehicleRegistration ?? existing.vehicleRegistration,
      deliveryNote: updated.deliveryNote ?? existing.deliveryNote,
    );
  }

  Future<bool> startDelivery(int orderId, double startingKm) async {
    state = state.copyWith(isUpdating: true, errorMessage: null);
    try {
      final updated = await _repository.updateStatus(
        orderId,
        status: 'out_for_delivery',
        startingKm: startingKm,
      );
      final newOrders = state.orders
          .map((o) => o.id == orderId ? _mergeOrderUpdate(o, updated) : o)
          .toList();
      state = state.copyWith(isUpdating: false, orders: newOrders);
      return true;
    } catch (e) {
      state = state.copyWith(isUpdating: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> markDelivered(
    int orderId,
    double endingKm, {
    String? notes,
    String? paymentStatus,
  }) async {
    state = state.copyWith(isUpdating: true, errorMessage: null);
    try {
      final updated = await _repository.updateStatus(
        orderId,
        status: 'delivered',
        endingKm: endingKm,
        notes: notes,
        paymentStatus: paymentStatus,
      );
      final newOrders = state.orders
          .map((o) => o.id == orderId ? _mergeOrderUpdate(o, updated) : o)
          .toList();
      state = state.copyWith(isUpdating: false, orders: newOrders);
      return true;
    } catch (e) {
      state = state.copyWith(isUpdating: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> assignVehicle(
    int orderId,
    int vehicleId, {
    String? registrationNumber,
  }) async {
    state = state.copyWith(isUpdating: true, errorMessage: null);
    try {
      await _repository.assignVehicle(orderId, vehicleId);
      final newOrders = state.orders.map((o) {
        if (o.id == orderId) {
          return o.copyWith(
            vehicleId: vehicleId,
            vehicleRegistration: registrationNumber ?? o.vehicleRegistration,
          );
        }
        return o;
      }).toList();
      state = state.copyWith(isUpdating: false, orders: newOrders);
      return true;
    } catch (e) {
      state = state.copyWith(isUpdating: false, errorMessage: e.toString());
      return false;
    }
  }

  Future<bool> rescheduleDelivery(
    int orderId,
    String formattedDate, {
    String? reason,
  }) async {
    state = state.copyWith(isUpdating: true, errorMessage: null);
    try {
      final updated = await _repository.updateStatus(
        orderId,
        status: 'rescheduled',
        deliveryDate: formattedDate,
        paymentNote: reason,
      );
      final newOrders = state.orders.map((o) => o.id == orderId ? updated : o).toList();
      state = state.copyWith(isUpdating: false, orders: newOrders);
      return true;
    } catch (e) {
      state = state.copyWith(isUpdating: false, errorMessage: e.toString());
      return false;
    }
  }
}

final riderOrdersProvider =
    StateNotifierProvider<RiderOrdersNotifier, RiderOrdersState>((ref) {
  final repository = ref.watch(riderOrderRepositoryProvider);
  return RiderOrdersNotifier(repository);
});

final riderVehiclesProvider = FutureProvider<List<VehicleModel>>((ref) async {
  final repository = ref.watch(riderOrderRepositoryProvider);
  return repository.fetchVehicles();
});
