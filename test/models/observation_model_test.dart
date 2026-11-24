import 'package:flutter_test/flutter_test.dart';
import 'package:urban_pets_verify/shared/models/models.dart';

void main() {
  group('ObservationModel.fromJson', () {
    test('parses a full manager/reviewer-context JSON payload', () {
      final json = {
        'id': 42,
        'type': 'stock_count',
        'task_id': 7,
        'item_id': 101,
        'item_name': 'Royal Canin Adult Dog 15kg',
        'branch_id': 1,
        'batch_no': 'A2301',
        'physical_qty': 18,
        'remarks': 'Two bags damaged',
        'idempotency_key': 'abc-123',
        'system_qty_snapshot': 20,
        'status': 'pending',
        'submitted_by': '9',
        'created_at': '2026-10-01T10:00:00Z',
      };

      final model = ObservationModel.fromJson(json);

      expect(model.id, '42');
      expect(model.type, 'stock_count');
      expect(model.itemId, '101');
      expect(model.batchNo, 'A2301');
      expect(model.physicalQty, 18);
      expect(model.systemQtySnapshot, 20);
      expect(model.status, 'pending');
      expect(model.variance, -2); // 18 - 20
    });

    test(
      'variance is null when system_qty_snapshot is absent (staff/blind context)',
      () {
        final json = {
          'id': 1,
          'type': 'stock_count',
          'item_id': 101,
          'branch_id': 1,
          'physical_qty': 18,
          'idempotency_key': 'abc-123',
          'status': 'pending',
          // system_qty_snapshot intentionally omitted, as a staff-facing
          // response must never include it.
        };

        final model = ObservationModel.fromJson(json);

        expect(model.systemQtySnapshot, isNull);
        expect(model.variance, isNull);
      },
    );

    test(
      'parses decimal-cast quantity fields when the server sends them as '
      'JSON STRINGS (e.g. "10.000") — Laravel decimal:N casts serialize '
      'this way for physical_qty/system_qty_snapshot/approved_qty/'
      'actual_adjustment_qty, verified against the real API during Phase 11',
      () {
        final json = {
          'id': 1,
          'type': 'stock_count',
          'item_id': 6,
          'branch_id': 1,
          'physical_qty': '10.000',
          'idempotency_key': 'k',
          'status': 'approved',
          'system_qty_snapshot': '13.000',
          'approved_qty': '10.000',
          'actual_adjustment_qty': '-3.000',
        };

        final model = ObservationModel.fromJson(json);

        expect(model.physicalQty, 10.0);
        expect(model.systemQtySnapshot, 13.0);
        expect(model.approvedQty, 10.0);
        expect(model.actualAdjustmentQty, -3.0);
        expect(model.variance, -3.0);
      },
    );

    test('round-trips core submission fields through toJson', () {
      final model = ObservationModel(
        id: '1',
        type: 'expiry_check',
        itemId: '55',
        branchId: '2',
        batchNo: 'B100',
        idempotencyKey: 'key-xyz',
        status: 'pending',
      );

      final json = model.toJson();

      expect(json['item_id'], '55');
      expect(json['branch_id'], '2');
      expect(json['batch_no'], 'B100');
      expect(json['idempotency_key'], 'key-xyz');
      expect(json.containsKey('system_qty_snapshot'), isFalse);
    });
  });

  group('BatchModel.fromJson — blind counting field presence', () {
    test(
      'hasSystemQty is false when the key is entirely absent (staff response)',
      () {
        final json = {'batch_no': 'A2301', 'exp_date': '2026-07-18'};

        final batch = BatchModel.fromJson(json);

        expect(batch.hasSystemQty, isFalse);
        expect(batch.systemQty, isNull);
      },
    );

    test(
      'hasSystemQty is true when the key is present with a value (manager response)',
      () {
        final json = {'batch_no': 'A2301', 'remaining_qty': 20};

        final batch = BatchModel.fromJson(json);

        expect(batch.hasSystemQty, isTrue);
        expect(batch.systemQty, 20);
      },
    );
  });
}
