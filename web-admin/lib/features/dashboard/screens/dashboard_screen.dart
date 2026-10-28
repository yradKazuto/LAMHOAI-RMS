// features/dashboard/screens/dashboard_screen.dart
// UPDATED Phase 8 — Location Mapping added
// UPDATED — Users & Homeowners now route to full pages inside the persistent shell
// UPDATED — Admin + Accountant: "Collected This Month" card and Recent Payments list
// UPDATED — Stat cards match the Figma: icon box, status bars, one pie chart
// UPDATED — Stat cards are equal height; calendar and Pending Complaints removed
// UPDATED — Added Outstanding Membership Balance from ledger
// UPDATED — Insights are role based:
//           Admin = Activity Log + Recent Payments
//           Officer = Recent Pending Complaints + Recent Pending Feedback
//           Accountant = Recent Payments
// UPDATED — Fixed field names (ComplaintModel.subject, nullable FeedbackModel.title)

import 'dart:math' as math;
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
import '../../../core/models/feedback_model.dart';
import '../../../core/theme/design_tokens.dart';
import '../../audit/screens/audit_screen.dart';

// Every insight card uses this height so they line up.
const double _insightCardHeight = 420;

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
              'Good day, ${user?.displayName ?? 'User'}',
              style: AppTypography.greeting,
            ),
            const SizedBox(height: 4),
            Text(
              'You are logged in as ${user?.role.label ?? ''}.',
              style: AppTypography.body
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 28),
            _StatsRow(role: auth.role),
            if (auth.role == UserRole.admin ||
                auth.role == UserRole.officer ||
                auth.role == UserRole.accountant) ...[
              const SizedBox(height: 28),
              const Text('Actionable Insights & Activity',
                  style: AppTypography.sectionHeader),
              const SizedBox(height: 14),
              _InsightsRow(role: auth.role),
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
    barrierColor: Colors.black.withValues(alpha: 0.35),
    builder: (context) {
      final content = Stack(
        children: [
          const AuditScreen(),
          Positioned(
            top: 10,
            right: 10,
            child: Material(
              color: AppColors.surface,
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
            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: _fs.streamMemberLedgers(),
              builder: (context, ledgerSnap) {
                final members  = memberSnap.data ?? [];
                final payments = paySnap.data ?? [];

                final activeMembers = members
                    .where((m) => m.status == MemberStatus.active)
                    .length;
                final inactiveMembers = members.length - activeMembers;
                final activePct = members.isEmpty
                    ? 0
                    : (activeMembers / members.length * 100).round();

                // displayStatus, not the raw stored `status` — nothing flips
                // a record to 'overdue' server-side when its dueDate passes.

                final collectedTotal = payments
                    .where((p) => p.status == PaymentStatus.paid)
                    .fold(0.0, (sum, p) => sum + p.amount);

                // Overdue Payments — red bar
                final overdueCount = payments
                    .where((p) => p.displayStatus == PaymentStatus.overdue)
                    .length;
                final notOverdue = payments.length - overdueCount;

                // Same definition the Analytics screen uses for
                // "Collected This Month".
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

                final collectedBefore = (collectedTotal - collectedThisMonth)
                    .clamp(0.0, double.infinity)
                    .toDouble();

                final cards = <Widget>[
                  // Total Members — blue = active, yellow = inactive
                  _StatCard(
                    label: 'Total Members',
                    value: '${members.length}',
                    sub:   '$activePct% active',
                    icon:  Icons.groups_outlined,
                    color: AppColors.primary,
                    bar: _SplitBar(segments: [
                      _BarSeg(activeMembers, AppColors.primary,
                          'Active $activeMembers'),
                      _BarSeg(inactiveMembers, AppColors.warning,
                          'Inactive $inactiveMembers'),
                    ]),
                  ),
                  if (role == UserRole.admin ||
                      role == UserRole.accountant) ...[
                    // Collected This Month — green pie (money)
                    _StatCard(
                      label: 'Collected This Month',
                      value: _peso(collectedThisMonth),
                      sub:   'All time ${_peso(collectedTotal)}',
                      icon:  Icons.payments_outlined,
                      color: AppColors.success,
                      onTap: () => context.go(AppRoutes.analytics),
                      trailing: _PieChart(
                        size: 56,
                        slices: [
                          _PieSlice(collectedThisMonth, AppColors.success),
                          _PieSlice(collectedBefore,
                              AppColors.success.withValues(alpha: 0.25)),
                        ],
                      ),
                      // Legend fills the space the other cards use for their bar.
                      bar: Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Wrap(
                          spacing: 12,
                          children: [
                            _LegendItem(
                                color: AppColors.success, label: 'This month'),
                            _LegendItem(
                                color:
                                    AppColors.success.withValues(alpha: 0.25),
                                label: 'Earlier'),
                          ],
                        ),
                      ),
                    ),
                    // Overdue Payments — red bar
                    _StatCard(
                      label: 'Overdue Payments',
                      value: '$overdueCount',
                      sub:   'need attention',
                      icon:  Icons.warning_amber_rounded,
                      color: AppColors.danger,
                      bar: _SplitBar(segments: [
                        _BarSeg(overdueCount, AppColors.danger,
                            'Overdue $overdueCount'),
                        _BarSeg(notOverdue,
                            AppColors.danger.withValues(alpha: 0.15),
                            'Not overdue $notOverdue'),
                      ]),
                    ),
                  ],
                ];

                return LayoutBuilder(
                  builder: (context, constraints) {
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

                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (int i = 0; i < cards.length; i++) ...[
                            if (i > 0) const SizedBox(width: 14),
                            Expanded(child: cards[i]),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

// Stat card laid out like the Figma: icon box + label on top, big figure,
// small caption. Optional pie (right side) or split status bar (bottom).
class _StatCard extends StatelessWidget {
  final String label, value, sub;
  final IconData icon;
  final Color color;
  final Widget? trailing; // pie chart
  final Widget? bar;      // status bar / legend
  final VoidCallback? onTap;

  const _StatCard({
    required this.label,
    required this.value,
    required this.sub,
    required this.icon,
    required this.color,
    this.trailing,
    this.bar,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Stat cards default color, no special status color (previously used for overdue)
    final valueColor = AppColors.textPrimary;

    final card = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardBorderRadius,
        border: Border.all(color: AppColors.border),
        boxShadow: [...AppShadows.cardGlow, ...AppShadows.card],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label
                        .copyWith(color: AppColors.textMuted)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 34,
                      width: double.infinity,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(value,
                            maxLines: 1,
                            style: AppTypography.greeting.copyWith(
                                fontSize: 28, color: valueColor)),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption
                            .copyWith(color: AppColors.textMuted)),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing!,
              ],
            ],
          ),
          if (bar != null) ...[
            const SizedBox(height: 12),
            bar!,
          ],
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

// ── Split status bar (members + overdue cards) ───────────────────────────────
class _BarSeg {
  final int value;
  final Color color;
  final String label;
  const _BarSeg(this.value, this.color, this.label);
}

class _SplitBar extends StatelessWidget {
  final List<_BarSeg> segments;
  const _SplitBar({required this.segments});

  @override
  Widget build(BuildContext context) {
    final total = segments.fold(0, (s, e) => s + e.value);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 8,
            child: total == 0
                ? Container(color: AppColors.borderSubtle)
                : Row(
                    children: [
                      for (final s in segments)
                        if (s.value > 0)
                          Expanded(
                              flex: s.value,
                              child: Container(color: s.color)),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 2,
          children: [
            for (final s in segments)
              _LegendItem(color: s.color, label: s.label),
          ],
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Text(label,
          style: AppTypography.caption
              .copyWith(fontSize: 10.5, color: AppColors.textSecondary)),
    ],
  );
}

// ── Pie chart (Collected This Month card) ────────────────────────────────────
class _PieSlice {
  final double value;
  final Color color;
  const _PieSlice(this.value, this.color);
}

class _PieChart extends StatelessWidget {
  final List<_PieSlice> slices;
  final double size;
  const _PieChart({required this.slices, required this.size});

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CustomPaint(painter: _PiePainter(slices)),
  );
}

class _PiePainter extends CustomPainter {
  final List<_PieSlice> slices;
  _PiePainter(this.slices);

  @override
  void paint(Canvas canvas, Size size) {
    final rect  = Offset.zero & size;
    final total = slices.fold(0.0, (s, e) => s + e.value);

    if (total <= 0) {
      canvas.drawCircle(
        rect.center,
        size.width / 2,
        Paint()..color = AppColors.borderSubtle,
      );
      return;
    }

    var start = -math.pi / 2;
    for (final s in slices) {
      if (s.value <= 0) continue;
      final sweep = s.value / total * 2 * math.pi;
      canvas.drawArc(rect, start, sweep, true, Paint()..color = s.color);
      canvas.drawArc(
        rect,
        start,
        sweep,
        true,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = AppColors.surface,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _PiePainter old) => true;
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

// ── Shared card pieces (header, empty state, loading) ────────────────────────
class _CardHeader extends StatelessWidget {
  final String title;
  final VoidCallback onViewAll;
  const _CardHeader({required this.title, required this.onViewAll});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(title,
          style: AppTypography.cardTitle
              .copyWith(color: AppColors.textPrimary)),
      const Spacer(),
      TextButton(
        onPressed: onViewAll,
        style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: const Size(0, 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap),
        child: Text('View all',
            style: AppTypography.bodyMedium
                .copyWith(color: AppColors.primary)),
      ),
    ],
  );
}

class _EmptyState extends StatelessWidget {
  final String text;
  const _EmptyState(this.text);

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 36),
      child: Text(text,
          textAlign: TextAlign.center,
          style: AppTypography.caption
              .copyWith(color: AppColors.textMuted)),
    ),
  );
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) => const Center(
    child: SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2)),
  );
}

// ── Recent Payments card (Admin + Accountant) ────────────────────────────────
// Fixed height (same as the other insight cards); the list scrolls inside it.
class _RecentPaymentsCard extends StatefulWidget {
  const _RecentPaymentsCard();

  @override
  State<_RecentPaymentsCard> createState() => _RecentPaymentsCardState();
}

class _RecentPaymentsCardState extends State<_RecentPaymentsCard> {
  late final Stream<List<PaymentModel>> _stream;
  final ScrollController _scroll = ScrollController();

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
      list.sort((a, b) {
        final c = b.paidDate!.compareTo(a.paidDate!);
        return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
      });
      return list.take(20).toList();
    });
  }

  @override
  Widget build(BuildContext context) => Container(
    height: _insightCardHeight,
    padding: const EdgeInsets.all(AppSpacing.cardPadding),
    decoration: AppComponents.cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CardHeader(
          title: 'Recent Payments',
          onViewAll: () => context.go(AppRoutes.payments),
        ),
        const SizedBox(height: AppSpacing.space1_5),
        Expanded(
          child: StreamBuilder<List<PaymentModel>>(
            stream: _stream,
            builder: (context, snap) {
              if (snap.hasError) {
                return const _EmptyState('Could not load recent payments.');
              }
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return const _LoadingState();
              }
              final payments = snap.data ?? [];
              if (payments.isEmpty) {
                return const _EmptyState('No recent payments.');
              }
              return Scrollbar(
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
                              height: 18, color: AppColors.borderSubtle),
                        _RecentPaymentRow(payment: payments[i]),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
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
            color: AppColors.success.withValues(alpha: 0.1),
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
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textPrimary),
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
            Text(_fmtDate(payment.paidDate!), style: AppTypography.label),
          ],
        ),
      ],
    );
  }
}

