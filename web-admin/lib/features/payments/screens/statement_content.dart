// features/payments/screens/statement_content.dart
//
// Shared statement content for the Installment Statement Preview. Used by both
// the dialog (opened from Member Detail > Payments) and the full-page route
// (/statement/:memberId). Renders actual saved data only — never recalculates
// or hardcodes anything.

import 'package:flutter/material.dart';
import '../../../core/services/sale_service.dart';
import '../../../core/models/lot_sale_model.dart';
import '../../../core/models/lot_payment_model.dart';
import '../../../core/theme/design_tokens.dart';
import '../../../core/utils/lot_pricing.dart';

/// Builds the statement body (header, account summary, down payment,
/// installment table, footer) inside [maxWidth]. Returns a Column so both the
/// dialog (ConstrainedBox + SingleChildScrollView) and the page
/// (SingleChildScrollView) can scroll it identically.
Widget installmentStatementContent({
  required BuildContext context,
  required String memberId,
  required SaleService saleService,
  double maxWidth = 600,
}) {
  return StreamBuilder<List<LotSaleModel>>(
    stream: saleService.streamAllSales(),
    builder: (context, saleSnap) {
      if (saleSnap.hasError) {
        return _errorView('Could not load sales: ${saleSnap.error}');
      }
      if (!saleSnap.hasData) {
        return const Center(child: CircularProgressIndicator());
      }

      final sales = saleSnap.data!.where((s) => s.buyerUid == memberId).toList();
      if (sales.isEmpty) {
        return const Center(child: Text('No sale found for member'));
      }
      final sale = sales.first;

      return StreamBuilder<List<LotPaymentModel>>(
        stream: saleService.streamPaymentsForSale(sale.id),
        builder: (context, paySnap) {
          if (paySnap.hasError) {
            return _errorView('Could not load payments: ${paySnap.error}');
          }
          if (!paySnap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final payments = paySnap.data!;
          if (payments.isEmpty) {
            return const Center(child: Text('No payments scheduled for this sale'));
          }

          return ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: _StatementBody(sale: sale, payments: payments),
          );
        },
      );
    },
  );
}

/// Status color for a lot payment display status.
Color _paymentStatusColor(LotPaymentStatus s) {
  switch (s) {
    case LotPaymentStatus.paid:
      return AppColors.success;
    case LotPaymentStatus.overdue:
      return AppColors.danger;
    case LotPaymentStatus.waived:
      return AppColors.textSecondary;
    case LotPaymentStatus.void_:
      return AppColors.textMuted;
    case LotPaymentStatus.scheduled:
      return AppColors.primary;
  }
}

Color _paymentStatusBg(LotPaymentStatus s) {
  switch (s) {
    case LotPaymentStatus.paid:
      return AppColors.successBg;
    case LotPaymentStatus.overdue:
      return AppColors.dangerBg;
    case LotPaymentStatus.waived:
      return AppColors.background;
    case LotPaymentStatus.void_:
      return AppColors.background;
    case LotPaymentStatus.scheduled:
      return AppColors.primaryBg;
  }
}

class _StatementBody extends StatelessWidget {
  final LotSaleModel sale;
  final List<LotPaymentModel> payments;

  const _StatementBody({required this.sale, required this.payments});

