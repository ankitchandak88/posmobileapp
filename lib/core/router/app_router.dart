import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/quick_unlock_setup_screen.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/unlock_screen.dart';
import '../../features/auth/state/auth_providers.dart';
import '../../features/barcode_mapping/presentation/screens/barcode_mapping_review_screen.dart';
import '../../features/barcode_mapping/presentation/screens/barcode_mapping_screen.dart';
import '../../features/dashboard/presentation/screens/dashboard_screen.dart';
import '../../features/dashboard/presentation/screens/expiry_bucket_settings_screen.dart';
import '../../features/dashboard/presentation/screens/root_shell.dart';
import '../../features/expiry/presentation/screens/expiry_verification_screen.dart';
import '../../features/history/presentation/screens/history_audit_screen.dart';
import '../../features/notifications/presentation/screens/notification_center_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/purchase/data/purchase_order_model.dart';
import '../../features/purchase/presentation/screens/inward_entry_screen.dart';
import '../../features/purchase/presentation/screens/purchase_lookup_screen.dart';
import '../../features/review/presentation/screens/observation_detail_screen.dart';
import '../../features/review/presentation/screens/review_queue_screen.dart';
import '../../features/rider/presentation/screens/rider_deliveries_screen.dart';
import '../../features/scanner/presentation/screens/barcode_scanner_screen.dart';
import '../../features/scanner/presentation/screens/product_search_screen.dart';
import '../../features/scanner/presentation/screens/quick_item_view_screen.dart';
import '../../features/stock_count/presentation/screens/stock_count_screen.dart';
import '../../features/stock_count/presentation/screens/submission_confirmation_screen.dart';
import '../../features/tasks/presentation/screens/create_task_screen.dart';
import '../../features/tasks/presentation/screens/my_submissions_screen.dart';
import '../../features/tasks/presentation/screens/task_detail_screen.dart';
import '../../features/tasks/presentation/screens/task_list_screen.dart';
import '../../shared/models/models.dart';

