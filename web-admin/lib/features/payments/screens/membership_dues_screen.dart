// features/payments/screens/membership_dues_screen.dart
//
// Dues management — handles BOTH the annual association membership fee
// and per-lot monthly dues, switched via the mode toggle at the top.
//
// IMPORTANT (listener-churn fix): the members stream and both payments
// streams are created ONCE and cached as fields, only recreated when
// _year/_month actually change — never on every rebuild. Both the
// annual and monthly bodies stay permanently mounted in an IndexedStack;
// toggling _mode only changes which one is visible, it never
// subscribes/unsubscribes a Firestore listener. Building streams inline
// in `build()` (recreating them on every setState, e.g. the unpaid-only
// checkbox) or tearing a StreamBuilder down when swapping modes both
// cause rapid Firestore listener subscribe/unsubscribe cycles, which can
// trigger a known Firestore JS SDK bug ("INTERNAL ASSERTION FAILED:
// Unexpected state", IDs ca9/b815 — firebase/firebase-js-sdk#9985).
// Keep this pattern (cached streams + IndexedStack) for any future
// screens with a similar mode toggle.
//
// Lets an admin/accountant:
//   1. Generate one unpaid dues record per active member for a chosen
//      year (annual mode) or month/year (monthly mode) — skipping members
//      who already have one for that period.
//      Monthly mode resolves the amount via RateHistoryService, so the
//      rate applied is whichever one was in effect for that month (rates
//      only change going forward — see RateHistoryService for the rule).
//   2. See, at a glance, who has/hasn't paid for the selected period.
//   3. Filter down to just the members who still owe it.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/member_model.dart';
import '../../../core/models/payment_model.dart';
import '../../../core/models/audit_log_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/rate_history_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/notification_service.dart';

enum _DuesMode { annual, monthly }

class MembershipDuesScreen extends StatefulWidget {
  const MembershipDuesScreen({super.key});
  @override
  State<MembershipDuesScreen> createState() => _MembershipDuesScreenState();
}

class _MembershipDuesScreenState extends State<MembershipDuesScreen> {
  final _fs       = FirestoreService();
  final _rateSvc  = RateHistoryService();
  final _settings = SettingsService();

  _DuesMode _mode = _DuesMode.annual;

  final _now = DateTime.now();
  late int _year  = _now.year;
  late int _month = _now.month;

  bool _unpaidOnly = false;
  bool _generating = false;

  // ── Cached streams — created once, only replaced when _year/_month ────
  // actually change (see class-level comment above for why this matters).
  late Stream<List<MemberModel>>  _membersStream;
  late Stream<List<PaymentModel>> _annualStream;
  late Stream<List<PaymentModel>> _monthlyStream;

  static const Color _navy   = Color(0xFF0D2A5C);
  static const Color _accent = Color(0xFF2E6BE6);
  static const Color _bg     = Color(0xFFF0F4FB);

  static const _monthNames = [
    'January','February','March','April','May','June',
    'July','August','September','October','November','December',
  ];

  @override
  void initState() {
    super.initState();
    _membersStream  = _fs.streamMembers();
    _annualStream   = _fs.streamMembershipFeesForYear(_year);
    _monthlyStream  = _fs.streamMonthlyDuesForMonth(_year, _month);
  }

  List<int> get _yearOptions {
    final now = DateTime.now().year;
    return [for (int y = now - 3; y <= now + 1; y++) y];
  }

  String get _periodLabel =>
      _mode == _DuesMode.annual ? '$_year' : '${_monthNames[_month - 1]} $_year';

  void _setYear(int y) {
    if (y == _year) return;
    setState(() {
      _year          = y;
      _annualStream  = _fs.streamMembershipFeesForYear(_year);
      _monthlyStream = _fs.streamMonthlyDuesForMonth(_year, _month);
    });
  }

  void _setMonth(int m) {
    if (m == _month) return;
    setState(() {
      _month         = m;
      _monthlyStream = _fs.streamMonthlyDuesForMonth(_year, _month);
    });
  }

