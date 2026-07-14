// features/dashboard/screens/dashboard_screen.dart
// UPDATED Phase 8 — Location Mapping added

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/user_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/models/member_model.dart';
import '../../../core/models/payment_model.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static const Color _navy   = Color(0xFF0D2A5C);
  static const Color _accent = Color(0xFF2E6BE6);
  static const Color _bg     = Color(0xFFF0F4FB);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.userModel;

    return Scaffold(
      backgroundColor: _bg,
      body: Row(
        children: [
          AppSidebar(
            currentPath: AppRoutes.dashboard,
            role:        auth.role,
            onSignOut:   () => auth.signOut(),
          ),
          Expanded(
            child: Column(
              children: [
                _TopBar(user: user),
                Expanded(
                  child: SingleChildScrollView(
                    padding:
                        const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Good day, ${user?.displayName ?? 'User'} 👋',
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight:
                                  FontWeight.w700,
                              color: _navy),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'You are logged in as ${user?.role.label ?? ''}.',
                          style: TextStyle(
                              fontSize: 14,
                              color:
                                  Colors.grey[600]),
                        ),
                        const SizedBox(height: 28),
                        _StatsRow(role: auth.role),
                        const SizedBox(height: 28),
                        const Text('Quick Access',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight:
                                    FontWeight.w700,
                                color: _navy)),
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 14,
                          runSpacing: 14,
                          children: _cards(
                              context, auth.role),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _cards(
      BuildContext context, UserRole role) => [
    if (role == UserRole.admin)
      _DashCard(
        icon:        Icons.manage_accounts_outlined,
        label:       'User Management',
        description: 'Manage staff accounts and roles',
        color:       const Color(0xFF5A1A7A),
        onTap: () => context.go(AppRoutes.users),
      ),
    if (role == UserRole.admin ||
        role == UserRole.officer)
      _DashCard(
        icon:        Icons.people_outline,
        label:       'Homeowner Records',
        description: 'View and manage member profiles',
        color:       const Color(0xFF1A4A9C),
        onTap: () => context.go(AppRoutes.members),
      ),
    if (role == UserRole.admin ||
        role == UserRole.accountant)
      _DashCard(
        icon:        Icons.account_balance_wallet_outlined,
        label:       'Finance & Dues',
        description: 'Billing, payments, and reports',
        color:       const Color(0xFF1A7A4A),
        onTap: () => context.go(AppRoutes.payments),
      ),
    if (role == UserRole.admin ||
        role == UserRole.officer)
      _DashCard(
        icon:        Icons.folder_outlined,
        label:       'Documents',
        description: 'Property titles and uploaded files',
        color:       const Color(0xFF7A3A1A),
        onTap: () => context.go(AppRoutes.documents),
      ),
    if (role == UserRole.admin ||
        role == UserRole.officer)
      _DashCard(
        icon:        Icons.map_outlined,
        label:       'Location Mapping',
        description: 'View lot occupancy and availability',
        color:       const Color(0xFF0A6E6E),
        onTap: () => context.go(AppRoutes.location),
      ),
    _DashCard(
      icon:        Icons.campaign_outlined,
      label:       'Announcements',
      description: 'Post notices to homeowners',
      color:       const Color(0xFF1A5A7A),
      onTap: () =>
          context.go(AppRoutes.announcements),
    ),
    if (role == UserRole.admin ||
        role == UserRole.officer)
      _DashCard(
        icon:        Icons.report_problem_outlined,
        label:       'Complaints',
        description: 'Review and resolve complaints',
        color:       const Color(0xFF7A1A1A),
        onTap: () =>
            context.go(AppRoutes.complaints),
      ),
    if (role == UserRole.admin ||
        role == UserRole.accountant) ...[
      _DashCard(
        icon:        Icons.bar_chart_outlined,
        label:       'Analytics',
        description: 'Charts and financial overview',
        color:       const Color(0xFF1A4A7A),
        onTap: () =>
            context.go(AppRoutes.analytics),
      ),
      _DashCard(
        icon:        Icons.summarize_outlined,
        label:       'Reports & Export',
        description: 'Export payments to PDF or CSV',
        color:       const Color(0xFF4A1A7A),
        onTap: () => context.go(AppRoutes.reports),
      ),
    ],
    if (role == UserRole.admin) ...[
      _DashCard(
        icon:        Icons.settings_outlined,
        label:       'Settings',
        description: 'HOA profile and dues config',
        color:       const Color(0xFF1A5A4A),
        onTap: () =>
            context.go(AppRoutes.settings),
      ),
      _DashCard(
        icon:        Icons.history_outlined,
        label:       'Audit Log',
        description: 'Track admin actions and changes',
        color:       const Color(0xFF5A4A1A),
        onTap: () => context.go(AppRoutes.audit),
      ),
      _DashCard(
        icon:        Icons.phone_android_outlined,
        label:       'Member Preview',
        description: 'Preview member mobile experience',
        color:       const Color(0xFF1A3A5A),
        onTap: () => context.go(AppRoutes.preview),
      ),
    ],
  ];
}

// ── Stats row ─────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final UserRole role;
  final _fs = FirestoreService();
  _StatsRow({required this.role});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MemberModel>>(
      stream: _fs.streamMembers(),
      builder: (context, memberSnap) {
        return StreamBuilder<List<PaymentModel>>(
          stream: _fs.streamPayments(),
          builder: (context, paySnap) {
            final members  = memberSnap.data ?? [];
            final payments = paySnap.data ?? [];

            final activeMembers = members
                .where((m) =>
                    m.status == MemberStatus.active)
                .length;
            final overdueCount = payments
                .where((p) =>
                    p.status == PaymentStatus.overdue)
                .length;
            final collectedTotal = payments
                .where((p) =>
                    p.status == PaymentStatus.paid)
                .fold(
                    0.0, (sum, p) => sum + p.amount);

            return LayoutBuilder(
              builder: (context, constraints) {
                return Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Total Members',
                        value: '${members.length}',
                        sub:   '$activeMembers active',
                        icon: Icons.people_outline,
                        color: const Color(0xFF1A4A9C),
                      ),
                    ),
                    if (role == UserRole.admin ||
                        role ==
                            UserRole.accountant) ...[
                      const SizedBox(width: 14),
                      Expanded(
                        child: _StatCard(
                          label: 'Total Collected',
                          value:
                              '₱${collectedTotal.toStringAsFixed(0)}',
                          sub:   'all time',
                          icon: Icons.payments_outlined,
                          color: const Color(
                              0xFF1A7A4A),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _StatCard(
                          label: 'Overdue Payments',
                          value: '$overdueCount',
                          sub:   'need attention',
                          icon: Icons
                              .warning_amber_outlined,
                          color: const Color(
                              0xFFCC2200),
                        ),
                      ),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value, sub;
  final IconData icon;
  final Color    color;

  const _StatCard({
    required this.label, required this.value,
    required this.sub,   required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
          color: const Color(0xFFE0E8F4)),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius:
                  BorderRadius.circular(8)),
          child:
              Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11.5,
                    color: Colors.grey[600])),
            Text(value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: color)),
            Text(sub,
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[400])),
          ],
        ),
      ],
    ),
  );
}

