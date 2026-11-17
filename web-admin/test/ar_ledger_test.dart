// test/ar_ledger_test.dart
//
// Pure-math checks for ArLedgerService — the AR T-account rules:
// debit = assessed charge (+ penalties), credit = money actually received
// (allocation rows + the derived line for settlements with no allocation
// trail). No Firestore involved.

import 'package:flutter_test/flutter_test.dart';
import 'package:lamhoai_admin/core/models/lot_payment_model.dart';
import 'package:lamhoai_admin/core/models/payment_allocation_model.dart';
import 'package:lamhoai_admin/core/models/payment_model.dart';
import 'package:lamhoai_admin/core/services/ar_ledger_service.dart';

PaymentModel _dues(String id, double amount,
    {PaymentStatus status = PaymentStatus.unpaid,
    double paid = 0.0,
    double penalty = 0.0,
    String txn = 'D-1',
    PaymentType type = PaymentType.dues}) {
  return PaymentModel(
    id: id,
    uid: 'm1',
    memberName: 'Member 1',
    type: type,
    amount: amount,
    status: status,
    dueDate: DateTime(2026, 11, 1),
    paidDate: status == PaymentStatus.paid ? DateTime(2026, 11, 10) : null,
    recordedBy: 'Admin',
    notes: '',
    createdAt: DateTime(2026, 10, 1),
    transactionId: txn,
    penaltyAmount: penalty,
    paidAmount: paid,
  );
}

LotPaymentModel _lot(String id, String txn, double amount,
    {LotPaymentStatus status = LotPaymentStatus.scheduled,
    double paid = 0.0,
    double penalty = 0.0,
    int period = 1}) {
  return LotPaymentModel(
    id: id,
    saleId: 's1',
    lotId: 'l1',
    period: period,
    transactionId: txn,
    dueDate: DateTime(2026, 11, 5),
    amount: amount,
    principalPortion: amount,
    interestPortion: 0,
    remainingBalance: 0,
    status: status,
    paidAmount: paid,
    penaltyAmount: penalty,
    paidAt: status == LotPaymentStatus.paid ? DateTime(2026, 11, 12) : null,
    createdAt: DateTime(2026, 10, 1),
  );
}

PaymentAllocationModel _alloc(String obligationId, double principal,
    {double penalty = 0.0, String txn = 'PAY-1'}) {
  return PaymentAllocationModel(
    id: 'a-$obligationId-$txn',
    transactionId: txn,
    memberUid: 'm1',
    obligationId: obligationId,
    allocatedPrincipal: principal,
    allocatedPenalty: penalty,
    allocatedAmount: principal + penalty,
    allocatedAt: DateTime(2026, 11, 10),
  );
}

