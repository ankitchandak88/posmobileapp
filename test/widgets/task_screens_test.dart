import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_pets_verify/core/network/api_exception.dart';
import 'package:urban_pets_verify/features/tasks/presentation/screens/create_task_screen.dart';
import 'package:urban_pets_verify/features/tasks/presentation/screens/task_detail_screen.dart';
import 'package:urban_pets_verify/features/tasks/presentation/screens/task_list_screen.dart';
import 'package:urban_pets_verify/shared/models/models.dart';

import '../helpers/test_harness.dart';

TaskModel task({
  String id = '1',
  String title = 'Count Royal Canin dog food',
  String status = 'pending',
  String assignedTo = '11',
  String? categoryValueId = '5',
  String? categoryName = 'Dog Food',
  String? brandId = '7',
  String? brandName = 'Royal Canin',
  String? section = 'Rack A',
  List<TaskItemModel> items = const [],
}) => TaskModel(
  id: id,
  branchId: '1',
  branchName: 'Main Branch',
  title: title,
  section: section,
  categoryValueId: categoryValueId,
  categoryName: categoryName,
  brandId: brandId,
  brandName: brandName,
  assignedTo: assignedTo,
  assigneeName: 'Alice Staff',
  assignerName: 'Mona Manager',
  priority: 'high',
  status: status,
  items: items,
);

final catalogue = [
  ItemModel(
    id: '100',
    name: 'RC Adult Dog 15kg',
    sku: 'RC001',
    brandId: '7',
    categoryValueId: '5',
  ),
  ItemModel(
    id: '101',
    name: 'RC Puppy 4kg',
    sku: 'RC003',
    brandId: '7',
    categoryValueId: '5',
  ),
  ItemModel(
    id: '102',
    name: 'Whiskas Tuna 85g',
    sku: 'WH001',
    brandId: '8',
    categoryValueId: '6',
  ),
];

