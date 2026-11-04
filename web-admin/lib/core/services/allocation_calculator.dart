// core/services/allocation_calculator.dart
//
// Pure allocation calculation — no Firestore dependency, so unit-testable.
// Used by FirestoreService.recordPaymentWithAllocations.
//
// Rules (plan-payment-automation.md §8.1):
//  - Obligations sorted oldest due date first.
//  - Within each obligation: allocate principal before penalty.
//  - Partial payment supported: obligation stays unpaid, paidAmount accumulates.
//  - Status flips to paid only when principal + penalty fully covered.
//  - Excess payment beyond total outstanding is flagged for rejection.
//
// State model per obligation (see PaymentModel):
//  - `amount` = total on the doc (may include penalty added by markOverduePenalties)
//  - `penaltyAmount` = penalty still allocatable from THIS doc (45 for overdue,
//                      0 otherwise; decreases as cash payments distribute penalty)
//  - `paidAmount` = cumulative principal allocated to THIS doc (must stay
//                    <= remaining principal)
//
// So: principalRemaining = amount - penaltyAmount; penaltyRemaining = penaltyAmount.

import '../models/payment_model.dart';

/// Result of allocating [paymentAmount] across a member's outstanding
/// obligations.
class AllocationResult {
  final List<Allocation> allocations;

  /// Remaining funds after all obligations are covered. > 0 means the
  /// payment exceeded total outstanding — caller rejects rather than apply.
  final double unappliedCredit;

  /// Non-null when unappliedCredit > 0, explaining why excess was rejected.
  final String? rejectionReason;

  const AllocationResult({
    required this.allocations,
    this.unappliedCredit = 0,
    this.rejectionReason,
  });

  bool get hasExcess => unappliedCredit > 0 && rejectionReason != null;
}

/// One obligation→allocation link produced by the FIFO algorithm.
class Allocation {
  final String obligationId;
  final double allocatedPrincipal;
  final double allocatedPenalty;
  final double allocatedAmount; // = principal + penalty
  final bool obligationPaid;

  const Allocation({
    required this.obligationId,
    required this.allocatedPrincipal,
    required this.allocatedPenalty,
    required this.allocatedAmount,
    this.obligationPaid = false,
  });

  @override
  String toString() =>
      'Allocation($obligationId: p=$allocatedPrincipal, pen=$allocatedPenalty, '
      'total=$allocatedAmount, paid=$obligationPaid)';
}

/// Input: member's outstanding obligations (already filtered for unpaid/
/// overdue status), each carrying total amount and remaining penalty.
class AllocationInput {
  final List<ObligationInput> obligations;
  final double paymentAmount;

  const AllocationInput({
    required this.obligations,
    required this.paymentAmount,
  });
}

/// Plain obligation snapshot for allocation computation.
/// principalRemaining = amount - penaltyAmount
/// penaltyRemaining = penaltyAmount
class ObligationInput {
  final String id;
  final double amount;
  final double penaltyAmount; // penalty still allocatable from this doc
  final DateTime dueDate;

  const ObligationInput({
    required this.id,
    required this.amount,
    required this.penaltyAmount,
    required this.dueDate,
  });
}

/// Computes FIFO allocation. Returns allocation results. Excess beyond
/// total outstanding is flagged; caller decides rejection.
AllocationResult computeAllocation({
  required List<ObligationInput> obligations,
  required double paymentAmount,
}) {
  final allocs = <Allocation>[];
  var remaining = paymentAmount;

  for (final ob in obligations) {
    if (remaining <= 0) break;

    final principalOwed = ob.amount - ob.penaltyAmount;
    final penaltyOwed = ob.penaltyAmount;

    // Principal first.
    final applyPrincipal = remaining < principalOwed
        ? remaining
        : principalOwed;
    remaining -= applyPrincipal;

    // Then penalty.
    var applyPenalty = penaltyOwd(remaining, penaltyOwed);
    if (applyPenalty > remaining) applyPenalty = remaining;
    remaining -= applyPenalty;

    allocs.add(Allocation(
      obligationId: ob.id,
      allocatedPrincipal: applyPrincipal,
      allocatedPenalty: applyPenalty,
      allocatedAmount: applyPrincipal + applyPenalty,
    ));
  }

  final totalApplied = allocs.fold<double>(
    0,
    (sum, a) => sum + a.allocatedAmount,
  );
  final unapplied = paymentAmount - totalApplied;

  return AllocationResult(
    allocations: allocs,
    unappliedCredit: unapplied,
    rejectionReason:
        unapplied > 0
            ? 'Excess payment of ${unapplied.toStringAsFixed(2)} not allowed until policy approved'
            : null,
  );
}

/// Capped allocation to remaining funds.
double penaltyOwd(double remainder, double owed) =>
    remainder < owed ? remainder : owed;
