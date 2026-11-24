import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:urban_pets_verify/features/history/data/history_repository.dart';
import 'package:urban_pets_verify/features/history/state/history_providers.dart';
import 'package:urban_pets_verify/features/review/data/observation_repository.dart';
import 'package:urban_pets_verify/features/tasks/data/task_repository.dart';
import 'package:urban_pets_verify/shared/models/models.dart';

import '../helpers/test_harness.dart';

void main() {
  group('TaskModel.fromJson', () {
    test('parses the real TaskController shape incl. nested relations', () {
      final task = TaskModel.fromJson({
        'id': 12,
        'branch_id': 1,
        'title': 'Count RC',
        'section': 'Rack A',
        'category_id': null,
        'category_value_id': 5,
        'brand_id': 7,
        'assigned_to': 11,
        'due_date': '2026-10-15T00:00:00.000000Z',
        'priority': 'high',
        'status': 'pending',
        'branch': {'id': 1, 'name': 'Main Branch'},
        'assignee': {'id': 11, 'name': 'Alice Staff', 'branch_id': 1},
        'assigner': {'id': 21, 'name': 'Mona Manager'},
        'category_value': {'id': 5, 'name': 'Dog Food', 'item_category_id': 2},
        'brand': {'id': 7, 'name': 'Royal Canin'},
        'items': [
          {
            'id': 1,
            'task_id': 12,
            'item_id': 100,
            'batch_no': 'B1',
            'item': {
              'id': 100,
              'name': 'RC Adult Dog 15kg',
              'item_code': 'RC001',
            },
          },
        ],
      });

      expect(task.id, '12');
      expect(task.categoryValueId, '5');
      expect(task.categoryName, 'Dog Food');
      expect(task.brandId, '7');
      expect(task.brandName, 'Royal Canin');
      expect(task.branchName, 'Main Branch');
      expect(task.assigneeName, 'Alice Staff');
      expect(task.assignerName, 'Mona Manager');
      expect(task.hasCategoryOrBrandScope, isTrue);
      expect(task.dueDate, isNotNull);
      expect(task.items.single.itemName, 'RC Adult Dog 15kg');
      expect(task.items.single.itemCode, 'RC001');
      expect(task.items.single.batchNo, 'B1');
    });

    test('derives progress from the detail endpoint observations', () {
      final task = TaskModel.fromJson({
        'id': 3,
        'branch_id': 1,
        'assigned_to': 7,
        'observations': [
          {'id': 1, 'item_id': 10, 'status': 'pending'},
          {'id': 2, 'item_id': 10, 'status': 'rejected'},
          {'id': 3, 'item_id': 16, 'status': 'approved'},
        ],
      });
      expect(task.observationCount, 3);
      expect(task.observedItemIds, {'10', '16'});
    });
    test('tolerates a minimal payload (no relations)', () {
      final task = TaskModel.fromJson({
        'id': 1,
        'branch_id': 1,
        'assigned_to': 2,
      });
      expect(task.title, 'Untitled task');
      expect(task.priority, 'normal');
      expect(task.status, 'pending');
      expect(task.items, isEmpty);
      expect(task.hasCategoryOrBrandScope, isFalse);
    });
  });

  group('PagedResult.fromLaravel', () {
    test('reads the Laravel paginator envelope', () {
      final page = PagedResult.fromLaravel({
        'current_page': 2,
        'last_page': 3,
        'per_page': 20,
        'total': 45,
        'data': [
          {'id': 1, 'name': 'Dog Food'},
        ],
      }, CategoryModel.fromJson);
      expect(page.items.single.name, 'Dog Food');
      expect(page.currentPage, 2);
      expect(page.total, 45);
      expect(page.hasMore, isTrue);
    });

    test('a bare list is a single final page', () {
      final page = PagedResult.fromLaravel([
        {'id': 1, 'name': 'A'},
        {'id': 2, 'name': 'B'},
      ], BrandModel.fromJson);
      expect(page.items, hasLength(2));
      expect(page.hasMore, isFalse);
      expect(page.total, 2);
    });
  });

  group('request building', () {
    test('history query maps filters 1:1 to API params', () {
      final q = ObservationRepository.historyQuery(
        branchId: '2',
        dateFrom: DateTime(2025, 4, 1),
        dateTo: DateTime(2025, 4, 30),
        type: 'stock_count',
        status: 'approved',
        page: 3,
      );
      expect(q, {
        'branch_id': '2',
        'date_from': '2025-04-01',
        'date_to': '2025-04-30',
        'type': 'stock_count',
        'status': 'approved',
        'page': 3,
        'per_page': 20,
      });
      expect(ObservationRepository.historyQuery(), {'page': 1, 'per_page': 20});
    });

    test('task create body carries category_value_id / brand_id / items', () {
      final body = TaskRepository.createBody(
        branchId: '1',
        title: 'Count',
        categoryValueId: '5',
        brandId: '7',
        assignedTo: '11',
        dueDate: DateTime(2026, 10, 15),
        items: [(itemId: '100', batchNo: null), (itemId: '101', batchNo: 'B1')],
      );
      expect(body['category_value_id'], '5');
      expect(body['brand_id'], '7');
      expect(body['due_date'], '2026-10-15');
      expect(body['items'], [
        {'item_id': '100'},
        {'item_id': '101', 'batch_no': 'B1'},
      ]);
      expect(
        TaskRepository.createBody(
          branchId: '1',
          title: 'x',
          assignedTo: '2',
        ).containsKey('items'),
        isFalse,
      );
    });

    test('HistoryTab maps to the API type values', () {
      expect(HistoryTab.all.apiValue, isNull);
      expect(HistoryTab.stockCount.apiValue, 'stock_count');
      expect(HistoryTab.expiryCheck.apiValue, 'expiry_check');
    });
  });

  group('HistoryController', () {
    test('drops a stale response from a superseded filter change', () async {
      final slow = Completer<void>();
      final repo = FakeObservationRepository();
      repo.historyHandler = (call) => PagedResult(
        items: [obs(id: call.type == null ? 'all' : 'expiry')],
        currentPage: 1,
        lastPage: 1,
        total: 1,
      );
      final gatedRepo = _GatedHistoryRepository(repo, firstCallGate: slow);
      final controller = HistoryController(gatedRepo, asReviewer: true);

      // First (slow) "All" request is in flight; user switches tab.
      controller.updateFilters((f) => f.copyWith(tab: HistoryTab.expiryCheck));
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.items.single.id, 'expiry');

      // The superseded "All" response arrives late — must be ignored.
      slow.complete();
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.items.single.id, 'expiry');
      controller.dispose();
    });

    test('a load-more failure keeps already-loaded rows', () async {
      final repo = FakeObservationRepository();
      repo.historyHandler = (call) => PagedResult(
        items: [obs(id: 'p${call.page}')],
        currentPage: call.page,
        lastPage: 2,
        total: 2,
      );
      final controller = HistoryController(
        HistoryRepository(observationRepository: repo),
        asReviewer: false,
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.items.map((o) => o.id), ['p1']);

      repo.historyError = Exception('timeout');
      await controller.loadMore();
      expect(controller.state.items.map((o) => o.id), ['p1']);
      expect(controller.state.loadMoreError, isNotNull);
      expect(repo.historyCalls.every((c) => c.endpoint == 'mine'), isTrue);
      controller.dispose();
    });
  });
}

/// Holds the FIRST search call open until [firstCallGate] completes.
class _GatedHistoryRepository extends HistoryRepository {
  _GatedHistoryRepository(this._inner, {required this.firstCallGate})
    : super(observationRepository: _inner);

  final FakeObservationRepository _inner;
  final Completer<void> firstCallGate;
  var _calls = 0;

  @override
  Future<PagedResult<ObservationModel>> search({
    required bool asReviewer,
    required HistoryFilters filters,
    int page = 1,
    int perPage = 20,
  }) async {
    _calls++;
    if (_calls == 1) await firstCallGate.future;
    return super.search(
      asReviewer: asReviewer,
      filters: filters,
      page: page,
      perPage: perPage,
    );
  }

  int get calls => _calls;
  FakeObservationRepository get inner => _inner;
}
