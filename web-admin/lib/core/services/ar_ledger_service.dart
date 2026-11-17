// core/services/ar_ledger_service.dart
//
// Accounts Receivable ledger — pure, read-only builder. Turns the HOA's
// obligation records into a proper double-entry T-account:
//
//   DEBIT  = assessed charges (dues, membership fees, special assessments,
//            penalties, lot down payments and installment periods)
//   CREDIT = money actually received against those charges (plus waivers)
//
// Sources — no new collection, no writes, no duplicate accounting source:
//   `payments`            obligation rows, EXCEPT the lot-payment mirrors
//                         (type lotPayment + LP- reference) which duplicate
//                         `lot_payments`; mirrors are skipped so a lot charge
//                         is never counted twice.
//   `lot_payments`        the amortization schedule — the assessed
//                         installment charges, paid or not
//   `payment_allocations` confirmed receipts mapped onto obligations
//
// Rules per obligation:
//   debit  = amount + penaltyAmount (penalty still owed)
//                 + penalty already allocated to receipts
//   credit = money received = the allocation rows for this obligation, plus a
//            derived line when the row was settled without an allocation
//            trail (quick "Mark Paid", sale-service mark-paid path)
//   balance = total debit - total credit = what the member still owes
//
// A payment never creates a debit; every debit here is an assessed charge.
// Over-payments are kept, not clipped: credit may exceed debit and shows as a
// credit balance.
//
// Limitations (documented, not invented):
//   • Penalty on rows settled before allocations existed is reconstructed
//     from the penaltyAmount still on the row; the historic rate is assumed
//     to be the current one.
//   • A quick "Mark Paid" settles the whole row including any penalty.

import '../models/lot_payment_model.dart';
import '../models/payment_allocation_model.dart';
import '../models/payment_model.dart';
import '../utils/lot_pricing.dart';
import '../utils/payment_labels.dart'; // PaymentModel.typeLabel

enum ArSide { debit, credit }

class ArLedgerEntry {
  final DateTime date;
  final String particulars;
  final String reference;
  final double amount;
  final ArSide side;
  /// Lot label / identifier, shown under the particulars.
  final String note;

  const ArLedgerEntry({
    required this.date,
    required this.particulars,
    required this.reference,
    required this.amount,
    required this.side,
    this.note = '',
  });
}

class ArLedger {
  final List<ArLedgerEntry> debits;
  final List<ArLedgerEntry> credits;

  const ArLedger({required this.debits, required this.credits});

  double get totalDebit =>
      debits.fold<double>(0, (s, e) => s + e.amount);
  double get totalCredit =>
      credits.fold<double>(0, (s, e) => s + e.amount);

  /// What the member still owes. Negative = overpayment (credit balance).
  double get balance => totalDebit - totalCredit;

  bool get hasEntries => debits.isNotEmpty || credits.isNotEmpty;

  String get statusLabel {
    if (balance > 0.005) return 'Outstanding';
    if (balance < -0.005) return 'Credit balance';
    return 'Settled';
  }

  /// Chronological across both sides, like a real ledger book.
  List<ArLedgerEntry> get entries {
    final all = [...debits, ...credits];
    all.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : a.reference.compareTo(b.reference);
    });
    return all;
  }
}

class ArLedgerService {
  const ArLedgerService();

  static const double _epsilon = 0.005;

