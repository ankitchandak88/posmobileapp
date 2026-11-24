import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../shared/models/models.dart';
import '../../auth/state/auth_providers.dart';
import '../data/item_repository.dart';

final itemRepositoryProvider = Provider<ItemRepository>((ref) {
  return ItemRepository(apiClient: ref.read(apiClientProvider));
});

final itemSearchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

final itemSearchResultsProvider = FutureProvider.autoDispose<List<ItemModel>>((
  ref,
) async {
  final query = ref.watch(itemSearchQueryProvider);
  if (query.trim().length < 2) return [];
  return ref.read(itemRepositoryProvider).search(query);
});

final itemBatchesProvider = FutureProvider.autoDispose
    .family<List<BatchModel>, ({String itemId, String branchId})>((
      ref,
      args,
    ) async {
      return ref
          .read(itemRepositoryProvider)
          .batches(itemId: args.itemId, branchId: args.branchId);
    });
