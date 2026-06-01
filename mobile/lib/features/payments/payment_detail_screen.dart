// lib/features/payments/payment_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/models/payment_model.dart';
import '../../core/services/firestore_service.dart';

class PaymentDetailScreen extends StatelessWidget {
  final String paymentId;
  const PaymentDetailScreen({super.key, required this.paymentId});

  // ── Design tokens ─────────────────────────────────────────────────────────
  static const _blue700   = Color(0xFF1A3D6B);
  static const _blue600   = Color(0xFF1E52A0);
  static const _blue200   = Color(0xFFBAD9FD);
  static const _blue50    = Color(0xFFEFF6FF);
  static const _gray50    = Color(0xFFF8FAFC);
  static const _gray100   = Color(0xFFEEF2F7);
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
    return Scaffold(
      backgroundColor: _gray50,
      body: SafeArea(
        child: FutureBuilder<PaymentModel>(
          future: FirestoreService().getPayment(paymentId),
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return _buildError(context, snap.error.toString());
            }
            return _buildContent(context, snap.data!);
          },
        ),
      ),
    );
  }

  // ── Content ───────────────────────────────────────────────────────────────

  Widget _buildContent(BuildContext context, PaymentModel p) {
    final fmt     = NumberFormat('#,##0.00', 'en_PH');
    final dateFmt = DateFormat('MMMM d, yyyy');

    final statusColor = _statusColor(p.status);
    final statusBg    = _statusBg(p.status);
    final statusEmoji = _statusEmoji(p.status);

    return Column(
      children: [
        _buildHeader(context, p),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Amount hero
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _gray100),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Center(
                          child: Text(statusEmoji,
                              style: const TextStyle(fontSize: 22)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '₱${fmt.format(p.amount)}',
                        style: TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          p.statusLabel.toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Details card
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _gray100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                        child: Row(
                          children: const [
                            Icon(Icons.receipt_long_outlined,
                                size: 14, color: _blue600),
                            SizedBox(width: 6),
                            Text(
                              'PAYMENT DETAILS',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _blue600,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 1, color: _gray100),
                      _detailRow('Type', p.typeLabel),
                      _detailRow(
                        'Period',
                        p.type == PaymentType.monthly
                            ? DateFormat('MMMM yyyy').format(p.dueDate)
                            : DateFormat('yyyy').format(p.dueDate),
                      ),
                      _detailRow('Due Date', dateFmt.format(p.dueDate)),
                      if (p.paidDate != null)
                        _detailRow('Paid On', dateFmt.format(p.paidDate!)),
                      _detailRow('Member', p.memberName),
                      _detailRow('Reference ID', p.id,
                          mono: true, isLast: p.recordedBy == null),
                      if (p.recordedBy != null)
                        _detailRow('Recorded By', p.recordedBy!,
                            isLast: true),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Info note for pending/overdue
                if (p.status == PaymentStatus.pending ||
                    p.status == PaymentStatus.overdue)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _blue50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _blue200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(Icons.info_outline,
                            size: 15, color: _blue600),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'To settle this payment, please visit the HOA office '
                            'or contact your HOA administrator.',
                            style: TextStyle(
                                fontSize: 11,
                                color: _gray600,
                                height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, PaymentModel p) {
    return Container(
      color: _blue700,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () =>
                context.canPop() ? context.pop() : context.go('/home/payments'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.arrow_back_ios_new, size: 12, color: _blue200),
                SizedBox(width: 4),
                Text('Payments',
                    style: TextStyle(fontSize: 10, color: _blue200)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Payment Detail',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            p.type == PaymentType.monthly
                ? '${p.typeLabel} — ${DateFormat('MMMM yyyy').format(p.dueDate)}'
                : p.typeLabel,
            style: const TextStyle(fontSize: 10, color: _blue200),
          ),
        ],
      ),
    );
  }

  // ── Detail row ────────────────────────────────────────────────────────────

  Widget _detailRow(String label, String value,
      {bool mono = false, bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: _gray100)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: _gray400)),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: _gray800,
                fontFamily: mono ? 'monospace' : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Status helpers ────────────────────────────────────────────────────────

  Color _statusColor(PaymentStatus s) {
    switch (s) {
      case PaymentStatus.paid:    return _success;
      case PaymentStatus.pending: return _warning;
      case PaymentStatus.overdue: return _danger;
      default:                    return _gray600;
    }
  }

  Color _statusBg(PaymentStatus s) {
    switch (s) {
      case PaymentStatus.paid:    return _successBg;
      case PaymentStatus.pending: return _warningBg;
      case PaymentStatus.overdue: return _dangerBg;
      default:                    return _gray100;
    }
  }

  String _statusEmoji(PaymentStatus s) {
    switch (s) {
      case PaymentStatus.paid:    return '💳';
      case PaymentStatus.pending: return '⏳';
      case PaymentStatus.overdue: return '⚠️';
      default:                    return '📄';
    }
  }

  Widget _buildError(BuildContext context, String msg) {
    return Column(
      children: [
        Container(
          color: _blue700,
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => context.canPop()
                    ? context.pop()
                    : context.go('/home/payments'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.arrow_back_ios_new,
                        size: 12, color: _blue200),
                    SizedBox(width: 4),
                    Text('Back',
                        style: TextStyle(fontSize: 10, color: _blue200)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Text(msg,
                style: const TextStyle(fontSize: 12, color: _danger)),
          ),
        ),
      ],
    );
  }
}