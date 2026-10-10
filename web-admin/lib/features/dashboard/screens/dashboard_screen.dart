// features/dashboard/screens/dashboard_screen.dart
// UPDATED Phase 8 — Location Mapping added
// UPDATED — Users & Homeowners now route to full pages inside the persistent shell
// UPDATED — Admin + Accountant: "Collected This Month" card and Recent Payments list

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/user_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/models/member_model.dart';
import '../../../core/models/payment_model.dart';
import '../../../core/models/audit_log_model.dart';
import '../../../core/models/complaint_model.dart';
import '../../../core/theme/design_tokens.dart';
import '../../audit/screens/audit_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  
  
  

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.userModel;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Good day, ${user?.displayName ?? 'User'} 👋',
              style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text(
              'You are logged in as ${user?.role.label ?? ''}.',
              style: TextStyle(
                  fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 28),
            _StatsRow(role: auth.role),
            // Accountants have no insights row, so their payments list sits
            // right under the stat cards.
            if (auth.role == UserRole.accountant) ...[
              const SizedBox(height: 28),
              const _RecentPaymentsCard(),
            ],
            if (auth.role == UserRole.admin ||
                auth.role == UserRole.officer) ...[
              const SizedBox(height: 28),
              const Text('Actionable Insights & Activity',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 14),
              const _ActivityAndComplaintsRow(),
            ],
            // Admins get it below Actionable Insights & Activity.
            if (auth.role == UserRole.admin) ...[
              const SizedBox(height: 28),
              const _RecentPaymentsCard(),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Audit Log dialog ─────────────────────────────────────────────────────────
Future<void> _openAuditLogDialog(BuildContext context) {
  final size     = MediaQuery.of(context).size;
  final isMobile = size.width < 700;

  return showDialog(
    context: context,
    barrierColor: Colors.black.withOpacity(0.35),
    builder: (context) {
      // Shared between both layouts so the close button always overlays
      // the screen the same way.
      final content = Stack(
        children: [
          const AuditScreen(),
          Positioned(
            top: 10,
            right: 10,
            child: Material(
              color: Colors.white,
              shape: const CircleBorder(),
              elevation: 3,
              child: IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
        ],
      );

      if (isMobile) {
        // A side-inset modal has no room left for the filter row and
        // list once padding is subtracted on a phone — go full-screen
        // instead of trying to shrink the desktop layout down.
        return Dialog.fullscreen(child: content);
      }

      return Dialog(
        insetPadding: const EdgeInsets.all(40),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: SizedBox(
          width:  size.width > 900 ? 820 : size.width * 0.92,
          height: size.height * 0.82,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: content,
          ),
        ),
      );
    },
  );
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
            // displayStatus, not the raw stored `status` — nothing flips
            // a record to 'overdue' server-side when its dueDate passes,
            // so trusting the raw field here undercounts (often to 0)
            // until an admin has separately opened Payments or Reports.
            final overdueCount = payments
                .where((p) =>
                    p.displayStatus == PaymentStatus.overdue)
                .length;
            final collectedTotal = payments
                .where((p) =>
                    p.status == PaymentStatus.paid)
                .fold(
                    0.0, (sum, p) => sum + p.amount);

            // Same definition the Analytics screen uses for
            // "Collected This Month" (see
            // AnalyticsService.getCollectedThisMonth): paid, and the
            // paidDate — when the cash came in — falls inside the
            // current calendar month. Computed from the stream we
            // already have, so no extra Firestore reads.
            final now          = DateTime.now();
            final startOfMonth = DateTime(now.year, now.month, 1);
            final endOfMonth   = DateTime(now.year, now.month + 1, 1);
            final collectedThisMonth = payments.where((p) {
              final d = p.paidDate;
              return p.status == PaymentStatus.paid &&
                  d != null &&
                  !d.isBefore(startOfMonth) &&
                  d.isBefore(endOfMonth);
            }).fold(0.0, (sum, p) => sum + p.amount);

            final cards = <Widget>[
              _StatCard(
                label: 'Total Members',
                value: '${members.length}',
                sub:   '$activeMembers active',
                icon: Icons.people_outline,
                color: const Color(0xFF1A4A9C),
              ),
              if (role == UserRole.admin ||
                  role == UserRole.accountant) ...[
                _StatCard(
                  label: 'Collected This Month',
                  value: _peso(collectedThisMonth),
                  sub:   'All time ${_peso(collectedTotal)}',
                  icon: Icons.payments_outlined,
                  color: const Color(0xFF1A7A4A),
                  onTap: () => context.go(AppRoutes.analytics),
                ),
                _StatCard(
                  label: 'Overdue Payments',
                  value: '$overdueCount',
                  sub:   'need attention',
                  icon: Icons.warning_amber_outlined,
                  color: const Color(0xFFCC2200),
                ),
              ],
            ];

            return LayoutBuilder(
              builder: (context, constraints) {
                // Below this, three cards side-by-side can't fit their
                // text without truncating — stack them full-width instead.
                final narrow = constraints.maxWidth < 640;

                if (narrow) {
                  return Column(
                    children: [
                      for (int i = 0; i < cards.length; i++) ...[
                        if (i > 0) const SizedBox(height: 12),
                        cards[i],
                      ],
                    ],
                  );
                }

                return Row(
                  children: [
                    for (int i = 0; i < cards.length; i++) ...[
                      if (i > 0) const SizedBox(width: 14),
                      Expanded(child: cards[i]),
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
  final VoidCallback? onTap;

  const _StatCard({
    required this.label, required this.value,
    required this.sub,   required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardBorderRadius,
        border: Border.all(color: AppColors.border),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.space2_5),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: AppRadius.buttonBorderRadius,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: AppSpacing.space3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label.copyWith(color: AppColors.textMuted)),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.greeting.copyWith(
                        fontSize: 20,
                        color: color)),
                Text(sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(onTap: onTap, child: card),
    );
  }
}

// ── Money / date helpers ─────────────────────────────────────────────────────
String _peso(double v, {int decimals = 0}) {
  final parts = v.abs().toStringAsFixed(decimals).split('.');
  final intPart = parts[0];
  final buf = StringBuffer();
  for (int i = 0; i < intPart.length; i++) {
    if (i > 0 && (intPart.length - i) % 3 == 0) buf.write(',');
    buf.write(intPart[i]);
  }
  final dec = parts.length > 1 ? '.${parts[1]}' : '';
  return '${v < 0 ? '-' : ''}₱$buf$dec';
}

String _fmtDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/${d.year}';

// ── Recent Payments card (Admin + Accountant) ────────────────────────────────
// Latest payments that were actually paid, newest paid-date first. Reads only
// a handful of documents (not the whole collection) and needs no composite
// index: it's a single-field orderBy on paidDate, then filtered client-side.
class _RecentPaymentsCard extends StatefulWidget {
  const _RecentPaymentsCard();

  @override
  State<_RecentPaymentsCard> createState() => _RecentPaymentsCardState();
}

class _RecentPaymentsCardState extends State<_RecentPaymentsCard> {
  late final Stream<List<PaymentModel>> _stream;
  final ScrollController _scroll = ScrollController();

  // The list scrolls inside a fixed-height box, so the dashboard page
  // doesn't get longer as more payments come in.
  static const double _listMaxHeight = 340;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _stream = FirestoreService()
        .db
        .collection('payments')
        .orderBy('paidDate', descending: true)
        .limit(25)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((d) => PaymentModel.fromMap(d.data(), d.id))
          .where((p) =>
              p.status == PaymentStatus.paid && p.paidDate != null)
          .toList();
      // Same-day payments share a paidDate, so fall back to when the
      // record was created to keep the order stable.
      list.sort((a, b) {
        final c = b.paidDate!.compareTo(a.paidDate!);
        return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
      });
      return list.take(20).toList();
    });
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.cardPadding),
    decoration: AppComponents.cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Recent Payments',
                style: AppTypography.cardTitle.copyWith(color: AppColors.textPrimary)),
            const Spacer(),
            TextButton(
              onPressed: () => context.go(AppRoutes.payments),
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: Text('View all',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.primary)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space1_5),
        StreamBuilder<List<PaymentModel>>(
          stream: _stream,
          builder: (context, snap) {
            if (snap.hasError) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('Could not load recent payments.',
                    style: TextStyle(
                        fontSize: 12.5, color: Colors.grey[500])),
              );
            }
            if (snap.connectionState == ConnectionState.waiting &&
                !snap.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2))),
              );
            }
            final payments = snap.data ?? [];
            if (payments.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('No payments recorded yet.',
                    style: TextStyle(
                        fontSize: 12.5, color: Colors.grey[500])),
              );
            }
            // Grows with the content up to _listMaxHeight, then scrolls.
            return ConstrainedBox(
              constraints:
                  const BoxConstraints(maxHeight: _listMaxHeight),
              child: Scrollbar(
                controller: _scroll,
                thumbVisibility: true,
                child: SingleChildScrollView(
                  controller: _scroll,
                  padding: const EdgeInsets.only(right: 12),
                  child: Column(
                    children: [
                      for (int i = 0; i < payments.length; i++) ...[
                        if (i > 0)
                          const Divider(
                              height: 18, color: Color(0xFFEFF3FA)),
                        _RecentPaymentRow(payment: payments[i]),
                      ],
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ],
    ),
  );
}

class _RecentPaymentRow extends StatelessWidget {
  final PaymentModel payment;
  const _RecentPaymentRow({required this.payment});

  @override
  Widget build(BuildContext context) {
    final subtitle = payment.lotLabel.isNotEmpty
        ? '${payment.type.label} · ${payment.lotLabel}'
        : payment.type.label;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.payments_outlined,
              size: 15, color: AppColors.success),
        ),
        const SizedBox(width: AppSpacing.space2_5),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                payment.memberName.isNotEmpty
                    ? payment.memberName
                    : 'Unknown member',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.space2_5),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(_peso(payment.amount, decimals: 2),
                style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.success)),
            const SizedBox(height: 2),
            Text(_fmtDate(payment.paidDate!),
                style: AppTypography.label),
          ],
        ),
      ],
    );
  }
}

