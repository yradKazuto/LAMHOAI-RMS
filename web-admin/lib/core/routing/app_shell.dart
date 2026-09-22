// core/routing/app_shell.dart
//
// Persistent frame for every authenticated route: the sidebar and top bar
// never rebuild/reload when navigating — only the routed page (`child`)
// swaps out underneath them. Wired up via a ShellRoute in app_router.dart.
//
// Responsive: at or above `_mobileBreakpoint` width the sidebar stays
// permanently docked (original desktop/web-admin behaviour). Below it,
// the sidebar moves into a Drawer opened via a hamburger button in the
// top bar, and the content column takes the full width.

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

  // Below this width the persistent sidebar becomes a Drawer instead.
  static const double _mobileBreakpoint = 900;

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
    final title = _titles[currentPath] ?? 'Dashboard';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < _mobileBreakpoint;

        Widget buildSidebar() => AppSidebar(
          currentPath: currentPath,
          role:        auth.role,
          onSignOut:   () => auth.signOut(),
        );

        if (isMobile) {
          return Scaffold(
            backgroundColor: _bg,
            drawer: Drawer(width: 220, child: buildSidebar()),
            body: Builder(
              builder: (drawerContext) => Column(
                children: [
                  AppTopBar(
                    user:  auth.userModel,
                    title: title,
                    showMenuButton: true,
                    onMenuTap: () => Scaffold.of(drawerContext).openDrawer(),
                  ),
                  Expanded(child: child),
                ],
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: _bg,
          body: Row(
            children: [
              buildSidebar(),
              Expanded(
                child: Column(
                  children: [
                    AppTopBar(user: auth.userModel, title: title),
                    Expanded(child: child),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}