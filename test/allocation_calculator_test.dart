// test/allocation_calculator_test.dart
// Tests for the pure allocation algorithm in allocation_calculator.dart.
// §14 of plan-payment-automation.md: Phase 1 test suite.

import 'package:flutter_test/flutter_test.dart';
import 'package:lamhoai_admin/core/services/allocation_calculator.dart';

void main() {
  group('computeAllocation', () {
    final obligation = ObligationInput(
      id: 'p1',
      amount:       100.0, // total (principal + any original penalty)
      penaltyAmount: 45.0,  // penalty still allocatable from this doc
      dueDate:      DateTime(2025, 6, 1),
    );

    test('no obligations — entire payment flagged as excess', () {
      final r = computeAllocation(obligations: [], paymentAmount: 50);
      expect(r.allocations, isEmpty);
      expect(r.unappliedCredit, 50);
      expect(r.rejectionReason, isNotNull);
    });

    test('single obligation fully covered by principal + penalty', () {
      final r = computeAllocation(
        obligations: [obligation],
        paymentAmount: 145.0, // principal(100) + penalty(45)
      );
      expect(r.allocations.length, 1);
      expect(r.allocations[0].allocatedPrincipal, 100);
      expect(r.allocations[0].allocatedPenalty, 45);
      expect(r.allocations[0].allocatedAmount, 145);
      expect(r.unappliedCredit, 0);
      expect(r.rejectionReason, isNull);
    });

    test('partial payment applies only principal, not penalty', () {
      final r = computeAllocation(
        obligations: [obligation],
        paymentAmount: 50.0, // only toward principal
      );
      expect(r.allocations.length, 1);
      expect(r.allocations[0].allocatedPrincipal, 50);
      expect(r.allocations[0].allocatedPenalty, 0);
    });

    test('multiple obligations FIFO — fills oldest first', () {
      final ob1 = ObligationInput(
        id: 'd1', amount:       500.0, penaltyAmount: 45.0,
        dueDate: DateTime(2025, 3, 1),
      );
      final ob2 = ObligationInput(
        id: 'd2', amount:       300.0, penaltyAmount: 30.0,
        dueDate: DateTime(2025, 9, 1),
      );
      final r = computeAllocation(
        obligations: [ob1, ob2],
        paymentAmount: 875.0, // exactly covers both
      );
      expect(r.allocations.length, 2);
      expect(r.allocations[0].obligationId, 'd1'); // earliest due
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
        dueDate: DateTime(2025, 3, 1),
      );
      final ob2 = ObligationInput(
        id: 'd2', amount:       100.0, penaltyAmount: 45.0,
        dueDate: DateTime(2025, 9, 1),
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

    test('partial payment on first obligation leaves it incomplete', () {
      final r = computeAllocation(
        obligations: [obligation],
        paymentAmount: 60.0, // toward principal of p1
      );
      expect(r.allocations.length, 1);
      expect(r.allocations[0].allocatedPrincipal, 60);
      // After paying 60 principal, remaining=0 → no penalty allocated.
      expect(r.allocations[0].allocatedPenalty, 0);
    });

    test('excess on second obligation does not consume third', () {
      final d1 = ObligationInput(
        id: 'd1', amount:       100.0, penaltyAmount: 0.0,
        dueDate: DateTime(2025, 1, 1),
      );
      final d2 = ObligationInput(
        id: 'd2', amount:       100.0, penaltyAmount: 0.0,
        dueDate: DateTime(2025, 7, 1),
      );
      final d3 = ObligationInput(
        id: 'd3', amount:       100.0, penaltyAmount: 0.0,
        dueDate: DateTime(2025, 11, 1),
      );
      final r = computeAllocation(
        obligations: [d1, d2, d3],
        paymentAmount: 250.0, // covers d1+d2 fully (200), leaves 50
      );
      expect(r.hasExcess, true);
      expect(r.unappliedCredit, 50);
      // Only d1 and d2 touched; d3 untouched.
      expect(r.allocations.map((a) => a.obligationId).toSet(), {'d1', 'd2'});
    });

    test('obligations sorted oldest-first regardless of input order', () {
      final later = ObligationInput(
        id: 'later', amount:       100.0, penaltyAmount: 0.0,
        dueDate: DateTime(2025, 12, 1),
      );
      final earlier = ObligationInput(
        id: 'earlier', amount:       100.0, penaltyAmount: 0.0,
        dueDate: DateTime(2025, 6, 1),
      );
      final r = computeAllocation(
        obligations: [later, earlier], // bad input order
        paymentAmount: 200.0,
      );
      expect(r.allocations.first.obligationId, 'earlier');
      expect(r.allocations.last.obligationId, 'later');
    });
  });
}
