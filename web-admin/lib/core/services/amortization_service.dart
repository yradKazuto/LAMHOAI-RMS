// core/services/amortization_service.dart
//
// Pure amortization math for lot installment sales. No Firestore, no UI —
// safe to unit-test in isolation.
//
//   monthlyPayment(P, annualRate, months)
//       = P * r * (1+r)^n / ((1+r)^n - 1),   r = annualRate / 12
//
// Rounding: money is kept to 2 decimals. Every intermediate principal and
// interest portion is rounded; the LAST period's principal absorbs the
// residual so the final remainingBalance is exactly 0. This keeps the
// schedule internally consistent without drift across terms.

import 'dart:math';

import '../models/lot_payment_model.dart';
import '../models/lot_sale_model.dart';
import 'transaction_id_service.dart';

class AmortizationService {
  const AmortizationService();

  /// Fixed-rate amortization monthly payment for [principal] at [annualRate]
  /// (percent per annum, e.g. 12.0 = 12%) over [months] equal installments.
  ///
  /// Returns 0 when principal <= 0 or months <= 0. A zero rate returns
  /// principal / months (flat, no interest).
  static double monthlyPayment(double principal, double annualRate, int months) {
    if (principal <= 0 || months <= 0) return 0.0;
    final r = annualRate / 100.0 / 12.0; // 12.0% p.a. -> 0.01 per month
    if (r == 0) return _round2(principal / months);
    final factor = pow(1 + r, months);
    final m = principal * r * factor / (factor - 1);
    return _round2(m);
  }

  /// Builds every payment period for [sale], starting at [firstDueDate].
  static List<LotPaymentModel> buildSchedule({
    required LotSaleModel sale,
    required DateTime firstDueDate,
    required String createdBy,
    int? saleSeq,
  }) {
    final seq = saleSeq ?? sale.saleSeq;
    final year = firstDueDate.year;

    if (sale.financedAmount <= 0 || sale.termMonths <= 0) {
      return [
        _period(
          sale: sale,
          period: 0,
          dueDate: firstDueDate,
          year: year,
          seq: seq,
          amount: sale.totalPrice,
          principal: sale.totalPrice,
          interest: 0.0,
          balanceAfter: 0.0,
          createdBy: createdBy,
        ),
      ];
    }

    final periods = <LotPaymentModel>[];
    final r = sale.annualInterestRate / 100.0 / 12.0;
    final m = monthlyPayment(sale.financedAmount, sale.annualInterestRate, sale.termMonths);
    final n = sale.termMonths;

    if (sale.downPayment > 0) {
      periods.add(_period(
        sale: sale,
        period: 0,
        dueDate: firstDueDate,
        year: year,
        seq: seq,
        amount: sale.downPayment,
        principal: sale.downPayment,
        interest: 0.0,
        balanceAfter: sale.financedAmount,
        createdBy: createdBy,
      ));
    }

    double balance = sale.financedAmount;
    for (var i = 1; i <= n; i++) {
      final due = DateTime(firstDueDate.year, firstDueDate.month + i, firstDueDate.day);
      final interest = _round2(balance * r);
      double principal;
      double amount;
      if (i == n) {
        principal = _round2(balance);
        amount = _round2(principal + interest);
      } else {
        principal = _round2(m - interest);
        amount = m;
      }
      balance = _round2(balance - principal);

      periods.add(_period(
        sale: sale,
        period: i,
        dueDate: due,
        year: year,
        seq: seq,
        amount: amount,
        principal: principal,
        interest: interest,
        balanceAfter: balance,
        createdBy: createdBy,
      ));
    }

    return periods;
  }

  static LotPaymentModel _period({
    required LotSaleModel sale,
    required int period,
    required DateTime dueDate,
    required int year,
    required int seq,
    required double amount,
    required double principal,
    required double interest,
    required double balanceAfter,
    required String createdBy,
  }) {
    return LotPaymentModel(
      saleId: sale.id,
      lotId: sale.lotId,
      period: period,
      transactionId: TransactionIdService.nextTransactionId(year, seq, period),
      dueDate: dueDate,
      amount: amount,
      principalPortion: principal,
      interestPortion: interest,
      remainingBalance: balanceAfter,
      status: LotPaymentStatus.scheduled,
      paidAt: null,
      paidBy: null,
      createdAt: DateTime.now(),
    );
  }

  static double _round2(double v) => (v * 100).round() / 100;
}
