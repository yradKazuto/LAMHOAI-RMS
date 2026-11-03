import 'package:flutter_test/flutter_test.dart';
import 'package:lamhoai_admin/core/models/payment_model.dart';
import 'package:lamhoai_admin/core/services/transaction_id_service.dart';

void main() {
  group('nextTransactionId', () {
    test('formats LP-{year}-{seq3}-{period3}', () {
      expect(TransactionIdService.nextTransactionId(2026, 1, 7),
          'LP-2026-001-007');
    });

    test('pads sequence and period to 3 digits', () {
      expect(TransactionIdService.nextTransactionId(2026, 100, 0),
          'LP-2026-100-000');
      expect(TransactionIdService.nextTransactionId(2025, 5, 12),
          'LP-2025-005-012');
      expect(TransactionIdService.nextTransactionId(2026, 999, 999),
          'LP-2026-999-999');
    });

    test('year is 4 digits', () {
      expect(TransactionIdService.nextTransactionId(2025, 1, 1),
          startsWith('LP-2025-'));
    });
  });

  group('prefixFor', () {
    test('maps each payment type to its prefix', () {
      expect(TransactionIdService.prefixFor(PaymentType.dues), 'MD');
      expect(TransactionIdService.prefixFor(PaymentType.membershipFee), 'MF');
      expect(TransactionIdService.prefixFor(PaymentType.monthlyMembership),
          'MM');
      expect(TransactionIdService.prefixFor(PaymentType.lotPayment), 'LPAY');
      expect(TransactionIdService.prefixFor(PaymentType.penalty), 'PEN');
      expect(TransactionIdService.prefixFor(PaymentType.specialAssessment),
          'SA');
      expect(TransactionIdService.prefixFor(PaymentType.other), 'TXN');
    });
  });

  group('paymentTransactionId', () {
    test('formats {prefix}-{year}-{seq4}', () {
      expect(TransactionIdService.paymentTransactionId(
          PaymentType.membershipFee, 2026, 1),
          'MF-2026-0001');
      expect(TransactionIdService.paymentTransactionId(
          PaymentType.dues, 2026, 42),
          'MD-2026-0042');
      expect(TransactionIdService.paymentTransactionId(
          PaymentType.lotPayment, 2025, 999),
          'LPAY-2025-0999');
    });

    test('pads the sequence to 4 digits', () {
      expect(TransactionIdService.paymentTransactionId(
          PaymentType.monthlyMembership, 2026, 12345),
          'MM-2026-12345');
    });

    test('different types never share a prefix', () {
      final ids = PaymentType.values
          .map((t) => TransactionIdService.paymentTransactionId(t, 2026, 1))
          .map((id) => id.split('-').first)
          .toSet();
      expect(ids.length, PaymentType.values.length);
    });
  });
}
