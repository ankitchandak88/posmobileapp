import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../shared/models/models.dart';
import '../../auth/state/auth_providers.dart';
import '../data/branch_repository.dart';
import '../data/dashboard_repository.dart';

final branchRepositoryProvider = Provider<BranchRepository>((ref) {
  return BranchRepository(apiClient: ref.read(apiClientProvider));
});

final expiryBucketRepositoryProvider = Provider<ExpiryBucketRepository>((ref) {
  return ExpiryBucketRepository(apiClient: ref.read(apiClientProvider));
});

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(apiClient: ref.read(apiClientProvider));
});

/// Calls the live `GET /v1/branches` endpoint. An empty list is a valid
/// response (not an error) and is returned as-is; a network/API failure
/// propagates as an [AsyncError] so the UI renders its existing [ErrorState]
/// widget rather than silently swapping to mock data.
final branchesProvider = FutureProvider<List<BranchModel>>((ref) async {
  return ref.read(branchRepositoryProvider).list();
});

/// Calls the live `GET /v1/expiry-buckets` endpoint. See [branchesProvider]
/// for why an error is allowed to propagate instead of falling back.
final expiryBucketsProvider = FutureProvider<List<ExpiryBucketModel>>((
  ref,
) async {
  return ref.read(expiryBucketRepositoryProvider).list();
});

final selectedBranchIdProvider = StateProvider<String?>((ref) => null);

/// Calls the live `GET /v1/dashboard/summary` endpoint. Re-fetches whenever
/// [selectedBranchIdProvider] changes (the branch dropdown on the dashboard
/// screen). An error propagates as an [AsyncError] rather than silently
/// falling back to a client-computed tile.
final dashboardSummaryProvider = FutureProvider.autoDispose<DashboardModel>((
  ref,
) async {
  final branchId = ref.watch(selectedBranchIdProvider);
  return ref.read(dashboardRepositoryProvider).summary(branchId: branchId);
});
