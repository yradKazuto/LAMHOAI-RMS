// features/payments/screens/payments_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/payment_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/notification_service.dart';
import 'add_payment_screen.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_router.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});
  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  final _fs     = FirestoreService();
  final _search = TextEditingController();
  final _notif  = NotificationService();

  bool _sendingReminders = false;

  String         _searchQuery  = '';
  PaymentStatus? _statusFilter;
  PaymentType?   _typeFilter;

  static const Color _navy   = Color(0xFF0D2A5C);
  static const Color _accent = Color(0xFF2E6BE6);
  static const Color _bg     = Color(0xFFF0F4FB);

  @override
  void dispose() { _search.dispose(); super.dispose(); }

  List<PaymentModel> _filtered(List<PaymentModel> all) {
    return all.where((p) {
      final q = _searchQuery.toLowerCase();
      final matchSearch = q.isEmpty ||
          p.memberName.toLowerCase().contains(q) ||
          p.type.label.toLowerCase().contains(q);
      final matchStatus = _statusFilter == null || p.status == _statusFilter;
      final matchType   = _typeFilter   == null || p.type   == _typeFilter;
      return matchSearch && matchStatus && matchType;
    }).toList();
  }

  // Summary totals
  Map<String, double> _totals(List<PaymentModel> list) {
    double totalCollected = 0, totalPending = 0, totalOverdue = 0;
    for (final p in list) {
      if (p.status == PaymentStatus.paid)    totalCollected += p.amount;
      if (p.status == PaymentStatus.unpaid)  totalPending   += p.amount;
      if (p.status == PaymentStatus.overdue) totalOverdue   += p.amount;
    }
    return {
      'collected': totalCollected,
      'pending':   totalPending,
      'overdue':   totalOverdue,
    };
  }

  Future<void> _sendDuesReminders() async {
    final days = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: const Text('Send Dues Reminder',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0D2A5C))),
        content: const Text(
            'Notify members whose unpaid dues are coming up within:',
            style: TextStyle(fontSize: 13.5)),
        actions: [
          for (final d in [1, 3, 7, 14])
            TextButton(
              onPressed: () => Navigator.pop(context, d),
              child: Text('$d day${d == 1 ? '' : 's'}'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context, null),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );

    if (days == null) return;

    setState(() => _sendingReminders = true);
    final result = await _notif.sendDuesReminders(daysAhead: days);
    if (mounted) {
      setState(() => _sendingReminders = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.message),
          backgroundColor: result.success
              ? const Color(0xFF1A7A4A)
              : const Color(0xFFCC2200),
        ),
      );
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
            // ── Header ───────────────────────────────────────────────────────
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: _navy),
                  tooltip: 'Back to Dashboard',
                  onPressed: () => context.go(AppRoutes.dashboard),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Payments',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: _navy)),
                    const SizedBox(height: 2),
                    Text('Track dues and payment records',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey[600])),
                  ],
                ),
                const Spacer(),
                if (canRecord) ...[
                  OutlinedButton.icon(
                    onPressed: _sendingReminders ? null : _sendDuesReminders,
                    icon: _sendingReminders
                        ? const SizedBox(
                            width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.notifications_active_outlined,
                            size: 18),
                    label: Text(
                        _sendingReminders ? 'Sending...' : 'Send Dues Reminder'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _navy,
                      side: const BorderSide(color: _navy),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AddPaymentScreen()),
                    ),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Record Payment'),
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

            // ── Summary cards ─────────────────────────────────────────────────
            StreamBuilder<List<PaymentModel>>(
              stream: _fs.streamPayments(),
              builder: (context, snap) {
                final all    = snap.data ?? [];
                final totals = _totals(all);
                return Row(
                  children: [
                    _SummaryCard(
                      label: 'Total Collected',
                      amount: totals['collected']!,
                      icon: Icons.check_circle_outline,
                      color: const Color(0xFF1A7A4A),
                    ),
                    const SizedBox(width: 14),
                    _SummaryCard(
                      label: 'Pending',
                      amount: totals['pending']!,
                      icon: Icons.schedule_outlined,
                      color: const Color(0xFF7A6A1A),
                    ),
                    const SizedBox(width: 14),
                    _SummaryCard(
                      label: 'Overdue',
                      amount: totals['overdue']!,
                      icon: Icons.warning_amber_outlined,
                      color: const Color(0xFFCC2200),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 20),

            // ── Filters ───────────────────────────────────────────────────────
            Row(
              children: [
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _search,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: _searchDec('Search member or type...'),
                  ),
                ),
                const SizedBox(width: 12),
                _FilterDrop<PaymentStatus?>(
                  value: _statusFilter,
                  hint: 'All Statuses',
                  items: const [null, ...PaymentStatus.values],
                  labelOf: (v) => v == null ? 'All Statuses' : v.label,
                  onChanged: (v) => setState(() => _statusFilter = v),
                ),
                const SizedBox(width: 12),
                _FilterDrop<PaymentType?>(
                  value: _typeFilter,
                  hint: 'All Types',
                  items: const [null, ...PaymentType.values],
                  labelOf: (v) => v == null ? 'All Types' : v.label,
                  onChanged: (v) => setState(() => _typeFilter = v),
                ),
                if (_searchQuery.isNotEmpty ||
                    _statusFilter != null ||
                    _typeFilter != null) ...[
                  const SizedBox(width: 10),
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _search.clear();
                      _searchQuery = '';
                      _statusFilter = null;
                      _typeFilter = null;
                    }),
                    icon: const Icon(Icons.clear, size: 15),
                    label: const Text('Clear'),
                    style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[600]),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // ── Table ─────────────────────────────────────────────────────────
            Expanded(
              child: StreamBuilder<List<PaymentModel>>(
                stream: _fs.streamPayments(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final payments = _filtered(snap.data ?? []);

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE0E8F4)),
                    ),
                    child: Column(
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 14),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF7F9FC),
                            borderRadius: BorderRadius.vertical(
                                top: Radius.circular(12)),
                          ),
                          child: const Row(
                            children: [
                              Expanded(flex: 3, child: _TH('Member')),
                              Expanded(flex: 2, child: _TH('Type')),
                              Expanded(flex: 2, child: _TH('Amount')),
                              Expanded(flex: 2, child: _TH('Due Date')),
                              Expanded(flex: 2, child: _TH('Paid Date')),
                              Expanded(flex: 2, child: _TH('Status')),
                              SizedBox(width: 80),
                            ],
                          ),
                        ),
                        const Divider(height: 1, color: Color(0xFFE0E8F4)),

                        if (payments.isEmpty)
                          const Expanded(
                            child: Center(
                              child: Text('No payment records found.',
                                  style: TextStyle(color: Colors.grey)),
                            ),
                          )
                        else
                          Expanded(
                            child: ListView.separated(
                              itemCount: payments.length,
                              separatorBuilder: (_, __) => const Divider(
                                  height: 1, color: Color(0xFFEEF2F9)),
                              itemBuilder: (_, i) => _PaymentTableRow(
                                  payment: payments[i],
                                  fs: _fs,
                                  canRecord: canRecord),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _searchDec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
    prefixIcon: const Icon(Icons.search, size: 18),
    filled: true, fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD0DBEE))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD0DBEE))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF2E6BE6), width: 1.5)),
  );
}