  @override
  Widget build(BuildContext context) {
    final downPayment = payments.where((p) => p.period == 0).firstOrNull;
    final installments = payments.where((p) => p.period > 0).toList()..sort((a, b) => a.period.compareTo(b.period));

    final totalDue = payments.fold<double>(0.0, (s, p) => s + p.amount);
    final totalPaid = payments
        .where((p) => p.status == LotPaymentStatus.paid)
        .fold<double>(0.0, (s, p) => s + p.amount);
    final outstanding = (totalDue - totalPaid).clamp(0.0, double.infinity);
    final statementRef = 'LSTM-${sale.saleSeq.toString().padLeft(3, '0')}';
    final now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Header ─────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(AppSpacing.space6),
          decoration: BoxDecoration(
            color: AppColors.primaryHeader,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(AppRadius.xl),
              topRight: Radius.circular(AppRadius.xl),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    child: const Icon(Icons.receipt_long_outlined,
                        color: AppColors.primary, size: 22),
                  ),
                  const Spacer(),
                  Text('INSTALLMENT STATEMENT',
                      style: const TextStyle(
                        fontFamily: AppTypography.fontFamily,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: AppColors.textInverted,
                      )),
                ],
              ),
              const SizedBox(height: AppSpacing.space6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('LAMHOAI Homeowners Association',
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textInverted,
                            )),
                        const SizedBox(height: AppSpacing.space0_5),
                        Text('Subdivision Management System',
                            style: TextStyle(
                              fontFamily: AppTypography.fontFamily,
                              fontSize: 11.5,
                              color: AppColors.primary.withValues(alpha: 0.85),
                            )),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Statement No.',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: AppColors.primary.withValues(alpha: 0.85),
                          )),
                      const SizedBox(height: AppSpacing.space0_5),
                      Text(statementRef,
                          style: const TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textInverted,
                          )),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space6),
              Divider(
                color: AppColors.primary.withValues(alpha: 0.35),
                height: 1,
              ),
              const SizedBox(height: AppSpacing.space4),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _DetailRow(
                      label: 'Member',
                      value: sale.buyerName.isEmpty ? '—' : sale.buyerName,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: _DetailRow(
                      label: 'Statement Date',
                      value: _fmtDMY(now),
                    ),
                  ),
                  Expanded(
                    child: _DetailRow(
                      label: 'Lot',
                      value:
                          '${sale.block.isNotEmpty ? 'Block ${sale.block} ' : ''}${sale.lotNumber.isNotEmpty ? 'Lot ${sale.lotNumber}' : ''}'.trim().isEmpty
                              ? '—'
                              : '${sale.block.isNotEmpty ? 'Block ${sale.block} ' : ''}${sale.lotNumber.isNotEmpty ? 'Lot ${sale.lotNumber}' : ''}'.trim(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space3),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: _DetailRow(
                      label: 'Property Location',
                      value:
                          '${sale.phase.isNotEmpty ? 'Phase ${sale.phase} ' : ''}${sale.block.isNotEmpty ? 'Block ${sale.block} ' : ''}'.trim(),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: _DetailRow(
                      label: 'Sale Type',
                      value: sale.saleType.label,
                    ),
                  ),
                  Expanded(
                    child: _DetailRow(
                      label: 'Reference',
                      value: installments.isNotEmpty ? installments.first.transactionId : '—',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.space6),

        // ── Account Summary ──────────────────────────────────────────────
        _SectionTitle('Account Summary'),
        const SizedBox(height: AppSpacing.space3),
        Row(
          children: [
            Expanded(child: _SummaryTile('Total Price', LotPricing.peso(sale.totalPrice))),
            Expanded(child: _SummaryTile('Down Payment', LotPricing.peso(sale.downPayment))),
            Expanded(child: _SummaryTile('Financed Amount', LotPricing.peso(sale.financedAmount))),
          ],
        ),
        const SizedBox(height: AppSpacing.space3),
        Row(
          children: [
            Expanded(child: _SummaryTile('Term (Months)', '${sale.termMonths}')),
            Expanded(child: _SummaryTile('Annual Interest', '${sale.annualInterestRate.toStringAsFixed(0)}%')),
            Expanded(child: _SummaryTile('Monthly Payment', LotPricing.peso(sale.monthlyPayment))),
          ],
        ),

        const SizedBox(height: AppSpacing.space6),

        // ── Down Payment ─────────────────────────────────────────────────
        _SectionTitle('Down Payment (Period 0)'),
        const SizedBox(height: AppSpacing.space3),
        Container(
          padding: const EdgeInsets.all(AppSpacing.space4),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: AppRadius.cardBorderRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: downPayment == null
              ? const Text('No down payment recorded.',
                  style: TextStyle(color: AppColors.textMuted))
              : Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Due Date',
                              style: const TextStyle(
                                  fontSize: 10.5,
                                  color: AppColors.textMuted)),
                          const SizedBox(height: AppSpacing.space0_5),
                          Text(_fmtDMY(downPayment.dueDate),
                              style: const TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text('Amount',
                              style: const TextStyle(
                                  fontSize: 10.5,
                                  color: AppColors.textMuted)),
                          const SizedBox(height: AppSpacing.space0_5),
                          Text(LotPricing.peso(downPayment.amount),
                              style: const TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary)),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.space4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _paymentStatusBg(downPayment.displayStatus),
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(downPayment.displayStatus.label,
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: _paymentStatusColor(downPayment.displayStatus))),
                    ),
                  ],
                ),
        ),

        const SizedBox(height: AppSpacing.space6),

        // ── Installment Schedule ─────────────────────────────────────────
        _SectionTitle('Monthly Installment Schedule'),
        const SizedBox(height: AppSpacing.space3),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 640;
            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: constraints.maxWidth,
                  maxWidth: compact ? 900 : double.infinity,
                ),
                child: DataTable(
                  headingRowColor: WidgetStateProperty.all(AppColors.background),
                  headingTextStyle: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMuted,
                  ),
                  dataTextStyle: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textPrimary,
                  ),
                  columns: const [
                    DataColumn(label: Text('Period')),
                    DataColumn(label: Text('Due Date')),
                    DataColumn(label: Text('Principal')),
                    DataColumn(label: Text('Interest')),
                    DataColumn(label: Text('Amount Due')),
                    DataColumn(label: Text('Balance After')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Reference')),
                  ],
                  rows: installments.map((p) {
                    return DataRow(
                      cells: [
                        DataCell(Text('${p.period}')),
                        DataCell(Text(_fmtDMY(p.dueDate))),
                        DataCell(Text(LotPricing.peso(p.principalPortion))),
                        DataCell(Text(LotPricing.peso(p.interestPortion))),
                        DataCell(Text(LotPricing.peso(p.amount),
                            style: const TextStyle(fontWeight: FontWeight.w600))),
                        DataCell(Text(LotPricing.peso(p.remainingBalance))),
                        DataCell(
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _paymentStatusBg(p.displayStatus),
                              borderRadius: BorderRadius.circular(AppRadius.full),
                            ),
                            child: Text(p.displayStatus.label,
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: _paymentStatusColor(p.displayStatus))),
                          ),
                        ),
                        DataCell(Text(p.transactionId.isEmpty ? '—' : p.transactionId,
                            style: const TextStyle(
                                fontSize: 10.5, color: AppColors.textSecondary))),
                      ],
                    );
                  }).toList(),
                ),
              ),
            );
          },
        ),

        const SizedBox(height: AppSpacing.space6),

        // ── Footer ───────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(AppSpacing.space4),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: AppRadius.cardBorderRadius,
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(child: _FooterLabel('Total Due', LotPricing.peso(totalDue))),
                  Expanded(child: _FooterLabel('Total Paid', LotPricing.peso(totalPaid))),
                  Expanded(child: _FooterLabel('Outstanding Balance', LotPricing.peso(outstanding),
                      valueColor: outstanding == 0 ? AppColors.success : AppColors.danger)),
                ],
              ),
              const SizedBox(height: AppSpacing.space4),
              Row(
                children: [
                  Expanded(
                    child: _FooterLabel('Generated', _fmtDMY(now)),
                  ),
                  Expanded(
                    child: _FooterLabel('Prepared By', 'Admin'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space4),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'This statement is for informational purposes only and is not an official receipt. '
                  'Amounts reflect actual saved payment records.',
                  style: TextStyle(
                    fontSize: 9.5,
                    color: AppColors.textMuted,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

extension FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

String _fmtDMY(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')} ${_monthName(d.month)} ${d.year}';

String _monthName(int m) {
  const names = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  return names[m - 1];
}

// Used only inside the dark navy header block, so both texts must be
// light-colored (dark text on navy is unreadable).
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style: TextStyle(
              fontSize: 10,
              color: AppColors.textInverted.withValues(alpha: 0.65))),
      const SizedBox(height: AppSpacing.space0_5),
      Text(value,
          style: const TextStyle(
              fontFamily: AppTypography.fontFamily,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColors.textInverted),
          overflow: TextOverflow.ellipsis),
    ],
  );
}

class _SummaryTile extends StatelessWidget {
  final String label;
  final String value;
  const _SummaryTile(this.label, this.value);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpacing.space4),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: AppRadius.cardBorderRadius,
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 10, color: AppColors.textMuted)),
        const SizedBox(height: AppSpacing.space0_5),
        Text(value,
            style: const TextStyle(
                fontFamily: AppTypography.fontFamily,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary),
            overflow: TextOverflow.ellipsis),
      ],
    ),
  );
}

class _FooterLabel extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;
  const _FooterLabel(this.label, this.value, {this.valueColor});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label,
          style: const TextStyle(
              fontSize: 10, color: AppColors.textMuted)),
      const SizedBox(height: AppSpacing.space0_5),
      Text(value,
          style: TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: valueColor ?? AppColors.textPrimary,
          ),
          overflow: TextOverflow.ellipsis),
    ],
  );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 4,
        height: 14,
        color: AppColors.primary,
      ),
      const SizedBox(width: AppSpacing.space1),
      Text(text,
          style: const TextStyle(
            fontFamily: AppTypography.fontFamily,
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          )),
    ],
  );
}

Widget _errorView(String message) => Center(
  child: Padding(
    padding: const EdgeInsets.all(24),
    child: Text(
      message,
      textAlign: TextAlign.center,
      style: const TextStyle(color: AppColors.danger),
    ),
  ),
);