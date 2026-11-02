// core/services/transaction_id_service.dart
//
// Pure ID formatting for lot-sale payment transaction references:
//   LP-{year}-{saleSeq}-{period}   e.g. LP-2026-001-007
//
// No Firestore, no UI — safe to unit-test in isolation.

class TransactionIdService {
  const TransactionIdService();

  /// Builds a transaction ID: `LP-{year}-{saleSeq}-{period}` with zero-padded
  /// sequence and period (3 digits each) and a 4-digit year.
  static String nextTransactionId(int year, int saleSeq, int period) {
    return 'LP-${_pad(year, 4)}-${_pad(saleSeq, 3)}-${_pad(period, 3)}';
  }

  static String _pad(int value, int width) =>
      value.toString().padLeft(width, '0');
}
