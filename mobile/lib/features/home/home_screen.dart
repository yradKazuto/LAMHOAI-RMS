// lib/features/home/home_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/routing/app_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // ── Design tokens ─────────────────────────────────────────────────────────
  static const _blue700  = Color(0xFF1A3D6B);
  static const _blue600  = Color(0xFF1E52A0);
  static const _blue500  = Color(0xFF2563EB);
  static const _blue200  = Color(0xFFBAD9FD);
  static const _blue50   = Color(0xFFEFF6FF);
  static const _gold     = Color(0xFFC9A84C);
  static const _gray50   = Color(0xFFF8FAFC);
  static const _gray100  = Color(0xFFEEF2F7);
  static const _gray400  = Color(0xFF8A9BB0);
  static const _gray600  = Color(0xFF4A5A6E);
  static const _gray800  = Color(0xFF1E2A3A);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final displayName = user?.displayName ?? 'Member';
    final initials = _initials(displayName);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(context, displayName, initials),
              _buildHeroCard(),
              _buildQuickAccess(context),
              _buildNotifications(context),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────

  Widget _buildTopBar(BuildContext context, String name, String initials) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning,'
        : hour < 17
            ? 'Good afternoon,'
            : 'Good evening,';

    return Container(
      color: _blue700,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Greeting + name
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                greeting,
                style: const TextStyle(fontSize: 10, color: _blue200),
              ),
              Text(
                name,
                style: const TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 16,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          // Avatar — tapping goes to Profile
          GestureDetector(
            onTap: () => context.go(Routes.profile),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _blue500,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.2), width: 2),
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero card ─────────────────────────────────────────────────────────────

  Widget _buildHeroCard() {
    return Container(
      margin: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_blue600, _blue500],
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(18),
      child: Stack(
        children: [
          // Decorative circle
          Positioned(
            right: -20,
            top: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.06),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'CURRENT BALANCE DUE',
                style: TextStyle(
                  fontSize: 10,
                  color: _blue200,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '₱2,400.00',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 28,
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              // Status pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4ADE80),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'Lot 12 · Phase 1 · Active',
                      style: TextStyle(fontSize: 10, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Quick Access grid ─────────────────────────────────────────────────────

  Widget _buildQuickAccess(BuildContext context) {
    final items = [
      _QuickItem(
        emoji: '💳',
        label: 'Payments',
        sub: '3 records',
        bg: _blue50,
        route: Routes.payments,
      ),
      _QuickItem(
        emoji: '📋',
        label: 'Dues',
        sub: 'Due July 1',
        bg: const Color(0xFFFEF9C3),
        route: Routes.payments,
      ),
      _QuickItem(
        emoji: '📣',
        label: 'Complaints',
        sub: 'Submit issue',
        bg: _blue50,
        route: Routes.complaints,
      ),
      _QuickItem(
        emoji: '👤',
        label: 'Profile',
        sub: 'View info',
        bg: _gray100,
        route: Routes.profile,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Quick Access',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _gray800,
            ),
          ),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 1.8,
            children: items
                .map((item) => _buildQuickCard(context, item))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickCard(BuildContext context, _QuickItem item) {
    return GestureDetector(
      onTap: () => context.go(item.route),
      child: Container(
        decoration: BoxDecoration(
          color: _gray50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _gray100),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: item.bg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(item.emoji, style: const TextStyle(fontSize: 14)),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _gray800,
                  ),
                ),
                Text(
                  item.sub,
                  style: const TextStyle(fontSize: 10, color: _gray400),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Notifications preview ─────────────────────────────────────────────────

  Widget _buildNotifications(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Notifications',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _gray800,
                ),
              ),
              GestureDetector(
                onTap: () => context.go(Routes.notifications),
                child: const Text(
                  'See all',
                  style: TextStyle(
                    fontSize: 11,
                    color: _blue500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          _buildNotifItem(
            dotColor: _blue500,
            text: 'Monthly due of ₱800 is due in 5 days',
            time: 'Today, 8:00 AM',
          ),
          _buildNotifItem(
            dotColor: _gold,
            text: 'Annual membership fee reminder for 2026',
            time: 'Yesterday, 3:00 PM',
          ),
        ],
      ),
    );
  }

  Widget _buildNotifItem({
    required Color dotColor,
    required String text,
    required String time,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: _gray100)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 11,
                    color: _gray600,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: const TextStyle(fontSize: 10, color: _gray400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

// ── Data class ────────────────────────────────────────────────────────────

class _QuickItem {
  final String emoji;
  final String label;
  final String sub;
  final Color bg;
  final String route;

  const _QuickItem({
    required this.emoji,
    required this.label,
    required this.sub,
    required this.bg,
    required this.route,
  });
}