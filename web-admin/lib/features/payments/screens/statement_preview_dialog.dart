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
    return Scaffold(
      appBar: AppBar(title: const Text('Statement Preview')),
      body: StreamBuilder<List<LotSaleModel>>(
        stream: _saleService.streamAllSales(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final sale = snap.data!.firstWhere(
            (s) => s.buyerUid == memberId,
            orElse: () => throw Exception('No sale found for member'),
          );

          return StreamBuilder<List<LotPaymentModel>>(
            stream: _saleService.streamPaymentsForSale(sale.id),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());

              final payments = snap.data!;
              return ListView.builder(
                itemCount: payments.length,
                itemBuilder: (context, index) {
                  final p = payments[index];
                  return ListTile(
                    title: Text('Period ${p.period} — Due: ${_fmt(p.dueDate)}'),
                    subtitle: Text('Status: ${p.status.name}'),
                    trailing: Text('₱${p.amount.toStringAsFixed(2)}'),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _fmt(DateTime d) => '${d.day}/${d.month}/${d.year}';
}
