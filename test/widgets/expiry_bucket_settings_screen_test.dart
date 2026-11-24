import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_pets_verify/core/network/api_exception.dart';
import 'package:urban_pets_verify/features/dashboard/presentation/screens/expiry_bucket_settings_screen.dart';
import 'package:urban_pets_verify/features/dashboard/state/dashboard_providers.dart';
import 'package:urban_pets_verify/shared/models/models.dart';

import '../helpers/test_harness.dart';

void main() {
  List<ExpiryBucketModel> defaults() => [
    ExpiryBucketModel(
      id: '1',
      label: 'Expiring Soon',
      minDays: 0,
      maxDays: 30,
      severity: 'critical',
      sortOrder: 1,
    ),
    ExpiryBucketModel(
      id: '2',
      label: 'Expiring Later',
      minDays: 31,
      maxDays: 60,
      severity: 'warning',
      sortOrder: 2,
    ),
  ];

  testWidgets('shows existing bucket ranges', (tester) async {
    useTallViewport(tester);
    final fake = FakeExpiryBucketRepository()..buckets = defaults();

    await pumpScreen(
      tester,
      const ExpiryBucketSettingsScreen(),
      user: managerUser,
      overrides: [
        expiryBucketRepositoryProvider.overrideWithValue(fake),
        expiryBucketsProvider.overrideWith((ref) async => fake.buckets),
      ],
    );

    expect(find.text('Expiring Soon'), findsOneWidget);
    expect(find.text('Expiring Later'), findsOneWidget);
  });

  testWidgets('editing a range and saving sends the updated buckets', (
    tester,
  ) async {
    useTallViewport(tester);
    final fake = FakeExpiryBucketRepository()..buckets = defaults();

    await pumpScreen(
      tester,
      const ExpiryBucketSettingsScreen(),
      user: managerUser,
      overrides: [
        expiryBucketRepositoryProvider.overrideWithValue(fake),
        expiryBucketsProvider.overrideWith((ref) async => fake.buckets),
      ],
    );

    await tester.enterText(
      find.byKey(const Key('expiry-bucket-max-1')),
      '15',
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pumpAndSettle();

    expect(fake.saveCalls, hasLength(1));
    expect(fake.saveCalls.single.first.maxDays, 15);
    expect(find.text('Expiry bucket settings saved.'), findsOneWidget);
  });

  testWidgets('a server validation error is shown, not swallowed', (
    tester,
  ) async {
    useTallViewport(tester);
    final fake = FakeExpiryBucketRepository()
      ..buckets = defaults()
      ..saveError = ApiException(
        message: 'Buckets must not overlap.',
        statusCode: 422,
      );

    await pumpScreen(
      tester,
      const ExpiryBucketSettingsScreen(),
      user: managerUser,
      overrides: [
        expiryBucketRepositoryProvider.overrideWithValue(fake),
        expiryBucketsProvider.overrideWith((ref) async => fake.buckets),
      ],
    );

    await tester.tap(find.widgetWithText(ElevatedButton, 'Save'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('expiry-bucket-error')), findsOneWidget);
    expect(find.text('Buckets must not overlap.'), findsOneWidget);
  });

  testWidgets('Add bucket appends a new editable row', (tester) async {
    useTallViewport(tester);
    final fake = FakeExpiryBucketRepository()..buckets = defaults();

    await pumpScreen(
      tester,
      const ExpiryBucketSettingsScreen(),
      user: managerUser,
      overrides: [
        expiryBucketRepositoryProvider.overrideWithValue(fake),
        expiryBucketsProvider.overrideWith((ref) async => fake.buckets),
      ],
    );

    await tester.tap(find.byKey(const Key('expiry-bucket-add')));
    await tester.pumpAndSettle();

    expect(find.text('New Bucket'), findsOneWidget);
  });
}
