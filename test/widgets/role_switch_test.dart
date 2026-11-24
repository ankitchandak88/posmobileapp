import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:urban_pets_verify/core/storage/quick_unlock_service.dart';
import 'package:urban_pets_verify/core/theme/app_theme.dart';
import 'package:urban_pets_verify/features/auth/data/user_model.dart';
import 'package:urban_pets_verify/features/auth/presentation/screens/login_screen.dart';
import 'package:urban_pets_verify/features/auth/presentation/widgets/role_switch_sheet.dart';
import 'package:urban_pets_verify/features/auth/state/auth_providers.dart';
import 'package:urban_pets_verify/features/dashboard/presentation/screens/dashboard_screen.dart';
import 'package:urban_pets_verify/features/dashboard/state/dashboard_providers.dart';
import 'package:urban_pets_verify/features/rider/data/rider_order_model.dart';
import 'package:urban_pets_verify/features/rider/presentation/screens/rider_deliveries_screen.dart';
import 'package:urban_pets_verify/features/rider/state/rider_order_providers.dart';
import 'package:urban_pets_verify/shared/models/models.dart';

import '../helpers/test_harness.dart';

class FakeRoleSwitchAuthRepository extends FakeAuthRepository {
  FakeRoleSwitchAuthRepository(
    super.user, {
    this.hasRider = false,
    this.hasStaff = false,
    this.riderUser,
    this.staffUser,
  });

  final bool hasRider;
  final bool hasStaff;
  final UserModel? riderUser;
  final UserModel? staffUser;

  @override
  Future<bool> hasLinkedRider() async => hasRider;

  @override
  Future<bool> hasLinkedStaff() async => hasStaff;

  @override
  Future<UserModel?> getUserForMode(String mode) async =>
      mode == 'rider' ? riderUser : staffUser;
}

class SwitchRoleTrackingAuthController extends AuthController {
  SwitchRoleTrackingAuthController({
    required UserModel initialUser,
    this.initialHasRider = false,
    this.initialHasStaff = false,
    this.initialRiderUser,
    this.initialStaffUser,
  }) : super(
          FakeRoleSwitchAuthRepository(
            initialUser,
            hasRider: initialHasRider,
            hasStaff: initialHasStaff,
            riderUser: initialRiderUser,
            staffUser: initialStaffUser,
          ),
          QuickUnlockService(
            storage: FakeTokenStorage(),
            checker: FakeBiometricChecker(),
          ),
        ) {
    state = AuthState(
      status: AuthStatus.authenticated,
      user: initialUser,
      activeMode: initialUser.isRider ? 'rider' : 'store_staff',
      hasLinkedRider: initialHasRider,
      hasLinkedStaff: initialHasStaff,
      riderUser: initialRiderUser,
      staffUser: initialStaffUser,
    );
  }

  final bool initialHasRider;
  final bool initialHasStaff;
  final UserModel? initialRiderUser;
  final UserModel? initialStaffUser;

  String? lastSwitchedTargetMode;
  String? lastLoginSavedMode;

  @override
  Future<bool> loginWithSavedRole(String mode) async {
    lastLoginSavedMode = mode;
    return switchRole(mode);
  }

  @override
  Future<bool> switchRole(String targetMode) async {
    lastSwitchedTargetMode = targetMode;
    final newUser = targetMode == 'rider'
        ? (initialRiderUser ?? riderUser)
        : (initialStaffUser ?? staffUser);
    state = state.copyWith(
      user: newUser,
      activeMode: targetMode,
    );
    return true;
  }
}

