import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:lamhoai_admin/core/models/lot_model.dart';
import 'package:lamhoai_admin/core/models/sales_rate_model.dart';
import 'package:lamhoai_admin/core/utils/lot_pricing.dart';

void main() {
  LotModel lot(double area, {double? price}) => LotModel(
        id: 'lot-1',
        phase: 'Phase 1',
        block: 'Block 1',
        lotNumber: 'Lot 5',
        status: LotStatus.forSale,
        price: price ?? 0,
        areaSqm: area,
        mapX: 0,
        mapY: 0,
        updatedBy: 'admin',
        updatedAt: Timestamp.now(),
      );

  test('price is area times the sample rate until the HOA confirms one', () {
    expect(LotPricing.priceFor(lot(100)), 100 * LotPricing.sampleRatePerSqm);
  });

  test('configured rate overrides the sample rate', () {
    expect(LotPricing.priceFor(lot(100), ratePerSqm: 2500), 250000.0);
  });

  test('zero configured rate falls back to the sample rate', () {
    expect(
      LotPricing.priceFor(lot(100), ratePerSqm: 0),
      100 * LotPricing.sampleRatePerSqm,
    );
  });

  test('lot with no area falls back to its saved price', () {
    expect(LotPricing.priceFor(lot(0, price: 75000)), 75000.0);
  });

  SalesRateEntry row(String id, int year, int month, double rate) =>
      SalesRateEntry(
        id: id,
        effectiveFrom: DateTime(year, month, 1),
        ratePerSqm: rate,
        setBy: 'admin',
        createdAt: DateTime(2026, 1, 1),
      );

  test('rateFor picks the row in force on the date', () {
    final rows = [row('a', 2026, 1, 2000), row('b', 2027, 1, 2500)];
    expect(LotPricing.rateFor(DateTime(2026, 6, 15), rows), 2000.0);
    expect(LotPricing.rateFor(DateTime(2027, 1, 1), rows), 2500.0); // boundary day
    expect(LotPricing.rateFor(DateTime(2027, 9, 1), rows), 2500.0);
  });

  test('rateFor is 0 with no rows or before the first row', () {
    expect(LotPricing.rateFor(DateTime.now(), []), 0.0);
    expect(
      LotPricing.rateFor(DateTime(2025, 12, 31), [row('a', 2026, 1, 2000)]),
      0.0,
    );
  });

  test('entryFor returns the winning row itself', () {
    final rows = [row('a', 2026, 1, 2000), row('b', 2027, 1, 2500)];
    expect(LotPricing.entryFor(DateTime(2027, 3, 1), rows)?.id, 'b');
    expect(LotPricing.entryFor(DateTime(2025, 1, 1), rows), isNull);
  });
}