  Future<void> _generateDues() async {
    double amount;
    if (_mode == _DuesMode.annual) {
      final settings = await _settings.getSettings();
      amount = settings.dues.annual;
    } else {
      amount = await _rateSvc.getRateForMonth(DateTime(_year, _month, 1));
      if (amount <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No monthly rate is set for $_periodLabel yet. '
                'Add one in Settings → Dues Configuration first.'),
          ),
        );
        return;
      }
    }

    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(
            _mode == _DuesMode.annual
                ? 'Generate Membership Dues'
                : 'Generate Monthly Dues',
            style: const TextStyle(
                fontSize: 16, fontWeight: FontWeight.w700, color: _navy)),
        content: Text(
          'Create an unpaid ₱${amount.toStringAsFixed(2)} '
          '${_mode == _DuesMode.annual ? 'membership fee' : 'monthly dues'} '
          'record for $_periodLabel for every active member who doesn\'t '
          'already have one. Members with an existing record for this '
          'period are skipped — this is safe to run more than once.',
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
      final auth = context.read<AuthProvider>();
      final result = _mode == _DuesMode.annual
          ? await _fs.generateMembershipFees(
              year:       _year,
              amount:     amount,
              recordedBy: auth.userModel?.uid ?? '',
            )
          : await _fs.generateMonthlyDues(
              year:       _year,
              month:      _month,
              amount:     amount,
              recordedBy: auth.userModel?.uid ?? '',
            );

      await _settings.logAction(
        performedBy:      auth.userModel?.uid ?? '',
        performedByName:  auth.userModel?.displayName ?? '',
        action:            AuditAction.created,
        targetCollection: 'payments',
        targetId: _mode == _DuesMode.annual
            ? 'membershipFee-$_year'
            : 'dues-$_year-$_month',
        description:
            'Generated $_periodLabel '
            '${_mode == _DuesMode.annual ? 'membership dues' : 'monthly dues'} '
            'at ₱${amount.toStringAsFixed(2)}: ${result.created} created, '
            '${result.skipped} already existed '
            '(${result.totalActiveMembers} active members).',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.created == 0
                ? 'Nothing to generate — all active members already have '
                  'a record for $_periodLabel.'
                : 'Created ${result.created} dues record'
                  '${result.created == 1 ? '' : 's'} for $_periodLabel. '
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
                    Text(
                        _mode == _DuesMode.annual
                            ? 'Membership Dues'
                            : 'Monthly Dues',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: _navy)),
                    const SizedBox(height: 2),
                    Text(
                        _mode == _DuesMode.annual
                            ? 'Annual association membership fee, by member'
                            : 'Per-lot monthly dues, by member',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey[600])),
                  ],
                ),
                const Spacer(),
                if (canRecord) ...[
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
            const SizedBox(height: 16),

            // ── Mode toggle + period selectors ──────────────────────────────
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFD0DBEE)),
                  ),
                  child: Row(
                    children: [
                      _ModeButton(
                        label: 'Annual',
                        selected: _mode == _DuesMode.annual,
                        // Only flips which IndexedStack child is visible —
                        // both streams stay subscribed the whole time.
                        onTap: () => setState(() => _mode = _DuesMode.annual),
                      ),
                      _ModeButton(
                        label: 'Monthly',
                        selected: _mode == _DuesMode.monthly,
                        onTap: () => setState(() => _mode = _DuesMode.monthly),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (_mode == _DuesMode.monthly) ...[
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
                        value: _month,
                        style: const TextStyle(
                            fontSize: 13, color: Color(0xFF1A2B4A)),
                        icon: const Icon(Icons.expand_more, size: 18),
                        items: List.generate(12, (i) => i + 1)
                            .map((m) => DropdownMenuItem(
                                value: m, child: Text(_monthNames[m - 1])))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) _setMonth(v);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
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
                        if (v != null) _setYear(v);
                      },
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Body: both modes stay mounted; only visibility flips ────────
            Expanded(
              child: IndexedStack(
                index: _mode == _DuesMode.annual ? 0 : 1,
                children: [
                  _DuesBody(
                    membersStream:  _membersStream,
                    paymentsStream: _annualStream,
                    periodLabel:    '$_year',
                    unpaidOnly:     _unpaidOnly,
                    onUnpaidOnlyChanged: (v) =>
                        setState(() => _unpaidOnly = v ?? false),
                    canRecord: canRecord,
                    fs:        _fs,
                    accent:    _accent,
                  ),
                  _DuesBody(
                    membersStream:  _membersStream,
                    paymentsStream: _monthlyStream,
                    periodLabel:    '${_monthNames[_month - 1]} $_year',
                    unpaidOnly:     _unpaidOnly,
                    onUnpaidOnlyChanged: (v) =>
                        setState(() => _unpaidOnly = v ?? false),
                    canRecord: canRecord,
                    fs:        _fs,
                    accent:    _accent,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Mode toggle button ───────────────────────────────────────────────────────
class _ModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  static const Color _navy = Color(0xFF0D2A5C);

  const _ModeButton({
    required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(8),
    child: Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: selected ? _navy : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Text(label,
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : Colors.grey[600])),
    ),
  );
}

// ── Shared body for one period (annual OR monthly) ──────────────────────────
// Given a members stream and a payments stream for whichever period this
// instance represents, renders the summary cards, filter, and table. Two
// instances of this are kept alive simultaneously inside an IndexedStack
// (see MembershipDuesScreen.build) so switching modes never disposes a
// StreamBuilder / cancels a Firestore listener.
class _DuesBody extends StatelessWidget {
  final Stream<List<MemberModel>>  membersStream;
  final Stream<List<PaymentModel>> paymentsStream;
  final String periodLabel;
  final bool   unpaidOnly;
  final ValueChanged<bool?> onUnpaidOnlyChanged;
  final bool   canRecord;
  final FirestoreService fs;
  final Color  accent;

  const _DuesBody({
    required this.membersStream,
    required this.paymentsStream,
    required this.periodLabel,
    required this.unpaidOnly,
    required this.onUnpaidOnlyChanged,
    required this.canRecord,
    required this.fs,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<MemberModel>>(
      stream: membersStream,
      builder: (context, memberSnap) {
        final allMembers = memberSnap.data ?? [];
        final members = allMembers
            .where((m) => m.status == MemberStatus.active)
            .toList();

        return StreamBuilder<List<PaymentModel>>(
          stream: paymentsStream,
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

            final visibleRows = unpaidOnly
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
                      label: 'Paid ($periodLabel)',
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
                      value: unpaidOnly,
                      activeColor: accent,
                      onChanged: onUnpaidOnlyChanged,
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
                                                fs: fs,
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
    );
  }
}

// A member joined with (possibly null) dues payment for the selected
// period (year, or month+year). Null payment means "not generated yet" —
// distinct from an existing record with status unpaid.
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
                ? 'Dues marked paid. Member notified.'
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