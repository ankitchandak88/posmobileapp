import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_pets_verify/core/theme/app_theme.dart';
import 'package:urban_pets_verify/features/auth/state/auth_providers.dart';
import 'package:urban_pets_verify/features/rider/data/rider_order_model.dart';
import 'package:urban_pets_verify/features/rider/presentation/screens/rider_deliveries_screen.dart';
import 'package:urban_pets_verify/features/rider/state/rider_order_providers.dart';

import '../helpers/test_harness.dart';

void main() {
  late FakeRiderOrderRepository fakeRepo;
  late List<RiderOrderModel> initialOrders;

  setUp(() {
    initialOrders = [
      riderOrderFixture(
        id: 101,
        invoiceNo: 'BILL-101',
        status: 'assigned',
        statusLabel: 'Assigned',
        totalAmount: 2200.0,
        paymentStatus: 'cash',
        customerName: 'Tarang Roghelia',
        customerPhone: '9825901508',
        streetAddress: '302, Sukirti Annexe',
        area: 'Satellite',
      ),
      riderOrderFixture(
        id: 102,
        invoiceNo: 'BILL-102',
        status: 'out_for_delivery',
        statusLabel: 'Out for Delivery',
        totalAmount: 1450.0,
        paymentStatus: 'online',
        customerName: 'Mehul Patel',
        customerPhone: '9988776655',
        streetAddress: '12, Shreyas Park',
        area: 'Motera',
        startingKm: 1200.0,
      ),
      riderOrderFixture(
        id: 103,
        invoiceNo: 'BILL-103',
        status: 'delivered',
        statusLabel: 'Delivered',
        totalAmount: 3200.0,
        paymentStatus: 'online',
        customerName: 'Anand Dave',
        customerPhone: '9797000000',
        streetAddress: 'B-4, Applewood',
        area: 'Bopal',
        startingKm: 1180.0,
        endingKm: 1195.0,
      ),
    ];
    fakeRepo = FakeRiderOrderRepository(initialOrders: initialOrders);
  });

  Widget createSubject() {
    return ProviderScope(
      overrides: [
        riderOrderRepositoryProvider.overrideWithValue(fakeRepo),
        authControllerProvider.overrideWith(
          (ref) => FakeAuthController(riderUser),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const RiderDeliveriesScreen(),
      ),
    );
  }

  testWidgets('RiderDeliveriesScreen renders header with rider name and summary pills', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    // Check greeting
    expect(find.text('Hi, Rahul Rider'), findsOneWidget);
    expect(find.text("Today's Deliveries"), findsOneWidget);

    // Check summary pills & counts
    expect(find.text('Assigned'), findsWidgets);
    expect(find.text('Out for Delivery'), findsWidgets);
    expect(find.text('Completed'), findsWidgets);

    // Initial total count = 3 orders rendered in 'All' tab
    expect(find.text('Bill #BILL-101'), findsOneWidget);
    expect(find.text('Bill #BILL-102'), findsOneWidget);
    expect(find.text('Bill #BILL-103'), findsOneWidget);
  });

  testWidgets('RiderDeliveriesScreen filter tabs switch visible orders', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    // Tap 'Assigned (1)' tab
    await tester.tap(find.byKey(const Key('rider_tab_assigned')));
    await tester.pumpAndSettle();

    expect(find.text('Bill #BILL-101'), findsOneWidget);
    expect(find.text('Bill #BILL-102'), findsNothing);
    expect(find.text('Bill #BILL-103'), findsNothing);

    // Tap 'Out (1)' tab
    await tester.tap(find.byKey(const Key('rider_tab_out_for_delivery')));
    await tester.pumpAndSettle();

    expect(find.text('Bill #BILL-101'), findsNothing);
    expect(find.text('Bill #BILL-102'), findsOneWidget);
    expect(find.text('Bill #BILL-103'), findsNothing);

    // Tap 'Delivered (1)' tab
    await tester.tap(find.byKey(const Key('rider_tab_delivered')));
    await tester.pumpAndSettle();

    expect(find.text('Bill #BILL-101'), findsNothing);
    expect(find.text('Bill #BILL-102'), findsNothing);
    expect(find.text('Bill #BILL-103'), findsOneWidget);
  });

  testWidgets('DeliveryOrderCard action buttons and Starting KM modal progression', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    // Switch to assigned
    await tester.tap(find.byKey(const Key('rider_tab_assigned')));
    await tester.pumpAndSettle();

    // Verify Action buttons: Call & WhatsApp removed as requested, Maps Navigation present
    expect(find.byKey(const Key('call_button_101')), findsNothing);
    expect(find.byKey(const Key('whatsapp_button_101')), findsNothing);
    expect(find.byKey(const Key('maps_button_101')), findsOneWidget);
    expect(find.byKey(const Key('start_delivery_button_101')), findsOneWidget);

    // Tap 'Start Delivery' button -> Step 1: Select Vehicle opens FIRST
    await tester.tap(find.byKey(const Key('start_delivery_button_101')));
    await tester.pumpAndSettle();

    expect(find.text('Select Vehicle'), findsOneWidget);
    expect(find.text('Step 1 of 2 • Select Vehicle (Next: Starting KM)'), findsOneWidget);

    // Select a vehicle -> Step 2: KmInputDialog opens NEXT
    await tester.tap(find.byKey(const Key('vehicle_option_1')));
    await tester.pumpAndSettle();

    // Verify KmInputDialog opened after vehicle selection with vehicle shown
    expect(find.text('Start Delivery — Odometer'), findsOneWidget);
    expect(find.text('Vehicle: GJ-01-AB-1234'), findsWidgets);
    expect(find.byKey(const Key('km_input_field')), findsOneWidget);

    // Enter starting KM: 1250.0
    await tester.enterText(find.byKey(const Key('km_input_field')), '1250.0');
    await tester.pumpAndSettle();

    // Submit
    await tester.tap(find.byKey(const Key('km_submit_button')));
    await tester.pumpAndSettle();

    // Order 101 should now have status 'out_for_delivery'
    // It should no longer be in 'assigned' tab
    expect(find.text('No deliveries in this section'), findsOneWidget);

    // Check in 'out_for_delivery' tab
    await tester.tap(find.byKey(const Key('rider_tab_out_for_delivery')));
    await tester.pumpAndSettle();

    expect(find.text('Bill #BILL-101'), findsOneWidget);
    expect(find.text('Vehicle: GJ-01-AB-1234'), findsOneWidget);
    expect(find.text('Start: 1250.0 km'), findsOneWidget);
  });

  testWidgets('Ending KM validation blocks entering KM <= starting KM', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    // Switch to out for delivery tab (Bill 102 has startingKm = 1200.0)
    await tester.tap(find.byKey(const Key('rider_tab_out_for_delivery')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('mark_delivered_button_102')), findsOneWidget);
    await tester.tap(find.byKey(const Key('mark_delivered_button_102')));
    await tester.pumpAndSettle();

    expect(find.text('Complete Delivery — Odometer'), findsOneWidget);
    expect(find.text('Starting Reading:'), findsOneWidget);
    expect(find.text('1200.0 km'), findsOneWidget);

    // Enter invalid ending KM: 1199.0 (< 1200.0)
    await tester.enterText(find.byKey(const Key('km_input_field')), '1199.0');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('km_submit_button')));
    await tester.pumpAndSettle();

    // Verify error message is shown and dialog stays open
    expect(
      find.text('Ending KM must be greater than starting KM (1200.0 km)'),
      findsOneWidget,
    );

    // Now enter valid ending KM: 1215.5
    await tester.enterText(find.byKey(const Key('km_input_field')), '1215.5');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('km_submit_button')));
    await tester.pumpAndSettle();

    // Dialog closed, order 102 is now delivered
    // Switch to delivered tab to verify
    await tester.tap(find.byKey(const Key('rider_tab_delivered')));
    await tester.pumpAndSettle();

    expect(find.text('Bill #BILL-102'), findsOneWidget);
    expect(find.text('Travelled: 15.5 km'), findsOneWidget);
  });

  testWidgets('Rider can select vehicle from sheet and enters delivery notes upon completion', (tester) async {
    useTallViewport(tester);
    await tester.pumpWidget(createSubject());
    await tester.pumpAndSettle();

    // Verify vehicle option exists on Bill 101 (no vehicle initially)
    expect(find.byKey(const Key('assign_vehicle_btn_101')), findsOneWidget);
    await tester.tap(find.byKey(const Key('assign_vehicle_btn_101')));
    await tester.pumpAndSettle();

    // Bottom sheet opened
    expect(find.text('Select Vehicle'), findsOneWidget);
    expect(find.text('GJ-01-AB-1234'), findsOneWidget);

    // Pick first vehicle
    await tester.tap(find.byKey(const Key('vehicle_option_1')));
    await tester.pumpAndSettle();

    // Verify card now shows assigned vehicle
    expect(find.text('Vehicle: GJ-01-AB-1234'), findsOneWidget);

    // Now test delivery completion with notes on order 102 (out for delivery)
    await tester.tap(find.byKey(const Key('rider_tab_out_for_delivery')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('mark_delivered_button_102')));
    await tester.pumpAndSettle();

    // Verify Ending KM field and Delivery Notes field are present
    expect(find.byKey(const Key('delivery_notes_field')), findsOneWidget);
    expect(find.text('Delivered to customer'), findsOneWidget);

    // Enter ending km and tap quick chip
    await tester.enterText(find.byKey(const Key('km_input_field')), '1225.0');
    await tester.tap(find.text('Delivered to customer'));
    await tester.pumpAndSettle();

    // Submit completion
    await tester.tap(find.byKey(const Key('km_submit_button')));
    await tester.pumpAndSettle();

    // Go to delivered tab
    await tester.tap(find.byKey(const Key('rider_tab_delivered')));
    await tester.pumpAndSettle();

    // Verify rider delivery note is displayed on card in distinct box
    expect(find.text('Rider Delivery Note'), findsOneWidget);
    expect(find.text('Delivered to customer'), findsOneWidget);
  });

  testWidgets('RiderDeliveriesScreen header summary pills filter orders on tap and displays pet name', (tester) async {
    useTallViewport(tester);
    final petOrders = [
      riderOrderFixture(
        id: 201,
        invoiceNo: 'BILL-201',
        status: 'assigned',
        statusLabel: 'Assigned',
        customerName: 'Sanjay Shah',
      ).copyWith(petName: 'Bruno (Labrador)'),
      riderOrderFixture(
        id: 202,
        invoiceNo: 'BILL-202',
        status: 'out_for_delivery',
        statusLabel: 'Out for Delivery',
        customerName: 'Amit Verma',
      ).copyWith(notes: 'Handle with care: pet food glass jar'),
    ];
    final repo = FakeRiderOrderRepository(initialOrders: petOrders);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          riderOrderRepositoryProvider.overrideWithValue(repo),
          authControllerProvider.overrideWith(
            (ref) => FakeAuthController(riderUser),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const RiderDeliveriesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Pet badge
    expect(find.text('Pet: Bruno (Labrador)'), findsOneWidget);

    // Verify Staff Note
    expect(find.text('Staff / Order Note'), findsOneWidget);
    expect(find.text('Handle with care: pet food glass jar'), findsOneWidget);

    // Tap header pill 'Assigned'
    await tester.tap(find.byKey(const Key('rider_summary_pill_assigned')));
    await tester.pumpAndSettle();

    expect(find.text('Bill #BILL-201'), findsOneWidget);
    expect(find.text('Bill #BILL-202'), findsNothing);

    // Tap header pill 'Out for Del.'
    await tester.tap(find.byKey(const Key('rider_summary_pill_out_for_delivery')));
    await tester.pumpAndSettle();

    expect(find.text('Bill #BILL-201'), findsNothing);
    expect(find.text('Bill #BILL-202'), findsOneWidget);
  });
}
