// features/payments/screens/membership_dues_screen.dart
//
// Annual membership fee management — separate from per-lot monthly dues
// (see payments_screen.dart for those). Lets an admin/accountant:
//   1. Generate one unpaid membership-fee record per active member for a
//      chosen year (skipping members who already have one for that year).
//   2. See, at a glance, who has/hasn't paid this year's membership fee.
//   3. Filter down to just the members who still owe it.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/member_model.dart';
import '../../../core/models/payment_model.dart';
import '../../../core/models/audit_log_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/notification_service.dart';

class MembershipDuesScreen extends StatefulWidget {
  const MembershipDuesScreen({super.key});
  @override
  State<MembershipDuesScreen> createState() => _MembershipDuesScreenState();
}

class _MembershipDuesScreenState extends State<MembershipDuesScreen> {
  final _fs       = FirestoreService();
  final _settings = SettingsService();

  int  _year          = DateTime.now().year;
  bool _unpaidOnly     = false;
  bool _generating     = false;

  static const Color _navy   = Color(0xFF0D2A5C);
  static const Color _accent = Color(0xFF2E6BE6);
  static const Color _bg     = Color(0xFFF0F4FB);

  List<int> get _yearOptions {
    final now = DateTime.now().year;
    return [for (int y = now - 3; y <= now + 1; y++) y];
  }