  ArLedger build({
    required List<PaymentModel> payments,
    required List<LotPaymentModel> lotPayments,
    required List<PaymentAllocationModel> allocations,
  }) {
    // Allocation rows key their obligation by the Firestore doc id and do NOT
    // record which collection it lives in. Ids are unique per collection, so
    // one flat map is enough: payments ids and lot_payments ids never collide
    // in practice, and an orphan row (deleted / voided obligation) simply
    // matches nothing below.
    final allocByObligation = <String, List<PaymentAllocationModel>>{};
    for (final a in allocations) {
      allocByObligation.putIfAbsent(a.obligationId, () => []).add(a);
    }

    final debits = <ArLedgerEntry>[];
    final credits = <ArLedgerEntry>[];

    void post({
      required String id,
      required String label,
      required String note,
      required String reference,
      required DateTime dueDate,
      required double amount,
      required double penaltyOwed,
      required double principalPaid,
      required DateTime? settledDate,
      required bool settled,
      required bool waived,
    }) {
      final penaltyPaid = (allocByObligation[id] ?? const <PaymentAllocationModel>[])
          .fold<double>(0, (s, a) => s + a.allocatedPenalty);
      final debit = amount + penaltyOwed + penaltyPaid;
      if (debit <= _epsilon) return;

      final penaltyTotal = penaltyOwed + penaltyPaid;
      debits.add(ArLedgerEntry(
        side: ArSide.debit,
        date: dueDate,
        particulars: label +
            (penaltyTotal > _epsilon
                ? ' (incl. ${LotPricing.peso(penaltyTotal)} penalty)'
                : ''),
        reference: reference,
        note: note,
        amount: debit,
      ));

      final remaining = settled
          ? 0.0
          : (amount - principalPaid).clamp(0.0, double.infinity) + penaltyOwed;

      // Confirmed receipts first — one credit line per allocation row.
      var credited = 0.0;
      for (final a in allocByObligation[id] ?? const <PaymentAllocationModel>[]) {
        if (a.allocatedAmount <= _epsilon) continue;
        credited += a.allocatedAmount;
        credits.add(ArLedgerEntry(
          side: ArSide.credit,
          date: a.allocatedAt,
          particulars: 'Payment · $label',
          reference: a.transactionId,
          note: note,
          amount: a.allocatedAmount,
        ));
      }

      // Settled without an allocation trail (quick Mark Paid, sale-service
      // mark-paid path): derive the residual as one credit so the side
      // balances. Never invented for an unsettled row.
      final gap = debit - remaining - credited;
      if (gap > _epsilon) {
        credits.add(ArLedgerEntry(
          side: ArSide.credit,
          date: settledDate ?? dueDate,
          particulars: waived ? 'Waived · $label' : 'Payment · $label',
          reference: reference,
          note: note,
          amount: gap,
        ));
      }
      // gap < 0 means receipts exceed the assessed charge — a genuine
      // over-payment. It stays on the credit side as a credit balance.
    }

    for (final p in payments) {
      if (p.status == PaymentStatus.voided) continue;
      // Lot-charge mirrors live in `payments` too, but `lot_payments` is the
      // source of truth for them; posting both would double-count.
      if (p.type == PaymentType.lotPayment &&
          p.transactionId.startsWith('LP-')) {
        continue;
      }
      post(
        id: p.id,
        label: p.typeLabel,
        note: p.lotLabel,
        reference: p.transactionId,
        dueDate: p.dueDate,
        amount: p.amount,
        penaltyOwed: p.penaltyAmount,
        principalPaid: p.paidAmount,
        settledDate: p.paidDate,
        settled: p.status == PaymentStatus.paid ||
            p.status == PaymentStatus.waived,
        waived: p.status == PaymentStatus.waived,
      );
    }

    for (final p in lotPayments) {
      if (p.status == LotPaymentStatus.void_) continue;
      post(
        id: p.id,
        label: p.period == 0
            ? 'Lot purchase / down payment'
            : 'Lot installment · Period ${p.period}',
        note: '',
        reference: p.transactionId,
        dueDate: p.dueDate,
        amount: p.amount,
        penaltyOwed: p.penaltyAmount,
        principalPaid: p.paidAmount,
        settledDate: p.paidAt,
        settled: p.status == LotPaymentStatus.paid ||
            p.status == LotPaymentStatus.waived,
        waived: p.status == LotPaymentStatus.waived,
      );
    }

    debits.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : a.reference.compareTo(b.reference);
    });
    credits.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : a.reference.compareTo(b.reference);
    });

    return ArLedger(debits: debits, credits: credits);
  }
}
