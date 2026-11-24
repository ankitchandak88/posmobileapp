import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

import 'features/auth/state/auth_providers.dart';

void main() {
  runApp(const ProviderScope(child: UrbanPetsVerifyApp()));
}

class UrbanPetsVerifyApp extends ConsumerStatefulWidget {
  const UrbanPetsVerifyApp({super.key});

  @override
  ConsumerState<UrbanPetsVerifyApp> createState() => _UrbanPetsVerifyAppState();
}

class _UrbanPetsVerifyAppState extends ConsumerState<UrbanPetsVerifyApp>
    with WidgetsBindingObserver {
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      if (_pausedAt != null) {
        final elapsed = DateTime.now().difference(_pausedAt!);
        // Auto-lock if backgrounded for more than 60 seconds
        if (elapsed.inSeconds >= 60) {
          ref.read(authControllerProvider.notifier).lockIfEnabled();
        }
        _pausedAt = null;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Urban Pets — Stock & Expiry Verification',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
