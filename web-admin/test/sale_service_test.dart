import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:lamhoai_admin/core/services/sale_service.dart';
import 'package:lamhoai_admin/core/models/lot_model.dart';
import 'package:lamhoai_admin/core/models/lot_sale_model.dart';
import 'package:lamhoai_admin/core/models/lot_payment_model.dart';

void main() {
  late FakeFirebaseFirestore fakeDb;
  late SaleService saleService;

  setUp(() {
    fakeDb = FakeFirebaseFirestore();
    saleService = SaleService(db: fakeDb);
  });

  group('SaleService.recordSale', () {
    test('cash sale creates one payment with status paid', () async {
      final lot = LotModel(
        id: 'lot-1',
        phase: 'Phase 1',
        block: 'Block 1',
        lotNumber: 'Lot 5',
        status: LotStatus.forSale,
        price: 40000.0,
        areaSqm: 100,
        mapX: 0,
        mapY: 0,
        updatedBy: 'admin',
        updatedAt: Timestamp.now(),
      );

      await saleService.recordSale(
        lot: lot,
        buyerUid: 'uid-1',
        buyerName: 'TestBuyer',
        downPayment: 0,
        termMonths: 0,
        annualInterestRate: 0,
        soldDate: DateTime(2026, 10, 30),
        recordedBy: 'admin_001',
      );

      // Verify lot status changed to occupied
      final lotDoc = await fakeDb.collection('lots').doc('lot-1').get();
      expect(lotDoc.data()?['status'], 'occupied');
      expect(lotDoc.data()?['uid'], 'uid-1');
      expect(lotDoc.data()?['ownerName'], 'TestBuyer');

      // Verify sale doc exists with paidOff status
      final salesSnap = await fakeDb.collection('lot_sales').get();
      expect(salesSnap.docs.length, 1);
      final sale = LotSaleModel.fromMap(salesSnap.docs.first.data(), salesSnap.docs.first.id);
      expect(sale.status, LotSaleStatus.paidOff);
      expect(sale.saleType, SaleType.cash);
      expect(sale.totalPrice, 40000.0);

      // Verify exactly one payment doc, status paid
      final paymentsSnap = await fakeDb.collection('lot_payments').get();
      expect(paymentsSnap.docs.length, 1);
      final payment = LotPaymentModel.fromMap(paymentsSnap.docs.first.data());
      expect(payment.status, LotPaymentStatus.paid);
      expect(payment.amount, 40000.0);
      expect(payment.period, 0);
    });

    test('installment sale creates N scheduled payments', () async {
      final lot = LotModel(
        id: 'lot-2',
        phase: 'Phase 2',
        block: 'Block 2',
        lotNumber: 'Lot 3',
        status: LotStatus.forSale,
        price: 50000.0,
        areaSqm: 120,
        mapX: 0,
        mapY: 0,
        updatedBy: 'admin',
        updatedAt: Timestamp.now(),
      );

      await saleService.recordSale(
        lot: lot,
        buyerUid: 'uid-2',
        buyerName: 'InstallmentBuyer',
        downPayment: 10000,
        termMonths: 12,
        annualInterestRate: 12.0,
        soldDate: DateTime(2026, 10, 30),
        recordedBy: 'admin_001',
      );

      // Verify N = 12 payment records created (13 with down payment)
      final paymentsSnap = await fakeDb.collection('lot_payments').get();
      expect(paymentsSnap.docs.length, 13);

      // Period 0 (down payment) should be paid
      final p0 = paymentsSnap.docs
          .firstWhere((d) => (d.data()['period'] as num?)?.toInt() == 0);
      expect((p0.data()['status'] as String?), 'paid');

      // Periods 1..12 should be scheduled
      for (var i = 1; i <= 12; i++) {
        final doc = paymentsSnap.docs
            .firstWhere((d) => (d.data()['period'] as num?)?.toInt() == i);
        expect((doc.data()['status'] as String?), 'scheduled');
      }

      // Verify sale status is active
      final salesSnap = await fakeDb.collection('lot_sales').get();
      expect(salesSnap.docs.length, 1);
      final sale = LotSaleModel.fromMap(salesSnap.docs.first.data(), salesSnap.docs.first.id);
      expect(sale.status, LotSaleStatus.active);
      expect(sale.saleType, SaleType.installment);
      expect(sale.termMonths, 12);
    });

    test('recordPayment pays the first unpaid period', () async {
      final lot = LotModel(
        id: 'lot-3',
        phase: 'Phase 3',
        block: 'Block 3',
        lotNumber: 'Lot 1',
        status: LotStatus.forSale,
        price: 30000.0,
        areaSqm: 100,
        mapX: 0,
        mapY: 0,
        updatedBy: 'admin',
        updatedAt: Timestamp.now(),
      );

      await saleService.recordSale(
        lot: lot,
        buyerUid: 'uid-3',
        buyerName: 'PayerBuyer',
        downPayment: 0,
        termMonths: 3,
        annualInterestRate: 0,
        soldDate: DateTime(2026, 10, 30),
        recordedBy: 'admin',
      );

      final salesSnap = await fakeDb.collection('lot_sales').get();
      final saleId = salesSnap.docs.first.id;

      await saleService.recordPayment(
        saleId: saleId,
        payer: 'PayerBuyer',
        paidBy: 'Officer',
        method: PaymentMethod.cash,
      );

      final paymentsSnap = await fakeDb.collection('lot_payments')
          .where('saleId', isEqualTo: saleId)
          .get();

      final docs = paymentsSnap.docs.toList();
      docs.sort((a, b) => (a.data()['period'] as num).compareTo(b.data()['period'] as num));
      final payments = docs.map((d) => LotPaymentModel.fromMap(d.data())).toList();

      // Period 1 (first period, as period 0 was not created) should now be paid
      expect(payments[0].period, 1);
      expect(payments[0].status, LotPaymentStatus.paid);
      expect(payments[0].paidBy, 'Officer');
      expect(payments[0].payer, 'PayerBuyer');
      expect(payments[0].paymentMethod, PaymentMethod.cash);
      // Period 2 should still be scheduled
      expect(payments[1].status, LotPaymentStatus.scheduled);
    });
  });
}