// ── Recent list card (Pending Complaints / Pending Feedback — Officer) ───────
class _RowData {
  final String title;
  final String subtitle;
  final DateTime? date;

  _RowData(String? title, String? subtitle, this.date)
      : title = (title == null || title.isEmpty) ? 'Untitled' : title,
        subtitle = subtitle ?? '';
}

class _RecentListCard<T> extends StatelessWidget {
  final String title;
  final String emptyText;
  final IconData icon;
  final Color color;
  final Stream<List<T>> stream;
  final _RowData Function(T) toRow;
  final VoidCallback onViewAll;

  const _RecentListCard({
    required this.title,
    required this.emptyText,
    required this.icon,
    required this.color,
    required this.stream,
    required this.toRow,
    required this.onViewAll,
  });

  @override
  Widget build(BuildContext context) => Container(
    height: _insightCardHeight,
    padding: const EdgeInsets.all(AppSpacing.cardPadding),
    decoration: AppComponents.cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CardHeader(title: title, onViewAll: onViewAll),
        const SizedBox(height: AppSpacing.space1_5),
        Expanded(
          child: StreamBuilder<List<T>>(
            stream: stream,
            builder: (context, snap) {
              if (snap.hasError) {
                return const _EmptyState('Could not load this list.');
              }
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return const _LoadingState();
              }
              final items = (snap.data ?? []).take(20).toList();
              if (items.isEmpty) return _EmptyState(emptyText);

              return SingleChildScrollView(
                child: Column(
                  children: [
                    for (int i = 0; i < items.length; i++) ...[
                      if (i > 0)
                        const Divider(
                            height: 18, color: AppColors.borderSubtle),
                      _RecentListRow(
                        data: toRow(items[i]),
                        icon: icon,
                        color: color,
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    ),
  );
}

class _RecentListRow extends StatelessWidget {
  final _RowData data;
  final IconData icon;
  final Color color;
  const _RecentListRow({
    required this.data,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Container(
        width: 30,
        height: 30,
        decoration: AppComponents.iconBoxDecoration(color),
        child: Icon(icon, size: 15, color: color),
      ),
      const SizedBox(width: AppSpacing.space2_5),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.textPrimary)),
            const SizedBox(height: 2),
            Text(data.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.caption),
          ],
        ),
      ),
      if (data.date != null) ...[
        const SizedBox(width: AppSpacing.space2_5),
        Text(_timeAgo(data.date!), style: AppTypography.label),
      ],
    ],
  );
}

// ── Insights row (cards depend on role) ──────────────────────────────────────
class _InsightsRow extends StatelessWidget {
  final UserRole role;
  final _fs = FirestoreService();

