// features/lots/mylots_screen.dart
//
// The member's lots — buyer or co-owner — each with its unpaid balance,
// mirroring web-admin's statement / installments view. Read-only here;
// recording a payment from the mobile app is intentionally not in scope.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../core/models/lot_payment_model.dart';
import '../../core/models/lot_sale_model.dart';
import '../../core/models/payment_model.dart' show buildLotLabel;
import '../../core/providers/auth_provider.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/status_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_header.dart';

class MyLotsScreen extends StatelessWidget {
  const MyLotsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().user?.uid ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          AppHeader(
            title: 'My Lots',
            subtitle: 'Balance and installments',
            onBack: () => context.go('/home'),
          ),
          Expanded(
            child: StreamBuilder<List<LotSaleModel>>(
              stream: FirestoreService().salesForMemberStream(uid),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(
                      child: Text('Could not load lots: ${snap.error}',
                          style: AppTypography.caption));
                }
                final sales = snap.data ?? <LotSaleModel>[];
                if (sales.isEmpty) {
                  return _buildEmpty();
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 14),
                  itemCount: sales.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.space3),
                  itemBuilder: (context, i) =>
                      _LotCard(sale: sales[i], currentUid: uid),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.home_outlined, size: 48, color: AppColors.textMuted),
            const SizedBox(height: 10),
            Text('No lots yet',
                style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary)),
            const SizedBox(height: 4),
            Text('Lots you own as buyer or co-owner appear here.',
                style: AppTypography.caption),
          ],
        ),
      );
}

/// One lot card — lot label, unpaid balance, unpaid installment count, and
/// the sale type badge. Tapping opens the lot's installment schedule.
class _LotCard extends StatelessWidget {
  final LotSaleModel sale;
  final String currentUid;

  const _LotCard({required this.sale, required this.currentUid});

  @override
  Widget build(BuildContext context) {
    final label = buildLotLabel(
        block: sale.block, lotNumber: sale.lotNumber, phase: sale.phase);
    final isOwner = sale.buyerUid == currentUid;
    return StreamBuilder<List<LotPaymentModel>>(
      stream: FirestoreService().lotPaymentsForSalesStream([sale.id]),
      builder: (context, snap) {
        final rows = snap.data ?? <LotPaymentModel>[];
        final owed = lotBalanceOwed(rows);
        final unpaid = rows
            .where((r) {
              final s = r.effectiveStatus;
              return s == LotPaymentStatus.scheduled ||
                  s == LotPaymentStatus.overdue;
            })
            .length;
        return AppCard(
          margin: EdgeInsets.zero,
          onTap: () => context.push('/home/lots/${sale.id}'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(label,
                                style: const TextStyle(
                                  fontFamily: AppTypography.fontFamily,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                )),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isOwner ? 'Owner' : 'Co-owner',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${sale.saleType.label} • '
                          '${sale.totalPrice > 0 ? '₱${NumberFormat('#,##0.00', 'en_PH').format(sale.totalPrice)}' : '—'}',
                          style: AppTypography.caption.copyWith(
                              color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                          '₱${NumberFormat('#,##0.00', 'en_PH').format(owed)}',
                          style: const TextStyle(
                            fontFamily: AppTypography.fontFamily,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary,
                          )),
                      const SizedBox(height: 4),
                      Text(
                        unpaid == 0
                            ? 'All installments settled'
                            : '$unpaid ${unpaid == 1 ? 'installment' : 'installments'} due',
                        style: TextStyle(
                          fontSize: 12,
                          color: owed == 0
                              ? AppColors.success
                              : AppColors.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.space3),
              Row(
                children: [
                  _stat('Buyer', sale.buyerName),
                  const SizedBox(width: AppSpacing.space4),
                  if (sale.coOwnerUids.isNotEmpty)
                    _stat('Co-owners', sale.coOwnerUids.length.toString()),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _stat(String label, String value) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$label: ',
              style: AppTypography.caption.copyWith(color: AppColors.textMuted)),
          Text(value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              )),
        ],
      );
}

/// Per-lot installment schedule — one row per period (0 = down payment /
/// cash lump, 1..N = installments) with due date, amount, balance after,
/// and status.
class LotDetailScreen extends StatelessWidget {
  final String saleId;

  const LotDetailScreen({super.key, required this.saleId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          AppHeader(title: 'Installments', onBack: () => context.pop()),
          Expanded(
            child: StreamBuilder<List<LotPaymentModel>>(
              stream: FirestoreService().lotPaymentsForSalesStream([saleId]),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return Center(child: Text(snap.error.toString(),
                      style: AppTypography.caption));
                }
                final rows = (snap.data ?? <LotPaymentModel>[])
                  ..sort((a, b) => a.period.compareTo(b.period));
                if (rows.isEmpty) return _buildEmpty();
                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.space4),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) => _PeriodRow(p: rows[i]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_outlined, size: 48,
                color: AppColors.textMuted),
            const SizedBox(height: 10),
            Text('No installments yet', style: AppTypography.bodyMedium),
          ],
        ),
      );
}

class _PeriodRow extends StatelessWidget {
  final LotPaymentModel p;

  const _PeriodRow({required this.p});

  @override
  Widget build(BuildContext context) {
    final status = p.effectiveStatus;
    final colors = StatusColors.forLabel(status.label);
    final fmt = DateFormat('MMM d, yyyy');
    final isFirst = p.period == 0;
    return AppCard(
      margin: EdgeInsets.zero,
      padding: const EdgeInsets.all(AppSpacing.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(isFirst ? 'Down payment' : 'Period ${p.period}',
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  )),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: colors.bg,
                    borderRadius: BorderRadius.circular(4)),
                child: Text(status.label, style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600,
                  color: colors.ink,
                )),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Due ${fmt.format(p.dueDate)}',
                        style: AppTypography.caption.copyWith(
                            color: AppColors.textMuted)),
                    const SizedBox(height: 2),
                    Text('₱${NumberFormat('#,##0.00', 'en_PH').format(p.amount)}',
                        style: const TextStyle(
                          fontFamily: AppTypography.fontFamily,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        )),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Balance ₱${NumberFormat('#,##0.00', 'en_PH').format(p.remainingBalance)}',
                      style: AppTypography.caption.copyWith(
                          color: AppColors.textMuted)),
                  if (p.paidAt != null)
                    Text('Paid ${fmt.format(p.paidAt!)}',
                        style: AppTypography.caption.copyWith(
                            color: AppColors.success,
                            fontSize: 11)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
