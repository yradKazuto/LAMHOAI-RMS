// lib/features/home/home_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/routing/app_router.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static const _blue700  = Color(0xFF1A3D6B);
  static const _blue600  = Color(0xFF1E52A0);
  static const _blue500  = Color(0xFF2563EB);
  static const _blue200  = Color(0xFFBAD9FD);
  static const _gold     = Color(0xFFC9A84C);
  static const _gray50   = Color(0xFFF8FAFC);
  static const _gray100  = Color(0xFFEEF2F7);
  static const _gray400  = Color(0xFF8A9BB0);
  static const _gray600  = Color(0xFF4A5A6E);
  static const _gray800  = Color(0xFF1E2A3A);
  static const _danger   = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    final auth        = context.watch<AuthProvider>();
    final user        = auth.user;
    final displayName = user?.displayName ?? 'Member';
    final initials    = _initials(displayName);
    final uid         = user?.uid ?? '';

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(context, displayName, initials),
              _buildHeroCard(uid),
              _buildQuickAccess(context),
              _buildNotificationsPreview(context, uid),
              _buildAnnouncementsPreview(context),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────

  Widget _buildTopBar(
      BuildContext context, String name, String initials) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good morning,'
        : hour < 17
            ? 'Good afternoon,'
            : 'Good evening,';

    return Container(
      color: _blue700,
      padding:
          const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting,
                  style:
                      const TextStyle(fontSize: 10, color: _blue200)),
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
          GestureDetector(
            onTap: () => context.go(Routes.profile),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _blue500,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: Colors.white.withOpacity(0.2), width: 2),
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

  // ── Hero card — real balance from Firestore ───────────────────────────────

  Widget _buildHeroCard(String uid) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('payments')
          .where('uid', isEqualTo: uid)
          .where('status', whereIn: ['unpaid', 'overdue'])
          .snapshots(),
      builder: (context, snap) {
        double totalDue    = 0;
        int    overdueCount = 0;

        if (snap.hasData) {
          for (final doc in snap.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            totalDue += (data['amount'] as num?)?.toDouble() ?? 0;
            if (data['status'] == 'overdue') overdueCount++;
          }
        }

        final fmt        = NumberFormat('#,##0.00', 'en_PH');
        final hasOverdue = overdueCount > 0;

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
                    'TOTAL BALANCE DUE',
                    style: TextStyle(
                      fontSize: 10,
                      color: _blue200,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  snap.connectionState == ConnectionState.waiting
                      ? const SizedBox(
                          height: 36,
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        )
                      : Text(
                          '₱${fmt.format(totalDue)}',
                          style: const TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 28,
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: hasOverdue
                          ? _danger.withOpacity(0.25)
                          : Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: hasOverdue
                                ? const Color(0xFFFCA5A5)
                                : const Color(0xFF4ADE80),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          totalDue == 0
                              ? 'All payments settled ✓'
                              : hasOverdue
                                  ? '$overdueCount overdue payment${overdueCount > 1 ? 's' : ''}'
                                  : 'Payments pending',
                          style: const TextStyle(
                              fontSize: 10, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Quick Access grid ─────────────────────────────────────────────────────

  Widget _buildQuickAccess(BuildContext context) {
    final items = [
      _QuickItem(emoji: '💳', label: 'Payments',
          sub: 'View records',   bg: _blue500.withOpacity(0.08),
          route: Routes.payments),
      _QuickItem(emoji: '📣', label: 'Complaints',
          sub: 'Submit issue',   bg: _blue500.withOpacity(0.08),
          route: Routes.complaints),
      _QuickItem(emoji: '🔔', label: 'Notifications',
          sub: 'View alerts',    bg: const Color(0xFFFEF9C3),
          route: Routes.notifications),
      _QuickItem(emoji: '👤', label: 'Profile',
          sub: 'View info',      bg: _gray100,
          route: Routes.profile),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quick Access',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _gray800)),
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
                  child: Text(item.emoji,
                      style: const TextStyle(fontSize: 14))),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.label,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _gray800)),
                Text(item.sub,
                    style: const TextStyle(
                        fontSize: 10, color: _gray400)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── Notifications preview ─────────────────────────────────────────────────

  Widget _buildNotificationsPreview(
      BuildContext context, String uid) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Notifications',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _gray800)),
              GestureDetector(
                onTap: () => context.go(Routes.notifications),
                child: const Text('See all',
                    style: TextStyle(
                        fontSize: 11,
                        color: _blue500,
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('uid', isEqualTo: uid)
                .orderBy('createdAt', descending: true)
                .limit(2)
                .snapshots(),
            builder: (context, snap) {
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text('No notifications yet.',
                        style: TextStyle(
                            fontSize: 11, color: _gray400)),
                  ),
                );
              }
              return Column(
                children: snap.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final type   = data['type']   as String? ?? 'general';
                  final isRead = data['isRead'] as bool?   ?? false;
                  final createdAt =
                      (data['createdAt'] as Timestamp?)?.toDate();
                  final dotColor =
                      type == 'announcement' ? _gold : _blue500;

                  return Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 10),
                    decoration: const BoxDecoration(
                      border: Border(
                          bottom: BorderSide(color: _gray100)),
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
                              color: isRead ? _gray400 : dotColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                data['title'] as String? ?? '',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: _gray600,
                                  height: 1.5,
                                  fontWeight: isRead
                                      ? FontWeight.w400
                                      : FontWeight.w600,
                                ),
                              ),
                              if (createdAt != null)
                                Text(
                                  _timeAgo(createdAt),
                                  style: const TextStyle(
                                      fontSize: 10, color: _gray400),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Announcements preview ─────────────────────────────────────────────────

  Widget _buildAnnouncementsPreview(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Announcements',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _gray800)),
              GestureDetector(
                onTap: () => context.go(Routes.announcements),
                child: const Text('See all',
                    style: TextStyle(
                        fontSize: 11,
                        color: _blue500,
                        fontWeight: FontWeight.w500)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('announcements')
                .where('isActive', isEqualTo: true)
                .orderBy('createdAt', descending: true)
                .limit(2)
                .snapshots(),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator());
              }
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text('No announcements.',
                        style: TextStyle(
                            fontSize: 11, color: _gray400)),
                  ),
                );
              }
              return Column(
                children: snap.data!.docs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final createdAt =
                      (data['createdAt'] as Timestamp?)?.toDate();

                  return GestureDetector(
                    onTap: () => context.go(Routes.announcements),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _gray50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _gray100),
                      ),
                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF9C3),
                              borderRadius:
                                  BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Text('📢',
                                  style:
                                      TextStyle(fontSize: 14)),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['title'] as String? ?? '',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _gray800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  data['body'] as String? ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontSize: 10,
                                      color: _gray400),
                                ),
                                if (createdAt != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    _timeAgo(createdAt),
                                    style: const TextStyle(
                                        fontSize: 9,
                                        color: _gray400),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right,
                              size: 14, color: _gray400),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Utilities ─────────────────────────────────────────────────────────────

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    if (diff.inDays < 7)     return '${diff.inDays}d ago';
    return DateFormat('MMM d, yyyy').format(dt);
  }
}

class _QuickItem {
  final String emoji;
  final String label;
  final String sub;
  final Color  bg;
  final String route;
  const _QuickItem({
    required this.emoji,
    required this.label,
    required this.sub,
    required this.bg,
    required this.route,
  });
}