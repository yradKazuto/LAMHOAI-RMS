import 'package:flutter/material.dart';
import '../../../core/services/sale_service.dart';
import 'statement_content.dart';

class StatementPreviewScreen extends StatelessWidget {
  final String memberId;
  final SaleService _saleService = SaleService();

  StatementPreviewScreen({super.key, required this.memberId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Installment Statement')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: installmentStatementContent(
            context: context,
            memberId: memberId,
            saleService: _saleService,
            maxWidth: 700,
          ),
        ),
      ),
    );
  }
}
