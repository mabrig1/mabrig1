import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'ui/screens/duplicates/duplicate_screen.dart';
import 'ui/screens/home/home_screen.dart';
import 'ui/screens/junk_scan/junk_scan_screen.dart';
import 'ui/screens/settings/settings_screen.dart';
import 'ui/shared/theme/app_theme.dart';
import 'ui/shared/widgets/permission_gate.dart';

final _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (_, __) => const PermissionGate(child: HomeScreen()),
    ),
    GoRoute(
      path: '/junk',
      builder: (_, __) => const PermissionGate(child: JunkScanScreen()),
    ),
    GoRoute(
      path: '/duplicates',
      builder: (_, __) => const PermissionGate(child: DuplicateScreen()),
    ),
    GoRoute(
      path: '/settings',
      builder: (_, __) => const SettingsScreen(),
    ),
  ],
);

class PhoneCleanerApp extends StatelessWidget {
  const PhoneCleanerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Phone Cleaner',
      theme: AppTheme.dark,
      routerConfig: _router,
      debugShowCheckedModeBanner: false,
    );
  }
}
