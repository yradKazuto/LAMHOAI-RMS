// features/payments/screens/member_installments_section.dart
//
// Shows a member's lot-installment records, rendered at the top of the member
// payments dialog in payments_screen.dart:
//   • the NEXT THREE unpaid periods (from `lot_payments`) with a one-click
//     "Mark Paid" on each, and
//   • the PAID history for the sale — the down payment (period 0) and every
//     period that has been marked paid — newest first.
//
// Nothing is generated here — the full amortization schedule already exists
// from SaleService.recordSale. This only picks the first three unpaid
// periods, so when Period 1 is paid, Period 4 slides into view by itself and
// Period 1 moves into the Paid list.
//
// Listener-churn rule (same as membership_dues_screen.dart): every stream
// is created ONCE in initState and cached, never inside build().

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/lot_payment_model.dart';
import '../../../core/models/lot_sale_model.dart';
import '../../../core/models/payment_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/sale_service.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/lot_pricing.dart';

/// How many upcoming unpaid periods to show per sale.
const int _kUpcomingPeriods = 3;

class MemberInstallmentsSection extends StatefulWidget {
  final String uid;
  final bool canRecord;

  const MemberInstallmentsSection({
    super.key,
    required this.uid,
    required this.canRecord,
  });

  @override
  State<MemberInstallmentsSection> createState() =>
      _MemberInstallmentsSectionState();
}

class _MemberInstallmentsSectionState extends State<MemberInstallmentsSection> {
  final _saleService = SaleService();
  late final Stream<List<LotSaleModel>> _salesStream;

  @override
  void initState() {
    super.initState();
    _salesStream = _saleService.streamSalesForBuyer(widget.uid);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LotSaleModel>>(
      stream: _salesStream,
      builder: (context, snap) {
        // Only active installment sales have periods left to pay.
        final sales = (snap.data ?? const <LotSaleModel>[])
            .where((s) =>
                s.status == LotSaleStatus.active && s.termMonths > 0)
            .toList();
        if (sales.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Lot Installments',
                  style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              for (final sale in sales)
                _SaleInstallments(
                  key: ValueKey(sale.id),
                  sale: sale,
                  canRecord: widget.canRecord,
                  saleService: _saleService,
                ),
            ],
          ),
        );
      },
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// One sale (one lot) → its next three unpaid periods + paid history
// ═════════════════════════════════════════════════════════════════════════════
class _SaleInstallments extends StatefulWidget {
  final LotSaleModel sale;
  final bool canRecord;
  final SaleService saleService;

  const _SaleInstallments({
    super.key,
    required this.sale,
    required this.canRecord,
    required this.saleService,
  });

  @override
  State<_SaleInstallments> createState() => _SaleInstallmentsState();
}

class _SaleInstallmentsState extends State<_SaleInstallments> {
  final _notif = NotificationService();
  late final Stream<List<LotPaymentModel>> _paymentsStream;
  int? _busyPeriod;

  @override
  void initState() {
    super.initState();
    _paymentsStream =
        widget.saleService.streamPaymentsForSale(widget.sale.id);
  }

  String get _lotLabel {
    final s = widget.sale;
    // buildLotLabel adds "Block"/"Lot" itself; the phase is stored already
    // worded (e.g. "Phase 1"), so don't prefix it again.
    final label = buildLotLabel(
        block: s.block, lotNumber: s.lotNumber, phase: s.phase);
    return label.isEmpty ? 'Lot' : label;
  }

  /// Period 0 is the down payment; everything after is a monthly period.
  String _periodLabel(LotPaymentModel p) =>
      p.period == 0 ? 'Down payment' : 'Period ${p.period}';

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  Color _fg(LotPaymentStatus s) {
    switch (s) {
      case LotPaymentStatus.paid:      return AppColors.success;
      case LotPaymentStatus.overdue:   return AppColors.danger;
      case LotPaymentStatus.waived:    return AppColors.textSecondary;
      case LotPaymentStatus.void_:     return AppColors.textSecondary;
      case LotPaymentStatus.scheduled: return AppColors.warning;
    }
  }

  Color _bg(LotPaymentStatus s) {
    switch (s) {
      case LotPaymentStatus.paid:      return AppColors.successBg;
      case LotPaymentStatus.overdue:   return AppColors.dangerBg;
      case LotPaymentStatus.waived:    return AppColors.background;
      case LotPaymentStatus.void_:     return AppColors.background;
      case LotPaymentStatus.scheduled: return AppColors.warningBg;
    }
  }

  String _methodLabel(PaymentMethod m) {
    switch (m) {
      case PaymentMethod.cash:   return 'Cash';
      case PaymentMethod.cheque: return 'Cheque';
      case PaymentMethod.bank:   return 'Bank transfer';
    }
  }

