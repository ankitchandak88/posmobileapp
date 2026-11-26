import 'package:flutter_test/flutter_test.dart';
import 'package:urban_pets_verify/features/rider/data/rider_order_model.dart';

void main() {
  group('RiderOrderModel JSON parsing & computed fields', () {
    test('parses full Laravel API order payload with delivery address', () {
      final json = {
        'id': 2282,
        'invoice_no': '38559',
        'invoice_date': '2026-09-15',
        'delivery_date': '2026-09-15',
        'status': 'out_for_delivery',
        'status_label': 'Out for Delivery',
        'total_amount': '2200.00',
        'payment_status': 'cash',
        'payment_note': 'Collect on arrival',
        'starting_km': 1420.5,
        'ending_km': null,
        'km_travelled': null,
        'notes': 'Call before reaching',
        'delivery_note': 'Leave at guard room',
        'customer': {
          'id': 390,
          'full_name': 'TARANG ROGHELIA',
          'mobile_number': '9825901508',
          'area': 'Satellite',
          'pet_name': 'Bruno (Golden Retriever)',
        },
        'delivery_address': {
          'id': 12,
          'street_address': '302, Sukirti Annexe, Nr. Prernatirth Bunglows',
          'postcode': '380015',
          'google_map_link': 'https://maps.google.com/?q=23.0225,72.5714',
        },
        'branch': {
          'id': 2,
          'title': 'Satellite',
        },
        'vehicle': {
          'id': 5,
          'registration_number': 'GJ-01-AB-1234',
        },
      };

      final order = RiderOrderModel.fromJson(json);

      expect(order.id, 2282);
      expect(order.invoiceNo, '38559');
      expect(order.customerName, 'TARANG ROGHELIA');
      expect(order.customerPhone, '9825901508');
      expect(order.totalAmount, 2200.00);
      expect(order.status, 'out_for_delivery');
      expect(order.statusLabel, 'Out for Delivery');
      expect(order.isOutForDelivery, isTrue);
      expect(order.isAssigned, isFalse);
      expect(order.isDelivered, isFalse);
      expect(order.isCashOnDelivery, isTrue);
      expect(order.isPaidOnline, isFalse);
      expect(order.notes, 'Call before reaching');
      expect(order.deliveryNote, 'Leave at guard room');
      expect(order.petName, 'Bruno (Golden Retriever)');
      expect(order.startingKm, 1420.5);
      expect(order.endingKm, isNull);
      expect(order.vehicleRegistration, 'GJ-01-AB-1234');
      expect(order.branchTitle, 'Satellite');
      expect(order.googleMapLink, 'https://maps.google.com/?q=23.0225,72.5714');
      expect(
        order.fullAddress,
        '302, Sukirti Annexe, Nr. Prernatirth Bunglows, Satellite, 380015',
      );
    });

    test('tolerates missing address and fallback to customer street address', () {
      final json = {
        'id': 101,
        'invoice_no': 'INV-101',
        'status': 'assigned',
        'status_label': 'Assigned',
        'total_amount': 550,
        'payment_status': 'online',
        'customer': {
          'full_name': 'Mehul Patel',
          'mobile_number': '9988776655',
          'street_address': 'Shop 4, Galaxy Mall',
          'area': 'Motera',
        },
      };

      final order = RiderOrderModel.fromJson(json);

      expect(order.id, 101);
      expect(order.customerName, 'Mehul Patel');
      expect(order.isAssigned, isTrue);
      expect(order.isPaidOnline, isTrue);
      expect(order.isCashOnDelivery, isFalse);
      expect(order.streetAddress, 'Shop 4, Galaxy Mall');
      expect(order.fullAddress, 'Shop 4, Galaxy Mall, Motera');
      expect(order.googleMapLink, isNull);
    });

    test('calculates kmTravelled and round-trips to json', () {
      final order = RiderOrderModel(
        id: 50,
        invoiceNo: 'BILL-50',
        status: 'delivered',
        statusLabel: 'Delivered',
        totalAmount: 1800.0,
        paymentStatus: 'online',
        startingKm: 1500.0,
        endingKm: 1512.5,
        kmTravelled: 12.5,
        customerName: 'Priya Shah',
        customerPhone: '9898000000',
        streetAddress: 'Bunglow 10, Palm Greens',
        area: 'Bopal',
      );

      expect(order.isDelivered, isTrue);
      expect(order.kmTravelled, 12.5);

      final json = order.toJson();
      expect(json['id'], 50);
      expect(json['invoice_no'], 'BILL-50');
      expect(json['status'], 'delivered');
      expect(json['starting_km'], 1500.0);
      expect(json['ending_km'], 1512.5);
    });
  });
}

