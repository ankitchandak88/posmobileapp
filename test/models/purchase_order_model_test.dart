import 'package:flutter_test/flutter_test.dart';
import 'package:urban_pets_verify/features/purchase/data/purchase_order_model.dart';

void main() {
  group('PurchaseOrderModel JSON parsing & unit tests', () {
    test('parses full PurchaseOrderModel with nested items', () {
      final json = {
        'id': 105,
        'po_number': 'PO-2026-0099',
        'po_date': '2026-11-25',
        'supplier_id': 12,
        'supplier_name': 'Mars Petcare India Pvt Ltd',
        'supplier_phone': '9876543210',
        'branch_id': 1,
        'branch_name': 'Viman Nagar Store',
        'status': 'Open',
        'total_qty': '45.000',
        'total_items': 3,
        'total_amount': '55000.50',
        'remarks': 'Urgent weekend restocking delivery',
        'items': [
          {
            'id': 1,
            'po_item_id': 1,
            'item_id': 101,
            'name': 'Pedigree Pro 10kg',
            'item_code': 'PED-PRO-10',
            'barcode': '8901234567890',
            'ordered_qty': '10.000',
            'received_qty': '0.000',
            'cost_price': '2200.00',
            'mrp': '2800.00',
          },
          {
            'id': 2,
            'po_item_id': 2,
            'item_id': 102,
            'name': 'Whiskas Ocean Fish 7kg',
            'item_code': 'WHISK-7',
            'barcode': '8901234567891',
            'qty': 20, // alternate key for ordered qty
            'received_qty': 5,
            'cost_price': 1800,
            'mrp': 2200,
          },
        ],
      };

      final po = PurchaseOrderModel.fromJson(json);

      expect(po.id, '105');
      expect(po.poNumber, 'PO-2026-0099');
      expect(po.poDate, '2026-11-25');
      expect(po.supplierId, '12');
      expect(po.supplierName, 'Mars Petcare India Pvt Ltd');
      expect(po.supplierPhone, '9876543210');
      expect(po.branchId, '1');
      expect(po.branchName, 'Viman Nagar Store');
      expect(po.status, 'Open');
      expect(po.totalQty, 45.0);
      expect(po.totalItems, 3);
      expect(po.totalAmount, 55000.5);
      expect(po.remarks, 'Urgent weekend restocking delivery');
      expect(po.items, hasLength(2));

      final item1 = po.items[0];
      expect(item1.itemId, '101');
      expect(item1.name, 'Pedigree Pro 10kg');
      expect(item1.itemCode, 'PED-PRO-10');
      expect(item1.barcode, '8901234567890');
      expect(item1.orderedQty, 10.0);
      expect(item1.receivedQty, 0.0);
      expect(item1.costPrice, 2200.0);
      expect(item1.mrp, 2800.0);

      final item2 = po.items[1];
      expect(item2.itemId, '102');
      expect(item2.orderedQty, 20.0);
      expect(item2.receivedQty, 5.0);
      expect(item2.costPrice, 1800.0);
      expect(item2.mrp, 2200.0);
    });

    test('tolerates missing optional fields gracefully', () {
      final json = {
        'id': '201',
        'supplier_id': '9',
      };

      final po = PurchaseOrderModel.fromJson(json);

      expect(po.id, '201');
      expect(po.poNumber, 'PO-201');
      expect(po.poDate, isNull);
      expect(po.supplierName, 'Unknown Supplier');
      expect(po.supplierPhone, isNull);
      expect(po.status, 'Open');
      expect(po.totalQty, 0);
      expect(po.totalItems, 0);
      expect(po.items, isEmpty);
    });

    test('round-trips through toJson()', () {
      const original = PurchaseOrderModel(
        id: '10',
        poNumber: 'PO-2026-0010',
        poDate: '2026-11-20',
        supplierId: '5',
        supplierName: 'Royal Canin India',
        supplierPhone: '9988776655',
        branchId: '2',
        branchName: 'Koregaon Park',
        status: 'Open',
        totalQty: 100,
        totalItems: 1,
        totalAmount: 120000,
        remarks: 'Test PO notes',
        items: [
          PurchaseOrderItemModel(
            id: '1',
            poItemId: '1',
            itemId: '201',
            name: 'Royal Canin Mini Adult 8kg',
            itemCode: 'RC-MINI-8',
            barcode: '8901234567888',
            orderedQty: 100,
            receivedQty: 0,
            costPrice: 1200,
            mrp: 1500,
          ),
        ],
      );

      final map = original.toJson();
      final roundTrip = PurchaseOrderModel.fromJson(map);

      expect(roundTrip.id, original.id);
      expect(roundTrip.poNumber, original.poNumber);
      expect(roundTrip.supplierId, original.supplierId);
      expect(roundTrip.supplierName, original.supplierName);
      expect(roundTrip.totalQty, original.totalQty);
      expect(roundTrip.items, hasLength(1));
      expect(roundTrip.items.first.name, 'Royal Canin Mini Adult 8kg');
      expect(roundTrip.items.first.orderedQty, 100);
    });
  });
}
