// test/allocation_calculator_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:lamhoai_admin/core/services/allocation_calculator.dart';

void main() {
  group('AllocationCalculator FIFO tests', () {
    test('allocates oldest first with principal before penalty', () {
      final now = DateTime.now();
      final obligations = [
        ObligationInput(
          id: 'obl1',
          amount: 1000.0,
          penaltyAmount: 45.0,
          dueDate: now.subtract(const Duration(days: 60)),
        ),
        ObligationInput(
          id: 'obl2',
          amount: 1000.0,
          penaltyAmount: 0.0,
          dueDate: now.subtract(const Duration(days: 30)),
        ),
      ];

      // Pay 500: should cover obl1 principal partly (955 principal, 45 penalty)
      final result = computeAllocation(
        obligations: obligations,
        paymentAmount: 500.0,
      );

      expect(result.allocations.length, 1);
      expect(result.allocations[0].obligationId, 'obl1');
      expect(result.allocations[0].allocatedPrincipal, 500.0);
      expect(result.allocations[0].allocatedPenalty, 0.0);
      expect(result.unappliedCredit, 0.0);
    });

    test('fully pays obl1 and starts obl2', () {
      final now = DateTime.now();
      final obligations = [
        ObligationInput(
          id: 'obl1',
          amount: 1000.0,
          penaltyAmount: 45.0,
          dueDate: now.subtract(const Duration(days: 60)),
        ),
        ObligationInput(
          id: 'obl2',
          amount: 1000.0,
          penaltyAmount: 0.0,
          dueDate: now.subtract(const Duration(days: 30)),
        ),
      ];

      // Pay 1045: covers obl1 (1000 principal + 45 penalty) exactly
      final result = computeAllocation(
        obligations: obligations,
        paymentAmount: 1045.0,
      );

      expect(result.allocations.length, 1);
      expect(result.allocations[0].obligationId, 'obl1');
      expect(result.allocations[0].allocatedPrincipal, 1000.0);
      expect(result.allocations[0].allocatedPenalty, 45.0);
      expect(result.unappliedCredit, 0.0);
    });

    test('flags excess payment', () {
      final now = DateTime.now();
      final obligations = [
        ObligationInput(
          id: 'obl1',
          amount: 500.0,
          penaltyAmount: 0.0,
          dueDate: now,
        ),
      ];

      final result = computeAllocation(
        obligations: obligations,
        paymentAmount: 600.0,
      );

      expect(result.hasExcess, true);
      expect(result.unappliedCredit, 100.0);
    });
  });
}