void main() {
  group('TaskListScreen', () {
    testWidgets('Staff: "My Tasks", rows show category/brand/section scope, '
        'no manager controls', (tester) async {
      final repo = FakeTaskRepository()..tasks = [task()];
      await pumpScreen(
        tester,
        const TaskListScreen(),
        user: staffUser,
        tasks: repo,
      );

      expect(find.text('My Tasks'), findsOneWidget);
      expect(find.text('Count Royal Canin dog food'), findsOneWidget);
      expect(find.text('Dog Food · Royal Canin · Rack A'), findsOneWidget);
      expect(find.text('HIGH'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.byKey(const Key('task-list-assign')), findsNothing);
      expect(find.byKey(const Key('task-filter-category')), findsNothing);
    });

    testWidgets('Manager: Assign action opens the assign-task route', (
      tester,
    ) async {
      final repo = FakeTaskRepository()..tasks = [task()];
      await pumpScreen(
        tester,
        const TaskListScreen(),
        user: managerUser,
        tasks: repo,
      );

      expect(find.text('Tasks'), findsOneWidget);
      expect(find.text('Assigned to Alice Staff'), findsOneWidget);
      await tester.tap(find.byKey(const Key('task-list-assign')));
      await tester.pumpAndSettle();
      expect(find.textContaining('ROUTE:/tasks/new'), findsOneWidget);
    });

    testWidgets('Manager: filter by Category, then Brand, re-queries the '
        'server with category_value_id / brand_id', (tester) async {
      final repo = FakeTaskRepository()
        ..tasks = [
          task(),
          task(
            id: '2',
            title: 'Whiskas shelf',
            categoryValueId: '6',
            categoryName: 'Cat Food',
            brandId: '8',
            brandName: 'Whiskas',
          ),
        ];
      await pumpScreen(
        tester,
        const TaskListScreen(),
        user: managerUser,
        tasks: repo,
      );
      expect(find.text('Whiskas shelf'), findsOneWidget);

      await tester.tap(find.byKey(const Key('task-filter-category')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Dog Food'));
      await tester.pumpAndSettle();

      expect(repo.listCalls.last.categoryValueId, '5');
      expect(find.text('Whiskas shelf'), findsNothing);
      expect(find.text('Count Royal Canin dog food'), findsOneWidget);

      await tester.tap(find.byKey(const Key('task-filter-brand')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Whiskas'));
      await tester.pumpAndSettle();

      expect(repo.listCalls.last.categoryValueId, '5');
      expect(repo.listCalls.last.brandId, '8');
      expect(find.text('No tasks match this filter'), findsOneWidget);

      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();
      expect(repo.listCalls.last.categoryValueId, isNull);
      expect(repo.listCalls.last.brandId, isNull);
      expect(find.text('Whiskas shelf'), findsOneWidget);
    });

    testWidgets('loading state while the request is in flight', (tester) async {
      final gate = Completer<void>();
      final repo = FakeTaskRepository()..listGate = gate;
      await pumpScreen(
        tester,
        const TaskListScreen(),
        user: staffUser,
        tasks: repo,
        settle: false,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.text('No tasks assigned'), findsOneWidget);
    });

    testWidgets('error state with retry', (tester) async {
      final repo = FakeTaskRepository()
        ..listError = ApiException(message: 'Server unavailable');
      await pumpScreen(
        tester,
        const TaskListScreen(),
        user: staffUser,
        tasks: repo,
      );
      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Server unavailable'), findsOneWidget);

      repo
        ..listError = null
        ..tasks = [task()];
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Count Royal Canin dog food'), findsOneWidget);
    });
  });

  group('TaskDetailScreen', () {
    testWidgets('assignee sees context, category/brand scope products and '
        '"Mark In Progress"; no cancel', (tester) async {
      useTallViewport(tester);
      final repo = FakeTaskRepository()..detailTask = task();
      final items = FakeItemRepository()..catalogue = catalogue;
      await pumpScreen(
        tester,
        const TaskDetailScreen(taskId: '1'),
        user: staffUser,
        tasks: repo,
        items: items,
      );

      expect(find.text('Main Branch'), findsOneWidget);
      expect(find.text('Dog Food'), findsOneWidget);
      expect(find.text('Royal Canin'), findsOneWidget);
      expect(find.text('Rack A'), findsOneWidget);
      expect(find.text('Alice Staff'), findsOneWidget);
      // Products resolved from the category+brand scope (server filter).
      expect(items.scopedCalls.last, 'q=|cat=5|brand=7');
      expect(find.text('2 products in scope'), findsOneWidget);
      expect(find.text('RC Adult Dog 15kg'), findsOneWidget);
      expect(find.text('Whiskas Tuna 85g'), findsNothing);

      expect(find.text('Mark In Progress'), findsOneWidget);
      expect(find.text('Cancel Task'), findsNothing);
      expect(find.text('Start Stock Count'), findsOneWidget);
      expect(find.text('Start Expiry Check'), findsOneWidget);
    });

    testWidgets('Mark In Progress calls the status transition endpoint', (
      tester,
    ) async {
      useTallViewport(tester);
      final repo = FakeTaskRepository()..detailTask = task();
      await pumpScreen(
        tester,
        const TaskDetailScreen(taskId: '1'),
        user: staffUser,
        tasks: repo,
      );

      await tester.tap(find.text('Mark In Progress'));
      await tester.pumpAndSettle();
      expect(repo.statusCalls, ['1:in_progress']);
    });

    testWidgets('a server rejection is shown, not swallowed', (tester) async {
      useTallViewport(tester);
      final repo = FakeTaskRepository()
        ..detailTask = task()
        ..statusError = ApiException(
          message: 'You are not allowed to perform this transition.',
          statusCode: 403,
        );
      await pumpScreen(
        tester,
        const TaskDetailScreen(taskId: '1'),
        user: staffUser,
        tasks: repo,
      );

      await tester.tap(find.text('Mark In Progress'));
      await tester.pumpAndSettle();
      expect(
        find.text('You are not allowed to perform this transition.'),
        findsOneWidget,
      );
    });

    testWidgets('manager on an in-progress task can cancel, not start', (
      tester,
    ) async {
      useTallViewport(tester);
      final repo = FakeTaskRepository()
        ..detailTask = task(status: 'in_progress');
      await pumpScreen(
        tester,
        const TaskDetailScreen(taskId: '1'),
        user: managerUser,
        tasks: repo,
      );

      expect(find.text('Cancel Task'), findsOneWidget);
      expect(find.text('Mark In Progress'), findsNothing);
      await tester.tap(find.text('Cancel Task'));
      await tester.pumpAndSettle();
      expect(repo.statusCalls, ['1:cancelled']);
    });

    testWidgets(
      'explicitly selected products are listed instead of the scope',
      (tester) async {
        useTallViewport(tester);
        final repo = FakeTaskRepository()
          ..detailTask = task(
            items: const [
              TaskItemModel(
                itemId: '100',
                itemName: 'RC Adult Dog 15kg',
                itemCode: 'RC001',
                batchNo: 'B1',
              ),
            ],
          );
        final items = FakeItemRepository()..catalogue = catalogue;
        await pumpScreen(
          tester,
          const TaskDetailScreen(taskId: '1'),
          user: staffUser,
          tasks: repo,
          items: items,
        );

        expect(find.text('RC Adult Dog 15kg'), findsOneWidget);
        expect(find.text('RC001 · Batch B1'), findsOneWidget);
        expect(items.scopedCalls, isEmpty);
      },
    );

    testWidgets('shows task progress: distinct products counted / target', (
      tester,
    ) async {
      useTallViewport(tester);
      final base = task(
        items: const [
          TaskItemModel(itemId: '100', itemName: 'RC Adult Dog 15kg'),
          TaskItemModel(itemId: '101', itemName: 'RC Puppy 4kg'),
        ],
      );
      final repo = FakeTaskRepository()
        ..detailTask = TaskModel(
          id: base.id,
          branchId: base.branchId,
          title: base.title,
          assignedTo: base.assignedTo,
          priority: base.priority,
          status: base.status,
          items: base.items,
          observedItemIds: const {'100'},
          observationCount: 2,
        );
      await pumpScreen(
        tester,
        const TaskDetailScreen(taskId: '1'),
        user: staffUser,
        tasks: repo,
      );

      expect(find.text('1 of 2 products counted'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });
    testWidgets('completed task hides count actions', (tester) async {
      useTallViewport(tester);
      final repo = FakeTaskRepository()..detailTask = task(status: 'completed');
      await pumpScreen(
        tester,
        const TaskDetailScreen(taskId: '1'),
        user: staffUser,
        tasks: repo,
      );
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('Start Stock Count'), findsNothing);
      expect(find.text('Mark Complete'), findsNothing);
    });
  });

  group('CreateTaskScreen (assign by Category / Brand)', () {
    /// Opens the multi-select category/brand dialog, checks each named
    /// option, then confirms with "Done".
    Future<void> chooseMulti(
      WidgetTester tester,
      String fieldKey,
      List<String> options,
    ) async {
      await tester.tap(
        find.descendant(
          of: find.byKey(Key(fieldKey)),
          matching: find.byType(InkWell),
        ),
      );
      await tester.pumpAndSettle();
      for (final option in options) {
        await tester.tap(find.widgetWithText(CheckboxListTile, option));
        await tester.pump();
      }
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
    }

    testWidgets('title is required — nothing is submitted', (tester) async {
      useTallViewport(tester);
      final repo = FakeTaskRepository();
      await pumpScreen(
        tester,
        const CreateTaskScreen(),
        user: managerUser,
        tasks: repo,
      );

      await tester.tap(find.widgetWithText(ElevatedButton, 'Assign Task'));
      await tester.pumpAndSettle();
      expect(find.text('Title is required'), findsOneWidget);
      expect(repo.createCalls, isEmpty);
    });

    testWidgets('assigns a task scoped by category + brand with an in-scope '
        'product, sending category_value_id / brand_id / items', (
      tester,
    ) async {
      useTallViewport(tester);
      final repo = FakeTaskRepository();
      final items = FakeItemRepository()..catalogue = catalogue;
      await pumpScreen(
        tester,
        const CreateTaskScreen(),
        user: managerUser,
        tasks: repo,
        items: items,
      );

      // Branch defaults to the manager's own branch.
      expect(find.text('Main Branch'), findsOneWidget);

      await chooseMulti(tester, 'create-task-category', ['Dog Food']);
      await chooseMulti(tester, 'create-task-brand', ['Royal Canin']);
      expect(find.text('2 products in this scope'), findsOneWidget);

      // Product picker only offers products inside the scope.
      await tester.tap(find.byKey(const Key('create-task-pick-products')));
      await tester.pumpAndSettle();
      expect(find.text('RC Adult Dog 15kg'), findsOneWidget);
      expect(find.text('Whiskas Tuna 85g'), findsNothing);
      await tester.tap(find.text('RC Adult Dog 15kg'));
      await tester.pump();
      await tester.tap(find.text('Use 1 product'));
      await tester.pumpAndSettle();
      expect(find.text('1 product selected'), findsOneWidget);

      await tester.enterText(
        find.descendant(
          of: find.widgetWithText(Column, 'Task title'),
          matching: find.byType(TextFormField),
        ),
        'Count RC dog food',
      );
      await chooseMulti(
        tester,
        'create-task-assignee',
        ['Alice Staff (Staff)'],
      );
      await tester.tap(find.text('High'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Assign Task'));
      await tester.pumpAndSettle();

      expect(repo.createCalls, hasLength(1));
      final body = repo.createCalls.single;
      expect(body['branch_id'], '1');
      expect(body['title'], 'Count RC dog food');
      expect(body['category_value_ids'], ['5']);
      expect(body['brand_ids'], ['7']);
      expect(body['assigned_to'], '11');
      expect(body['priority'], 'high');
      expect(body['items'], [
        {'item_id': '100'},
      ]);
    });

    testWidgets('picking a batch for a selected product sends batch_no', (
      tester,
    ) async {
      useTallViewport(tester);
      final repo = FakeTaskRepository();
      final items = FakeItemRepository()
        ..catalogue = catalogue
        ..batchesByItem = {
          '100': [
            BatchModel.fromJson({'batch_no': 'B-100', 'exp_date': '2026-12-01'}),
            BatchModel.fromJson({'batch_no': 'B-200', 'exp_date': '2027-01-01'}),
          ],
        };
      await pumpScreen(
        tester,
        const CreateTaskScreen(),
        user: managerUser,
        tasks: repo,
        items: items,
      );

      await chooseMulti(tester, 'create-task-category', ['Dog Food']);
      await chooseMulti(tester, 'create-task-brand', ['Royal Canin']);

      await tester.tap(find.byKey(const Key('create-task-pick-products')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('RC Adult Dog 15kg'));
      await tester.pumpAndSettle();

      // Batch dropdown appears once the product is checked.
      final batchField = find.byKey(const Key('product-picker-batch-100'));
      expect(batchField, findsOneWidget);
      await tester.tap(batchField);
      await tester.pumpAndSettle();
      await tester.tap(find.text('B-200').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Use 1 product'));
      await tester.pumpAndSettle();
      expect(find.textContaining('batch B-200'), findsOneWidget);

      await tester.enterText(
        find.descendant(
          of: find.widgetWithText(Column, 'Task title'),
          matching: find.byType(TextFormField),
        ),
        'Count RC dog food',
      );
      await chooseMulti(
        tester,
        'create-task-assignee',
        ['Alice Staff (Staff)'],
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Assign Task'));
      await tester.pumpAndSettle();

      expect(repo.createCalls, hasLength(1));
      expect(repo.createCalls.single['items'], [
        {'item_id': '100', 'batch_no': 'B-200'},
      ]);
    });

    testWidgets('changing the brand drops selected products outside it', (
      tester,
    ) async {
      useTallViewport(tester);
      final items = FakeItemRepository()..catalogue = catalogue;
      await pumpScreen(
        tester,
        const CreateTaskScreen(),
        user: managerUser,
        items: items,
      );

      await chooseMulti(tester, 'create-task-brand', ['Royal Canin']);
      await tester.tap(find.byKey(const Key('create-task-pick-products')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('RC Puppy 4kg'));
      await tester.pump();
      await tester.tap(find.text('Use 1 product'));
      await tester.pumpAndSettle();
      expect(find.text('1 product selected'), findsOneWidget);

      // Switching the brand selection to Whiskas-only drops the RC product.
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('create-task-brand')),
          matching: find.byType(InkWell),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Royal Canin'));
      await tester.pump();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Whiskas'));
      await tester.pump();
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(find.text('1 product selected'), findsNothing);
      expect(find.text('Pick specific products (optional)'), findsOneWidget);
    });

    testWidgets('server-side validation errors are shown', (tester) async {
      useTallViewport(tester);
      final repo = FakeTaskRepository()
        ..createError = ApiException(
          message:
              'These selected products do not belong to the chosen category/brand: Whiskas Tuna 85g.',
          statusCode: 422,
        );
      await pumpScreen(
        tester,
        const CreateTaskScreen(),
        user: managerUser,
        tasks: repo,
      );

      await tester.enterText(
        find.descendant(
          of: find.widgetWithText(Column, 'Task title'),
          matching: find.byType(TextFormField),
        ),
        'Bad scope',
      );
      await chooseMulti(
        tester,
        'create-task-assignee',
        ['Alice Staff (Staff)'],
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Assign Task'));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('create-task-error')), findsOneWidget);
      expect(find.textContaining('Whiskas Tuna 85g'), findsOneWidget);
    });
  });
}