void main() {
  final staffUser = UserModel(
    id: '1',
    name: 'Ankit Staff',
    email: 'moterastore@gmail.com',
    role: 'Staff',
    branchId: '1',
  );

  final riderUser = UserModel(
    id: '2',
    name: 'Ankit Rider',
    email: 'sonalmukesh7070@gmail.com',
    role: 'Rider',
    branchId: null,
  );

  testWidgets('RoleSwitchSheet displays Store Staff and Delivery Rider cards with active indicator', (tester) async {
    final controller = SwitchRoleTrackingAuthController(
      initialUser: staffUser,
      initialHasRider: true,
      initialHasStaff: true,
      initialRiderUser: riderUser,
      initialStaffUser: staffUser,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => controller),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(body: RoleSwitchSheet()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Switch Profile / Role'), findsOneWidget);
    expect(find.text('Store Staff'), findsOneWidget);
    expect(find.text('Delivery Rider'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);
    expect(find.text('Switch'), findsOneWidget);

    // Tap Switch to switch to Delivery Rider
    await tester.tap(find.text('Switch'));
    await tester.pumpAndSettle();

    expect(controller.lastSwitchedTargetMode, 'rider');
  });

  testWidgets('DashboardScreen renders role switch button in AppBar and switches to rider', (tester) async {
    useTallViewport(tester);
    final controller = SwitchRoleTrackingAuthController(
      initialUser: staffUser,
      initialHasRider: true,
      initialHasStaff: true,
      initialRiderUser: riderUser,
      initialStaffUser: staffUser,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => controller),
          branchesProvider.overrideWith((ref) async => []),
          dashboardSummaryProvider.overrideWith(
            (ref) async => DashboardModel(
              role: 'Staff',
              taskCounts: DashboardTaskCounts(
                pending: 0,
                inProgress: 0,
                completed: 0,
              ),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const DashboardScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final switchBtn = find.byKey(const Key('dashboard_role_switch_button'));
    expect(switchBtn, findsOneWidget);

    await tester.tap(switchBtn);
    await tester.pumpAndSettle();

    expect(controller.lastSwitchedTargetMode, 'rider');
  });

  testWidgets('RiderDeliveriesScreen renders Store switch button and switches to store_staff', (tester) async {
    useTallViewport(tester);
    final controller = SwitchRoleTrackingAuthController(
      initialUser: riderUser,
      initialHasRider: true,
      initialHasStaff: true,
      initialRiderUser: riderUser,
      initialStaffUser: staffUser,
    );

    final fakeRepo = FakeRiderOrderRepository(initialOrders: <RiderOrderModel>[]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          riderOrderRepositoryProvider.overrideWithValue(fakeRepo),
          authControllerProvider.overrideWith((ref) => controller),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const RiderDeliveriesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final storeSwitchBtn = find.byKey(const Key('rider_switch_store_button'));
    expect(storeSwitchBtn, findsOneWidget);

    await tester.tap(storeSwitchBtn);
    await tester.pumpAndSettle();

    expect(controller.lastSwitchedTargetMode, 'store_staff');
  });

  testWidgets('LoginScreen displays Option A connected account cards when accounts are saved', (tester) async {
    useTallViewport(tester);
    final controller = SwitchRoleTrackingAuthController(
      initialUser: staffUser,
      initialHasRider: true,
      initialHasStaff: true,
      initialRiderUser: riderUser,
      initialStaffUser: staffUser,
    );
    // Set unauthenticated so LoginScreen is rendered with saved accounts
    controller.state = AuthState(
      status: AuthStatus.unauthenticated,
      hasLinkedRider: true,
      hasLinkedStaff: true,
      riderUser: riderUser,
      staffUser: staffUser,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => controller),
        ],
        child: MaterialApp(
          theme: AppTheme.light,
          home: const LoginScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Connected Accounts'), findsOneWidget);
    expect(find.byKey(const Key('login_saved_staff_card')), findsOneWidget);
    expect(find.byKey(const Key('login_saved_rider_card')), findsOneWidget);
    expect(find.text('Ankit Staff'), findsOneWidget);
    expect(find.text('Ankit Rider'), findsOneWidget);

    // Tap 1-Tap Login on the rider card
    final riderCard = find.byKey(const Key('login_saved_rider_card'));
    await tester.tap(riderCard);
    await tester.pumpAndSettle();

    expect(controller.lastLoginSavedMode, 'rider');
  });
}