// ── Activity Log + Pending Complaints row ────────────────────────────────────
class _ActivityAndComplaintsRow extends StatelessWidget {
  const _ActivityAndComplaintsRow();

  @override
  Widget build(BuildContext context) {
    final settingsSvc = SettingsService();
    final fs          = FirestoreService();

    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 760;
        final activity   = _RecentActivityCard(svc: settingsSvc);
        final complaints = _PendingComplaintsCard(fs: fs);

        if (narrow) {
          return Column(
            children: [
              activity,
              const SizedBox(height: 14),
              complaints,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 3, child: activity),
            const SizedBox(width: 14),
            Expanded(flex: 2, child: complaints),
          ],
        );
      },
    );
  }
}

// ── Recent Activity Log card (sourced from Audit Log) ────────────────────────
class _RecentActivityCard extends StatelessWidget {
  final SettingsService svc;
  const _RecentActivityCard({required this.svc});

  Color _actionColor(AuditAction a) {
    switch (a) {
      case AuditAction.created:       return AppColors.success;
      case AuditAction.updated:       return AppColors.primary;
      case AuditAction.deleted:       return AppColors.danger;
      case AuditAction.statusChanged: return AppColors.warning;
      case AuditAction.roleChanged:   return const Color(0xFF5A1A7A);
      case AuditAction.login:         return AppColors.textSecondary;
    }
  }

