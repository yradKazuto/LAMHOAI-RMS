// lib/features/payments/payment_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/models/payment_model.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/status_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_header.dart';

class PaymentDetailScreen extends StatelessWidget {
  final String paymentId;
  const PaymentDetailScreen({super.key, required this.paymentId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: FutureBuilder<PaymentModel>(
        future: FirestoreService().getPayment(paymentId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Column(
              children: [
                AppHeader(title: 'Payment Detail'),
                Expanded(child: Center(child: CircularProgressIndicator())),
              ],
            );
          }
          if (snap.hasError) {
            return Column(
              children: [
                AppHeader(
                  title: 'Payment Detail',
                  onBack: () => context.canPop()
                      ? context.pop()
                      : context.go('/home/payments'),
                ),
                Expanded(child: _buildError(snap.error.toString())),
              ],
            );
          }
          return Column(
            children: [
              AppHeader(
                title: 'Payment Detail',
                subtitle: snap.data != null && snap.data!.id.isNotEmpty
                    ? (snap.data!.type == PaymentType.dues
                        ? '${snap.data!.typeLabel} — ${DateFormat('MMMM yyyy').format(snap.data!.dueDate)}'
                        : snap.data!.typeLabel)
                    : null,
                onBack: () => context.canPop()
                    ? context.pop()
                    : context.go('/home/payments'),
              ),
              Expanded(child: _buildContent(context, snap.data!)),
            ],
          );
        },
      ),
    );
  }

  // ── Content ───────────────────────────────────────────────────────────────

  Widget _buildContent(BuildContext context, PaymentModel p) {
    final fmt      = NumberFormat('#,##0.00', 'en_PH');
    final dateFmt = DateFormat('MMMM d, yyyy');
    final status   = StatusColors.forLabel(p.statusLabel.toLowerCase());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Amount hero
          AppCard(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: status.bg,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
                  child: Center(
                    child: Icon(
                      _emojiFor(p),
                      size: 22,
                      color: status.ink,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  '₱${fmt.format(p.amount)}',
                  style: AppTypography.money.copyWith(color: status.ink),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: status.bg,
                    borderRadius: BorderRadius.circular(AppRadius.full),
                  ),
                  child: Text(
                    p.statusLabel.toUpperCase(),
                    style: AppTypography.button.copyWith(
                      color: status.ink,
                      fontSize: 10,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Details card
          AppCard(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Payment details', style: AppTypography.cardTitle),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.receipt_long_outlined,
                        size: 14, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text('Type', style: AppTypography.caption),
                    const SizedBox(width: 8),
                    Text(
                      p.typeLabel,
                      style: AppTypography.bodyMedium,
                    ),
                  ],
                ),
                _row('Period', _period(p)),
                _row('Due date', dateFmt.format(p.dueDate)),
                if (p.paidDate != null)
                  _row('Paid on', dateFmt.format(p.paidDate!)),
                _row('Member', p.memberName),
                _row('Reference ID', p.id, mono: true, isLast: p.recordedBy == null),
                if (p.recordedBy != null)
                  _row('Recorded by', p.recordedBy!, isLast: true),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Info note for unpaid/overdue
          if (p.statusLabel.toLowerCase() != 'paid')
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 15, color: AppColors.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'To settle this payment, please visit the HOA office or contact your HOA administrator.',
                      style: AppTypography.body.copyWith(
                          color: AppColors.textSecondary, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(String label, String value,
      {bool mono = false, bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.label.copyWith(color: AppColors.textMuted)),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: mono
                  ? const TextStyle(fontFamily: 'monospace', fontSize: 11)
                  : AppTypography.body,
            ),
          ),
        ],
      ),
    );
  }

  String _period(PaymentModel p) {
    if (p.type == PaymentType.dues) return DateFormat('MMMM yyyy').format(p.dueDate);
    return DateFormat('yyyy').format(p.dueDate);
  }

  IconData _emojiFor(PaymentModel p) {
    switch (p.statusLabel.toLowerCase()) {
      case 'paid':
        return Icons.check_circle_outline;
      case 'overdue':
        return Icons.error_outline;
      default:
        return Icons.schedule;
    }
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
            Text(msg,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(color: AppColors.danger)),
          ],
        ),
      ),
    );
  }
}