// ── Top bar ───────────────────────────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final UserModel? user;
  static const Color _navy   = Color(0xFF0D2A5C);
  static const Color _accent = Color(0xFF2E6BE6);
  const _TopBar({this.user});

  @override
  Widget build(BuildContext context) => Container(
    height: 60,
    padding: const EdgeInsets.symmetric(
        horizontal: 28),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(
          bottom: BorderSide(
              color: Color(0xFFE0E8F4))),
    ),
    child: Row(
      children: [
        const Text('Dashboard',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _navy)),
        const Spacer(),
        if (user != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _accent.withOpacity(0.1),
              borderRadius:
                  BorderRadius.circular(20),
            ),
            child: Text(user!.role.label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _accent)),
          ),
          const SizedBox(width: 10),
          Text(user!.displayName,
              style: const TextStyle(
                  fontSize: 13.5,
                  color: _navy,
                  fontWeight: FontWeight.w500)),
        ],
      ],
    ),
  );
}

// ── Dashboard card ────────────────────────────────────────────────────────────
class _DashCard extends StatelessWidget {
  final IconData     icon;
  final String       label, description;
  final Color        color;
  final VoidCallback onTap;

  const _DashCard({
    required this.icon,        required this.label,
    required this.description, required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Container(
      width: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFFE0E8F4)),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius:
                  BorderRadius.circular(8),
            ),
            child:
                Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 14),
          Text(label,
              style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0D2A5C))),
          const SizedBox(height: 4),
          Text(description,
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[500],
                  height: 1.4)),
        ],
      ),
    ),
  );
}

// ── App sidebar ───────────────────────────────────────────────────────────────
class AppSidebar extends StatelessWidget {
  final String       currentPath;
  final UserRole     role;
  final VoidCallback onSignOut;

