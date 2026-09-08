// core/routing/app_shell.dart
//
// Persistent frame for every authenticated route: the sidebar and top bar
// never rebuild/reload when navigating — only the routed page (`child`)
// swaps out underneath them. Wired up via a ShellRoute in app_router.dart.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'app_router.dart';
import '../../features/dashboard/screens/dashboard_screen.dart'
    show AppSidebar, AppTopBar;

class AppShell extends StatelessWidget {
  final String currentPath;
  final Widget child;

  const AppShell({
    super.key,
    required this.currentPath,
    required this.child,
  });

  static const Color _bg = Color(0xFFF4F7FB);

  // Page titles shown in the top bar for each route. Falls back to
  // 'Dashboard' for anything not listed here.
  static const Map<String, String> _titles = {
    AppRoutes.dashboard:     'Dashboard',
    AppRoutes.users:         'User Management',
    AppRoutes.members:       'Homeowners',
    AppRoutes.payments:      'Finance',
    AppRoutes.documents:     'Documents',
    AppRoutes.announcements: 'Announcements',
    AppRoutes.complaints:    'Complaints',
    AppRoutes.analytics:     'Analytics',
    AppRoutes.reports:       'Reports',
    AppRoutes.settings:      'Settings',
    AppRoutes.audit:         'Audit Log',
    AppRoutes.preview:       'Member Preview',
    // Note: AppRoutes.location is intentionally absent — it's a
    // standalone full-page route outside this shell (see app_router.dart).
  };

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: _bg,
      body: Row(
        children: [
          AppSidebar(
            currentPath: currentPath,
            role:        auth.role,
            onSignOut:   () => auth.signOut(),
          ),
          Expanded(
            child: Column(
              children: [
                AppTopBar(
                  user:  auth.userModel,
                  title: _titles[currentPath] ?? 'Dashboard',
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ],
      ),
    );
  }
}