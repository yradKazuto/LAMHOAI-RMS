// lib/features/home/home_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../../core/models/payment_model.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/design_tokens.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth        = context.watch<AuthProvider>();
    final user        = auth.user;
    final displayName = user?.displayName ?? 'Member';
    final uid         = user?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTopBar(context, displayName),
              _buildHeroCard(uid),
              _buildQuickAccess(context),
              _buildNotificationsPreview(context, uid),
              _buildAnnouncementsPreview(context),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ── Top bar ───────────────────────────────────────────────────────────────

  Widget _buildTopBar(BuildContext context, String name) {
    final hour     = DateTime.now().hour;
    final greeting = hour < 12 ? 'Good morning,' : hour < 17 ? 'Good afternoon,' : 'Good evening,';
    final initials = _initials(name);

    return Container(
      color: AppColors.primaryHeader,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting, style: AppTypography.caption.copyWith(color: AppPrimitiveColors.blue200)),
              Text(
                name,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 16,
                  color: AppColors.textInverted,
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
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.textInverted.withValues(alpha: 0.2), width: 2),
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textInverted),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero card ─────────────────────────────────────────────────────────────

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
            // effectiveStatus (not the raw Firestore `status`), same as
            // PaymentsScreen — nothing flips a record's stored status to
            // 'overdue' server-side when its dueDate passes (that only
            // happens when an admin opens Payments/Reports on
            // web-admin), so trusting the raw field here under-reports
            // overdue payments and shows a false "up to date" pill.
            final payment = PaymentModel.fromFirestore(doc);
            totalDue += payment.amount;
            if (payment.effectiveStatus == PaymentStatus.overdue) {
              overdueCount++;
            }
          }
        }

        final fmt        = NumberFormat('#,##0.00', 'en_PH');
        final hasOverdue = overdueCount > 0;

        return Container(
          margin: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primaryHeader,
            borderRadius: AppRadius.cardBorderRadius,
            border: Border.all(color: AppColors.primary),
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total balance due',
                style: AppTypography.caption.copyWith(
                  color: AppPrimitiveColors.blue200,
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
                          child: CircularProgressIndicator(color: AppColors.textInverted, strokeWidth: 2),
                        ),
                      ),
                    )
                  : Text(
                      '₱${fmt.format(totalDue)}',
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 28,
                        color: AppColors.textInverted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: hasOverdue ? AppColors.errorBg : AppColors.successBg,
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: hasOverdue ? AppColors.error : AppColors.success,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      totalDue == 0
                          ? 'All payments settled'
                          : hasOverdue
                              ? '$overdueCount overdue payment${overdueCount > 1 ? 's' : ''}'
                              : 'Payments pending',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Quick Access ──────────────────────────────────────────────────────────

  Widget _buildQuickAccess(BuildContext context) {
    final items = [
      _QuickItem(icon: Icons.receipt_long_outlined, label: 'Payments',      sub: 'View records',  route: Routes.payments),
      _QuickItem(icon: Icons.report_problem_outlined, label: 'Complaints',    sub: 'Submit issue',  route: Routes.complaints),
      _QuickItem(icon: Icons.notifications_none_outlined, label: 'Notifications', sub: 'View alerts',   route: Routes.notifications),
      _QuickItem(icon: Icons.person_outline, label: 'Profile',       sub: 'View info',     route: Routes.profile),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Quick access', style: AppTypography.sectionHeader),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.2,
            children: items.map((item) => _buildQuickCard(context, item)).toList(),
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
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadius.lg),
          border: Border.all(color: AppColors.border),
        ),
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: AppComponents.iconBoxDecoration(AppColors.primary),
              child: Center(
                child: Icon(item.icon, size: 17, color: AppColors.primary),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(item.label, style: AppTypography.bodyMedium),
                  Text(item.sub, style: AppTypography.caption),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Notifications preview ─────────────────────────────────────────────────

  Widget _buildNotificationsPreview(BuildContext context, String uid) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Notifications', style: AppTypography.sectionHeader),
              GestureDetector(
                onTap: () => context.go(Routes.notifications),
                child: Text(
                  'See all',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text('No notifications yet.', style: AppTypography.caption),
                  ),
                );
              }
              return Column(
                children: snap.data!.docs.map((doc) {
                  final data    = doc.data() as Map<String, dynamic>;
                  final type    = data['type']   as String? ?? 'general';
                  final isRead  = data['isRead'] as bool?   ?? false;
                  final created = (data['createdAt'] as Timestamp?)?.toDate();
                  final color   = type == 'announcement'
                      ? AppPrimitiveColors.gold
                      : AppColors.primary;

                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
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
                              color: isRead ? AppColors.textMuted : color,
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
                                data['title'] as String? ?? '',
                                style: AppTypography.caption.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.5,
                                  fontWeight:
                                      isRead ? FontWeight.w400 : FontWeight.w600,
                                ),
                              ),
                              if (created != null)
                                Text(_timeAgo(created), style: AppTypography.caption),
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
              Text('Announcements', style: AppTypography.sectionHeader),
              GestureDetector(
                onTap: () => context.go(Routes.announcements),
                child: Text(
                  'See all',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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
                return const Center(child: CircularProgressIndicator());
              }
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Center(
                    child: Text('No announcements.', style: AppTypography.caption),
                  ),
                );
              }
              return Column(
                children: snap.data!.docs.map((doc) {
                  final data    = doc.data() as Map<String, dynamic>;
                  final created = (data['createdAt'] as Timestamp?)?.toDate();

                  return GestureDetector(
                    onTap: () => context.go(Routes.announcements),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: AppComponents.iconBoxDecoration(
                              AppPrimitiveColors.gold,
                            ),
                            child: Center(
                              child: Icon(
                                Icons.campaign_outlined,
                                size: 17,
                                color: AppPrimitiveColors.gold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['title'] as String? ?? '',
                                  style: AppTypography.bodyMedium,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  data['body'] as String? ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.caption,
                                ),
                                if (created != null) ...[
                                  const SizedBox(height: 2),
                                  Text(_timeAgo(created), style: AppTypography.caption),
                                ],
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, size: 14, color: AppColors.textMuted),
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
    if (parts.length >= 2) return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
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
  final IconData icon;
  final String label, sub, route;
  const _QuickItem({
    required this.icon,
    required this.label,
    required this.sub,
    required this.route,
  });
}