  _InsightsRow({required this.role});

  @override
  Widget build(BuildContext context) {
    final isAdmin      = role == UserRole.admin;
    final isOfficer    = role == UserRole.officer;
    final isAccountant = role == UserRole.accountant;

    final cards = <Widget>[
      // Admin: Activity Log first, then Recent Payments
      if (isAdmin) _RecentActivityCard(svc: SettingsService()),
      if (isAdmin || isAccountant) const _RecentPaymentsCard(),

      // Officer: pending lists only
      if (isOfficer) ...[
        _RecentListCard<ComplaintModel>(
          title: 'Recent Pending Complaints',
          emptyText: 'No pending complaints.',
          icon: Icons.report_problem_outlined,
          color: AppColors.warning,
          stream: _fs.streamPendingComplaints(),
          toRow: (c) => _RowData(c.subject, c.memberName, c.createdAt),
          onViewAll: () => context.go(AppRoutes.complaints),
        ),
        _RecentListCard<FeedbackModel>(
          title: 'Recent Pending Feedback',
          emptyText: 'No pending feedback.',
          icon: Icons.feedback_outlined,
          color: AppColors.primary,
          stream: _fs.streamPendingFeedbacks(),
          toRow: (f) => _RowData(
              (f.title != null && f.title!.isNotEmpty) ? f.title : f.message,
              f.memberName,
              f.createdAt),
          onViewAll: () => context.go(AppRoutes.feedback),
        ),
      ],
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 14.0;
        final canSplit = constraints.maxWidth >= 760;
        final cols = (!canSplit || cards.length == 1) ? 1 : 2;
        final itemWidth = (constraints.maxWidth - gap * (cols - 1)) / cols;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final c in cards) SizedBox(width: itemWidth, child: c),
          ],
        );
      },
    );
  }
}

