// core/routing/app_router.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../providers/auth_provider.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/dashboard/screens/dashboard_screen.dart';

// ── Route names ──────────────────────────────────────────────────────────────
class AppRoutes {
  static const login = '/login';
  static const dashboard = '/dashboard';
  // Add more routes here as phases progress
  // static const homeowners  = '/homeowners';
  // static const finance     = '/finance';
  // static const userManager = '/users';
}

// ── Router factory ────────────────────────────────────────────────────────────
GoRouter createRouter(AuthProvider authProvider) {
  return GoRouter(
    debugLogDiagnostics: true,
    initialLocation: AppRoutes.login,
    refreshListenable: authProvider,
    redirect: (BuildContext context, GoRouterState state) {
      final status = authProvider.status;
      final isOnLogin = state.matchedLocation == AppRoutes.login;

      // Still initialising — stay put
      if (status == AuthStatus.initial || status == AuthStatus.loading) {
        return null;
      }

      // Not logged in → force to login
      if (status == AuthStatus.unauthenticated ||
          status == AuthStatus.error) {
        return isOnLogin ? null : AppRoutes.login;
      }

      // Logged in, on login page → send to dashboard
      if (status == AuthStatus.authenticated && isOnLogin) {
        return AppRoutes.dashboard;
      }

      // Role-based guards — expand as more routes are added
      final role = authProvider.role;
      final path = state.matchedLocation;

      // Example guard (uncomment when routes exist):
      // if (path.startsWith('/users') && role != UserRole.admin) {
      //   return AppRoutes.dashboard;
      // }
      // if (path.startsWith('/finance') &&
      //     role != UserRole.admin && role != UserRole.accountant) {
      //   return AppRoutes.dashboard;
      // }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        name: 'dashboard',
        builder: (context, state) => const DashboardScreen(),
      ),
    ],
    errorBuilder: (context, state) => _ErrorScreen(error: state.error),
  );
}

// ── 404 / error page ──────────────────────────────────────────────────────────
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
            const Icon(Icons.error_outline, size: 48, color: Color(0xFF1A3A6B)),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(color: const Color(0xFF1A3A6B)),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => context.go(AppRoutes.dashboard),
              child: const Text('Go to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }
}