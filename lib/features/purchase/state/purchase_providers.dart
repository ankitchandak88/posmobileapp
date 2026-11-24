import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../shared/models/reference_models.dart';
import '../../auth/state/auth_providers.dart';
import '../data/purchase_lookup_model.dart';
import '../data/purchase_repository.dart';

final purchaseRepositoryProvider = Provider<PurchaseRepository>((ref) {
  return PurchaseRepository(ref.watch(apiClientProvider));
});

final suppliersProvider = FutureProvider.autoDispose<List<SupplierModel>>((ref) async {
  return ref.watch(purchaseRepositoryProvider).suppliers();
});

final selectedSupplierProvider = StateProvider<SupplierModel?>((ref) => null);

class PurchaseLookupState {
  const PurchaseLookupState({
    this.isLoading = false,
    this.data,
    this.errorMessage,
    this.searchedCode,
  });

  final bool isLoading;
  final PurchaseLookupModel? data;
  final String? errorMessage;
  final String? searchedCode;

  PurchaseLookupState copyWith({
    bool? isLoading,
    PurchaseLookupModel? data,
    String? errorMessage,
    String? searchedCode,
  }) {
    return PurchaseLookupState(
      isLoading: isLoading ?? this.isLoading,
      data: data ?? this.data,
      errorMessage: errorMessage,
      searchedCode: searchedCode ?? this.searchedCode,
    );
  }
}

class PurchaseLookupNotifier extends StateNotifier<PurchaseLookupState> {
  PurchaseLookupNotifier(this._repository) : super(const PurchaseLookupState());

  final PurchaseRepository _repository;

  Future<void> lookup(String code, {String? branchId}) async {
    final clean = code.trim();
    if (clean.isEmpty) return;

    state = state.copyWith(
      isLoading: true,
      errorMessage: null,
      searchedCode: clean,
    );

    try {
      final res = await _repository.lookupItem(clean, branchId: branchId);
      state = state.copyWith(isLoading: false, data: res);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void clear() {
    state = const PurchaseLookupState();
  }
}

final purchaseLookupProvider =
    StateNotifierProvider<PurchaseLookupNotifier, PurchaseLookupState>((ref) {
  return PurchaseLookupNotifier(ref.watch(purchaseRepositoryProvider));
});
