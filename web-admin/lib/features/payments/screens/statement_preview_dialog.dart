import 'package:flutter/material.dart';
import '../../../core/services/sale_service.dart';
import '../../../core/models/lot_sale_model.dart';
import '../../../core/models/lot_payment_model.dart';
import '../../../core/theme/design_tokens.dart';

class StatementPreviewDialog extends StatelessWidget {
  final String memberId;
  final SaleService _saleService = SaleService();

  StatementPreviewDialog({super.key, required this.memberId});

  static Future<void> show(BuildContext context, String memberId) {
    return showDialog(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: StatementPreviewDialog(memberId: memberId),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Statement Preview',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close, color: AppColors.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: StreamBuilder<List<LotSaleModel>>(
                  stream: _saleService.streamAllSales(),
                  builder: (context, snap) {
                    // Show stream errors instead of spinning forever — a
                    // missing permission or index used to look exactly like
                    // "still loading".
                    if (snap.hasError) {
                      return _errorView('Could not load sales: ${snap.error}');
                    }
                    if (!snap.hasData) {
                      return const Center(
                          child: CircularProgressIndicator());
                    }

                    final sales = snap.data!
                        .where((s) => s.buyerUid == memberId)
                        .toList();
                    if (sales.isEmpty) {
                      return const Center(
                          child: Text('No sale found for member'));
                    }
                    final sale = sales.first;

                    return StreamBuilder<List<LotPaymentModel>>(
                      stream: _saleService.streamPaymentsForSale(sale.id),
                      builder: (context, snap) {
                        if (snap.hasError) {
                          return _errorView(
                              'Could not load payments: ${snap.error}');
                        }
                        if (!snap.hasData) {
                          return const Center(
                              child: CircularProgressIndicator());
                        }

                        final payments = snap.data!;
                        if (payments.isEmpty) {
                          return const Center(
                              child: Text(
                                  'No payments scheduled for this sale'));
                        }
                        return ListView.separated(
                          shrinkWrap: true,
                          itemCount: payments.length,
                          separatorBuilder: (_, _) => const Divider(
                              height: 1, color: AppColors.background),
                          itemBuilder: (context, index) {
                            final p = payments[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                  'Period ${p.period} — Due: ${_fmt(p.dueDate)}'),
                              subtitle: Text(
                                'Status: ${p.status.label}'
                                '${p.transactionId.isEmpty ? '' : ' · ${p.transactionId}'}',
                              ),
                              trailing: Text(
                                  '₱${p.amount.toStringAsFixed(2)}'),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _errorView(String message) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.danger),
          ),
        ),
      );

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
}
