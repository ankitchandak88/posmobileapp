import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_pets_verify/features/purchase/data/purchase_order_model.dart';
import 'package:urban_pets_verify/features/purchase/presentation/screens/inward_entry_screen.dart';
import 'package:urban_pets_verify/shared/models/models.dart';

import '../helpers/test_harness.dart';

final testItem = ItemModel(
  id: '101',
  name: 'Pedigree Adult Meat & Rice 10kg',
  sku: 'PED-10K',
  mrp: 1250,
);

final testExtraItem = ItemModel(
  id: '999',
  name: 'Royal Canin Maxi Puppy 4kg',
  sku: 'RC-MAXI',
  mrp: 2900,
);

const testSupplier = SupplierModel(
  id: '7',
  name: 'Mars Petcare India',
  mobile: '9876543210',
);

const testPO = PurchaseOrderModel(
  id: '501',
  poNumber: 'PO-2026-0042',
  supplierId: '7',
  supplierName: 'Mars Petcare India',
  branchId: '1',
  totalQty: 25,
  totalItems: 2,
  items: [
    PurchaseOrderItemModel(
      id: '1',
      poItemId: '1',
      itemId: '101',
      name: 'Pedigree Adult Meat & Rice 10kg',
      orderedQty: 10,
    ),
    PurchaseOrderItemModel(
      id: '2',
      poItemId: '2',
      itemId: '102',
      name: 'Whiskas Ocean Fish 3kg',
      orderedQty: 15,
    ),
  ],
);

