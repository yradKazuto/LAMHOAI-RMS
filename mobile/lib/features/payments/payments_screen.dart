// lib/features/payments/payments_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/models/payment_model.dart';
import '../../core/models/ledger_model.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/status_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_header.dart';

class PaymentsScreen extends StatefulWidget {
  const PaymentsScreen({super.key});

  @override
  State<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _PaymentsScreenState extends State<PaymentsScreen> {
  String? _filter;

  @override
  Widget build(BuildContext context) {
    final uid  = context.watch<AuthProvider>().user?.uid ?? '';
    final name = context.watch<AuthProvider>().user?.displayName ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          AppHeader(
            title: 'Payment Records',
            subtitle: name,
            onBack: () =>
                context.canPop() ? context.pop() : context.go('/home'),
          ),
          StreamBuilder<LedgerModel?>(
            stream: FirestoreService().ledgerStream(uid),
            builder: (context, ledgerSnap) {
              final balance = ledgerSnap.data?.currentBalance;
              return Expanded(
                child: StreamBuilder<List<PaymentModel>>(
                  stream: FirestoreService().paymentsStream(uid),
                  builder: (context, snap) {
                    if (snap.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snap.hasError) {
                      return _buildError(snap.error.toString());
                    }
                    return _buildBody(snap.data ?? [], balance);
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Body ──────────────────────────────────────────────────────────────────

  Widget _buildBody(List<PaymentModel> all, double? balance) {
    double paid = 0, unpaid = 0, overdue = 0;
    for (final p in all) {
      // Use effectiveStatus (not the raw Firestore `status`) so an unpaid
      // payment whose dueDate has passed is counted as overdue here too —
      // this keeps the summary totals in sync with what each list item
      // displays via statusLabel. Waived payments are excluded from all
      // three buckets since they're neither owed nor paid.
      switch (p.effectiveStatus) {
        case PaymentStatus.paid:
          paid += p.amount;
          break;
        case PaymentStatus.overdue:
          overdue += p.amount;
          break;
        case PaymentStatus.waived:
          break;
        case PaymentStatus.unpaid:
          unpaid += p.amount;
          break;
      }
    }

    final filtered = _filter == null
        ? all
        : all.where((p) => p.statusLabel.toLowerCase() == _filter).toList();

    return SingleChildScrollView(
      child: Column(
        children: [
          if (balance != null) _buildBalanceCard(balance),
          _buildSummary(paid, unpaid, overdue),
          _buildFilterRow(),
          filtered.isEmpty ? _buildEmpty() : _buildList(filtered),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildBalanceCard(double balance) {
    final fmt = NumberFormat('#,##0.00', 'en_PH');
    return AppCard(
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text('Outstanding Balance', style: AppTypography.bodyMedium),
          Text(
            '₱${fmt.format(balance)}',
            style: AppTypography.money.copyWith(
              fontSize: 18,
              color: balance > 0 ? AppColors.danger : AppColors.success,
            ),
          ),
        ],
      ),
    );
  }

  // ── Summary ───────────────────────────────────────────────────────────────

  Widget _buildSummary(double paid, double unpaid, double overdue) {
    final fmt = NumberFormat('#,##0.00', 'en_PH');
    return AppCard(
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          _sumItem('₱${fmt.format(paid)}',    'Paid',    AppColors.success),
          _divider(),
          _sumItem('₱${fmt.format(unpaid)}',  'Unpaid',  AppColors.warning),
          _divider(),
          _sumItem('₱${fmt.format(overdue)}', 'Overdue', AppColors.danger),
        ],
      ),
    );
  }

  Widget _sumItem(String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: AppTypography.money.copyWith(color: color),
            ),
          ),
          const SizedBox(height: 3),
          Text(label, style: AppTypography.caption),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 32, color: AppColors.borderSubtle);

  // ── Filters ───────────────────────────────────────────────────────────────

  Widget _buildFilterRow() {
    final filters = {'All': null, 'Paid': 'paid', 'Unpaid': 'unpaid', 'Overdue': 'overdue'};
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
                color: active ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active ? AppColors.primary : AppColors.border,
                  width: 1.5,
                ),
              ),
              child: Text(
                e.key,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: active ? AppColors.textInverted : AppColors.textSecondary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── List ──────────────────────────────────────────────────────────────────

  Widget _buildList(List<PaymentModel> payments) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardBorderRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: payments.asMap().entries.map((e) {
          return _buildPaymentItem(e.value, e.key == payments.length - 1);
        }).toList(),
      ),
    );
  }

  Widget _buildPaymentItem(PaymentModel p, bool isLast) {
    final fmt      = NumberFormat('#,##0.00', 'en_PH');
    final dateFmt  = DateFormat('MMM d, yyyy');
    final statusS  = p.statusLabel.toLowerCase();
    final status   = StatusColors.forLabel(statusS);

    final IconData icon;
    final String dateLabel;

    if (statusS == 'paid') {
      icon = Icons.check_circle_outline;
      dateLabel =
          p.paidDate != null ? 'Paid on ${dateFmt.format(p.paidDate!)}' : 'Paid';
    } else if (statusS == 'overdue') {
      icon = Icons.error_outline;
      dateLabel = 'Overdue since ${dateFmt.format(p.dueDate)}';
    } else {
      icon = Icons.schedule;
      dateLabel = 'Due ${dateFmt.format(p.dueDate)}';
    }

    return GestureDetector(
      onTap: () => context.go('/home/payments/${p.id}'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : const Border(bottom: BorderSide(color: AppColors.borderSubtle)),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: status.bg,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Center(
                child: Icon(icon, size: 18, color: status.ink),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.type == PaymentType.dues
                        ? '${p.typeLabel} — ${DateFormat('MMMM yyyy').format(p.dueDate)}'
                        : p.typeLabel,
                    style: AppTypography.bodyMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(dateLabel, style: AppTypography.caption),
                ],
              ),
            ),
            Text(
              '₱${fmt.format(p.amount)}',
              style: AppTypography.money.copyWith(color: status.ink),
            ),
          ],
        ),
      ),
    );
  }

  // ── Empty / Error ─────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    return AppEmptyState(
      icon: Icons.receipt_long_outlined,
      message: _filter == null
          ? 'No payment records found.'
          : 'No ${_filter!} payments.',
    );
  }

  Widget _buildError(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 36, color: AppColors.danger),
            const SizedBox(height: 12),
            Text(
              msg,
              textAlign: TextAlign.center,
              style: AppTypography.body.copyWith(color: AppColors.danger),
            ),
          ],
        ),
      ),
    );
  }
}