  IconData _actionIcon(AuditAction a) {
    switch (a) {
      case AuditAction.created:       return Icons.add_circle_outline;
      case AuditAction.updated:       return Icons.edit_outlined;
      case AuditAction.deleted:       return Icons.delete_outline;
      case AuditAction.statusChanged: return Icons.swap_horiz_outlined;
      case AuditAction.roleChanged:   return Icons.manage_accounts_outlined;
      case AuditAction.login:         return Icons.login_outlined;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.cardPadding),
    decoration: AppComponents.cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Recent Activity Log',
                style: AppTypography.cardTitle.copyWith(color: AppColors.textPrimary)),
            const Spacer(),
            TextButton(
              onPressed: () => _openAuditLogDialog(context),
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: Text('View all',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.primary)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space1_5),
        StreamBuilder<List<AuditLogModel>>(
          stream: svc.streamAuditLogs(limit: 5),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting &&
                !snap.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2))),
              );
            }
            final logs = snap.data ?? [];
            if (logs.isEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('No recent activity.',
                    style: TextStyle(
                        fontSize: 12.5, color: Colors.grey[500])),
              );
            }
            return Column(
              children: [
                for (int i = 0; i < logs.length; i++) ...[
                  if (i > 0)
                    const Divider(
                        height: 18, color: Color(0xFFEFF3FA)),
                  _ActivityRow(
                    log:   logs[i],
                    color: _actionColor(logs[i].action),
                    icon:  _actionIcon(logs[i].action),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    ),
  );
}

class _ActivityRow extends StatelessWidget {
  final AuditLogModel log;
  final Color         color;
  final IconData      icon;
  const _ActivityRow({
    required this.log, required this.color, required this.icon,
  });

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 30, height: 30,
        decoration: AppComponents.iconBoxDecoration(color),
        child: Icon(icon, size: 15, color: color),
      ),
      const SizedBox(width: AppSpacing.space2_5),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: log.performedByName.isNotEmpty
                        ? log.performedByName
                        : 'Someone',
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary)),
                TextSpan(
                    text: ' ${log.description}',
                    style: AppTypography.bodyMedium.copyWith(color: AppColors.textSecondary)),
              ]),
            ),
            const SizedBox(height: 2),
            Text(_timeAgo(log.createdAt),
                style: AppTypography.caption),
          ],
        ),
      ),
    ],
  );
}