  const AppSidebar({
    super.key,
    required this.currentPath,
    required this.role,
    required this.onSignOut,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: const BoxDecoration(
        color: Color(0xFF0D2A5C),
        border: Border(
            right: BorderSide(
                color: Color(0xFF1A3A7C))),
      ),
      child: Column(
        children: [
          // Logo
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 20, vertical: 22),
            child: Row(
              children: [
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white
                        .withOpacity(0.15),
                  ),
                  child: const Icon(
                      Icons.account_balance,
                      color: Colors.white,
                      size: 17),
                ),
                const SizedBox(width: 10),
                const Text('LAMHOAI',
                    style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        letterSpacing: 1.5)),
              ],
            ),
          ),
          const Divider(
              color: Color(0xFF1E3E7C), height: 1),
          const SizedBox(height: 8),

          // Scrollable nav
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _NavItem(
                    icon:     Icons.dashboard_outlined,
                    label:    'Dashboard',
                    selected: currentPath ==
                        AppRoutes.dashboard,
                    onTap: () => context
                        .go(AppRoutes.dashboard),
                  ),
                  if (role == UserRole.admin)
                    _NavItem(
                      icon:     Icons
                          .manage_accounts_outlined,
                      label:    'Users',
                      selected: currentPath ==
                          AppRoutes.users,
                      onTap: () => context
                          .go(AppRoutes.users),
                    ),
                  if (role == UserRole.admin ||
                      role == UserRole.accountant)
                    _NavItem(
                      icon:     Icons
                          .account_balance_wallet_outlined,
                      label:    'Finance',
                      selected: currentPath ==
                          AppRoutes.payments,
                      onTap: () => context
                          .go(AppRoutes.payments),
                    ),
                  if (role == UserRole.admin ||
                      role == UserRole.officer)
                    _NavItem(
                      icon: Icons.people_outline,
                      label:    'Homeowners',
                      selected: currentPath ==
                          AppRoutes.members,
                      onTap: () => context
                          .go(AppRoutes.members),
                    ),
                  if (role == UserRole.admin ||
                      role == UserRole.officer)
                    _NavItem(
                      icon:     Icons.folder_outlined,
                      label:    'Documents',
                      selected: currentPath ==
                          AppRoutes.documents,
                      onTap: () => context
                          .go(AppRoutes.documents),
                    ),
                  if (role == UserRole.admin ||
                      role == UserRole.officer)
                    _NavItem(
                      icon:     Icons.map_outlined,
                      label:    'Location Mapping',
                      selected: currentPath ==
                          AppRoutes.location,
                      onTap: () => context
                          .go(AppRoutes.location),
                    ),
                  _NavItem(
                    icon:     Icons.campaign_outlined,
                    label:    'Announcements',
                    selected: currentPath ==
                        AppRoutes.announcements,
                    onTap: () => context.go(
                        AppRoutes.announcements),
                  ),
                  if (role == UserRole.admin ||
                      role == UserRole.officer)
                    _NavItem(
                      icon:     Icons
                          .report_problem_outlined,
                      label:    'Complaints',
                      selected: currentPath ==
                          AppRoutes.complaints,
                      onTap: () => context
                          .go(AppRoutes.complaints),
                    ),
                  if (role == UserRole.admin ||
                      role == UserRole.accountant) ...[
                    _NavItem(
                      icon: Icons.bar_chart_outlined,
                      label:    'Analytics',
                      selected: currentPath ==
                          AppRoutes.analytics,
                      onTap: () => context
                          .go(AppRoutes.analytics),
                    ),
                    _NavItem(
                      icon:
                          Icons.summarize_outlined,
                      label:    'Reports',
                      selected: currentPath ==
                          AppRoutes.reports,
                      onTap: () => context
                          .go(AppRoutes.reports),
                    ),
                  ],
                  if (role == UserRole.admin) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8),
                      child: Divider(
                          color: Color(0xFF1E3E7C),
                          height: 1),
                    ),
                    _NavItem(
                      icon:     Icons.settings_outlined,
                      label:    'Settings',
                      selected: currentPath ==
                          AppRoutes.settings,
                      onTap: () => context
                          .go(AppRoutes.settings),
                    ),
                    _NavItem(
                      icon:     Icons.history_outlined,
                      label:    'Audit Log',
                      selected: currentPath ==
                          AppRoutes.audit,
                      onTap: () =>
                          context.go(AppRoutes.audit),
                    ),
                    _NavItem(
                      icon: Icons.phone_android_outlined,
                      label:    'Member Preview',
                      selected: currentPath ==
                          AppRoutes.preview,
                      onTap: () => context
                          .go(AppRoutes.preview),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const Divider(
              color: Color(0xFF1E3E7C), height: 1),
          InkWell(
            onTap: onSignOut,
            child: const Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Icon(Icons.logout,
                      color: Color(0xFF7A9CCE),
                      size: 18),
                  SizedBox(width: 10),
                  Text('Sign Out',
                      style: TextStyle(
                          color: Color(0xFF7A9CCE),
                          fontSize: 13.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final bool         selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,  required this.label,
    required this.onTap, this.selected = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(
        horizontal: 10, vertical: 2),
    decoration: BoxDecoration(
      color: selected
          ? Colors.white.withOpacity(0.12)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: ListTile(
        dense: true,
        leading: Icon(icon, size: 18,
            color: selected
                ? Colors.white
                : const Color(0xFF7A9CCE)),
        title: Text(label,
            style: TextStyle(
                fontSize: 13.5,
                color: selected
                    ? Colors.white
                    : const Color(0xFF7A9CCE),
                fontWeight: selected
                    ? FontWeight.w600
                    : FontWeight.normal)),
        onTap: onTap,
      ),
    ),
  );
}