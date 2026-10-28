// lib/features/complaints/complaints_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/routing/app_router.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/status_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_header.dart';

class ComplaintsScreen extends StatefulWidget {
  const ComplaintsScreen({super.key});

  @override
  State<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().user?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          AppHeader(
            title: 'My Complaints',
            subtitle: 'Track and submit HOA complaints',
            onBack: () =>
                context.canPop() ? context.pop() : context.go('/home'),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('complaints')
                  .where('uid', isEqualTo: uid)
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
                final all  = docs.map((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return _ComplaintItem(
                    id:          d.id,
                    title:       data['title']       as String? ?? '',
                    description: data['description'] as String? ?? '',
                    category:    data['category']    as String? ?? 'general',
                    status:      data['status']      as String? ?? 'pending',
                    createdAt:   (data['createdAt']  as Timestamp?)?.toDate(),
                    resolvedAt:  (data['resolvedAt'] as Timestamp?)?.toDate(),
                  );
                }).toList();

                final filtered = _filter == 'All'
                    ? all
                    : all.where((c) => c.status.toLowerCase() == _filter.toLowerCase()).toList();

                return Column(
                  children: [
                    _buildSummaryRow(all),
                    _buildFilterRow(),
                    Expanded(
                      child: filtered.isEmpty ? _buildEmpty() : _buildList(filtered),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(Routes.submitComplaint),
        backgroundColor: AppColors.primary,
        elevation: 2,
        icon: const Icon(Icons.add, color: AppColors.textInverted, size: 18),
        label: const Text(
          'New Complaint',
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textInverted,
          ),
        ),
      ),
    );
  }

  // ── Summary row ───────────────────────────────────────────────────────────

  Widget _buildSummaryRow(List<_ComplaintItem> all) {
    final pending   = all.where((c) => c.status == 'pending').length;
    final reviewing = all.where((c) => c.status == 'reviewing').length;
    final resolved  = all.where((c) => c.status == 'resolved').length;

    return AppCard(
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          _sumItem('$pending', 'Pending'),
          _divider(),
          _sumItem('$reviewing', 'Reviewing'),
          _divider(),
          _sumItem('$resolved', 'Resolved'),
        ],
      ),
    );
  }

  Widget _sumItem(String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: AppTypography.money),
          const SizedBox(height: 3),
          Text(label, style: AppTypography.caption),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 32, color: AppColors.borderSubtle);

  // ── Filter row ────────────────────────────────────────────────────────────

  Widget _buildFilterRow() {
    final filters = ['All', 'Pending', 'Reviewing', 'Resolved', 'Rejected'];
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
        children: filters.map((f) {
          final active = _filter == f;
          return GestureDetector(
            onTap: () => setState(() => _filter = f),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: active ? AppColors.primary : AppColors.surface,
                borderRadius: AppRadius.pillBorderRadius,
                border: Border.all(
                  color: active ? AppColors.primary : AppColors.border,
                  width: 1.5,
                ),
              ),
              child: Text(
                f,
                style: AppTypography.label.copyWith(
                  fontWeight: FontWeight.w500,
                  color: active ? AppColors.textInverted : AppColors.textSecondary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── List ──────────────────────────────────────────────────────────────────

  Widget _buildList(List<_ComplaintItem> items) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 90),
      itemCount: items.length,
      itemBuilder: (context, i) => _buildCard(items[i]),
    );
  }

  Widget _buildCard(_ComplaintItem item) {
    final dateFmt = DateFormat('MMM d, yyyy');
    final status  = StatusColors.forLabel(item.status);

    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      borderColor: AppColors.borderSubtle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: AppComponents.iconBoxDecoration(AppColors.primary),
                child: const Center(
                  child: Icon(
                    Icons.report_problem_outlined,
                    size: 18,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(item.title, style: AppTypography.bodyMedium),
              ),
              const SizedBox(width: 8),
              AppStatusPill(
                label: _statusLabel(item.status),
                color: status.ink,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.caption.copyWith(
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                _categoryLabel(item.category),
                style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.calendar_today_outlined,
                size: 10,
                color: AppColors.textMuted,
              ),
              const SizedBox(width: 4),
              Text(
                item.createdAt != null ? dateFmt.format(item.createdAt!) : '—',
                style: AppTypography.caption,
              ),
            ],
          ),
          if (item.resolvedAt != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  size: 11,
                  color: AppColors.success,
                ),
                const SizedBox(width: 4),
                Text(
                  'Resolved ${dateFmt.format(item.resolvedAt!)}',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Empty / Error ─────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    return AppEmptyState(
      icon: Icons.report_problem_outlined,
      message: _filter == 'All'
          ? 'No complaints submitted yet.'
          : 'No ${_filter.toLowerCase()} complaints.',
      hint: 'Tap "New Complaint" to submit one.',
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

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _statusLabel(String s) => s.isEmpty ? '' : s[0].toUpperCase() + s.substring(1);

  String _categoryLabel(String c) {
    switch (c.toLowerCase()) {
      case 'maintenance':  return 'Maintenance';
      case 'noise':        return 'Noise';
      case 'security':     return 'Security';
      case 'cleanliness':  return 'Cleanliness';
      case 'billing':      return 'Billing';
      default:             return 'General';
    }
  }
}

class _ComplaintItem {
  final String id, title, description, category, status;
  final DateTime? createdAt, resolvedAt;
  const _ComplaintItem({
    required this.id, required this.title, required this.description,
    required this.category, required this.status, this.createdAt, this.resolvedAt,
  });
}
