import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:lamhoai_admin/core/services/sale_service.dart';
import 'package:lamhoai_admin/core/models/rate_schedule_model.dart';
import 'package:lamhoai_admin/core/models/lot_sale_model.dart';
import 'package:lamhoai_admin/core/services/amortization_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  late FakeFirebaseFirestore instance;
  late SaleService service;

  setUp(() {
    instance = FakeFirebaseFirestore();
    service = SaleService(db: instance);
  });

  test('recalculateActiveSales updates active sale with new tiered rate', () async {
    final existingSchedule = RateScheduleModel(
      id: 'sched-1',
      year: 2027,
      isActive: true,
      tiers: [
        RateTier(label: 'Below 120sqm', threshold: 0, rate: 5000),
        RateTier(label: '120sqm and up', threshold: 120, rate: 6000),
      ],
    );
    await instance.collection('rate_schedules').doc(existingSchedule.id).set(existingSchedule.toMap());

    final sale = LotSaleModel(
      id: 'sale-test-1',
      lotId: 'lot-1',
      lotNumber: '2',
      phase: '1',
      block: '1',
      buyerUid: 'u-buyer-1',
      buyerName: 'Buyer One',
      saleType: SaleType.installment,
      totalPrice: 240000,
      downPayment: 60000,
      financedAmount: 180000,
      termMonths: 12,
      annualInterestRate: 6.0,
      monthlyPayment: 15000.0,
      status: LotSaleStatus.active,
      soldDate: DateTime.now(),
      saleSeq: 1,
      createdBy: 'admin',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await instance.collection('lot_sales').doc(sale.id).set(sale.toMap());

    // Action
    final expectedFinanced = (200 * 6000.0) - 60000.0;
    final expectedMonthly = AmortizationService.monthlyPayment(expectedFinanced, 6.0, 12);
    await service.recalculateActiveSales(existingSchedule, saleArea: 200);

    // Verify
    final updatedSale = await service.getSale('sale-test-1');
    print('Updated sale: ${updatedSale?.toMap()}');
    expect(updatedSale?.monthlyPayment, closeTo(expectedMonthly, 0.01));

    // Verify future periods exist — recalculated schedule
    final payments = await instance.collection('lot_payments').where('saleId', isEqualTo: 'sale-test-1').get();
    expect(payments.docs.length, greaterThanOrEqualTo(6));
  });
}
