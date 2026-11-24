import 'package:flutter_test/flutter_test.dart';
import 'package:urban_pets_verify/features/scanner/presentation/screens/quick_item_view_screen.dart';
import 'package:urban_pets_verify/shared/models/models.dart';

import '../helpers/test_harness.dart';

void main() {
  final testItem = ItemModel(
    id: '101',
    name: 'Pedigree Adult Meat & Rice 3kg',
    sku: 'PED-101',
    barcode: '8901234567890',
  );

  final testBatches = [
    BatchModel(
      batchNo: 'B2401',
      expDate: DateTime.now().add(const Duration(days: 60)),
      rackSection: 'Aisle 3, Shelf B',
    ),
    BatchModel(
      batchNo: 'B2402',
      expDate: DateTime.now().add(const Duration(days: 15)),
      rackSection: 'Aisle 3, Shelf C',
    ),
  ];

  testWidgets('QuickItemViewScreen renders product header and active batches', (
    tester,
  ) async {
    useTallViewport(tester);
    final itemsRepo = FakeItemRepository()..batchesByItem = {'101': testBatches};

    await pumpScreen(
      tester,
      QuickItemViewScreen(item: testItem),
      user: staffUser,
      items: itemsRepo,
    );

    expect(find.text('Item Details'), findsOneWidget);
    expect(find.text('Pedigree Adult Meat & Rice 3kg'), findsOneWidget);
    expect(find.text('Item ID: #101'), findsOneWidget);
    expect(find.text('PED-101'), findsOneWidget);
    expect(find.text('8901234567890'), findsOneWidget);

    expect(find.text('Batch: B2401'), findsOneWidget);
    expect(find.text('Batch: B2402'), findsOneWidget);
    expect(find.text('Rack: Aisle 3, Shelf B'), findsOneWidget);

    expect(find.text('Start Stock Count'), findsOneWidget);
    expect(find.text('Verify Expiry Date'), findsOneWidget);
  });
}
