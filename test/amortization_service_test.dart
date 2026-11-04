// test/amortization_service_test.dart
// Tests for the pure allocation algorithm in allocation_calculator.dart.
//
// §14 of plan-payment-automation.md: Phase 1 test suite.

import 'package:flutter_test/flutter_test.dart';
import 'package:lamhoai_web_admin/core/services/allocation_calculator.dart';

void main() {
  group('computeAllocation', () {
    final obligation = ObligationInput(
      id: 'p1',
      amount:       100.0,
      penaltyAmount: 45.0,
      paidAmount:   0.0,
      dueDate:      DateTime(2025, 6, 1),
    );

    test('no obligations — unapplied = full payment, no allocations', () {
      final r = computeAllocation(obligations: [], paymentAmount: 50);
      expect(r.allocations, isEmpty);
      expect(r.unappliedCredit, 50);
      expect(r.rejectionReason, isNotNull);
    });

    test('single obligation fully paid without excess', () {
      final r = computeAllocation(
        obligations: [obligation],
        paymentAmount: 145.0, // principal + penalty
      );
      expect(r.allocations.length, 1);
      expect(r.allocations[0].allocatedPrincipal, 100);
      expect(r.allocations[0].allocatedPenalty, 45);
      expect(r.allocations[0].allocatedAmount, 145);
      expect(r.unappliedCredit, 0);
      expect(r.rejectionReason, isNull);
    });

    test('principal-first allocation within single obligation', () {
      final r = computeAllocation(
        obligations: [obligation],
        paymentAmount: 50.0, // partial — only principal, not penalty
      );
      expect(r.allocations.length, 1);
      expect(r.allocations[0].allocatedPrincipal, 50);
      expect(r.allocations[0].allocatedPenalty, 0);
      expect(r.allocations[0].allocatedAmount, 50);
      // Penalty should NOT have been touched.
      expect(r.unappliedCredit, 0);
    });

    test('multiple obligations FIFO — fills oldest first', () {
      final ob1 = ObligationInput(
        id: 'd1', amount:       500.0, penaltyAmount: 45.0,
        paidAmount: 0.0, dueDate: DateTime(2025, 3, 1),
      );
      final ob2 = ObligationInput(
        id: 'd2', amount:       300.0, penaltyAmount: 30.0,
        paidAmount: 0.0, dueDate: DateTime(2025, 9, 1),
      );
      final r = computeAllocation(
        obligations: [ob1, ob2],
        paymentAmount: 875.0, // exactly covers both (500 + 300 + 45 + 30)
      );
      expect(r.allocations.length, 2);
      expect(r.allocations[0].obligationId, 'd1');
      expect(r.allocations[0].allocatedPrincipal, 500);
      expect(r.allocations[0].allocatedPenalty, 45);
      expect(r.allocations[1].obligationId, 'd2');
      expect(r.allocations[1].allocatedPrincipal, 300);
      expect(r.allocations[1].allocatedPenalty, 30);
      expect(r.unappliedCredit, 0);
    });

    test('excess payment rejected — second obligation untouched', () {
      final ob1 = ObligationInput(
        id: 'd1', amount:       100.0, penaltyAmount: 45.0,
        paidAmount: 0.0, dueDate: DateTime(2025, 3, 1),
      );
      final ob2 = ObligationInput(
        id: 'd2', amount:       100.0, penaltyAmount: 45.0,
        paidAmount: 0.0, dueDate: DateTime(2025, 9, 1),
      );
      final r = computeAllocation(
        obligations: [ob1, ob2],
        paymentAmount: 250.0, // 145 covers d1, 105 leftover
      );
      expect(r.hasExcess, true);
      expect(r.unappliedCredit, 105.0);
      expect(r.rejectionReason, isNotNull);
      // d2 must NOT be touched.
      expect(r.allocations.length, 1);
      expect(r.allocations[0].obligationId, 'd1');
    });

    test('partial payment on first obligation accumulates into paidAmount', () {
      final r = computeAllocation(
        obligations: [obligation],
        paymentAmount: 20.0, // only 20 toward principal of p1
      );
      expect(r.allocations.length, 1);
      expect(r.allocations[0].allocatedPrincipal, 20);
      // remaining 145 applied to principal of p1... no wait, cap function caps by remaining after principal.
      // After allocating 20, remaining = 125. Then allocate penalty capped at 125 > 45, so full 45.
      // Actually no — paymentAmount is 20, so after principal: remaining = 0, no penalty applied.
      // CORRECTION: paymentAmount=20 means remaining=20, principal capped to 20, remaining becomes 0.
      // So no penalty.
      expect(r.allocations[0].allocatedPenalty, 0);
    });

    test('prior allocations respected — d1 already partially paid', () {
      final ob1 = ObligationInput(
        id: 'd1', amount:       100.0, penaltyAmount: 45.0,
        paidAmount: 60.0, // already paid 60 toward principal
        dueDate:    DateTime(2025, 3, 1),
      );
      final r = computeAllocation(
        obligations: [ob1],
        paymentAmount: 50.0, // remaining principal = 40, but trying to pay 50
      );
      expect(r.allocations.length, 1);
      // Principal: min(50, 40) = 40. Remaining: 10.
      // Penalty: remaining(10) < penaltyOwed(45)? yes → 10 penalty.
      expect(r.allocations[0].allocatedPrincipal, 40);
      expect(r.allocations[0].allocatedPenalty, 10);
    });

    test('multiple obligations sorted oldest-first', () {
      // d1 later than d2 in raw list but dueDate is earlier → sorted first
      final d1_later = ObligationInput(
        id: 'd1', amount:       100.0, penaltyAmount: 0.0,
        paidAmount: 0.0, dueDate: DateTime(2025, 12, 1),
      );
      final d2_earlier = ObligationInput(
        id: 'd2', amount:       100.0, penaltyAmount: 0.0,
        paidAmount: 0.0, dueDate: DateTime(2025, 6, 1),
      );
      final r = computeAllocation(
        obligations: [d1_later, d2_earlier],
        paymentAmount: 100.0,
      );
      expect(r.allocations.first.obligationId, 'd2'); // d2 due earlier → first
      expect(r.allocations.last.obligationId, 'd1');
    });
  });
}