  Future<void> _markPaid(LotPaymentModel p) async {
    // Confirm + payment method. Pops with the DIALOG's own context.
    final method = await showDialog<PaymentMethod>(
      context: context,
      builder: (dialogContext) {
        var selected = PaymentMethod.cash;
        return StatefulBuilder(
          builder: (_, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            title: Text('Mark ${_periodLabel(p)} paid'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${LotPricing.peso(p.amount)} · due ${_fmt(p.dueDate)}',
                  style: const TextStyle(fontSize: 13.5),
                ),
                const SizedBox(height: 12),
                const Text('Payment method',
                    style: TextStyle(
                        fontSize: 11.5, color: AppColors.textSecondary)),
                DropdownButton<PaymentMethod>(
                  value: selected,
                  isExpanded: true,
                  items: PaymentMethod.values
                      .map((m) => DropdownMenuItem(
                          value: m, child: Text(_methodLabel(m))))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selected = v);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, null),
                child: const Text('Cancel',
                    style: TextStyle(color: AppColors.textMuted)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, selected),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.textPrimary,
                  foregroundColor: AppColors.textInverted,
                ),
                child: const Text('Mark Paid'),
              ),
            ],
          ),
        );
      },
    );

    if (method == null || !mounted) return;

    setState(() => _busyPeriod = p.period);
    try {
      final auth = context.read<AuthProvider>();
      await widget.saleService.markInstallmentPaid(
        saleId: widget.sale.id,
        period: p.period,
        payer: widget.sale.buyerName,
        paidBy: auth.userModel?.uid ?? '',
        method: method,
      );

      // Notify the member AFTER the record is saved, so a failed push never
      // blocks or misrepresents the payment itself.
      String? notifyError;
      try {
        final result = await _notif.sendToMember(
          uid: widget.sale.buyerUid,
          title: 'Payment Confirmed',
          body: 'Hi ${widget.sale.buyerName}, your '
              '${LotPricing.peso(p.amount)} lot '
              '${p.period == 0 ? 'down payment' : 'installment'} '
              '(${_periodLabel(p)}, $_lotLabel) has been received and '
              'confirmed.',
          type: 'payment',
          extraData: {
            'saleId': widget.sale.id,
            'period': '${p.period}',
          },
        );
        if (!result.success) notifyError = result.message;
      } catch (e) {
        notifyError = '$e';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(notifyError == null
                ? '${_periodLabel(p)} marked paid. Member notified.'
                : '${_periodLabel(p)} marked paid, but notification '
                  'failed: $notifyError'),
            backgroundColor:
                notifyError == null ? AppColors.success : AppColors.warning,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error marking period paid: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busyPeriod = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.textInverted,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: StreamBuilder<List<LotPaymentModel>>(
        stream: _paymentsStream,
        builder: (context, snap) {
          if (snap.hasError) {
            return Padding(
              padding: const EdgeInsets.all(12),
              child: Text('Could not load installments: ${snap.error}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.danger)),
            );
          }
          if (!snap.hasData) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            );
          }

          // Already sorted by period by streamPaymentsForSale. Unpaid =
          // anything still owed; skip zero-amount rows (no down payment).
          final unpaid = snap.data!
              .where((p) =>
                  p.status != LotPaymentStatus.paid &&
                  p.status != LotPaymentStatus.waived &&
                  p.status != LotPaymentStatus.void_ &&
                  p.amount > 0)
              .toList();
          final next = unpaid.take(_kUpcomingPeriods).toList();

          // Paid history: the down payment (period 0) + every period marked
          // paid, newest period first.
          final paid = snap.data!
              .where((p) =>
                  p.status == LotPaymentStatus.paid && p.amount > 0)
              .toList()
            ..sort((a, b) => b.period.compareTo(a.period));

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(_lotLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary)),
                    ),
                    Text('${unpaid.length} left',
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.textMuted)),
                  ],
                ),
              ),
              if (next.isEmpty)
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Text('No unpaid installments.',
                      style: TextStyle(
                          fontSize: 12, color: AppColors.textMuted)),
                )
              else
                for (final p in next) ...[
                  const Divider(height: 1, color: AppColors.background),
                  _periodRow(p),
                ],

              // ── Paid history ────────────────────────────────────────────
              if (paid.isNotEmpty) ...[
                const Divider(height: 1, color: AppColors.border),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Text('Paid (${paid.length})',
                      style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                ),
                // Not a scroller of its own: every host (the member payments
                // dialog, the member Payments tab) already scrolls, and a
                // capped inner list clipped rows under the "Paid" header.
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: paid.length,
                  separatorBuilder: (_, __) => const Divider(
                      height: 1, color: AppColors.background),
                  itemBuilder: (_, i) => _paidRow(paid[i]),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _paidRow(LotPaymentModel p) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_periodLabel(p),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                Text('Due ${_fmt(p.dueDate)}',
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.textMuted)),
              ],
            ),
          ),
          Text(LotPricing.peso(p.amount),
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _bg(LotPaymentStatus.paid),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Paid',
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: _fg(LotPaymentStatus.paid))),
          ),
        ],
      ),
    );
  }

  Widget _periodRow(LotPaymentModel p) {
    final status = p.displayStatus;
    final busy = _busyPeriod == p.period;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_periodLabel(p),
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
                Text('Due ${_fmt(p.dueDate)}',
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColors.textMuted)),
              ],
            ),
          ),
          Text(LotPricing.peso(p.amount),
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: _bg(status),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(status.label,
                style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: _fg(status))),
          ),
          if (widget.canRecord) ...[
            const SizedBox(width: 6),
            TextButton(
              onPressed: busy ? null : () => _markPaid(p),
              style: TextButton.styleFrom(
                  foregroundColor: AppColors.success,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Mark Paid',
                      style: TextStyle(fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }
}