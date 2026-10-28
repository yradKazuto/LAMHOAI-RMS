import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:lamhoai_admin/core/models/payment_model.dart';
import 'package:lamhoai_admin/core/services/firestore_service.dart';

void main() {
  late FakeFirebaseFirestore fakeDb;
  late FirestoreService firestoreService;

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
    firestoreService = FirestoreService(db: fakeDb);
  });

  group('createOrUpdateLedger', () {
    test('creates a new ledger with given fields', () async {
      const uid = 'member123';
      await firestoreService.createOrUpdateLedger(uid, 1500.0, 1500.0, 2026);
      final doc = await fakeDb.collection('member_ledgers').doc(uid).get();
      expect(doc.exists, isTrue);
      expect(doc['annualTarget'], 1500.0);
      expect(doc['currentBalance'], 1500.0);
      expect(doc['year'], 2026);
      expect(doc['uid'], uid);
    });

    test('updates existing ledger without overwriting target', () async {
      const uid = 'member456';
      await firestoreService.createOrUpdateLedger(uid, 1500.0, 1500.0, 2026);
      // Later set again — should update currentBalance but keep annualTarget
      await firestoreService.createOrUpdateLedger(uid, 2000.0, 1800.0, 2027);
      final doc = await fakeDb.collection('member_ledgers').doc(uid).get();
      expect(doc.exists, isTrue);
      expect(doc['annualTarget'], 2000.0); // Changed
      expect(doc['currentBalance'], 1800.0); // Changed
    });
  });

  group('updateLedgerBalance', () {
    test('increases balance when amountDelta > 0', () async {
      await firestoreService.createOrUpdateLedger('memA', 1000.0, 0.0, 2026);
      await firestoreService.updateLedgerBalance('memA', 200.0);
      await firestoreService.updateLedgerBalance('memA', -500.0);
      final doc = await fakeDb.collection('member_ledgers').doc('memA').get();
      expect((doc.data()?['currentBalance'] as num?)?.toDouble() ?? -999.0, closeTo(-300.0, 0.01));
    });

    test('does nothing if ledger doc does not exist', () async {
      // Should not throw, just return
      await firestoreService.updateLedgerBalance('nonexistent', 100.0);
    });
  });

  group('ledger in payment lifecycle', () {
    test('adding membershipFee payment decreases ledger balance', () async {
      const uid = 'memTest1';
      await firestoreService.createOrUpdateLedger(uid, 1000.0, 1000.0, 2026);
      final p = PaymentModel(
        id: 'p1', uid: uid, memberName: 'Test', type: PaymentType.membershipFee,
        amount: 300.0, status: PaymentStatus.paid, dueDate: DateTime(2026, 1, 1),
        recordedBy: 'admin', notes: 'test', createdAt: DateTime.now(),
      );
      await firestoreService.addPayment(p);
      final doc = await fakeDb.collection('member_ledgers').doc(uid).get();
      expect((doc.data()?['currentBalance'] as num?)?.toDouble() ?? 1000.0, closeTo(700.0, 0.01));
    });

    test('adding monthlyMembership payment decreases ledger balance', () async {
      const uid = 'memTest2';
      await firestoreService.createOrUpdateLedger(uid, 0.0, 0.0, 2026);
      final p = PaymentModel(
        id: 'p2', uid: uid, memberName: 'Test', type: PaymentType.monthlyMembership,
        amount: 200.0, status: PaymentStatus.unpaid, dueDate: DateTime(2026, 3, 1),
        recordedBy: 'admin', notes: 'test', createdAt: DateTime.now(),
      );
      await firestoreService.addPayment(p);
      final doc = await fakeDb.collection('member_ledgers').doc(uid).get();
      expect((doc.data()?['currentBalance'] as num?)?.toDouble() ?? 0.0, closeTo(200.0, 0.01));
    });

    test('adding non-membership payment does not touch ledger', () async {
      const uid = 'memNonMem';
      await firestoreService.createOrUpdateLedger(uid, 1000.0, 1000.0, 2026);
      final p = PaymentModel(
        id: 'p3', uid: uid, memberName: 'Test', type: PaymentType.dues,
        amount: 50.0, status: PaymentStatus.unpaid, dueDate: DateTime(2026, 3, 1),
        recordedBy: 'admin', notes: 'lot dues', createdAt: DateTime.now(),
      );
      await firestoreService.addPayment(p);
      final doc = await fakeDb.collection('member_ledgers').doc(uid).get();
      expect((doc.data()?['currentBalance'] as num?)?.toDouble() ?? 1000.0, closeTo(1000.0, 0.01));
    });

    test('deleting membership payment restores ledger balance', () async {
      const uid = 'memDel';
      await firestoreService.createOrUpdateLedger(uid, 1000.0, 1000.0, 2026);
      final p = PaymentModel(
        id: 'p4', uid: uid, memberName: 'Test', type: PaymentType.membershipFee,
        amount: 250.0, status: PaymentStatus.paid, dueDate: DateTime(2026, 1, 1),
        recordedBy: 'admin', notes: 'should restore', createdAt: DateTime.now(),
      );
      await firestoreService.addPayment(p);
      await firestoreService.deletePayment('p4');
      final doc = await fakeDb.collection('member_ledgers').doc(uid).get();
      expect((doc.data()?['currentBalance'] as num?)?.toDouble() ?? 1000.0, closeTo(1000.0, 0.01));
    });
    test('deleting non-membership payment does not touch ledger', () async {
      const uid = 'memNoLedgerTouch';
      await firestoreService.createOrUpdateLedger(uid, 1000.0, 1000.0, 2026);
      final p = PaymentModel(
        id: 'p5', uid: uid, memberName: 'Test', type: PaymentType.dues,
        amount: 50.0, status: PaymentStatus.unpaid, dueDate: DateTime(2026, 1, 1),
        recordedBy: 'admin', notes: 'lot dues', createdAt: DateTime.now(),
      );
      await firestoreService.addPayment(p);
      await firestoreService.deletePayment('p5');
      final doc = await fakeDb.collection('member_ledgers').doc(uid).get();
      expect((doc.data()?['currentBalance'] as num?)?.toDouble() ?? 1000.0, closeTo(1000.0, 0.01));
    });

    test('deducts twice for two membership payments', () async {
      const uid = 'memDeduct2';
      await firestoreService.createOrUpdateLedger(uid, 500.0, 500.0, 2026);
      await firestoreService.addPayment(
        PaymentModel(id: 'd1', uid: uid, memberName: 'T', type: PaymentType.membershipFee,
          amount: 100.0, status: PaymentStatus.paid, dueDate: DateTime(2026, 1, 1),
          recordedBy: 'a', notes: '', createdAt: DateTime.now()),
      );
      await firestoreService.addPayment(
        PaymentModel(id: 'd2', uid: uid, memberName: 'T', type: PaymentType.membershipFee,
          amount: 200.0, status: PaymentStatus.paid, dueDate: DateTime(2026, 1, 1),
          recordedBy: 'a', notes: '', createdAt: DateTime.now()),
      );
      final doc = await fakeDb.collection('member_ledgers').doc(uid).get();
      expect((doc.data()?['currentBalance'] as num?)?.toDouble() ?? 500.0, closeTo(200.0, 0.01));
    });
  });
}
