// test/lot_balance_test.dart
//
// Covers the two pure helpers the member app derives its money views from:
// lotBalanceOwed (My Lots balance) and mergePaymentsById (buyer rows show up
// in both the uid query and the saleId query, so they must dedupe).

import 'package:flutter_test/flutter_test.dart';
import 'package:lamhoai_rms/core/models/lot_payment_model.dart';
import 'package:lamhoai_rms/core/models/payment_model.dart';
import 'package:lamhoai_rms/core/services/firestore_service.dart';

LotPaymentModel row(String id, double amount,
    {LotPaymentStatus status = LotPaymentStatus.scheduled,
    double paidAmount = 0.0,
    DateTime? dueDate}) {
  return LotPaymentModel(
    id: id,
    saleId: 'sale-1',
    lotId: 'lot-1',
    period: 1,
    transactionId: '',
    dueDate: dueDate ?? DateTime(2099),
    amount: amount,
    remainingBalance: 0,
    status: status,
    paidAmount: paidAmount,
  );
}

void main() {
  test('lotBalanceOwed counts scheduled/overdue rows minus paidAmount', () {
    final past = DateTime.now().subtract(const Duration(days: 10));
    final rows = [
      row('a', 1000),                                   // scheduled, full
      row('b', 2000, dueDate: past),                    // derived overdue
      row('c', 3000, paidAmount: 1200),                 // partial
      row('d', 4000, status: LotPaymentStatus.paid),    // excluded
      row('e', 5000, status: LotPaymentStatus.waived),  // excluded
      row('f', 6000, status: LotPaymentStatus.void_),   // excluded
    ];
    expect(lotBalanceOwed(rows), 1000 + 2000 + 1800);
  });

  test('lotBalanceOwed clamps an overpaid row to zero', () {
    expect(lotBalanceOwed([row('a', 100, paidAmount: 500)]), 0);
  });

  test('mergePaymentsById dedupes by id, first list wins', () {
    PaymentModel p(double amount) => PaymentModel(
          id: 'p1',
          memberId: 'u1',
          memberName: '',
          type: PaymentType.lotPayment,
          amount: amount,
          status: PaymentStatus.unpaid,
          dueDate: DateTime(2099),
        );

    final merged = mergePaymentsById([p(100)], [p(200)]);
    expect(merged.length, 1);
    expect(merged.single.amount, 100);
  });
}