// ── Recent Activity Log card (Admin only, sourced from Audit Log) ────────────
class _RecentActivityCard extends StatelessWidget {
  final SettingsService svc;
  const _RecentActivityCard({required this.svc});

  Color _actionColor(AuditAction a) {
    switch (a) {
      case AuditAction.created:       return AppColors.success;
      case AuditAction.updated:       return AppColors.primary;
      case AuditAction.deleted:       return AppColors.danger;
      case AuditAction.statusChanged: return AppColors.warning;
      case AuditAction.roleChanged:   return AppColors.purple;
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
    height: _insightCardHeight,
    padding: const EdgeInsets.all(AppSpacing.cardPadding),
    decoration: AppComponents.cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _CardHeader(
          title: 'Recent Activity Log',
          onViewAll: () => _openAuditLogDialog(context),
        ),
        const SizedBox(height: AppSpacing.space1_5),
        Expanded(
          child: StreamBuilder<List<AuditLogModel>>(
            stream: svc.streamAuditLogs(limit: 10),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting &&
                  !snap.hasData) {
                return const _LoadingState();
              }
              final logs = snap.data ?? [];
              if (logs.isEmpty) {
                return const _EmptyState('No recent activity.');
              }
              return SingleChildScrollView(
                child: Column(
                  children: [
                    for (int i = 0; i < logs.length; i++) ...[
                      if (i > 0)
                        const Divider(
                            height: 18, color: AppColors.borderSubtle),
                      _ActivityRow(
                        log:   logs[i],
                        color: _actionColor(logs[i].action),
                        icon:  _actionIcon(logs[i].action),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
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
                    style: AppTypography.bodyMedium
                        .copyWith(color: AppColors.textPrimary)),
                TextSpan(
                    text: ' ${log.description}',
                    style: AppTypography.bodyMedium
                        .copyWith(color: AppColors.textSecondary)),
              ]),
            ),
            const SizedBox(height: 2),
            Text(_timeAgo(log.createdAt), style: AppTypography.caption),
          ],
        ),
      ),
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
    padding: EdgeInsets.symmetric(horizontal: showMenuButton ? 16 : 28),
    decoration: const BoxDecoration(
      color: AppColors.surface,
      border: Border(bottom: BorderSide(color: AppColors.border)),
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
            style: AppTypography.sectionHeader.copyWith(fontSize: 16)),
        const Spacer(),
        if (user != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(user!.role.label,
                style: AppTypography.bodyMedium
                    .copyWith(color: AppColors.primary)),
          ),
          if (!showMenuButton) ...[
            const SizedBox(width: 10),
            Text(user!.displayName,
                style: AppTypography.body
                    .copyWith(fontWeight: FontWeight.w500)),
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
        color: AppColors.sidebarBg,
        border: Border(right: BorderSide(color: AppColors.sidebarBorder)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SizedBox(
                height: 42,
                child: Image.asset(
                  'assets/images/logo.png',
                  width: double.infinity,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          const Divider(color: AppColors.sidebarDivider, height: 1),
          const SizedBox(height: 8),

          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _NavItem(
                    icon:     Icons.dashboard_outlined,
                    label:    'Dashboard',
                    selected: currentPath == AppRoutes.dashboard,
                    onTap: () => context.go(AppRoutes.dashboard),
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
                      icon:     Icons.account_balance_wallet_outlined,
                      label:    'Finance',
                      selected: currentPath == AppRoutes.payments,
                      onTap: () => context.go(AppRoutes.payments),
                    ),
                  if (role == UserRole.admin ||
                      role == UserRole.officer)
                    _NavItem(
                      icon:     Icons.people_outline,
                      label:    'Homeowners',
                      selected: currentPath == AppRoutes.members,
                      onTap: () => context.go(AppRoutes.members),
                    ),
                  if (role == UserRole.admin ||
                      role == UserRole.officer)
                    _NavItem(
                      icon:     Icons.map_outlined,
                      label:    'Location Mapping',
                      selected: currentPath == AppRoutes.location,
                      onTap: () => context.go(AppRoutes.location),
                    ),
                  _NavItem(
                    icon:     Icons.campaign_outlined,
                    label:    'Announcements',
                    selected: currentPath == AppRoutes.announcements,
                    onTap: () => context.go(AppRoutes.announcements),
                  ),
                  if (role == UserRole.admin ||
                      role == UserRole.officer)
                    _NavItem(
                      icon:     Icons.report_problem_outlined,
                      label:    'Complaints',
                      selected: currentPath == AppRoutes.complaints,
                      onTap: () => context.go(AppRoutes.complaints),
                    ),
                  if (role == UserRole.admin ||
                      role == UserRole.officer)
                    _NavItem(
                      icon:     Icons.feedback_outlined,
                      label:    'Feedback',
                      selected: currentPath == AppRoutes.feedback,
                      onTap: () => context.go(AppRoutes.feedback),
                    ),
                  if (role == UserRole.admin ||
                      role == UserRole.accountant) ...[
                    _NavItem(
                      icon:     Icons.bar_chart_outlined,
                      label:    'Analytics',
                      selected: currentPath == AppRoutes.analytics,
                      onTap: () => context.go(AppRoutes.analytics),
                    ),
                    _NavItem(
                      icon:     Icons.summarize_outlined,
                      label:    'Reports',
                      selected: currentPath == AppRoutes.reports,
                      onTap: () => context.go(AppRoutes.reports),
                    ),
                  ],
                  if (role == UserRole.admin) ...[
                    const Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      child: Divider(
                          color: AppColors.sidebarDivider, height: 1),
                    ),
                    _NavItem(
                      icon:     Icons.settings_outlined,
                      label:    'Settings',
                      selected: currentPath == AppRoutes.settings,
                      onTap: () => context.go(AppRoutes.settings),
                    ),
                    _NavItem(
                      icon:     Icons.history_outlined,
                      label:    'Audit Log',
                      selected: currentPath == AppRoutes.audit,
                      onTap: () => _openAuditLogDialog(context),
                    ),
                    _NavItem(
                      icon:     Icons.phone_android_outlined,
                      label:    'Member Preview',
                      selected: currentPath == AppRoutes.preview,
                      onTap: () => context.go(AppRoutes.preview),
                    ),
                  ],
                ],
              ),
            ),
          ),

