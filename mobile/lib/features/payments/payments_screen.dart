// lib/features/payments/payments_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/models/payment_model.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/firestore_service.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  PaymentStatus? _filter; // null = All

  // ── Design tokens ─────────────────────────────────────────────────────────
  static const _blue700   = Color(0xFF1A3D6B);
  static const _blue600   = Color(0xFF1E52A0);
  static const _blue200   = Color(0xFFBAD9FD);
  static const _gray50    = Color(0xFFF8FAFC);
  static const _gray100   = Color(0xFFEEF2F7);
  static const _gray200   = Color(0xFFD4DCE8);
  static const _gray400   = Color(0xFF8A9BB0);
  static const _gray600   = Color(0xFF4A5A6E);
  static const _gray800   = Color(0xFF1E2A3A);
  static const _success   = Color(0xFF16A34A);
  static const _successBg = Color(0xFFDCFCE7);
  static const _warning   = Color(0xFFB45309);
  static const _warningBg = Color(0xFFFEF9C3);
  static const _danger    = Color(0xFFDC2626);
  static const _dangerBg  = Color(0xFFFEE2E2);

  @override
  Widget build(BuildContext context) {
    final auth    = context.watch<AuthProvider>();
    final uid     = auth.user?.uid ?? '';
    final lotInfo = '${auth.user?.displayName ?? ''}';

    return Scaffold(
      backgroundColor: _gray50,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, auth),
            Expanded(
              child: StreamBuilder<List<PaymentModel>>(
                stream: FirestoreService().paymentsStream(uid),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return _buildError(snap.error.toString());
                  }
                  final all = snap.data ?? [];
                  return _buildBody(all);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, AuthProvider auth) {
    return Container(
      color: _blue700,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Back button
          GestureDetector(
            onTap: () => context.canPop() ? context.pop() : context.go('/home'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.arrow_back_ios_new, size: 12, color: _blue200),
                SizedBox(width: 4),
                Text('Back',
                    style: TextStyle(fontSize: 10, color: _blue200)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Payment Records',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            auth.user?.displayName ?? '',
            style: const TextStyle(fontSize: 10, color: _blue200),
          ),
        ],
      ),
    );
  }

  // ── Body ──────────────────────────────────────────────────────────────────

  Widget _buildBody(List<PaymentModel> all) {
    // Summary totals
    double totalPaid    = 0;
    double totalPending = 0;
    double totalOverdue = 0;
    for (final p in all) {
      if (p.status == PaymentStatus.paid)    totalPaid    += p.amount;
      if (p.status == PaymentStatus.pending) totalPending += p.amount;
      if (p.status == PaymentStatus.overdue) totalOverdue += p.amount;
    }

    // Filter
    final filtered = _filter == null
        ? all
        : all.where((p) => p.status == _filter).toList();

    return SingleChildScrollView(
      child: Column(
        children: [
          _buildSummary(totalPaid, totalPending, totalOverdue),
          _buildFilterRow(),
          if (filtered.isEmpty)
            _buildEmpty()
          else
            _buildList(filtered),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Summary card ──────────────────────────────────────────────────────────

  Widget _buildSummary(double paid, double pending, double overdue) {
    final fmt = NumberFormat('#,##0.00', 'en_PH');
    return Container(
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gray100),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E2A3A).withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _sumItem('₱${fmt.format(paid)}',    'PAID',    _success),
          _divider(),
          _sumItem('₱${fmt.format(pending)}', 'PENDING', _warning),
          _divider(),
          _sumItem('₱${fmt.format(overdue)}', 'OVERDUE', _danger),
        ],
      ),
    );
  }

  Widget _sumItem(String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              )),
          const SizedBox(height: 3),
          Text(label,
              style: const TextStyle(
                fontSize: 9,
                color: _gray400,
                letterSpacing: 0.5,
              )),
        ],
      ),
    );
  }

  Widget _divider() => Container(
      width: 1, height: 32, color: _gray100);

  // ── Filter row ────────────────────────────────────────────────────────────

  Widget _buildFilterRow() {
    final filters = <String, PaymentStatus?>{
      'All': null,
      'Paid': PaymentStatus.paid,
      'Pending': PaymentStatus.pending,
      'Overdue': PaymentStatus.overdue,
    };

    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: filters.entries.map((e) {
          final active = _filter == e.value;
          return GestureDetector(
            onTap: () => setState(() => _filter = e.value),
            child: Container(
              margin: const EdgeInsets.only(right: 6, bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: active ? _blue600 : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active ? _blue600 : _gray200,
                  width: 1.5,
                ),
              ),
              child: Text(
                e.key,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: active ? Colors.white : _gray600,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Payment list ──────────────────────────────────────────────────────────

  Widget _buildList(List<PaymentModel> payments) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gray100),
      ),
      child: Column(
        children: payments.asMap().entries.map((e) {
          final isLast = e.key == payments.length - 1;
          return _buildPaymentItem(e.value, isLast);
        }).toList(),
      ),
    );
  }

  Widget _buildPaymentItem(PaymentModel p, bool isLast) {
    final fmt = NumberFormat('#,##0.00', 'en_PH');
    final dateFmt = DateFormat('MMM d, yyyy');

    Color iconBg;
    String emoji;
    Color amountColor;
    String dateLabel;

    switch (p.status) {
      case PaymentStatus.paid:
        iconBg = _successBg;
        emoji = '💳';
        amountColor = _success;
        dateLabel = p.paidDate != null
            ? 'Paid on ${dateFmt.format(p.paidDate!)}'
            : 'Paid';
        break;
      case PaymentStatus.pending:
        iconBg = _warningBg;
        emoji = '⏳';
        amountColor = _warning;
        dateLabel = 'Due ${dateFmt.format(p.dueDate)}';
        break;
      case PaymentStatus.overdue:
        iconBg = _dangerBg;
        emoji = '⚠️';
        amountColor = _danger;
        dateLabel = 'Overdue since ${dateFmt.format(p.dueDate)}';
        break;
      default:
        iconBg = _gray100;
        emoji = '📄';
        amountColor = _gray600;
        dateLabel = dateFmt.format(p.dueDate);
    }

    return GestureDetector(
      onTap: () => context.go('/home/payments/${p.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(
                  bottom: BorderSide(color: _gray100)),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                  child: Text(emoji,
                      style: const TextStyle(fontSize: 16))),
            ),
            const SizedBox(width: 10),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.type == PaymentType.monthly
                        ? '${p.typeLabel} — ${DateFormat('MMMM yyyy').format(p.dueDate)}'
                        : p.typeLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _gray800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(dateLabel,
                      style: const TextStyle(
                          fontSize: 10, color: _gray400)),
                ],
              ),
            ),
            // Amount
            Text(
              '₱${fmt.format(p.amount)}',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: amountColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty state ───────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          const Text('📭', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 12),
          Text(
            _filter == null
                ? 'No payment records found.'
                : 'No ${_filter!.name} payments.',
            style: const TextStyle(fontSize: 12, color: _gray400),
          ),
        ],
      ),
    );
  }

  // ── Error state ───────────────────────────────────────────────────────────

  Widget _buildError(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(msg,
            style: const TextStyle(fontSize: 12, color: _danger)),
      ),
    );
  }
}