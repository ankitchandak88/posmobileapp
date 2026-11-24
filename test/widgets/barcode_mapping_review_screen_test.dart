import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_pets_verify/core/network/api_exception.dart';
import 'package:urban_pets_verify/features/barcode_mapping/data/barcode_mapping_repository.dart';
import 'package:urban_pets_verify/features/barcode_mapping/presentation/screens/barcode_mapping_review_screen.dart';
import 'package:urban_pets_verify/features/barcode_mapping/presentation/screens/barcode_mapping_screen.dart';
import 'package:urban_pets_verify/shared/models/models.dart';

import '../helpers/test_harness.dart';

class FakeMappingRepository extends BarcodeMappingRepository {
  FakeMappingRepository() : super(apiClient: offlineApiClient());

  List<BarcodeMappingRequestModel> pending = [];
  final calls = <String>[];

  /// When true, the first non-forced approve fails like the real server does
  /// for an item that already has a different barcode.
  bool alreadyMapped = false;

  @override
  Future<PagedResult<BarcodeMappingRequestModel>> list({
    String status = 'pending',
    int page = 1,
  }) async => PagedResult(
    items: pending,
    currentPage: 1,
    lastPage: 1,
    total: pending.length,
  );

  @override
  Future<void> approve(
    String id, {
    String? itemId,
    bool force = false,
    String? remarks,
  }) async {
    calls.add('approve:$id:$itemId:force=$force');
    if (alreadyMapped && !force) {
      throw ApiException(
        message:
            'Item "RC Adult Dog 15kg" is already mapped to barcode "890000000001". Pass force=true to overwrite.',
        statusCode: 422,
      );
    }
    pending = [];
  }

  @override
  Future<void> reject(String id, {required String remarks}) async {
    calls.add('reject:$id:$remarks');
    pending = [];
  }
}

BarcodeMappingRequestModel request({String? currentBarcode}) =>
    BarcodeMappingRequestModel(
      id: '4',
      scannedBarcode: '8901234567890',
      suggestedItemId: '100',
      suggestedItemName: 'RC Adult Dog 15kg',
      suggestedItemCurrentBarcode: currentBarcode,
      branchId: '1',
      branchName: 'Main Branch',
      status: 'pending',
      submittedByName: 'Alice Staff',
      remarks: 'Label torn',
    );

void main() {
  Future<FakeMappingRepository> pump(
    WidgetTester tester, {
    required FakeMappingRepository repo,
  }) async {
    useTallViewport(tester);
    await pumpScreen(
      tester,
      const BarcodeMappingReviewScreen(),
      user: managerUser,
      overrides: [barcodeMappingRepositoryProvider.overrideWithValue(repo)],
    );
    return repo;
  }

  testWidgets('lists pending requests with suggestion and context', (
    tester,
  ) async {
    await pump(tester, repo: FakeMappingRepository()..pending = [request()]);

    expect(find.text('8901234567890'), findsOneWidget);
    expect(find.text('Suggested product: RC Adult Dog 15kg'), findsOneWidget);
    expect(find.textContaining('Alice Staff'), findsOneWidget);
    expect(find.text('"Label torn"'), findsOneWidget);
  });

  testWidgets('approve requires confirmation, then calls the API once', (
    tester,
  ) async {
    final repo = await pump(
      tester,
      repo: FakeMappingRepository()..pending = [request()],
    );

    await tester.tap(find.byKey(const Key('mapping-approve-4')));
    await tester.pumpAndSettle();
    expect(find.text('Approve mapping?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Approve'));
    await tester.pumpAndSettle();

    expect(repo.calls, ['approve:4:100:force=false']);
    expect(find.text('Mapping approved.'), findsOneWidget);
    expect(find.text('No pending barcode requests'), findsOneWidget);
  });

  testWidgets('an existing different barcode is only replaced after an '
      'explicit second confirmation; cancelling sends no force', (
    tester,
  ) async {
    final repo = await pump(
      tester,
      repo: FakeMappingRepository()
        ..pending = [request(currentBarcode: '890000000001')]
        ..alreadyMapped = true,
    );
    expect(find.textContaining('Currently mapped to 890000000001'), findsOne);

    await tester.tap(find.byKey(const Key('mapping-approve-4')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Approve'));
    await tester.pumpAndSettle();

    expect(find.text('Replace existing barcode?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(repo.calls, ['approve:4:100:force=false']);

    // Try again and confirm the replacement this time.
    await tester.tap(find.byKey(const Key('mapping-approve-4')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Approve'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Replace'));
    await tester.pumpAndSettle();

    expect(repo.calls.last, 'approve:4:100:force=true');
  });

  testWidgets('reject requires a reason', (tester) async {
    final repo = await pump(
      tester,
      repo: FakeMappingRepository()..pending = [request()],
    );

    await tester.tap(find.byKey(const Key('mapping-reject-4')));
    await tester.pumpAndSettle();
    final rejectAction = find.widgetWithText(TextButton, 'Reject');
    expect(tester.widget<TextButton>(rejectAction).onPressed, isNull);

    await tester.enterText(
      find.byKey(const Key('mapping-reject-remarks')),
      'Not our product',
    );
    await tester.pump();
    await tester.tap(rejectAction);
    await tester.pumpAndSettle();

    expect(repo.calls, ['reject:4:Not our product']);
  });

  testWidgets('empty state', (tester) async {
    await pump(tester, repo: FakeMappingRepository());
    expect(find.text('No pending barcode requests'), findsOneWidget);
  });
}
