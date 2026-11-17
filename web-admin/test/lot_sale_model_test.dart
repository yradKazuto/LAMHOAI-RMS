import 'package:flutter_test/flutter_test.dart';
import 'package:lamhoai_admin/core/models/lot_sale_model.dart';

void main() {
  LotSaleModel sale({List<String> coOwnerUids = const [], List<String> ownerUids = const []}) =>
      LotSaleModel(
        id: 'sale-1',
        lotId: 'lot-1',
        lotNumber: 'Lot 5',
        phase: 'Phase 1',
        block: 'Block 1',
        buyerUid: 'buyer-uid',
        buyerName: 'Buyer',
        coOwnerUids: coOwnerUids,
        ownerUids: ownerUids,
        saleType: SaleType.installment,
        totalPrice: 100000,
        downPayment: 10000,
        financedAmount: 90000,
        termMonths: 60,
        annualInterestRate: 12,
        monthlyPayment: 2000,
        status: LotSaleStatus.active,
        soldDate: DateTime(2026, 1, 1),
        saleSeq: 1,
        createdBy: 'admin',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

  test('co-owner lists survive a Firestore round-trip', () {
    final s = sale(coOwnerUids: ['a', 'b'], ownerUids: ['buyer-uid', 'a', 'b']);
    final back = LotSaleModel.fromMap(s.toMap(), s.id);
    expect(back.coOwnerUids, ['a', 'b']);
    expect(back.ownerUids, ['buyer-uid', 'a', 'b']);
  });

  test('old sale docs without the fields load as sole-owner', () {
    final back = LotSaleModel.fromMap(sale().toMap()..remove('coOwnerUids')..remove('ownerUids'), 'x');
    expect(back.coOwnerUids, isEmpty);
    expect(back.ownerUids, isEmpty);
  });
}
