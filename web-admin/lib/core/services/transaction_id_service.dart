// core/services/transaction_id_service.dart
//
// Pure ID formatting for financial transaction references:
//   Lot payments (amortization periods):
//     LP-{year}-{saleSeq}-{period}          e.g. LP-2026-001-007
//   Payments-collection records (PaymentModel), prefix per type:
//     MF-{year}-{seq}   annual membership fee    e.g. MF-2026-0001
//     MD-{year}-{seq}   monthly dues             e.g. MD-2026-0001
//     MM-{year}-{seq}   monthly membership fee   e.g. MM-2026-0001
//     LPAY-{year}-{seq} lot payment (manual)     e.g. LPAY-2026-0001
//     PEN-{year}-{seq}  penalty
//     SA-{year}-{seq}   special assessment
//     TXN-{year}-{seq}  other
//
// No Firestore, no UI — safe to unit-test in isolation.

import '../models/payment_model.dart';

class TransactionIdService {
  const TransactionIdService();

  /// Builds a lot-payment transaction ID: `LP-{year}-{saleSeq}-{period}` with
  /// zero-padded sequence and period (3 digits each) and a 4-digit year.
  static String nextTransactionId(int year, int saleSeq, int period) {
    return 'LP-${_pad(year, 4)}-${_pad(saleSeq, 3)}-${_pad(period, 3)}';
  }

  /// Prefix for a payments-collection record, by type. `TXN` is the
  /// catch-all so every record always gets a non-empty, readable ID.
  static String prefixFor(PaymentType type) {
    switch (type) {
      case PaymentType.dues:              return 'MD';
      case PaymentType.membershipFee:     return 'MF';
      case PaymentType.monthlyMembership: return 'MM';
      case PaymentType.lotPayment:        return 'LPAY';
      case PaymentType.penalty:           return 'PEN';
      case PaymentType.specialAssessment: return 'SA';
      case PaymentType.other:             return 'TXN';
    }
  }

  /// Builds a payments-collection transaction ID:
  /// `{prefix}-{year}-{seq}` with a 4-digit zero-padded sequence.
  static String paymentTransactionId(PaymentType type, int year, int seq) =>
      '${prefixFor(type)}-${_pad(year, 4)}-${_pad(seq, 4)}';

  static String _pad(int value, int width) =>
      value.toString().padLeft(width, '0');
}
