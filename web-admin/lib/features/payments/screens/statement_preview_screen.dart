import 'package:flutter/material.dart';
import '../../../core/services/sale_service.dart';
import '../../../core/models/lot_sale_model.dart';
import '../../../core/models/lot_payment_model.dart';
import '../../../core/theme/design_tokens.dart';

class StatementPreviewScreen extends StatelessWidget {
  final String memberId;
  final SaleService _saleService = SaleService();

  StatementPreviewScreen({super.key, required this.memberId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Statement Preview')),
      body: StreamBuilder<List<LotSaleModel>>(
        stream: _saleService.streamAllSales(),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());

          final sales = snap.data!.where((s) => s.buyerUid == memberId).toList();

          if (sales.isEmpty) {
            return const Center(child: Text('No sale found for member'));
          }

          final sale = sales.first;

          return StreamBuilder<List<LotPaymentModel>>(
            stream: _saleService.streamPaymentsForSale(sale.id),
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());

              final payments = snap.data!;
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: payments.length,
                itemBuilder: (context, index) {
                  final p = payments[index];
                  return Card(
                    child: ListTile(
                      title: Text('Period ${p.period} — Due: ${_fmt(p.dueDate)}'),
                      subtitle: Text('Status: ${p.status.name}'),
                      trailing: Text('₱${p.amount.toStringAsFixed(2)}'),
                    ),
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