          _NavItem(
            icon:     Icons.help_outline,
            label:    'Help',
            selected: currentPath == AppRoutes.help,
            onTap: () => context.go(AppRoutes.help),
          ),

          const Divider(color: AppColors.sidebarDivider, height: 1),
          InkWell(
            onTap: () => _confirmSignOut(context),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 16),
              child: Row(
                children: [
                  Icon(Icons.logout,
                      color: AppColors.sidebarText, size: 17),
                  const SizedBox(width: 10),
                  Text('Sign Out',
                      style: AppTypography.body.copyWith(
                          color: AppColors.sidebarText, fontSize: 12.5)),
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
            borderRadius: AppRadius.cardBorderRadius),
        title: Text('Sign Out?',
            style: AppTypography.sectionHeader.copyWith(fontSize: 16)),
        content: const Text(
            'You\'ll need to sign in again to access the dashboard.',
            style: AppTypography.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.textInverted,
              shape: RoundedRectangleBorder(
                  borderRadius: AppRadius.buttonBorderRadius),
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
    margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
    decoration: BoxDecoration(
      color: selected ? AppColors.sidebarSelectedBg : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: ListTile(
        dense: true,
        leading: Icon(icon, size: 17,
            color: selected
                ? AppColors.sidebarTextActive
                : AppColors.sidebarText),
        title: Text(label,
            style: TextStyle(
                fontSize: 12.5,
                color: selected
                    ? AppColors.sidebarTextActive
                    : AppColors.sidebarText,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.normal)),
        onTap: onTap,
      ),
    ),
  );
}