import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_pets_verify/core/network/api_exception.dart';
import 'package:urban_pets_verify/features/expiry/presentation/screens/expiry_verification_screen.dart';
import 'package:urban_pets_verify/features/review/presentation/screens/observation_detail_screen.dart';
import 'package:urban_pets_verify/features/stock_count/presentation/screens/stock_count_screen.dart';
import 'package:urban_pets_verify/shared/models/models.dart';
import 'package:urban_pets_verify/shared/widgets/widgets.dart';

import '../helpers/test_harness.dart';

final item = ItemModel(
  id: '100',
  name: 'Royal Canin Adult Dog 15kg',
  sku: 'RC-AD-15',
);

void main() {
  group('StockCountScreen — blind count + Save & Next Scan', () {
    testWidgets('blind mode: no system quantity anywhere, even when handed a '
        'batch that carries one', (tester) async {
      useTallViewport(tester);
      final batch = BatchModel.fromJson({
        'batch_no': 'A2301',
        'exp_date': '2026-07-18',
        'remaining_qty': 777,
      });
      await pumpScreen(
        tester,
        StockCountScreen(item: item, batch: batch, taskId: '3'),
        user: staffUser,
      );

      expect(find.textContaining('Blind Count Mode'), findsOneWidget);
      expect(find.textContaining('777'), findsNothing);
      expect(find.text('System Qty'), findsNothing);
      expect(find.textContaining('A2301'), findsWidgets);
    });

    testWidgets('stepper updates the physical quantity; Save & Next Scan '
        'submits it and returns to the scanner for the same task', (
      tester,
    ) async {
      useTallViewport(tester);
      final repo = FakeObservationRepository();
      await pumpScreen(
        tester,
        StockCountScreen(item: item, taskId: '3'),
        user: staffUser,
        observations: repo,
      );

      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byIcon(Icons.add));
        await tester.pump();
      }
      await tester.tap(find.byIcon(Icons.remove));
      await tester.pump();
      expect(find.text('2'), findsOneWidget);

      await tester.tap(find.text('Save & Next Scan'));
      await tester.pumpAndSettle();

      expect(repo.submitCalls, hasLength(1));
      final call = repo.submitCalls.single;
      expect(call.type, 'stock_count');
      expect(call.itemId, '100');
      expect(call.taskId, '3');
      expect(call.branchId, '1');
      expect(call.physicalQty, 2);
      expect(call.idempotencyKey, isNotEmpty);
      expect(find.textContaining('ROUTE:/scanner'), findsOneWidget);
      expect(find.textContaining('mode: stock_count'), findsOneWidget);
      expect(find.textContaining('taskId: 3'), findsOneWidget);
    });

    testWidgets('unified flow: physical quantity and observed expiry date + batch are entered and submitted together', (
      tester,
    ) async {
      useTallViewport(tester);
      final repo = FakeObservationRepository();
      await pumpScreen(
        tester,
        StockCountScreen(item: item, taskId: '5'),
        user: staffUser,
        observations: repo,
      );

      // Increment physical qty to 3
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byIcon(Icons.add));
        await tester.pump();
      }

      // Enter optional batch and expiry date (15102026 -> 15/10/2026)
      await tester.enterText(
        find.widgetWithText(TextField, 'Batch Number (Optional)'),
        'BAT-99',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Observed Expiry Date (Optional)'),
        '15102026',
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Valid date: 15/10/2026'), findsOneWidget);

      await tester.tap(find.text('Save & Finish'));
      await tester.pumpAndSettle();

      expect(repo.submitCalls, hasLength(1));
      final call = repo.submitCalls.single;
      expect(call.type, 'stock_count');
      expect(call.itemId, '100');
      expect(call.physicalQty, 3);
      expect(call.batchNo, 'BAT-99');
      expect(call.expDateObserved, DateTime(2026, 10, 15));
      expect(find.textContaining('ROUTE:/submission-confirmation'), findsOneWidget);
    });

    testWidgets('Save & Finish goes to the submission confirmation', (
      tester,
    ) async {
      useTallViewport(tester);
      final repo = FakeObservationRepository();
      await pumpScreen(
        tester,
        StockCountScreen(item: item),
        user: staffUser,
        observations: repo,
      );

      await tester.tap(find.text('Save & Finish'));
      await tester.pumpAndSettle();
      expect(find.textContaining('ROUTE:/submission-confirmation'), findsOne);
    });

    testWidgets('repeated taps while submitting do not create duplicate '
        'submissions', (tester) async {
      useTallViewport(tester);
      final gate = Completer<void>();
      final repo = FakeObservationRepository()..submitGate = gate;
      await pumpScreen(
        tester,
        StockCountScreen(item: item),
        user: staffUser,
        observations: repo,
      );

      await tester.tap(find.text('Save & Next Scan'));
      await tester.pump();
      // Button is now in its loading state; further taps are ignored.
      await tester.tap(find.text('Save & Finish'), warnIfMissed: false);
      await tester.pump();
      expect(repo.submitCalls, hasLength(1));

      gate.complete();
      await tester.pumpAndSettle();
      expect(repo.submitCalls, hasLength(1));
    });

    testWidgets('a failed submission shows the error, stays on screen, and a '
        'retry reuses the SAME idempotency key', (tester) async {
      useTallViewport(tester);
      final repo = FakeObservationRepository()
        ..submitError = ApiException(
          message: 'Network error. Please check your connection and try again.',
          isNetworkError: true,
        );
      await pumpScreen(
        tester,
        StockCountScreen(item: item),
        user: staffUser,
        observations: repo,
      );

      await tester.tap(find.text('Save & Next Scan'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Network error'), findsOneWidget);
      expect(find.text('Stock & Expiry Check'), findsOneWidget); // still here

      repo.submitError = null;
      await tester.tap(find.text('Save & Next Scan'));
      await tester.pumpAndSettle();

      expect(repo.submitCalls, hasLength(2));
      expect(
        repo.submitCalls[1].idempotencyKey,
        repo.submitCalls[0].idempotencyKey,
      );
      expect(find.textContaining('ROUTE:/scanner'), findsOneWidget);
    });
  });

  group('ExpiryVerificationScreen', () {
    testWidgets('observed expiry date is required before submitting (batch is optional)', (tester) async {
      useTallViewport(tester);
      final repo = FakeObservationRepository();
      await pumpScreen(
        tester,
        ExpiryVerificationScreen(item: item),
        user: staffUser,
        observations: repo,
      );

      await tester.tap(find.text('Save & Finish'));
      await tester.pump();
      expect(find.textContaining('Observed expiry date is required'), findsOneWidget);
      expect(repo.submitCalls, isEmpty);
    });

    testWidgets('submits an expiry_check with batch + observed expiry and '
        'shows the confirmation (no quantity is invented)', (tester) async {
      useTallViewport(tester);
      final repo = FakeObservationRepository();
      final batch = BatchModel(
        batchNo: 'B9981',
        expDate: DateTime(2026, 7, 18),
      );
      await pumpScreen(
        tester,
        ExpiryVerificationScreen(item: item, batch: batch, taskId: '4'),
        user: staffUser,
        observations: repo,
      );

      expect(find.text('18/7/2026'), findsOneWidget);
      await tester.tap(find.text('Save & Finish'));
      await tester.pumpAndSettle();

      final call = repo.submitCalls.single;
      expect(call.type, 'expiry_check');
      expect(call.batchNo, 'B9981');
      expect(call.expDateObserved, DateTime(2026, 7, 18));
      expect(call.taskId, '4');
      expect(call.physicalQty, isNull);
      expect(find.textContaining('ROUTE:/submission-confirmation'), findsOne);
    });
  });

  group('ObservationDetailScreen — review actions', () {
    ObservationModel pending({
      num? physicalQty = 18,
      String type = 'stock_count',
    }) => obs(
      id: '5',
      type: type,
      physicalQty: physicalQty,
      systemQty: 20,
      submittedByName: 'John Tan',
    );

    testWidgets('manager sees system qty / physical / variance and can '
        'approve the counted quantity', (tester) async {
      useTallViewport(tester);
      final repo = FakeObservationRepository();
      await pumpScreen(
        tester,
        ObservationDetailScreen(observation: pending()),
        user: managerUser,
        observations: repo,
      );

      expect(find.text('System Qty'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);
      expect(find.text('-2'), findsOneWidget);
      expect(find.text('John Tan'), findsOneWidget);

      await tester.tap(find.widgetWithText(ElevatedButton, 'Approve'));
      await tester.pumpAndSettle();
      expect(repo.reviewCalls, ['approve:5:18']);
    });

    testWidgets('manager can change the approved target quantity', (
      tester,
    ) async {
      useTallViewport(tester);
      final repo = FakeObservationRepository();
      await pumpScreen(
        tester,
        ObservationDetailScreen(observation: pending()),
        user: managerUser,
        observations: repo,
      );

      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('approved-qty-field')),
          matching: find.byType(TextFormField),
        ),
        '17',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Approve'));
      await tester.pumpAndSettle();
      expect(repo.reviewCalls, ['approve:5:17']);
    });

    testWidgets('a stock-count observation without a counted qty can NOT be '
        'approved as an accidental 0 — a target must be entered', (
      tester,
    ) async {
      useTallViewport(tester);
      final repo = FakeObservationRepository();
      await pumpScreen(
        tester,
        ObservationDetailScreen(
          observation: pending(physicalQty: null, type: 'stock_count'),
        ),
        user: managerUser,
        observations: repo,
      );

      final approve = find.widgetWithText(ElevatedButton, 'Approve');
      expect(tester.widget<ElevatedButton>(approve).onPressed, isNull);
      await tester.tap(approve, warnIfMissed: false);
      await tester.pump();
      expect(repo.reviewCalls, isEmpty);
    });

    testWidgets(
      'an expiry_check with no counted qty CAN be approved — it never '
      'touches stock, so no quantity field is required or shown',
      (tester) async {
        useTallViewport(tester);
        final repo = FakeObservationRepository();
        await pumpScreen(
          tester,
          ObservationDetailScreen(
            observation: pending(physicalQty: null, type: 'expiry_check'),
          ),
          user: managerUser,
          observations: repo,
        );

        expect(find.byKey(const Key('approved-qty-field')), findsNothing);
        final approve = find.widgetWithText(ElevatedButton, 'Approve');
        expect(tester.widget<ElevatedButton>(approve).onPressed, isNotNull);
        await tester.tap(approve);
        await tester.pumpAndSettle();
        expect(repo.reviewCalls, ['approve:5:null']);
      },
    );

    testWidgets('Request Recount / Reject require remarks, then enable', (
      tester,
    ) async {
      useTallViewport(tester);
      final repo = FakeObservationRepository();
      await pumpScreen(
        tester,
        ObservationDetailScreen(observation: pending()),
        user: managerUser,
        observations: repo,
      );

      final recount = find.widgetWithText(OutlinedButton, 'Request Recount');
      expect(tester.widget<OutlinedButton>(recount).onPressed, isNull);

      await tester.enterText(
        find.descendant(
          of: find.widgetWithText(AppTextField, 'Review Remarks'),
          matching: find.byType(TextFormField),
        ),
        'Recount rack A',
      );
      await tester.pump();
      expect(tester.widget<OutlinedButton>(recount).onPressed, isNotNull);

      await tester.tap(recount);
      await tester.pumpAndSettle();
      expect(repo.reviewCalls, ['recount:5:Recount rack A']);
    });

    testWidgets('reject with remarks', (tester) async {
      useTallViewport(tester);
      final repo = FakeObservationRepository();
      await pumpScreen(
        tester,
        ObservationDetailScreen(observation: pending()),
        user: managerUser,
        observations: repo,
      );

      await tester.enterText(
        find.descendant(
          of: find.widgetWithText(AppTextField, 'Review Remarks'),
          matching: find.byType(TextFormField),
        ),
        'Wrong product scanned',
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(ElevatedButton, 'Reject'));
      await tester.pumpAndSettle();
      expect(repo.reviewCalls, ['reject:5:Wrong product scanned']);
    });

    testWidgets('already-reviewed observation shows no actions', (
      tester,
    ) async {
      useTallViewport(tester);
      await pumpScreen(
        tester,
        ObservationDetailScreen(
          observation: obs(id: '6', status: 'approved', systemQty: 20),
        ),
        user: managerUser,
      );
      expect(find.text('Approve'), findsNothing);
      expect(find.text('Reject'), findsNothing);
    });

    testWidgets('staff opening their own submission sees no system qty, no '
        'variance and no review actions', (tester) async {
      useTallViewport(tester);
      await pumpScreen(
        tester,
        // Defence in depth: even a model carrying a system qty must not show it.
        ObservationDetailScreen(observation: pending()),
        user: staffUser,
      );

      expect(find.text('Your count'), findsOneWidget);
      expect(find.text('18'), findsOneWidget);
      expect(find.text('System Qty'), findsNothing);
      expect(find.text('20'), findsNothing);
      expect(find.text('-2'), findsNothing);
      expect(find.text('Approve'), findsNothing);
      expect(find.text('Request Recount'), findsNothing);
    });

    ObservationModel withPhoto() => ObservationModel(
      id: '5',
      type: 'stock_count',
      itemId: '1005',
      itemName: 'Royal Canin Adult Dog 15kg',
      branchId: '1',
      idempotencyKey: 'key-5',
      status: 'pending',
      physicalQty: 18,
      systemQtySnapshot: 20,
      submittedByName: 'John Tan',
      photoPath: 'observations/evidence.jpg',
    );

    ObservationModel withRecounts() => ObservationModel(
      id: '5',
      type: 'stock_count',
      itemId: '1005',
      itemName: 'Royal Canin Adult Dog 15kg',
      branchId: '1',
      idempotencyKey: 'key-5',
      status: 'pending',
      physicalQty: 18,
      systemQtySnapshot: 20,
      submittedByName: 'John Tan',
      recounts: [obs(id: '4', status: 'rejected', physicalQty: 10)],
    );

    testWidgets('manager sees the evidence photo card when the observation '
        'has a photo', (tester) async {
      useTallViewport(tester);
      final repo = FakeObservationRepository()..showHandler = (id) => withPhoto();
      await pumpScreen(
        tester,
        ObservationDetailScreen(observation: pending()),
        user: managerUser,
        observations: repo,
      );

      expect(repo.showCalls, ['5']);
      expect(find.text('Evidence Photo'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('staff never sees the evidence photo card, even if the '
        'observation has one', (tester) async {
      useTallViewport(tester);
      final repo = FakeObservationRepository()..showHandler = (id) => withPhoto();
      await pumpScreen(
        tester,
        ObservationDetailScreen(observation: pending()),
        user: staffUser,
        observations: repo,
      );

      expect(find.text('Evidence Photo'), findsNothing);
    });

    testWidgets('recount history lists prior attempts and their outcome', (
      tester,
    ) async {
      useTallViewport(tester);
      final repo = FakeObservationRepository()
        ..showHandler = (id) => withRecounts();
      await pumpScreen(
        tester,
        ObservationDetailScreen(observation: pending()),
        user: managerUser,
        observations: repo,
      );

      expect(find.text('Recount History'), findsOneWidget);
      expect(find.textContaining('Recount · 10'), findsOneWidget);
    });

    testWidgets('no recount history section when there is no recount chain', (
      tester,
    ) async {
      useTallViewport(tester);
      await pumpScreen(
        tester,
        ObservationDetailScreen(observation: pending()),
        user: managerUser,
      );

      expect(find.text('Recount History'), findsNothing);
    });
  });
}
