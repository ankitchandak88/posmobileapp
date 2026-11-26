import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_pets_verify/features/purchase/presentation/screens/inward_entry_screen.dart';
import 'package:urban_pets_verify/shared/models/models.dart';

import '../helpers/test_harness.dart';

final testItem = ItemModel(
  id: '101',
  name: 'Pedigree Adult Meat & Rice 10kg',
  sku: 'PED-10K',
  mrp: 1250,
);

const testSupplier = SupplierModel(
  id: '7',
  name: 'Mars Petcare India',
  mobile: '9876543210',
);

void main() {
  group('InwardEntryScreen', () {
    testWidgets('shows supplier selector when no initial supplier provided', (tester) async {
      useTallViewport(tester);
      await pumpScreen(
        tester,
        const InwardEntryScreen(),
        user: staffUser,
      );

      expect(find.text('Inward / Supplier Stock'), findsOneWidget);
      expect(find.text('Tap to Select Supplier (Required)'), findsOneWidget);
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

      expect(find.text('Tap to Select Supplier (Required)'), findsOneWidget);
      expect(find.text('Mars Petcare India'), findsNothing);
    });
  });
}
