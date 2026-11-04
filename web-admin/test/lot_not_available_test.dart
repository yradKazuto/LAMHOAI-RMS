import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:lamhoai_admin/core/services/sale_service.dart';
import 'package:lamhoai_admin/core/models/lot_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

void main() {
  test('Available lot passes validation', () async {
    final instance = FakeFirebaseFirestore();
    final saleService = SaleService(db: instance);

    await instance.collection('lots').doc('lot1').set({
      'status': 'vacant',
      'uid': null,
    });

    expect(() => saleService.recordSale(
      lot: LotModel(
        id: 'lot1',
        phase: 'P1',
        block: 'B1',
        lotNumber: 'L1',
        status: LotStatus.vacant,
        updatedBy: 'test',
        updatedAt: Timestamp.now(),
      ),
      buyerUid: 'buyer1',
      buyerName: 'Buyer',
      downPayment: 0,
      termMonths: 0,
      annualInterestRate: 0,
      soldDate: DateTime.now(),
      recordedBy: 'test',
    ), returnsNormally);
  });

  test('Occupied lot fails with exception', () async {
    final instance = FakeFirebaseFirestore();
    final saleService = SaleService(db: instance);

    await instance.collection('lots').doc('lot1').set({
      'status': 'occupied',
      'uid': 'someoneElse',
    });

    expect(() => saleService.recordSale(
      lot: LotModel(
        id: 'lot1',
        phase: 'P1',
        block: 'B1',
        lotNumber: 'L1',
        status: LotStatus.occupied,
        updatedBy: 'test',
        updatedAt: Timestamp.now(),
      ),
      buyerUid: 'buyer1',
      buyerName: 'Buyer',
      downPayment: 0,
      termMonths: 0,
      annualInterestRate: 0,
      soldDate: DateTime.now(),
      recordedBy: 'test',
    ), throwsA(isA<LotNotAvailableException>()));
  });

  test('LotNotAvailableException message contains lotId', () {
    const e = LotNotAvailableException('lot123');
    expect(e.lotId, 'lot123');
    expect(e.toString(), contains('lot123'));
  });
}