// ── Pending Complaints card ───────────────────────────────────────────────────
class _PendingComplaintsCard extends StatelessWidget {
  final FirestoreService fs;
  const _PendingComplaintsCard({required this.fs});

  Color _statusColor(ComplaintStatus s) {
    switch (s) {
      case ComplaintStatus.pending:   return AppColors.warning;
      case ComplaintStatus.reviewing: return AppColors.primary;
      case ComplaintStatus.resolved:  return AppColors.success;
      case ComplaintStatus.rejected:  return AppColors.danger;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.cardPadding),
    decoration: AppComponents.cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Pending Complaints',
                style: AppTypography.cardTitle.copyWith(color: AppColors.textPrimary)),
            const Spacer(),
            TextButton(
              onPressed: () => context.go(AppRoutes.complaints),
              style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 0),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: Text('View all',
                  style: AppTypography.bodyMedium.copyWith(color: AppColors.primary)),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.space2_5),
        StreamBuilder<List<ComplaintModel>>(
          stream: fs.streamComplaints(),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting &&
                !snap.hasData) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                    child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2))),
              );
            }
            final all = snap.data ?? [];
            final pending = all
                .where((c) =>
                    c.status == ComplaintStatus.pending ||
                    c.status == ComplaintStatus.reviewing)
                .toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            final pendingCount = all
                .where((c) => c.status == ComplaintStatus.pending)
                .length;
            final reviewingCount = all
                .where((c) => c.status == ComplaintStatus.reviewing)
                .length;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${pending.length}',
                        style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B))),
                    const SizedBox(width: 12),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 4,
                        children: [
                          _StatusDot(
                              color: _statusColor(
                                  ComplaintStatus.pending),
                              label: 'Pending ($pendingCount)'),
                          _StatusDot(
                              color: _statusColor(
                                  ComplaintStatus.reviewing),
                              label: 'Reviewing ($reviewingCount)'),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                if (pending.isEmpty)
                  Text('No open complaints right now.',
                      style: TextStyle(
                          fontSize: 12.5, color: Colors.grey[500]))
                else
                  Column(
                    children: [
                      for (int i = 0; i < pending.length && i < 4; i++) ...[
                        if (i > 0)
                          const Divider(
                              height: 16, color: Color(0xFFEFF3FA)),
                        _ComplaintRow(
                          complaint: pending[i],
                          color: _statusColor(pending[i].status),
                        ),
                      ],
                    ],
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class _StatusDot extends StatelessWidget {
  final Color  color;
  final String label;
  const _StatusDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 7, height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: AppSpacing.space1),
      Text(label,
          style: AppTypography.caption.copyWith(color: AppColors.textSecondary)),
    ],
  );
}