// ── Summary card ──────────────────────────────────────────────────────────────
class _SummaryCard extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;

  const _SummaryCard({
    required this.label, required this.amount,
    required this.icon, required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E8F4)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey[600])),
              const SizedBox(height: 3),
              Text('₱${amount.toStringAsFixed(2)}',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ],
          ),
        ],
      ),
    ),
  );
}

// ── Payment table row ─────────────────────────────────────────────────────────
class _PaymentTableRow extends StatefulWidget {
  final PaymentModel payment;
  final FirestoreService fs;
  final bool canRecord;

  const _PaymentTableRow({
    required this.payment, required this.fs, required this.canRecord});

  @override
  State<_PaymentTableRow> createState() => _PaymentTableRowState();
}

class _PaymentTableRowState extends State<_PaymentTableRow> {
  final _notif = NotificationService();
  bool _marking = false;

  Color _fg(PaymentStatus s) {
    switch (s) {
      case PaymentStatus.paid:    return const Color(0xFF1A7A4A);
      case PaymentStatus.unpaid:  return const Color(0xFF7A6A1A);
      case PaymentStatus.overdue: return const Color(0xFFCC2200);
      case PaymentStatus.waived:  return const Color(0xFF5A7099);
    }
  }

  Color _bg(PaymentStatus s) {
    switch (s) {
      case PaymentStatus.paid:    return const Color(0xFFEAF7F0);
      case PaymentStatus.unpaid:  return const Color(0xFFFFF8E0);
      case PaymentStatus.overdue: return const Color(0xFFFFF0EE);
      case PaymentStatus.waived:  return const Color(0xFFF0F4FB);
    }
  }

  String _fmt(DateTime? d) => d == null ? '—'
      : '${d.day.toString().padLeft(2,'0')}/'
        '${d.month.toString().padLeft(2,'0')}/${d.year}';

  Future<void> _markPaid() async {
    setState(() => _marking = true);
    final payment = widget.payment;

    try {
      await widget.fs.markPaymentPaid(payment.id);

      // Notify the member their payment was confirmed. Fire this after
      // the Firestore update succeeds, so a failed/slow push never
      // blocks or misrepresents the actual payment record.
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
                ? 'Payment marked paid. Member notified.'
                : 'Payment marked paid, but notification failed: ${result.message}'),
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
    final payment = widget.payment;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(payment.memberName,
              style: const TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w500,
                  color: Color(0xFF0D2A5C)),
              overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: Text(payment.type.label,
              style: TextStyle(fontSize: 13, color: Colors.grey[700]))),
          Expanded(flex: 2, child: Text(
              '₱${payment.amount.toStringAsFixed(2)}',
              style: const TextStyle(
                  fontSize: 13.5, fontWeight: FontWeight.w600,
                  color: Color(0xFF1A2B4A)))),
          Expanded(flex: 2, child: Text(_fmt(payment.dueDate),
              style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
          Expanded(flex: 2, child: Text(_fmt(payment.paidDate),
              style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _bg(payment.status),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(payment.status.label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: _fg(payment.status))),
            ),
          ),
          SizedBox(
            width: 80,
            child: (widget.canRecord &&
                    (payment.status == PaymentStatus.unpaid ||
                     payment.status == PaymentStatus.overdue))
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

class _TH extends StatelessWidget {
  final String text;
  const _TH(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: Color(0xFF5A7099), letterSpacing: 0.4));
}

class _FilterDrop<T> extends StatelessWidget {
  final T value;
  final String hint;
  final List<T> items;
  final String Function(T) labelOf;
  final void Function(T) onChanged;

  const _FilterDrop({
    required this.value, required this.hint,
    required this.items, required this.labelOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
    height: 42,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFD0DBEE)),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<T>(
        value: value,
        hint: Text(hint,
            style: TextStyle(fontSize: 13, color: Colors.grey[500])),
        style: const TextStyle(
            fontSize: 13, color: Color(0xFF1A2B4A)),
        icon: const Icon(Icons.expand_more, size: 18),
        items: items.map((i) => DropdownMenuItem<T>(
            value: i, child: Text(labelOf(i)))).toList(),
        onChanged: (v) => onChanged(v as T),
      ),
    ),
  );
}