import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:urban_pets_verify/features/stock_count/presentation/widgets/blind_batch_summary.dart';
import 'package:urban_pets_verify/shared/models/models.dart';

void main() {
  group('BlindBatchSummary — blind counting defense in depth', () {
    testWidgets('renders no system-quantity text even when constructed with a '
        'BatchModel that HAS system_qty populated (e.g. a stray manager-shaped '
        'response reaching the staff screen)', (tester) async {
      final batchWithSystemQty = BatchModel.fromJson({
        'batch_no': 'A2301',
        'exp_date': '2026-07-18',
        'remaining_qty': 999, // must never be surfaced on this widget
      });
      expect(batchWithSystemQty.hasSystemQty, isTrue);
      expect(batchWithSystemQty.systemQty, 999);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: BlindBatchSummary(batch: batchWithSystemQty)),
        ),
      );

      // The widget shows batch/expiry context...
      expect(find.textContaining('A2301'), findsOneWidget);
      // ...but the system quantity value must never appear anywhere in the
      // rendered tree, and no "System" labelled field exists.
      expect(find.textContaining('999'), findsNothing);
      expect(find.textContaining('System'), findsNothing);
      expect(find.textContaining('system'), findsNothing);
    });

    testWidgets(
      'renders normally for a batch with no system quantity at all (true staff response)',
      (tester) async {
        final staffBatch = BatchModel.fromJson({'batch_no': 'B9981'});
        expect(staffBatch.hasSystemQty, isFalse);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: BlindBatchSummary(batch: staffBatch)),
          ),
        );

        expect(find.textContaining('B9981'), findsOneWidget);
        expect(find.textContaining('System'), findsNothing);
      },
    );
  });
}
