// lib/core/routing/app_router.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../models/user_model.dart';
import '../providers/auth_provider.dart' as ap;
import '../../features/home/home_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/forgot_password_screen.dart';
import '../../features/payments/payments_screen.dart';
import '../../features/payments/payment_detail_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../../features/announcements/announcements_screen.dart';
import '../../features/complaints/complaints_screen.dart';
import '../../features/complaints/submit_complaint_screen.dart';
import '../../features/profile/profile_screen.dart';

// ── Route names ───────────────────────────────────────────────────────────────

class Routes {
  Routes._();

  static const splash          = '/splash';
  static const login           = '/login';
  static const forgotPassword  = '/forgot-password';
  static const memberHome      = '/home';
  static const payments        = '/home/payments';
  static const notifications   = '/home/notifications';
  static const announcements   = '/home/announcements';
  static const complaints      = '/home/complaints';
  static const submitComplaint = '/home/complaints/submit';
  static const profile         = '/home/profile';
  static const adminHome       = '/admin';
}

// ── Router factory ────────────────────────────────────────────────────────────

class AppRouter {
  AppRouter._();

  static GoRouter create(ap.AuthProvider authProvider) {
    return GoRouter(
      debugLogDiagnostics: true,
      initialLocation: Routes.splash,
      refreshListenable: authProvider,
      redirect: (BuildContext context, GoRouterState state) {
        final status   = authProvider.status;
        final location = state.matchedLocation;

        // Still initialising — stay on splash
        if (status == ap.AuthStatus.initial ||
            status == ap.AuthStatus.loading) {
          return location == Routes.splash ? null : Routes.splash;
        }

        final authed           = authProvider.isAuthenticated;
        final onLogin          = location == Routes.login;
        final onSplash         = location == Routes.splash;
        final onForgotPassword = location == Routes.forgotPassword;

        // Not authenticated — only allow login and forgot password
        if (!authed) {
          return (onLogin || onForgotPassword) ? null : Routes.login;
        }

        // Authenticated — redirect splash/login to role home
        if (onLogin || onSplash) {
          return _homeForRole(authProvider.user?.role);
        }

        // Prevent members from reaching admin routes
        if (_isAdminRoute(location) &&
            authProvider.user?.role != UserRole.admin) {
          return Routes.memberHome;
        }

        // Prevent admins from reaching member shell routes
        if (_isMemberRoute(location) &&
            authProvider.user?.role == UserRole.admin) {
          return Routes.adminHome;
        }

        return null;
      },
      routes: [
        // ── Splash ────────────────────────────────────────────────────────
        GoRoute(
          path: Routes.splash,
          builder: (_, __) => const _SplashScreen(),
        ),

        // ── Auth ──────────────────────────────────────────────────────────
        GoRoute(
          path: Routes.login,
          builder: (_, __) => const LoginScreen(),
        ),
        GoRoute(
          path: Routes.forgotPassword,
          builder: (_, __) => const ForgotPasswordScreen(),
        ),

        // ── Member shell ──────────────────────────────────────────────────
        StatefulShellRoute.indexedStack(
          builder: (context, state, shell) => _MemberShell(shell: shell),
          branches: [
            // Home
            StatefulShellBranch(routes: [
              GoRoute(
                path: Routes.memberHome,
                builder: (_, __) => const HomeScreen(),
                routes: [
                  // Announcements nested under home
                  GoRoute(
                    path: 'announcements',
                    builder: (_, __) => const AnnouncementsScreen(),
                  ),
                ],
              ),
            ]),

            // Payments + detail
            StatefulShellBranch(routes: [
              GoRoute(
                path: Routes.payments,
                builder: (_, __) => const PaymentsScreen(),
                routes: [
                  GoRoute(
                    path: ':paymentId',
                    builder: (_, state) => PaymentDetailScreen(
                      paymentId: state.pathParameters['paymentId']!,
                    ),
                  ),
                ],
              ),
            ]),

            // Notifications
            StatefulShellBranch(routes: [
              GoRoute(
                path: Routes.notifications,
                builder: (_, __) => const NotificationsScreen(),
              ),
            ]),

            // Complaints + submit
            StatefulShellBranch(routes: [
              GoRoute(
                path: Routes.complaints,
                builder: (_, __) => const ComplaintsScreen(),
                routes: [
                  GoRoute(
                    path: 'submit',
                    builder: (_, __) => const SubmitComplaintScreen(),
                  ),
                ],
              ),
            ]),

            // Profile
            StatefulShellBranch(routes: [
              GoRoute(
                path: Routes.profile,
                builder: (_, __) => const ProfileScreen(),
              ),
            ]),
          ],
        ),

        // ── Admin ─────────────────────────────────────────────────────────
        GoRoute(
          path: Routes.adminHome,
          builder: (_, __) => const _Placeholder(label: 'Admin dashboard'),
        ),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  static String _homeForRole(UserRole? role) {
    if (role == UserRole.admin) return Routes.adminHome;
    return Routes.memberHome;
  }

  static bool _isAdminRoute(String location) =>
      location.startsWith('/admin');

  static bool _isMemberRoute(String location) =>
      location.startsWith('/home');
}

// ── Shared widgets ────────────────────────────────────────────────────────────

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _MemberShell extends StatelessWidget {
  final StatefulNavigationShell shell;
  const _MemberShell({required this.shell});

  static const _tabs = [
    (icon: Icons.home_outlined,          label: 'Home'),
    (icon: Icons.receipt_long_outlined,  label: 'Payments'),
    (icon: Icons.notifications_outlined, label: 'Alerts'),
    (icon: Icons.feedback_outlined,      label: 'Complaints'),
    (icon: Icons.person_outlined,        label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: shell.goBranch,
        destinations: _tabs
            .map((t) => NavigationDestination(
                  icon: Icon(t.icon),
                  label: t.label,
                ))
            .toList(),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  final String label;
  const _Placeholder({required this.label});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(label)),
      body: Center(child: Text('$label — coming soon')),
    );
  }
}