import 'package:flutter/material.dart';
import '../../../core/services/sale_service.dart';
import '../../../core/theme/design_tokens.dart';
import 'statement_content.dart';

class StatementPreviewDialog extends StatelessWidget {
  final String memberId;
  final SaleService _saleService = SaleService();

  StatementPreviewDialog({super.key, required this.memberId});

  static Future<void> show(BuildContext context, String memberId) {
    return showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: AppRadius.dialogBorderRadius),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: 700,
            maxHeight: 720,
          ),
          child: StatementPreviewDialog(memberId: memberId),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text('Installment Statement',
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
        const SizedBox(height: 12),
        Flexible(
          child: SingleChildScrollView(
            child: installmentStatementContent(
              context: context,
              memberId: memberId,
              saleService: _saleService,
              maxWidth: 700,
            ),
          ),
        ),
      ],
    );
  }
}
