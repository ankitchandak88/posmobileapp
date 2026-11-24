import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';

/// Bottom-nav shell wrapping Home / Tasks / Scan / History / Profile, used
/// by the ShellRoute in app_router.dart.
class RootShell extends StatelessWidget {
  const RootShell({super.key, required this.child});

  final Widget child;

  int _indexForLocation(String location) {
    if (location.startsWith('/tasks')) return 1;
    if (location.startsWith('/history')) return 3;
    if (location.startsWith('/profile')) return 4;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primaryBlue,
        shape: const CircleBorder(),
        onPressed: () =>
            context.push('/scanner', extra: {'mode': 'stock_count'}),
        child: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Color(0x0D101530),
              blurRadius: 10,
              offset: Offset(0, -3),
            ),
          ],
        ),
        child: BottomAppBar(
          shape: const CircularNotchedRectangle(),
          notchMargin: 8,
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _navItem(context, Icons.home_rounded, 'Home', 0, '/home'),
              _navItem(context, Icons.assignment_rounded, 'Tasks', 1, '/tasks'),
              const SizedBox(width: 48),
              _navItem(context, Icons.history_rounded, 'History', 3, '/history'),
              _navItem(context, Icons.person_rounded, 'Profile', 4, '/profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    BuildContext context,
    IconData icon,
    String label,
    int index,
    String route,
  ) {
    final location = GoRouterState.of(context).matchedLocation;
    final isActive = _indexForLocation(location) == index;
    final color = isActive ? AppColors.primaryBlue : AppColors.textMuted;
    return InkWell(
      onTap: () => context.go(route),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
