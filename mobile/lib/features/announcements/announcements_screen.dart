// lib/features/announcements/announcements_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/theme/design_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_header.dart';

class AnnouncementsScreen extends StatelessWidget {
  const AnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          AppHeader(
            title: 'Announcements',
            subtitle: 'Official notices from La Milagrosa HOA',
            onBack: () =>
                context.canPop() ? context.pop() : context.go('/home'),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('announcements')
                  .where('isActive', isEqualTo: true)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return _buildError(snap.error.toString());
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) return _buildEmpty();
                return _buildList(context, docs);
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── List ──────────────────────────────────────────────────────────────────

  Widget _buildList(BuildContext context, List<QueryDocumentSnapshot> docs) {
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: docs.length,
      itemBuilder: (context, i) {
        final data = docs[i].data() as Map<String, dynamic>;
        return _buildCard(context, data);
      },
    );
  }

  Widget _buildCard(BuildContext context, Map<String, dynamic> data) {
    final title     = data['title']        as String? ?? '';
    final body      = data['body']         as String? ?? '';
    final postedBy  = data['postedByName'] as String? ?? 'HOA Admin';
    final createdAt = (data['createdAt']   as Timestamp?)?.toDate();
    final dateFmt   = DateFormat('MMMM d, yyyy');
    final timeFmt   = DateFormat('h:mm a');

    return AppCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: EdgeInsets.zero,
      onTap: () => _showDetail(context, data),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Flat accent bar — carries the hierarchy the gradient used to.
          Container(
            height: 3,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppRadius.xl),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration:
                          AppComponents.iconBoxDecoration(AppPrimitiveColors.gold),
                      child: const Center(
                        child: Icon(
                          Icons.campaign_outlined,
                          size: 18,
                          color: AppPrimitiveColors.gold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: AppTypography.cardTitle),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.person_outline,
                                  size: 10, color: AppColors.textMuted),
                              const SizedBox(width: 3),
                              Text(postedBy, style: AppTypography.caption),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const AppStatusPill(
                      label: 'OFFICIAL',
                      color: AppColors.primary,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  body,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 10, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      createdAt != null
                          ? '${dateFmt.format(createdAt)}  ·  ${timeFmt.format(createdAt)}'
                          : '—',
                      style: AppTypography.caption,
                    ),
                    const Spacer(),
                    Text(
                      'Read more',
                      style: AppTypography.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        size: 12, color: AppColors.primary),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Detail bottom sheet ───────────────────────────────────────────────────

  void _showDetail(BuildContext context, Map<String, dynamic> data) {
    final title     = data['title']        as String? ?? '';
    final body      = data['body']         as String? ?? '';
    final postedBy  = data['postedByName'] as String? ?? 'HOA Admin';
    final createdAt = (data['createdAt']   as Timestamp?)?.toDate();
    final dateFmt   = DateFormat('MMMM d, yyyy · h:mm a');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.65,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warningBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppPrimitiveColors.gold.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.campaign_outlined,
                        size: 11, color: AppPrimitiveColors.gold),
                    SizedBox(width: 4),
                    Text('Official Announcement',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppPrimitiveColors.gold)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(title, style: AppTypography.pageTitle),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person_outline,
                      size: 12, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Text(postedBy, style: AppTypography.caption),
                  const SizedBox(width: 12),
                  const Icon(Icons.calendar_today_outlined,
                      size: 12, color: AppColors.textMuted),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      createdAt != null ? dateFmt.format(createdAt) : '—',
                      style: AppTypography.caption,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(color: AppColors.borderSubtle),
              const SizedBox(height: 16),
              Text(
                body,
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    side: const BorderSide(color: AppColors.border, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Close',
                      style: AppTypography.button
                          .copyWith(color: AppColors.textSecondary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Empty / Error ─────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    return const Center(
      child: AppEmptyState(
        icon: Icons.campaign_outlined,
        message: 'No announcements at this time.',
      ),
    );
  }

  Widget _buildError(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 36, color: AppColors.error),
            const SizedBox(height: 12),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: AppColors.error),
            ),
          ],
        ),
      ),
    );
  }
}
