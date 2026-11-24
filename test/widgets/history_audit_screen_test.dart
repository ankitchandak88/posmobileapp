import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_pets_verify/core/network/api_exception.dart';
import 'package:urban_pets_verify/features/history/presentation/screens/history_audit_screen.dart';
import 'package:urban_pets_verify/shared/models/models.dart';

import '../helpers/test_harness.dart';

void main() {
  final managerRows = [
    obs(id: '1', systemQty: 20, physicalQty: 18, submittedByName: 'John Tan'),
    obs(
      id: '2',
      itemName: 'Whiskas Tuna 85g',
      status: 'approved',
      systemQty: 4,
      physicalQty: 10,
      submittedByName: 'Alex Wong',
    ),
    obs(
      id: '3',
      itemName: "Hill's Science Diet 1.5kg",
      status: 'recount_requested',
      systemQty: 7,
      physicalQty: 7,
      submittedByName: 'Mary Lim',
    ),
  ];

  PagedResult<ObservationModel> onePage(List<ObservationModel> rows) =>
      PagedResult(items: rows, currentPage: 1, lastPage: 1, total: rows.length);

  group('HistoryAuditScreen — Manager/Owner (cross-staff audit)', () {
    testWidgets('renders the reference layout: filters, tabs, rows with '
        'submitter, signed variance and status pills', (tester) async {
      useTallViewport(tester);
      final repo = FakeObservationRepository()
        ..historyHandler = (_) => onePage(managerRows);

      await pumpScreen(
        tester,
        const HistoryAuditScreen(),
        user: managerUser,
        observations: repo,
      );

      expect(find.text('History & Audit'), findsOneWidget);
      expect(find.text('Branch'), findsOneWidget);
      expect(find.text('Date Range'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Stock Count'), findsOneWidget);
      expect(find.text('Expiry Check'), findsOneWidget);

      expect(find.text('Royal Canin Adult Dog 15kg'), findsOneWidget);
      expect(find.text('24 Apr 2025, 10:24 AM'), findsNWidgets(3));
      expect(find.text('John Tan'), findsOneWidget);
      expect(find.text('Alex Wong'), findsOneWidget);
      expect(find.text('-2'), findsOneWidget);
      expect(find.text('+6'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('Approved'), findsOneWidget);
      expect(find.text('Recount'), findsOneWidget);
      expect(find.textContaining('3 records'), findsOneWidget);
      expect(find.textContaining('All staff'), findsOneWidget);

      // Reviewer uses the cross-staff endpoint, never the own-only one.
      expect(repo.historyCalls.map((c) => c.endpoint).toSet(), {'history'});
    });

    testWidgets('type tabs re-query the server with the right type filter', (
      tester,
    ) async {
      final repo = FakeObservationRepository()
        ..historyHandler = (_) => onePage(managerRows);
      await pumpScreen(
        tester,
        const HistoryAuditScreen(),
        user: managerUser,
        observations: repo,
      );

      await tester.tap(find.byKey(const Key('history-tab-expiryCheck')));
      await tester.pumpAndSettle();
      expect(repo.historyCalls.last.type, 'expiry_check');
      expect(repo.historyCalls.last.page, 1);

      await tester.tap(find.byKey(const Key('history-tab-stockCount')));
      await tester.pumpAndSettle();
      expect(repo.historyCalls.last.type, 'stock_count');

      await tester.tap(find.byKey(const Key('history-tab-all')));
      await tester.pumpAndSettle();
      expect(repo.historyCalls.last.type, isNull);
    });

    testWidgets('status filter sheet applies and clears a status filter', (
      tester,
    ) async {
      final repo = FakeObservationRepository()
        ..historyHandler = (_) => onePage(managerRows);
      await pumpScreen(
        tester,
        const HistoryAuditScreen(),
        user: managerUser,
        observations: repo,
      );

      await tester.tap(find.byKey(const Key('history-status-filter')));
      await tester.pumpAndSettle();
      expect(find.text('Filter by status'), findsOneWidget);
      await tester.tap(find.widgetWithText(ListTile, 'Approved'));
      await tester.pumpAndSettle();

      expect(repo.historyCalls.last.status, 'approved');
      expect(find.byKey(const Key('history-status-chip')), findsOneWidget);

      // Delete the chip → status cleared → re-query without status.
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('history-status-chip')),
          matching: find.byIcon(Icons.close_rounded),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.historyCalls.last.status, isNull);
      expect(find.byKey(const Key('history-status-chip')), findsNothing);
    });

    testWidgets('branch dropdown filters by branch (Owner with 2 branches)', (
      tester,
    ) async {
      final repo = FakeObservationRepository()
        ..historyHandler = (_) => onePage(managerRows);
      await pumpScreen(
        tester,
        const HistoryAuditScreen(),
        user: managerUser,
        observations: repo,
        branches: [
          BranchModel(id: '1', name: 'Satellite'),
          BranchModel(id: '2', name: 'Motera'),
        ],
      );

      expect(find.text('All Branches'), findsOneWidget);
      await tester.tap(find.byKey(const Key('history-branch')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Motera').last);
      await tester.pumpAndSettle();

      expect(repo.historyCalls.last.branchId, '2');
    });

    testWidgets('paginates: Load more fetches the next page and appends', (
      tester,
    ) async {
      useTallViewport(tester);
      final repo = FakeObservationRepository()
        ..historyHandler = (call) => call.page == 1
            ? PagedResult(
                items: [managerRows[0]],
                currentPage: 1,
                lastPage: 2,
                total: 2,
              )
            : PagedResult(
                items: [managerRows[1]],
                currentPage: 2,
                lastPage: 2,
                total: 2,
              );

      await pumpScreen(
        tester,
        const HistoryAuditScreen(),
        user: managerUser,
        observations: repo,
      );

      expect(find.text('Whiskas Tuna 85g'), findsNothing);
      // The tall viewport means the scroll threshold may already have
      // triggered page 2; tap Load more only if it is still offered.
      final loadMore = find.byKey(const Key('history-load-more'));
      if (loadMore.evaluate().isNotEmpty) {
        await tester.tap(loadMore);
        await tester.pumpAndSettle();
      }

      expect(repo.historyCalls.map((c) => c.page), containsAllInOrder([1, 2]));
      expect(find.text('Royal Canin Adult Dog 15kg'), findsOneWidget);
      expect(find.text('Whiskas Tuna 85g'), findsOneWidget);
      expect(find.text('End of history'), findsOneWidget);
    });

    testWidgets('empty state', (tester) async {
      await pumpScreen(
        tester,
        const HistoryAuditScreen(),
        user: managerUser,
        observations: FakeObservationRepository(),
      );
      expect(find.text('No history found'), findsOneWidget);
    });

    testWidgets('error state with retry', (tester) async {
      final repo = FakeObservationRepository()
        ..historyError = ApiException(
          message: 'Network error. Please check your connection and try again.',
          isNetworkError: true,
        );
      await pumpScreen(
        tester,
        const HistoryAuditScreen(),
        user: managerUser,
        observations: repo,
      );

      expect(find.text("You're offline"), findsOneWidget);
      final callsBefore = repo.historyCalls.length;

      repo
        ..historyError = null
        ..historyHandler = (_) => onePage(managerRows);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();

      expect(repo.historyCalls.length, callsBefore + 1);
      expect(find.text('Royal Canin Adult Dog 15kg'), findsOneWidget);
    });

    testWidgets('tapping a row opens the observation detail route', (
      tester,
    ) async {
      final repo = FakeObservationRepository()
        ..historyHandler = (_) => onePage(managerRows);
      await pumpScreen(
        tester,
        const HistoryAuditScreen(),
        user: managerUser,
        observations: repo,
      );

      await tester.tap(find.text('Whiskas Tuna 85g'));
      await tester.pumpAndSettle();
      expect(find.textContaining('ROUTE:/review/2'), findsOneWidget);
    });
  });

  group('HistoryAuditScreen — Staff (own records only, blind)', () {
    testWidgets('uses the own-only endpoint and never renders variance, '
        'even if a row somehow carried a system quantity', (tester) async {
      final repo = FakeObservationRepository()
        ..historyHandler = (_) => onePage([
          // Defence in depth: the real /mine endpoint never sends
          // system_qty_snapshot; even if it did, nothing may show it.
          obs(id: '9', systemQty: 999, physicalQty: 12, batchNo: 'A2301'),
        ]);

      await pumpScreen(
        tester,
        const HistoryAuditScreen(),
        user: staffUser,
        observations: repo,
      );

      expect(repo.historyCalls, isNotEmpty);
      expect(repo.historyCalls.map((c) => c.endpoint).toSet(), {'mine'});

      expect(find.text('Royal Canin Adult Dog 15kg'), findsOneWidget);
      expect(find.text('Stock Count · Batch A2301'), findsOneWidget);
      expect(find.byKey(const Key('variance-9')), findsNothing);
      expect(find.textContaining('999'), findsNothing);
      expect(find.text('-987'), findsNothing);
      expect(find.textContaining('Your submissions only'), findsOneWidget);
      // Single own branch from /branches → locked, shown by name.
      expect(find.text('Main Branch'), findsOneWidget);
    });

    testWidgets('staff filters are passed through to the own-only endpoint', (
      tester,
    ) async {
      final repo = FakeObservationRepository();
      await pumpScreen(
        tester,
        const HistoryAuditScreen(),
        user: staffUser,
        observations: repo,
      );

      await tester.tap(find.byKey(const Key('history-tab-expiryCheck')));
      await tester.pumpAndSettle();

      expect(repo.historyCalls.last.endpoint, 'mine');
      expect(repo.historyCalls.last.type, 'expiry_check');
      expect(find.text('No history found'), findsOneWidget);
    });
  });
}