/// Re-evaluates redirects whenever auth state changes.
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Ref ref) {
    ref.listen(authControllerProvider, (prev, next) {
      if (prev?.status != next.status ||
          prev?.activeMode != next.activeMode ||
          prev?.user?.id != next.user?.id ||
          prev?.user?.isRider != next.user?.isRider) {
        notifyListeners();
      }
    });
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = _RouterRefreshNotifier(ref);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final auth = ref.read(authControllerProvider);
      final isSplash = state.matchedLocation == '/splash';
      final isLoggingIn = state.matchedLocation == '/login';
      final isUnlock = state.matchedLocation == '/unlock';
      final isQuickUnlockSetup = state.matchedLocation == '/quick-unlock-setup';

      if (auth.status == AuthStatus.unknown) {
        return isSplash ? null : '/splash';
      }
      if (auth.status == AuthStatus.unauthenticated) {
        return isLoggingIn ? null : '/login';
      }
      if (auth.status == AuthStatus.locked) {
        return isUnlock ? null : '/unlock';
      }
      // authenticated
      if (auth.showQuickUnlockPrompt) {
        return isQuickUnlockSetup ? null : '/quick-unlock-setup';
      }

      final isRiderMode =
          auth.activeMode == 'rider' || (auth.user?.isRider ?? false);

      if (isLoggingIn || isSplash || isUnlock || isQuickUnlockSetup) {
        return isRiderMode ? '/rider-deliveries' : '/home';
      }
      if (isRiderMode && state.matchedLocation == '/home') {
        return '/rider-deliveries';
      }
      if (!isRiderMode && state.matchedLocation == '/rider-deliveries') {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (c, s) => const SplashScreen()),
      GoRoute(path: '/login', builder: (c, s) => const LoginScreen()),
      GoRoute(path: '/unlock', builder: (c, s) => const UnlockScreen()),
      GoRoute(
        path: '/quick-unlock-setup',
        builder: (c, s) => const QuickUnlockSetupScreen(),
      ),
      GoRoute(
        path: '/rider-deliveries',
        builder: (c, s) => const RiderDeliveriesScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => RootShell(child: child),
        routes: [
          GoRoute(path: '/home', builder: (c, s) => const DashboardScreen()),
          GoRoute(path: '/tasks', builder: (c, s) => const TaskListScreen()),
          // Dedicated History & Audit screen for every role. The data scope
          // (cross-staff vs own-only) is chosen inside the screen by role and
          // independently enforced by the server.
          GoRoute(
            path: '/history',
            builder: (c, s) => const HistoryAuditScreen(),
          ),
          GoRoute(path: '/profile', builder: (c, s) => const ProfileScreen()),
        ],
      ),
      GoRoute(
        path: '/scanner',
        builder: (c, s) => BarcodeScannerScreen(
          mode: (s.extra as Map?)?['mode'] as String? ?? 'stock_count',
          taskId: (s.extra as Map?)?['taskId'] as String?,
        ),
      ),
      GoRoute(
        path: '/product-search',
        builder: (c, s) => ProductSearchScreen(
          mode: (s.extra as Map?)?['mode'] as String? ?? 'stock_count',
          taskId: (s.extra as Map?)?['taskId'] as String?,
        ),
      ),
      // Must precede '/tasks/:id' so 'new' is not captured as a task id.
      GoRoute(path: '/tasks/new', builder: (c, s) => const CreateTaskScreen()),
      GoRoute(
        path: '/expiry-bucket-settings',
        builder: (c, s) => const ExpiryBucketSettingsScreen(),
      ),
      GoRoute(
        path: '/my-submissions',
        builder: (c, s) => const MySubmissionsScreen(),
      ),
      GoRoute(
        path: '/tasks/:id',
        builder: (c, s) => TaskDetailScreen(taskId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/stock-count',
        builder: (c, s) {
          final extra = s.extra is Map ? s.extra as Map : null;
          final item = extra?['item'] as ItemModel?;
          if (item == null) {
            return const DashboardScreen();
          }
          return StockCountScreen(
            item: item,
            batch: extra?['batch'] as BatchModel?,
            taskId: extra?['taskId'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/quick-item-view',
        builder: (c, s) {
          final extra = s.extra is Map ? s.extra as Map : null;
          final item = extra?['item'] as ItemModel?;
          if (item == null) {
            return const DashboardScreen();
          }
          return QuickItemViewScreen(
            item: item,
            taskId: extra?['taskId'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/expiry-check',
        builder: (c, s) {
          final extra = s.extra is Map ? s.extra as Map : null;
          final item = extra?['item'] as ItemModel?;
          if (item == null) {
            return const DashboardScreen();
          }
          return ExpiryVerificationScreen(
            item: item,
            batch: extra?['batch'] as BatchModel?,
            taskId: extra?['taskId'] as String?,
          );
        },
      ),
      GoRoute(
        path: '/submission-confirmation',
        builder: (c, s) {
          final extra = s.extra is Map ? s.extra as Map : null;
          return SubmissionConfirmationScreen(
            itemName: extra?['itemName'] as String? ?? 'Item',
            type: extra?['type'] as String? ?? 'stock_count',
          );
        },
      ),
      GoRoute(path: '/review', builder: (c, s) => const ReviewQueueScreen()),
      GoRoute(
        path: '/review/:id',
        builder: (c, s) => ObservationDetailScreen(
          observation:
              (s.extra as ObservationModel?) ??
              ObservationModel(
                id: s.pathParameters['id']!,
                type: 'stock_count',
                itemId: '-',
                branchId: '-',
                idempotencyKey: '-',
                status: 'pending',
              ),
        ),
      ),
      GoRoute(
        path: '/barcode-mapping',
        builder: (c, s) {
          final barcode = s.extra is Map
              ? (s.extra as Map)['scannedBarcode'] as String?
              : (s.extra as String?);
          return BarcodeMappingScreen(scannedBarcode: barcode);
        },
      ),
      // Manager/Owner review of unknown-barcode mapping requests.
      GoRoute(
        path: '/barcode-mapping/review',
        builder: (c, s) => const BarcodeMappingReviewScreen(),
      ),
      GoRoute(
        path: '/notifications',
        builder: (c, s) => const NotificationCenterScreen(),
      ),
      GoRoute(
        path: '/purchase-lookup',
        builder: (c, s) {
          final code = s.extra is Map
              ? (s.extra as Map)['code'] as String?
              : (s.uri.queryParameters['code'] ?? s.extra as String?);
          return PurchaseLookupScreen(initialCode: code);
        },
      ),
      GoRoute(
        path: '/inward-entry',
        builder: (c, s) {
          final extra = s.extra is Map ? s.extra as Map : null;
          return InwardEntryScreen(
            initialSupplier: extra?['supplier'] as SupplierModel?,
            initialPO: extra?['po'] as PurchaseOrderModel?,
            item: extra?['item'] as ItemModel?,
            batch: extra?['batch'] as BatchModel?,
          );
        },
      ),
    ],
  );
});