void main() {
  const svc = ArLedgerService();

  test('unpaid dues posts as a debit with no credit', () {
    final ledger = svc.build(
      payments: [_dues('d1', 1000)],
      lotPayments: const [],
      allocations: const [],
    );
    expect(ledger.totalDebit, 1000);
    expect(ledger.totalCredit, 0);
    expect(ledger.balance, 1000);
    expect(ledger.statusLabel, 'Outstanding');
  });

  test('partial payment credits only what was received', () {
    final ledger = svc.build(
      payments: [_dues('d1', 1000, paid: 700)],
      lotPayments: const [],
      allocations: [_alloc('d1', 700)],
    );
    expect(ledger.totalDebit, 1000);
    expect(ledger.totalCredit, 700);
    expect(ledger.balance, 300);
  });

  test('full payment including penalty balances the account', () {
    final ledger = svc.build(
      // post-allocation state: penaltyAmount is what is STILL owed (0)
      payments: [_dues('d1', 1000, status: PaymentStatus.paid, paid: 1000)],
      lotPayments: const [],
      allocations: [_alloc('d1', 1000, penalty: 45)],
    );
    expect(ledger.totalDebit, 1045, reason: 'charge + penalty assessed');
    expect(ledger.totalCredit, 1045);
    expect(ledger.balance, 0);
    expect(ledger.statusLabel, 'Settled');
  });

  test('penalty still owed is added to the debit side', () {
    final ledger = svc.build(
      payments: [_dues('d1', 1000, penalty: 45)],
      lotPayments: const [],
      allocations: const [],
    );
    expect(ledger.totalDebit, 1045);
    expect(ledger.debits.single.particulars.contains('penalty'), isTrue);
  });

  test('waived obligation credits itself with no payment received', () {
    final ledger = svc.build(
      payments: [_dues('d1', 500, status: PaymentStatus.waived)],
      lotPayments: const [],
      allocations: const [],
    );
    expect(ledger.totalDebit, 500);
    expect(ledger.totalCredit, 500);
    expect(ledger.balance, 0);
    expect(ledger.credits.single.particulars.startsWith('Waived'), isTrue);
  });

  test('voided records post nothing', () {
    final ledger = svc.build(
      payments: [_dues('d1', 1000, status: PaymentStatus.voided)],
      lotPayments: [_lot('v1', 'LP-2026-0001-1', 300,
          status: LotPaymentStatus.void_)],
      allocations: const [],
    );
    expect(ledger.hasEntries, isFalse);
    expect(ledger.balance, 0);
  });

  test('lot mirror in `payments` is skipped — lot_payments is the source',
      () {
    final ledger = svc.build(
      payments: [
        _dues('d1', 1000, type: PaymentType.lotPayment, txn: 'LP-2026-0001-1'),
      ],
      lotPayments: [_lot('row1', 'LP-2026-0001-1', 1000)],
      allocations: const [],
    );
    expect(ledger.totalDebit, 1000, reason: 'counted once, not twice');
    expect(ledger.debits.single.reference, 'LP-2026-0001-1');
  });

  test('manual LPAY- lot payment row is NOT skipped', () {
    final ledger = svc.build(
      payments: [_dues('d1', 250, txn: 'LPAY-2026-0001-1',
          type: PaymentType.lotPayment)],
      lotPayments: const [],
      allocations: const [],
    );
    expect(ledger.totalDebit, 250);
  });

  test('scheduled installment from lot_payments appears as a debit', () {
    final ledger = svc.build(
      payments: const [],
      lotPayments: [_lot('row1', 'LP-2026-0002-1', 300)],
      allocations: const [],
    );
    expect(ledger.totalDebit, 300);
    expect(ledger.debits.single.particulars, 'Lot installment · Period 1');
  });

  test('quick mark-paid lot row derives its credit from status', () {
    final ledger = svc.build(
      payments: const [],
      lotPayments: [_lot('row1', 'LP-2026-0002-1', 400,
          status: LotPaymentStatus.paid)],
      allocations: const [],
    );
    expect(ledger.totalDebit, 400);
    expect(ledger.totalCredit, 400,
        reason: 'no allocation trail — derived line must balance it');
    expect(ledger.balance, 0);
    expect(ledger.credits.single.date, DateTime(2026, 11, 12));
  });

  test('one obligation paid by two receipts posts two credit lines', () {
    final ledger = svc.build(
      payments: [_dues('d1', 1000)],
      lotPayments: const [],
      allocations: [_alloc('d1', 600, txn: 'PAY-1'), _alloc('d1', 400, txn: 'PAY-2')],
    );
    expect(ledger.credits.length, 2);
    expect(ledger.totalCredit, 1000);
    expect(ledger.balance, 0);
  });

  test('receipts above the assessed charge stay visible as a credit balance',
      () {
    final ledger = svc.build(
      payments: [_dues('d1', 500)],
      lotPayments: const [],
      allocations: [_alloc('d1', 700, txn: 'PAY-1')],
    );
    expect(ledger.totalDebit, 500);
    expect(ledger.totalCredit, 700, reason: 'overpayment is never clipped');
    expect(ledger.balance, -200);
    expect(ledger.statusLabel, 'Credit balance');
  });

  test('entries sort chronologically across both sides', () {
    final ledger = svc.build(
      payments: [_dues('d1', 1000, paid: 1000, status: PaymentStatus.paid)],
      lotPayments: const [],
      allocations: [_alloc('d1', 1000)],
    );
    final dates = ledger.entries.map((e) => e.date).toList();
    expect(dates, List.of(dates)..sort());
  });
}