  Future<void> _generateDues() async {
    final settings = await _settings.getSettings();
    final amount   = settings.dues.annual;

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Generate Membership Dues',
            style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: _navy)),
        content: Text(
          'Create an unpaid ₱${amount.toStringAsFixed(2)} membership fee '
          'record for $_year for every active member who doesn\'t already '
          'have one. Members with an existing $_year record are skipped — '
          'this is safe to run more than once.',
          style: const TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _navy,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Generate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _generating = true);
    try {
      final auth   = context.read<AuthProvider>();
      final result = await _fs.generateMembershipFees(
        year:       _year,
        amount:     amount,
        recordedBy: auth.userModel?.uid ?? '',
      );

      await _settings.logAction(
        performedBy:      auth.userModel?.uid ?? '',
        performedByName:  auth.userModel?.displayName ?? '',
        action:            AuditAction.created,
        targetCollection: 'payments',
        targetId:         'membershipFee-$_year',
        description:
            'Generated $_year membership dues: ${result.created} created, '
            '${result.skipped} already existed '
            '(${result.totalActiveMembers} active members).',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.created == 0
                ? 'Nothing to generate — all active members already have a '
                  '$_year membership fee record.'
                : 'Created ${result.created} membership fee record'
                  '${result.created == 1 ? '' : 's'} for $_year. '
                  '${result.skipped} member${result.skipped == 1 ? '' : 's'} '
                  'already had one.'),
            backgroundColor: const Color(0xFF1A7A4A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating dues: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth      = context.watch<AuthProvider>();
    final canRecord = auth.isAdmin || auth.isAccountant;

    return Scaffold(
      backgroundColor: _bg,
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────────
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: _navy),
                  tooltip: 'Back to Payments',
                  onPressed: () => Navigator.pop(context),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Membership Dues',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: _navy)),
                    const SizedBox(height: 2),
                    Text('Annual association membership fee, by member',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey[600])),
                  ],
                ),
                const Spacer(),
                Container(
                  height: 42,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFD0DBEE)),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      value: _year,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF1A2B4A)),
                      icon: const Icon(Icons.expand_more, size: 18),
                      items: _yearOptions
                          .map((y) => DropdownMenuItem(
                              value: y, child: Text('$y')))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) setState(() => _year = v);
                      },
                    ),
                  ),
                ),
                if (canRecord) ...[
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _generating ? null : _generateDues,
                    icon: _generating
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.playlist_add_check, size: 18),
                    label: Text(_generating ? 'Generating...' : 'Generate Dues'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 24),

            // ── Body: join active members with this year's fee records ────
            Expanded(
              child: StreamBuilder<List<MemberModel>>(
                stream: _fs.streamMembers(),
                builder: (context, memberSnap) {
                  final allMembers = memberSnap.data ?? [];
                  final members = allMembers
                      .where((m) => m.status == MemberStatus.active)
                      .toList();

                  return StreamBuilder<List<PaymentModel>>(
                    stream: _fs.streamMembershipFeesForYear(_year),
                    builder: (context, paySnap) {
                      final payments = paySnap.data ?? [];
                      final byUid = {for (final p in payments) p.uid: p};

                      final rows = members
                          .map((m) => _DuesRow(member: m, payment: byUid[m.uid]))
                          .toList();

                      final paidCount = rows
                          .where((r) => r.payment?.status == PaymentStatus.paid)
                          .length;
                      final unpaidCount = rows.length - paidCount;
                      final totalCollected = rows
                          .where((r) => r.payment?.status == PaymentStatus.paid)
                          .fold<double>(0, (sum, r) => sum + (r.payment?.amount ?? 0));
                      final totalPending = rows
                          .where((r) => r.payment?.status != PaymentStatus.paid)
                          .fold<double>(0, (sum, r) => sum + (r.payment?.amount ?? 0));

                      final visibleRows = _unpaidOnly
                          ? rows.where((r) => r.payment?.status != PaymentStatus.paid).toList()
                          : rows;

                      final loading = memberSnap.connectionState == ConnectionState.waiting ||
                          paySnap.connectionState == ConnectionState.waiting;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ── Summary cards ──────────────────────────────
                          Row(
                            children: [
                              _SummaryCard(
                                label: 'Paid ($_year)',
                                value: '$paidCount',
                                icon: Icons.check_circle_outline,
                                color: const Color(0xFF1A7A4A),
                              ),
                              const SizedBox(width: 14),
                              _SummaryCard(
                                label: 'Unpaid / Not Generated',
                                value: '$unpaidCount',
                                icon: Icons.schedule_outlined,
                                color: const Color(0xFF7A6A1A),
                              ),
                              const SizedBox(width: 14),
                              _SummaryCard(
                                label: 'Total Collected',
                                value: '₱${totalCollected.toStringAsFixed(2)}',
                                icon: Icons.payments_outlined,
                                color: const Color(0xFF1A7A4A),
                              ),
                              const SizedBox(width: 14),
                              _SummaryCard(
                                label: 'Total Pending',
                                value: '₱${totalPending.toStringAsFixed(2)}',
                                icon: Icons.hourglass_bottom,
                                color: const Color(0xFFCC2200),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),

                          // ── Filter ─────────────────────────────────────
                          Row(
                            children: [
                              Checkbox(
                                value: _unpaidOnly,
                                activeColor: _accent,
                                onChanged: (v) =>
                                    setState(() => _unpaidOnly = v ?? false),
                              ),
                              const Text('Show unpaid / not yet generated only',
                                  style: TextStyle(
                                      fontSize: 13, color: Color(0xFF1A2B4A))),
                            ],
                          ),
                          const SizedBox(height: 10),

                          // ── Table ────────────────────────────────────────
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE0E8F4)),
                              ),
                              child: loading
                                  ? const Center(child: CircularProgressIndicator())
                                  : Column(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 20, vertical: 12),
                                          decoration: const BoxDecoration(
                                            border: Border(
                                                bottom: BorderSide(
                                                    color: Color(0xFFE0E8F4))),
                                          ),
                                          child: const Row(
                                            children: [
                                              Expanded(flex: 3, child: _TH('MEMBER')),
                                              Expanded(flex: 2, child: _TH('PHASE')),
                                              Expanded(flex: 2, child: _TH('AMOUNT')),
                                              Expanded(flex: 2, child: _TH('PAID DATE')),
                                              Expanded(flex: 2, child: _TH('STATUS')),
                                              SizedBox(width: 80),
                                            ],
                                          ),
                                        ),
                                        Expanded(
                                          child: visibleRows.isEmpty
                                              ? Center(
                                                  child: Text(
                                                    members.isEmpty
                                                        ? 'No active members found.'
                                                        : 'No members match this filter.',
                                                    style: TextStyle(
                                                        fontSize: 13,
                                                        color: Colors.grey[500]),
                                                  ),
                                                )
                                              : ListView.separated(
                                                  itemCount: visibleRows.length,
                                                  separatorBuilder: (_, __) =>
                                                      const Divider(
                                                          height: 1,
                                                          color: Color(0xFFF0F4FB)),
                                                  itemBuilder: (context, i) =>
                                                      _DuesTableRow(
                                                          row: visibleRows[i],
                                                          fs: _fs,
                                                          canRecord: canRecord),
                                                ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// A member joined with (possibly null) membership-fee payment for the
// selected year. Null payment means "not generated yet" — distinct from an
// existing record with status unpaid.
class _DuesRow {
  final MemberModel member;
  final PaymentModel? payment;
  const _DuesRow({required this.member, required this.payment});
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label, required this.value,
    required this.icon, required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E8F4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Text(value,
                    style: TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700, color: color),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _TH extends StatelessWidget {
  final String text;
  const _TH(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: Color(0xFF5A7099), letterSpacing: 0.4));
}

class _DuesTableRow extends StatefulWidget {
  final _DuesRow row;
  final FirestoreService fs;
  final bool canRecord;

  const _DuesTableRow({
    required this.row, required this.fs, required this.canRecord});

  @override
  State<_DuesTableRow> createState() => _DuesTableRowState();
}

class _DuesTableRowState extends State<_DuesTableRow> {
  final _notif = NotificationService();
  bool _marking = false;

  Color _fg(PaymentStatus? s) {
    switch (s) {
      case PaymentStatus.paid:    return const Color(0xFF1A7A4A);
      case PaymentStatus.overdue: return const Color(0xFFCC2200);
      case PaymentStatus.waived:  return const Color(0xFF5A7099);
      case PaymentStatus.unpaid:
      case null:                  return const Color(0xFF7A6A1A);
    }
  }

  Color _bgColor(PaymentStatus? s) {
    switch (s) {
      case PaymentStatus.paid:    return const Color(0xFFEAF7F0);
      case PaymentStatus.overdue: return const Color(0xFFFFF0EE);
      case PaymentStatus.waived:  return const Color(0xFFF0F4FB);
      case PaymentStatus.unpaid:
      case null:                  return const Color(0xFFFFF8E0);
    }
  }

  String _label(PaymentStatus? s) => s == null ? 'Not Generated' : s.label;

  String _fmt(DateTime? d) => d == null ? '—'
      : '${d.day.toString().padLeft(2,'0')}/'
        '${d.month.toString().padLeft(2,'0')}/${d.year}';

  Future<void> _markPaid() async {
    final payment = widget.row.payment;
    if (payment == null) return; // nothing to mark paid — not generated yet

    setState(() => _marking = true);
    try {
      await widget.fs.markPaymentPaid(payment.id);

      final result = await _notif.sendToMember(
        uid: payment.uid,
        title: 'Payment Confirmed',
        body: 'Hi ${payment.memberName}, your ₱${payment.amount.toStringAsFixed(2)} '
            '${payment.type.label} payment has been received and confirmed.',
        type: 'payment',
        extraData: {'paymentId': payment.id},
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.success
                ? 'Membership fee marked paid. Member notified.'
                : 'Marked paid, but notification failed: ${result.message}'),
            backgroundColor: result.success
                ? const Color(0xFF1A7A4A)
                : const Color(0xFF7A6A1A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error marking payment paid: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _marking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.row.payment;
    final effective = p?.displayStatus;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(widget.row.member.name,
              style: const TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w500,
                  color: Color(0xFF0D2A5C)),
              overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: Text(widget.row.member.phase,
              style: TextStyle(fontSize: 13, color: Colors.grey[700]))),
          Expanded(flex: 2, child: Text(
              p == null ? '—' : '₱${p.amount.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w600,
                  color: Color(0xFF1A2B4A)))),
          Expanded(flex: 2, child: Text(_fmt(p?.paidDate),
              style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _bgColor(effective),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(_label(effective),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: _fg(effective))),
            ),
          ),
          SizedBox(
            width: 80,
            child: (widget.canRecord && p != null &&
                    (p.status == PaymentStatus.unpaid ||
                     p.status == PaymentStatus.overdue))
                ? TextButton(
                    onPressed: _marking ? null : _markPaid,
                    style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF1A7A4A),
                        padding: EdgeInsets.zero),
                    child: _marking
                        ? const SizedBox(
                            width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Mark Paid',
                            style: TextStyle(fontSize: 12)))
                : null,
          ),
        ],
      ),
    );
  }
}