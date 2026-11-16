import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:lamhoai_admin/core/services/firestore_service.dart';
import 'package:lamhoai_admin/core/models/payment_model.dart';
import 'package:lamhoai_admin/core/models/lot_payment_model.dart';

void main() {
  late FakeFirebaseFirestore fakeDb;
  late FirestoreService firestoreService;

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
    firestoreService = FirestoreService(db: fakeDb);
  });

  Future<void> seedDues(String uid, double amount) => fakeDb
      .collection('payments')
      .add({
        'uid': uid,
        'type': PaymentType.membershipFee.name,
        'amount': amount,
        'paidAmount': 0.0,
        'penaltyAmount': 0.0,
        'status': PaymentStatus.unpaid.name,
        'dueDate': Timestamp.now(),
      });

  Future<String> seedInstallment(String uid, String saleId, double amount,
      {bool overdue = false}) async {
    await fakeDb.collection('lot_sales').doc(saleId).set({
      'buyerUid': uid,
      'buyerName': 'Member 1',
    });
    final ref = await fakeDb.collection('lot_payments').add({
      'saleId': saleId,
      'amount': amount,
      'paidAmount': 0.0,
      'penaltyAmount': 0.0,
      'penaltyApplied': false,
      'status': overdue
          ? LotPaymentStatus.overdue.name
          : LotPaymentStatus.scheduled.name,
      'period': 1,
      'dueDate': Timestamp.now(),
    });
    return ref.id;
  }

  test('recordPaymentWithAllocations covers lot_payments alongside dues', () async {
    // 1. Setup: Create a member with dues debt and a lot installment debt.
    final uid = 'member-1';

    // Add dues debt (type: membershipFee)
    await seedDues(uid, 1000.0);

    // Add lot installment debt (type: lotPayment) in lot_payments
    // The current firestoreService.recordPaymentWithAllocations ONLY reads from 'payments' collection
    final saleId = 'sale-1';
    await seedInstallment(uid, saleId, 500.0);

    // 2. Action: Call recordPaymentWithAllocations
    await firestoreService.recordPaymentWithAllocations(
      memberUid: uid,
      memberName: 'Member 1',
      paymentAmount: 1500.0,
      type: PaymentType.membershipFee,
      dueDate: DateTime.now(),
      recordedBy: 'Admin',
    );

    // 3. Verify:
    // With FIFO, it should have paid 1000 dues + 500 lot installment = 1500 total.
    // If the bug exists, lot_payments will remain 'scheduled' (unpaid).
    final lotPaymentSnap = await fakeDb.collection('lot_payments')
        .where('saleId', isEqualTo: saleId)
        .get();

    expect(lotPaymentSnap.docs.first.data()['status'], 'paid',
        reason: 'Bug: Lot installment was ignored by allocation engine');
  });

  test('partial payment pays oldest obligation first and leaves newer one scheduled', () async {
    final uid = 'member-1';
    await seedDues(uid, 1000.0);
    await seedInstallment(uid, 'sale-1', 500.0);

    await firestoreService.recordPaymentWithAllocations(
      memberUid: uid,
      memberName: 'Member 1',
      paymentAmount: 700.0,
      type: PaymentType.membershipFee,
      dueDate: DateTime.now(),
      recordedBy: 'Admin',
    );

    final duesSnap = await fakeDb.collection('payments').get();
    final dues = duesSnap.docs.first.data();
    expect(dues['paidAmount'], 700.0);
    expect(dues['status'], PaymentStatus.unpaid.name,
        reason: 'partial payment does not clear the dues doc');

    final lotSnap = await fakeDb.collection('lot_payments').get();
    expect(lotSnap.docs.first.data()['status'], LotPaymentStatus.scheduled.name,
        reason: 'installment untouched until dues fully covered');
  });

  test('payment exceeding total outstanding is rejected, nothing written', () async {
    final uid = 'member-1';
    await seedDues(uid, 1000.0);
    await seedInstallment(uid, 'sale-1', 500.0);

    await firestoreService.recordPaymentWithAllocations(
      memberUid: uid,
      memberName: 'Member 1',
      paymentAmount: 2000.0,
      type: PaymentType.membershipFee,
      dueDate: DateTime.now(),
      recordedBy: 'Admin',
    );

    final duesSnap = await fakeDb.collection('payments').get();
    expect(duesSnap.docs.first.data()['paidAmount'], 0.0,
        reason: 'excess payment must not be partially applied');

    final lotSnap = await fakeDb.collection('lot_payments').get();
    expect(lotSnap.docs.first.data()['status'], LotPaymentStatus.scheduled.name);

    final txSnap = await fakeDb.collection('payment_transactions').get();
    expect(txSnap.docs, isEmpty, reason: 'no transaction row for rejected payment');
  });

  test('mixed debt pays penalty before principal on the same obligation', () async {
    final uid = 'member-1';
    // Dues doc with a penalty already applied.
    await fakeDb.collection('payments').add({
      'uid': uid,
      'type': PaymentType.dues.name,
      'amount': 1000.0,
      'paidAmount': 0.0,
      'penaltyAmount': 45.0,
      'status': PaymentStatus.overdue.name,
      'dueDate': Timestamp.now(),
    });
    await seedInstallment(uid, 'sale-1', 500.0);

    await firestoreService.recordPaymentWithAllocations(
      memberUid: uid,
      memberName: 'Member 1',
      paymentAmount: 1045.0,
      type: PaymentType.dues,
      dueDate: DateTime.now(),
      recordedBy: 'Admin',
    );

    final duesSnap = await fakeDb.collection('payments').get();
    final dues = duesSnap.docs.first.data();
    expect(dues['paidAmount'], 1000.0);
    expect(dues['penaltyAmount'], 0.0);
    expect(dues['status'], PaymentStatus.paid.name);

    // Installment should be untouched: 1045 exactly covered the dues debt.
    final lotSnap = await fakeDb.collection('lot_payments').get();
    expect(lotSnap.docs.first.data()['status'], LotPaymentStatus.scheduled.name);
  });

  test('applyOverduePenalties marks overdue lot installments and sets penalty', () async {
    final uid = 'member-1';
    final saleId = 'sale-1';
    await fakeDb.collection('lot_sales').doc(saleId).set({'buyerUid': uid});
    await fakeDb.collection('lot_payments').add({
      'saleId': saleId,
      'amount': 500.0,
      'paidAmount': 0.0,
      'penaltyAmount': 0.0,
      'penaltyApplied': false,
      'status': LotPaymentStatus.scheduled.name,
      'period': 1,
      'dueDate': Timestamp.fromDate(
          DateTime.now().subtract(const Duration(days: 60))),
    });

    final count = await firestoreService.applyOverduePenalties(
      penaltyAmount: 45.0,
      graceDays: 30,
    );

    expect(count, 1);
    final snap = await fakeDb.collection('lot_payments').get();
    final data = snap.docs.first.data();
    expect(data['penaltyAmount'], 45.0);
    expect(data['penaltyApplied'], true);
    expect(data['status'], LotPaymentStatus.overdue.name);
  });

  test('identical payment resubmitted within 30s is rejected as duplicate',
      () async {
    final uid = 'member-1';
    await seedDues(uid, 1000.0);

    await firestoreService.recordPaymentWithAllocations(
      memberUid: uid,
      memberName: 'Member 1',
      paymentAmount: 1000.0,
      type: PaymentType.membershipFee,
      dueDate: DateTime.now(),
      recordedBy: 'Admin',
    );

    final second = await firestoreService.recordPaymentWithAllocations(
      memberUid: uid,
      memberName: 'Member 1',
      paymentAmount: 1000.0,
      type: PaymentType.membershipFee,
      dueDate: DateTime.now(),
      recordedBy: 'Admin',
    );

    expect(second.applied, isFalse,
        reason: 'same member + same amount within 30s is a double-submit');

    final txSnap = await fakeDb.collection('payment_transactions').get();
    expect(txSnap.docs.length, 1, reason: 'duplicate wrote no transaction row');
  });
}
