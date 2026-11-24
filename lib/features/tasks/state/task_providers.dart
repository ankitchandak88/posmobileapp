import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../shared/models/models.dart';
import '../../auth/state/auth_providers.dart';
import '../../scanner/state/scanner_providers.dart';
import '../data/task_repository.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository(apiClient: ref.read(apiClientProvider));
});

/// Manager/Owner task-list filter: product category and/or brand
/// (master prompt §9 — "assign tasks using … Category or brand").
class TaskListFilter {
  const TaskListFilter({this.categoryValueId, this.brandId});

  final String? categoryValueId;
  final String? brandId;

  bool get isActive => categoryValueId != null || brandId != null;
}

final taskListFilterProvider = StateProvider<TaskListFilter>(
  (ref) => const TaskListFilter(),
);

/// Calls the live `GET /v1/tasks` endpoint directly (re-fetches when the
/// category/brand filter changes). A network/API failure propagates as an
/// [AsyncError] so the UI renders its existing [ErrorState] widget — it must
/// NOT silently fall back to mock data.
final myTasksProvider = FutureProvider.autoDispose<List<TaskModel>>((
  ref,
) async {
  final filter = ref.watch(taskListFilterProvider);
  return ref
      .read(taskRepositoryProvider)
      .myTasks(
        categoryValueId: filter.categoryValueId,
        brandId: filter.brandId,
      );
});

/// Single task via `GET /v1/tasks/{id}` (not a lookup in the paginated
/// list, which may not contain it for a Manager with many tasks).
final taskByIdProvider = FutureProvider.autoDispose.family<TaskModel?, String>((
  ref,
  id,
) async {
  return ref.read(taskRepositoryProvider).detail(id);
});

final categoriesProvider = FutureProvider<List<CategoryModel>>((ref) async {
  return ref.read(taskRepositoryProvider).categories();
});

final brandsProvider = FutureProvider<List<BrandModel>>((ref) async {
  return ref.read(taskRepositoryProvider).brands();
});

final brandsByScopeProvider = FutureProvider.autoDispose
    .family<List<BrandModel>, String?>((ref, categoryValueId) async {
      return ref.read(taskRepositoryProvider).brands(categoryValueId: categoryValueId);
    });

final assigneesProvider = FutureProvider.autoDispose
    .family<List<AssigneeModel>, String>((ref, branchId) async {
      return ref.read(taskRepositoryProvider).assignees(branchId);
    });

/// First page (up to 50) of the products a category/brand scope resolves to,
/// plus the server-side total. Used on Task Details and the Assign Task
/// product picker.
final scopeItemsProvider = FutureProvider.autoDispose
    .family<
      PagedResult<ItemModel>,
      ({String? categoryValueId, String? brandId, String query})
    >((ref, scope) async {
      return ref
          .read(itemRepositoryProvider)
          .searchScoped(
            query: scope.query,
            categoryValueId: scope.categoryValueId,
            brandId: scope.brandId,
            perPage: 50,
          );
    });