void main() {
  group('InwardEntryScreen', () {
    testWidgets('shows PO selector and ad-hoc inward options when no initial PO/supplier provided', (tester) async {
      useTallViewport(tester);
      await pumpScreen(
        tester,
        const InwardEntryScreen(),
        user: staffUser,
      );

      expect(find.text('Inward / Stock Receive'), findsOneWidget);
      expect(find.text('Select Purchase Order (Recommended)'), findsOneWidget);
      expect(find.text('Or Direct Inward without PO (Ad-hoc)'), findsOneWidget);
    });

    testWidgets('submits inward observation with supplier, quantity, and expiry date', (tester) async {
      useTallViewport(tester);
      final repo = FakeObservationRepository();

      await pumpScreen(
        tester,
        InwardEntryScreen(
          initialSupplier: testSupplier,
          item: testItem,
        ),
        user: staffUser,
        observations: repo,
      );

      // Verify supplier and product details are shown
      expect(find.text('Mars Petcare India'), findsOneWidget);
      expect(find.textContaining('Pedigree Adult Meat & Rice 10kg'), findsOneWidget);

      // Increment inward quantity to 3 (starts null -> 1 -> 2 -> 3)
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      // Enter Batch and Expiry Date
      await tester.enterText(
        find.widgetWithText(TextField, 'Batch Number (Optional)'),
        'MARS-BATCH-01',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Observed Expiry Date'),
        '25122026',
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Valid date: 25/12/2026'), findsOneWidget);

      // Submit via Save & Finish
      await tester.tap(find.text('Save & Finish (Submit to POS)'));
      await tester.pumpAndSettle();

      expect(repo.submitCalls, hasLength(1));
      final call = repo.submitCalls.single;
      expect(call.type, 'stock_count');
      expect(call.itemId, '101');
      expect(call.supplierId, '7');
      expect(call.physicalQty, 3);
      expect(call.batchNo, 'MARS-BATCH-01');
      expect(call.expDateObserved, DateTime(2026, 12, 25));
      expect(find.textContaining('ROUTE:/submission-confirmation'), findsOneWidget);
    });

    testWidgets('Save & Next Item keeps the supplier and resets item for next scan', (tester) async {
      useTallViewport(tester);
      final repo = FakeObservationRepository();

      await pumpScreen(
        tester,
        InwardEntryScreen(
          initialSupplier: testSupplier,
          item: testItem,
        ),
        user: staffUser,
        observations: repo,
      );

      // Set inward quantity to 1
      await tester.tap(find.byIcon(Icons.add));
      await tester.pump();

      // Enter Expiry Date
      await tester.enterText(
        find.widgetWithText(TextField, 'Observed Expiry Date'),
        '10112026',
      );
      await tester.pumpAndSettle();

      // Tap Save & Next Item
      await tester.tap(find.text('Save & Next Item'));
      await tester.pumpAndSettle();

      expect(repo.submitCalls, hasLength(1));
      final call = repo.submitCalls.single;
      expect(call.supplierId, '7');
      expect(call.itemId, '101');
      expect(call.physicalQty, 1);
      expect(call.expDateObserved, DateTime(2026, 11, 10));

      // Supplier should still be retained
      expect(find.text('Mars Petcare India'), findsOneWidget);
    });

    testWidgets('Clear button removes selected supplier', (tester) async {
      useTallViewport(tester);

      await pumpScreen(
        tester,
        InwardEntryScreen(
          initialSupplier: testSupplier,
          item: testItem,
        ),
        user: staffUser,
      );

      expect(find.text('Mars Petcare India'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);

      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      expect(find.text('Select Purchase Order (Recommended)'), findsOneWidget);
      expect(find.text('Mars Petcare India'), findsNothing);
    });

    testWidgets('Option 1: PO-Linked Inward matches PO item, shows variance, and appends [PO: #...] in remarks', (tester) async {
      useTallViewport(tester);
      final repo = FakeObservationRepository();

      await pumpScreen(
        tester,
        InwardEntryScreen(
          initialPO: testPO,
          item: testItem,
        ),
        user: staffUser,
        observations: repo,
      );

      // Verify PO Mode Active badge and PO Card
      expect(find.text('PO-Linked Mode'), findsOneWidget);
      expect(find.text('PO-2026-0042'), findsOneWidget);
      expect(find.text('Mars Petcare India'), findsOneWidget);

      // Verify item match banner with ordered quantity
      expect(find.textContaining('PO Match: Ordered 10 units in #PO-2026-0042'), findsOneWidget);

      // Match PO quantity using quick chip
      await tester.tap(find.text('Match PO (10)'));
      await tester.pump();

      // Verify exact match feedback pill
      expect(find.textContaining('Exact Match with PO quantity (10 units)'), findsOneWidget);

      // Submit via Save & Finish
      await tester.tap(find.text('Save & Finish (Submit to POS)'));
      await tester.pumpAndSettle();

      expect(repo.submitCalls, hasLength(1));
      final call = repo.submitCalls.single;
      expect(call.type, 'stock_count');
      expect(call.itemId, '101');
      expect(call.supplierId, '7');
      expect(call.physicalQty, 10);
      expect(call.remarks, contains('[PO: PO-2026-0042]'));
    });

    testWidgets('Option 1: Warns when an item is NOT in the selected Purchase Order', (tester) async {
      useTallViewport(tester);

      await pumpScreen(
        tester,
        InwardEntryScreen(
          initialPO: testPO,
          item: testExtraItem,
        ),
        user: staffUser,
      );

      // Extra item warning banner should be displayed
      expect(find.textContaining('Extra Item: Not listed in Purchase Order #PO-2026-0042'), findsOneWidget);
    });

    testWidgets('Option 1: Real-time PO variance shows Shortage and Excess delivery alerts', (tester) async {
      useTallViewport(tester);

      await pumpScreen(
        tester,
        InwardEntryScreen(
          initialPO: testPO,
          item: testItem, // Ordered: 10
        ),
        user: staffUser,
      );

      // Tap +5 -> Count is 5 (< 10)
      await tester.tap(find.text('+5'));
      await tester.pump();

      expect(find.textContaining('Shortage: 5 units pending from supplier'), findsOneWidget);

      // Tap +10 -> Count is 15 (> 10)
      await tester.tap(find.text('+10'));
      await tester.pump();

      expect(find.textContaining('Excess Delivery: +5 extra units than ordered!'), findsOneWidget);
    });

    testWidgets('Option 1: Tapping View PO Checklist opens sheet and selecting item loads it directly', (tester) async {
      useTallViewport(tester);

      await pumpScreen(
        tester,
        const InwardEntryScreen(
          initialPO: testPO,
        ),
        user: staffUser,
      );

      // Tap View PO Checklist button
      await tester.tap(find.textContaining('View PO Checklist'));
      await tester.pumpAndSettle();

      // Verify bottom sheet title and items
      expect(find.text('PO #PO-2026-0042 Items'), findsOneWidget);
      expect(find.text('Whiskas Ocean Fish 3kg'), findsOneWidget);

      // Tap on Whiskas Ocean Fish 3kg from the checklist
      await tester.tap(find.text('Whiskas Ocean Fish 3kg'));
      await tester.pumpAndSettle();

      // Product should now be selected as _currentItem
      expect(find.text('Whiskas Ocean Fish 3kg'), findsOneWidget);
      expect(find.textContaining('PO Match: Ordered 15 units in #PO-2026-0042'), findsOneWidget);
    });

    testWidgets('Option 1: Clear button on PO resets back to initial option selector', (tester) async {
      useTallViewport(tester);

      await pumpScreen(
        tester,
        const InwardEntryScreen(
          initialPO: testPO,
        ),
        user: staffUser,
      );

      expect(find.text('PO-2026-0042'), findsOneWidget);
      expect(find.text('Clear'), findsOneWidget);

      await tester.tap(find.text('Clear'));
      await tester.pumpAndSettle();

      expect(find.text('Select Purchase Order (Recommended)'), findsOneWidget);
      expect(find.text('PO-2026-0042'), findsNothing);
    });
  });
}