class _ComplaintRow extends StatelessWidget {
  final ComplaintModel complaint;
  final Color          color;
  const _ComplaintRow({required this.complaint, required this.color});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        margin: const EdgeInsets.only(top: 4),
        width: 6, height: 6,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: AppSpacing.space1),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(complaint.subject.isNotEmpty
                    ? complaint.subject
                    : '(No subject)',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary)),
            Text(complaint.memberName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption),
          ],
        ),
      ),
      const SizedBox(width: AppSpacing.space1),
      Text(_timeAgo(complaint.createdAt),
          style: AppTypography.caption),
    ],
  );
}

// ── Shared time-ago formatter ─────────────────────────────────────────────────
String _timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60)  return 'just now';
  if (diff.inMinutes < 60)  return '${diff.inMinutes}m ago';
  if (diff.inHours   < 24)  return '${diff.inHours}h ago';
  if (diff.inDays    < 7)   return '${diff.inDays}d ago';
  return '${dt.month}/${dt.day}/${dt.year}';
}

// ── Top bar ───────────────────────────────────────────────────────────────────
class AppTopBar extends StatelessWidget {
  final UserModel? user;
  final String     title;
  final bool         showMenuButton;
  final VoidCallback? onMenuTap;
  
  
  const AppTopBar({
    super.key,
    this.user,
    this.title = 'Dashboard',
    this.showMenuButton = false,
    this.onMenuTap,
  });

  @override
  Widget build(BuildContext context) => Container(
    height: 60,
    padding: EdgeInsets.symmetric(
        horizontal: showMenuButton ? 16 : 28),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(
          bottom: BorderSide(
              color: Color(0xFFE0E8F4))),
    ),
    child: Row(
      children: [
        if (showMenuButton)
          InkWell(
            onTap: onMenuTap,
            borderRadius: BorderRadius.circular(6),
            child: const Padding(
              padding: EdgeInsets.only(right: 12),
              child: Icon(Icons.menu,
                  color: AppColors.textPrimary, size: 22),
            ),
          ),
        Text(title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary)),
        const Spacer(),
        if (user != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius:
                  BorderRadius.circular(20),
            ),
            child: Text(user!.role.label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary)),
          ),
          if (!showMenuButton) ...[
            const SizedBox(width: 10),
            Text(user!.displayName,
                style: const TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500)),
          ],
        ],
      ],
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
        color: Color(0xFF1E293B),
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
    icon:     Icons.manage_accounts_outlined,
    label:    'Users',
    selected: currentPath == AppRoutes.users,
    onTap: () => context.go(AppRoutes.users),
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
    selected: currentPath == AppRoutes.members,
    onTap: () => context.go(AppRoutes.members),
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
                      role == UserRole.officer)
                    _NavItem(
                      icon:     Icons
                          .feedback_outlined,
                      label:    'Feedback',
                      selected: currentPath ==
                          AppRoutes.feedback,
                      onTap: () => context
                          .go(AppRoutes.feedback),
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
  selected: currentPath == AppRoutes.audit,
  onTap: () => _openAuditLogDialog(context),
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

          // Help & Onboarding — visible to every role
          _NavItem(
            icon: Icons.help_outline,
            label: 'Help',
            selected: currentPath == AppRoutes.help,
            onTap: () => context.go(AppRoutes.help),
          ),

          const Divider(
              color: Color(0xFF1E3E7C), height: 1),
          InkWell(
            onTap: () => _confirmSignOut(context),
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

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        title: const Text('Sign Out?',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700)),
        content: const Text(
            'You\'ll need to sign in again to access the dashboard.',
            style: TextStyle(fontSize: 13.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) onSignOut();
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