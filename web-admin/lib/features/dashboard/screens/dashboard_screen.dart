// features/dashboard/screens/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/user_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/routing/app_router.dart';
import 'package:go_router/go_router.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static const Color _navy = Color(0xFF0D2A5C);
  static const Color _blue = Color(0xFF1A4A9C);
  static const Color _accent = Color(0xFF2E6BE6);
  static const Color _lightBg = Color(0xFFF0F4FB);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.userModel;

    return Scaffold(
      backgroundColor: _lightBg,
      body: Row(
        children: [
          // ── Sidebar ────────────────────────────────────────────────────────
          _Sidebar(role: auth.role, onSignOut: () => auth.signOut()),

          // ── Main content ───────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top bar
                Container(
                  height: 60,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    border: Border(
                      bottom: BorderSide(color: Color(0xFFE0E8F4)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Text(
                        'Dashboard',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _navy,
                        ),
                      ),
                      const Spacer(),
                      if (user != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            user.role.label,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _accent,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          user.displayName,
                          style: const TextStyle(
                            fontSize: 13.5,
                            color: _navy,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Good day, ${user?.displayName ?? 'User'} 👋',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: _navy,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'You are logged in as ${user?.role.label ?? ''}.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Placeholder cards
                        Wrap(
                          spacing: 16,
                          runSpacing: 16,
                          children: _getCardsForRole(auth.role),
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

  List<Widget> _getCardsForRole(UserRole role) {
    final all = [
      if (role == UserRole.admin)
        _DashCard(
          icon: Icons.manage_accounts_outlined,
          label: 'User Management',
          description: 'Manage admin accounts and roles',
          color: const Color(0xFF1A4A9C),
        ),
      if (role == UserRole.admin || role == UserRole.accountant)
        _DashCard(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Finance & Dues',
          description: 'Billing, payments, and reports',
          color: const Color(0xFF1A7A4A),
        ),
      if (role == UserRole.admin || role == UserRole.officer)
        _DashCard(
          icon: Icons.people_outline,
          label: 'Homeowner Records',
          description: 'View and manage homeowner data',
          color: const Color(0xFF7A3A1A),
        ),
      _DashCard(
        icon: Icons.notifications_outlined,
        label: 'Announcements',
        description: 'Post notices to residents',
        color: const Color(0xFF5A1A7A),
      ),
    ];
    return all;
  }
}

// ── Dashboard card ────────────────────────────────────────────────────────────
class _DashCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color color;

  const _DashCard({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E8F4)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 14),
          Text(
            label,
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF0D2A5C),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[500],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sidebar ───────────────────────────────────────────────────────────────────
class _Sidebar extends StatelessWidget {
  final UserRole role;
  final VoidCallback onSignOut;

  static const Color _navy = Color(0xFF0D2A5C);
  static const Color _blue = Color(0xFF1A4A9C);

  const _Sidebar({required this.role, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      decoration: const BoxDecoration(
        color: Color(0xFF0D2A5C),
        border: Border(right: BorderSide(color: Color(0xFF1A3A7C))),
      ),
      child: Column(
        children: [
          // Logo
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.15),
                  ),
                  child: const Icon(Icons.account_balance,
                      color: Colors.white, size: 17),
                ),
                const SizedBox(width: 10),
                const Text(
                  'LAMHOAI',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const Divider(color: Color(0xFF1E3E7C), height: 1),
          const SizedBox(height: 8),

          // Nav items
          _NavItem(icon: Icons.dashboard_outlined, label: 'Dashboard', selected: true),
          if (role == UserRole.admin)
            _NavItem(icon: Icons.manage_accounts_outlined, label: 'Users'),
          if (role == UserRole.admin || role == UserRole.accountant)
            _NavItem(icon: Icons.account_balance_wallet_outlined, label: 'Finance'),
          if (role == UserRole.admin || role == UserRole.officer)
            _NavItem(icon: Icons.people_outline, label: 'Homeowners'),
          _NavItem(icon: Icons.campaign_outlined, label: 'Announcements'),
          _NavItem(icon: Icons.document_scanner_outlined, label: 'Documents'),

          const Spacer(),
          const Divider(color: Color(0xFF1E3E7C), height: 1),

          // Sign out
          InkWell(
            onTap: onSignOut,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Icon(Icons.logout, color: Color(0xFF7A9CCE), size: 18),
                  SizedBox(width: 10),
                  Text(
                    'Sign Out',
                    style: TextStyle(
                      color: Color(0xFF7A9CCE),
                      fontSize: 13.5,
                    ),
                  ),
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
  final IconData icon;
  final String label;
  final bool selected;

  const _NavItem({
    required this.icon,
    required this.label,
    this.selected = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: selected
            ? Colors.white.withOpacity(0.12)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          icon,
          size: 18,
          color: selected ? Colors.white : const Color(0xFF7A9CCE),
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            color: selected ? Colors.white : const Color(0xFF7A9CCE),
            fontWeight:
                selected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onTap: () {},
      ),
    );
  }
}