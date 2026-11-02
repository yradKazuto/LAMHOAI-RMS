import 'package:flutter_test/flutter_test.dart';
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
}
