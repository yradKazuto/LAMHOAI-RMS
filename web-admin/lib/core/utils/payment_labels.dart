// core/utils/payment_labels.dart
//
// Display label for a payment's type. Lot payments (PaymentType.lotPayment)
// used to show as "Monthly Lot Dues" for everything. Now:
//   • cash purchase        → "Full Payment"
//   • installment down payment → "Down Payment"
//   • installment period   → "Installment"
// All other payment types keep their normal label.

import '../models/payment_model.dart';

extension PaymentTypeLabel on PaymentModel {
  String get typeLabel {
    if (type != PaymentType.lotPayment) return type.label;

    final id = transactionId.toUpperCase();
    final note = notes.toLowerCase();

    // Cash purchase: transaction id ends in -CASH ("LP-2026-0007-CASH");
    // older records without an id are recognized by their note.
    if (id.endsWith('-CASH') || note.contains('(cash)')) {
      return 'Full Payment';
    }

    // Down payment: transaction id ends in -DP ("LP-2026-0010-DP");
    // older records without an id are recognized by their note
    // ("Lot down payment").
    if (id.endsWith('-DP') || note.contains('down payment')) {
      return 'Down Payment';
    }

    return 'Installment';
  }
}