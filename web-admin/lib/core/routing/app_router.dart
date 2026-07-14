// core/routing/app_router.dart
// UPDATED Phase 8 — adds /location route (Location Mapping)

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';
import '../../features/members/screens/members_screen.dart';
import '../../features/payments/screens/payments_screen.dart';
import '../../features/documents/screens/documents_screen.dart';
import '../../features/users/screens/user_management_screen.dart';
import '../../features/announcements/screens/announcements_screen.dart';
import '../../features/complaints/screens/complaints_screen.dart';
import '../../features/analytics/screens/analytics_screen.dart';
import '../../features/reports/screens/reports_screen.dart';
import '../../features/settings/screens/settings_screen.dart';
import '../../features/audit/screens/audit_screen.dart';
import '../../features/preview/screens/member_preview_screen.dart';
import '../../features/location/screens/location_mapping_screen.dart';

class AppRoutes {
  static const login         = '/login';
  static const dashboard     = '/dashboard';
  static const members       = '/members';
  static const payments      = '/payments';
  static const documents     = '/documents';
  static const users         = '/users';
  static const announcements = '/announcements';
  static const complaints    = '/complaints';
  static const analytics     = '/analytics';
  static const reports       = '/reports';
  static const settings      = '/settings';
  static const audit         = '/audit';
  static const preview       = '/preview';
  static const location      = '/location';
}

GoRouter createRouter(AuthProvider authProvider) {
  return GoRouter(
    debugLogDiagnostics: true,
    initialLocation: AppRoutes.login,
    refreshListenable: authProvider,
    redirect: (context, state) {
      final status    = authProvider.status;
      final isOnLogin =
          state.matchedLocation == AppRoutes.login;

      if (status == AuthStatus.initial ||
          status == AuthStatus.loading) return null;

      if (status == AuthStatus.unauthenticated ||
          status == AuthStatus.error) {
        return isOnLogin ? null : AppRoutes.login;
      }

      if (status == AuthStatus.authenticated &&
          isOnLogin) {
        return AppRoutes.dashboard;
      }

      final role = authProvider.role;
      final path = state.matchedLocation;

      // Admin only routes
      if ((path.startsWith(AppRoutes.users) ||
              path.startsWith(AppRoutes.audit) ||
              path.startsWith(AppRoutes.settings) ||
              path.startsWith(AppRoutes.preview)) &&
          role != UserRole.admin) {
        return AppRoutes.dashboard;
      }

      // Finance — Admin + Accountant
      if (path.startsWith(AppRoutes.payments) &&
          role != UserRole.admin &&
          role != UserRole.accountant) {
        return AppRoutes.dashboard;
      }

      // Reports — Admin + Accountant
      if (path.startsWith(AppRoutes.reports) &&
          role != UserRole.admin &&
          role != UserRole.accountant) {
        return AppRoutes.dashboard;
      }

      // Analytics — Admin + Accountant
      if (path.startsWith(AppRoutes.analytics) &&
          role != UserRole.admin &&
          role != UserRole.accountant) {
        return AppRoutes.dashboard;
      }

      // Members — Admin + Officer
      if (path.startsWith(AppRoutes.members) &&
          role != UserRole.admin &&
          role != UserRole.officer) {
        return AppRoutes.dashboard;
      }

      // Documents — Admin + Officer
      if (path.startsWith(AppRoutes.documents) &&
          role != UserRole.admin &&
          role != UserRole.officer) {
        return AppRoutes.dashboard;
      }

      // Complaints — Admin + Officer
      if (path.startsWith(AppRoutes.complaints) &&
          role != UserRole.admin &&
          role != UserRole.officer) {
        return AppRoutes.dashboard;
      }

      // Location Mapping — Admin + Officer
      if (path.startsWith(AppRoutes.location) &&
          role != UserRole.admin &&
          role != UserRole.officer) {
        return AppRoutes.dashboard;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        name: 'dashboard',
        builder: (_, __) => const DashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.members,
        name: 'members',
        builder: (_, __) => const MembersScreen(),
      ),
      GoRoute(
        path: AppRoutes.payments,
        name: 'payments',
        builder: (_, __) => const PaymentsScreen(),
      ),
      GoRoute(
        path: AppRoutes.documents,
        name: 'documents',
        builder: (_, __) => const DocumentsScreen(),
      ),
      GoRoute(
        path: AppRoutes.users,
        name: 'users',
        builder: (_, __) =>
            const UserManagementScreen(),
      ),
      GoRoute(
        path: AppRoutes.announcements,
        name: 'announcements',
        builder: (_, __) =>
            const AnnouncementsScreen(),
      ),
      GoRoute(
        path: AppRoutes.complaints,
        name: 'complaints',
        builder: (_, __) => const ComplaintsScreen(),
      ),
      GoRoute(
        path: AppRoutes.analytics,
        name: 'analytics',
        builder: (_, __) => const AnalyticsScreen(),
      ),
      GoRoute(
        path: AppRoutes.reports,
        name: 'reports',
        builder: (_, __) => const ReportsScreen(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        name: 'settings',
        builder: (_, __) => const SettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.audit,
        name: 'audit',
        builder: (_, __) => const AuditScreen(),
      ),
      GoRoute(
        path: AppRoutes.preview,
        name: 'preview',
        builder: (_, __) =>
            const MemberPreviewScreen(),
      ),
      GoRoute(
        path: AppRoutes.location,
        name: 'location',
        builder: (_, __) =>
            const LocationMappingScreen(),
      ),
    ],
    errorBuilder: (context, state) =>
        _ErrorScreen(error: state.error),
  );
}

class _ErrorScreen extends StatelessWidget {
  final Exception? error;
  const _ErrorScreen({this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FA),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline,
                size: 48, color: Color(0xFF1A3A6B)),
            const SizedBox(height: 16),
            Text('Page not found',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(
                        color:
                            const Color(0xFF1A3A6B))),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () =>
                  context.go(AppRoutes.dashboard),
              child:
                  const Text('Go to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}