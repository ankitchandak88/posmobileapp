import 'package:flutter_test/flutter_test.dart';
import 'package:urban_pets_verify/features/purchase/data/purchase_lookup_model.dart';

void main() {
  group('PurchaseLookupModel JSON parsing', () {
    test('parses full purchase lookup payload with inwards and pricing', () {
      final json = {
        'item': {
          'id': '101',
          'name': 'Royal Canin Maxi Adult 15kg',
          'item_code': 'RC-MAXI-15',
          'ean_upc_code': '8901234567890',
          'brand_name': 'Royal Canin',
          'category_name': 'Dog Food',
        },
        'pricing': {
          'cost_price': 5200.0,
          'landing_cost': 5350.0,
          'mrp': 7200.0,
          'sell_price': 6800.0,
          'margin_percent': 27.8,
        },
        'supplier': {
          'id': 12,
          'name': 'Maharashtra Pet Distributors',
          'mobile': '9876543210',
          'gstin': '27ABCDE1234F1Z5',
          'email': 'orders@mpd.in',
        },
        'inventory': {
          'branch_id': 1,
          'current_stock': 18.0,
          'batch_count': 2,
        },
        'recent_inwards': [
          {
            'id': 501,
            'invoice_number': 'PINV-2026-089',
            'invoice_date': '2026-10-15',
            'supplier_name': 'Maharashtra Pet Distributors',
            'branch_name': 'Viman Nagar',
            'cost_price': 5200.0,
            'qty': 10.0,
            'free_qty': 1.0,
            'net_amount': 52000.0,
            'batch_no': 'B-OCT26-01',
            'exp_date': '2027-10-31',
          },
        ],
      };

      final model = PurchaseLookupModel.fromJson(json);

      expect(model.item.id, '101');
      expect(model.item.name, 'Royal Canin Maxi Adult 15kg');
      expect(model.item.sku, 'RC-MAXI-15');
      expect(model.item.barcode, '8901234567890');
      expect(model.item.brandName, 'Royal Canin');
      expect(model.pricing.costPrice, 5200.0);
      expect(model.pricing.marginPercent, 27.8);
      expect(model.supplier?.name, 'Maharashtra Pet Distributors');
      expect(model.supplier?.mobile, '9876543210');
      expect(model.inventory.currentStock, 18.0);
      expect(model.recentInwards, hasLength(1));
      expect(model.recentInwards.first.invoiceNumber, 'PINV-2026-089');
      expect(model.recentInwards.first.freeQty, 1.0);
    });

    test('tolerates missing optional fields gracefully', () {
      final json = {
        'item': {
          'id': '202',
          'name': 'Pedigree Meat 3kg',
          'item_code': 'PED-3KG',
        },
        'pricing': {
          'cost_price': 400.0,
          'landing_cost': 400.0,
          'mrp': 500.0,
          'sell_price': 480.0,
          'margin_percent': 20.0,
        },
        'inventory': {
          'branch_id': 1,
          'current_stock': 5.0,
        },
        'recent_inwards': [],
      };

      final model = PurchaseLookupModel.fromJson(json);
      expect(model.item.id, '202');
      expect(model.supplier, isNull);
      expect(model.recentInwards, isEmpty);
      expect(model.item.barcode, isNull);
    });
  });
}

