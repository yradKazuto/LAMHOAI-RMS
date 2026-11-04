import 'package:flutter_test/flutter_test.dart';
import 'package:lamhoai_admin/core/services/amortization_service.dart';
import 'package:lamhoai_admin/core/services/transaction_id_service.dart';
import 'package:lamhoai_admin/core/models/lot_payment_model.dart';
import 'package:lamhoai_admin/core/models/lot_sale_model.dart';

void main() {
  const createdBy = 'admin1';

  LotSaleModel installmentSale({
    double totalPrice = 240000,
    double downPayment = 40000,
    int termMonths = 12,
    double annualRate = 12.0,
    int saleSeq = 1,
    DateTime? firstDueDate,
  }) {
    final financed = totalPrice - downPayment;
    final m = AmortizationService.monthlyPayment(financed, annualRate,
        termMonths);
    return LotSaleModel(
      id: 'sale1', lotId: 'lot1', lotNumber: '12', phase: '1', block: '3',
      buyerUid: 'buyer1', buyerName: 'Juan Dela Cruz', saleType: SaleType.installment,
      totalPrice: totalPrice, downPayment: downPayment, financedAmount: financed,
      termMonths: termMonths, annualInterestRate: annualRate,
      monthlyPayment: m, status: LotSaleStatus.active,
      soldDate: firstDueDate ?? DateTime(2026, 1, 15), saleSeq: saleSeq,
      createdBy: createdBy,
      createdAt: DateTime.now(), updatedAt: DateTime.now(),
    );
  }

  group('monthlyPayment', () {
    test('spot-check matches closed-form formula', () {
      // P=100000, annual=12%, n=12 => r=0.01, factor=1.126825...
      // M = 100000 * 0.01 * 1.126825 / (1.126825 - 1) ≈ 8884.88
      final m = AmortizationService.monthlyPayment(100000.0, 12.0, 12);
      expect(m, closeTo(8884.88, 0.02));
    });

    test('zero rate is a flat principal / months split', () {
      expect(AmortizationService.monthlyPayment(12000.0, 0.0, 12), 1000.0);
    });

    test('non-positive principal or months returns 0', () {
      expect(AmortizationService.monthlyPayment(0.0, 12.0, 12), 0.0);
      expect(AmortizationService.monthlyPayment(-100.0, 12.0, 12), 0.0);
      expect(AmortizationService.monthlyPayment(1000.0, 12.0, 0), 0.0);
      expect(AmortizationService.monthlyPayment(1000.0, 12.0, -3), 0.0);
    });
  });

  group('buildSchedule — installment', () {
    test('schedule sums to financedAmount and ends at balance 0', () {
      final sale = installmentSale();
      final periods = AmortizationService.buildSchedule(
        sale: sale,
        firstDueDate: DateTime(2026, 2, 1),
        createdBy: createdBy,
        saleSeq: 1,
      );

      // Period 0 (down payment) + 12 installments.
      expect(periods.length, 13);

      // Period 0: down payment only.
      final p0 = periods.firstWhere((p) => p.period == 0);
      expect(p0.amount, closeTo(40000.0, 0.01));
      expect(p0.principalPortion, closeTo(40000.0, 0.01));
      expect(p0.interestPortion, 0.0);
      expect(p0.remainingBalance, closeTo(200000.0, 0.01));
      expect(p0.transactionId, 'LP-2026-001-000');

      // Installment periods sum of principal == financedAmount.
      final installmentPrincipal = periods
          .where((p) => p.period > 0)
          .fold<double>(0.0, (s, p) => s + p.principalPortion);
      expect(installmentPrincipal, closeTo(200000.0, 0.05));

      // Total principal across all periods == totalPrice.
      final totalPrincipal = periods
          .fold<double>(0.0, (s, p) => s + p.principalPortion);
      expect(totalPrincipal, closeTo(240000.0, 0.05));

      // Final period clears the balance exactly.
      final last = periods.last;
      expect(last.remainingBalance, closeTo(0.0, 0.005));
      expect(last.period, 12);
      expect(last.transactionId, 'LP-2026-001-012');
    });

    test('zero-interest installment: all payments equal', () {
      final sale = installmentSale(totalPrice: 120000, downPayment: 0,
          termMonths: 12, annualRate: 0.0);
      final periods = AmortizationService.buildSchedule(
        sale: sale, firstDueDate: DateTime(2026, 3, 1),
        createdBy: createdBy, saleSeq: 2,
      );

      expect(periods.length, 12); // no down payment -> 12 periods
      for (final p in periods) {
        expect(p.amount, closeTo(10000.0, 0.01)); // 120000 / 12
        expect(p.interestPortion, 0.0);
        expect(p.principalPortion, closeTo(10000.0, 0.01));
      }
      expect(periods.last.remainingBalance, closeTo(0.0, 0.005));
    });

    test('principal increases and interest decreases month over month', () {
      final sale = installmentSale();
      final periods = AmortizationService.buildSchedule(
        sale: sale, firstDueDate: DateTime(2026, 2, 1),
        createdBy: createdBy, saleSeq: 1,
      );
      final installments = periods.where((p) => p.period > 0).toList();

      for (var i = 1; i < installments.length; i++) {
        expect(installments[i].principalPortion,
            greaterThanOrEqualTo(installments[i - 1].principalPortion));
        expect(installments[i].interestPortion,
            lessThanOrEqualTo(installments[i - 1].interestPortion));
      }
    });

    test('due dates advance one month per period', () {
      final sale = installmentSale();
      final periods = AmortizationService.buildSchedule(
        sale: sale, firstDueDate: DateTime(2026, 1, 15),
        createdBy: createdBy, saleSeq: 1,
      );
      final installments = periods.where((p) => p.period > 0).toList();

      expect(installments.first.dueDate, DateTime(2026, 2, 15));
      expect(installments.last.dueDate, DateTime(2027, 1, 15));
    });

    group('buildSchedule — end-of-month dates', () {
      test('Jan 31 anchor clamps to Feb last day (28 in non-leap year)', () {
        final sale = installmentSale(firstDueDate: DateTime(2026, 1, 31));
        final periods = AmortizationService.buildSchedule(
          sale: sale, firstDueDate: DateTime(2026, 1, 31),
          createdBy: createdBy, saleSeq: 1,
        );
        final installments = periods.where((p) => p.period > 0).toList();

        // Feb 31 does not exist -> clamps to Feb 28, NOT Mar 3.
        expect(installments.first.dueDate, DateTime(2026, 2, 28));
        expect(installments[1].dueDate, DateTime(2026, 3, 31));
        expect(installments[2].dueDate, DateTime(2026, 4, 30));
        // 12 months from Jan 2026 lands in Jan 2027, day clamped to 31.
        expect(installments.last.dueDate, DateTime(2027, 1, 31));
      });

      test('Dec 31 anchor crosses into next January', () {
        final sale = installmentSale(firstDueDate: DateTime(2026, 12, 31));
        final periods = AmortizationService.buildSchedule(
          sale: sale, firstDueDate: DateTime(2026, 12, 31),
          createdBy: createdBy, saleSeq: 1,
        );
        final installments = periods.where((p) => p.period > 0).toList();

        expect(installments.first.dueDate, DateTime(2027, 1, 31));
        expect(installments.last.dueDate, DateTime(2027, 12, 31));
      });

      test('leap-year Feb 29 anchor advances to Mar 29 (not Feb 30)', () {
        final sale = installmentSale(firstDueDate: DateTime(2024, 2, 29));
        final periods = AmortizationService.buildSchedule(
          sale: sale, firstDueDate: DateTime(2024, 2, 29),
          createdBy: createdBy, saleSeq: 1,
        );
        final installments = periods.where((p) => p.period > 0).toList();

        expect(installments.first.dueDate, DateTime(2024, 3, 29));
        expect(installments[1].dueDate, DateTime(2024, 4, 29));
        // Feb 29 + 12 months -> Feb 2025 has no 29th, clamps to Feb 28.
        expect(installments.last.dueDate, DateTime(2025, 2, 28));
      });

      test('each date is computed independently from the anchor (no chaining drift)', () {
        final sale = installmentSale(firstDueDate: DateTime(2026, 1, 31));
        final periods = AmortizationService.buildSchedule(
          sale: sale, firstDueDate: DateTime(2026, 1, 31),
          createdBy: createdBy, saleSeq: 1,
        );
        final installments = periods.where((p) => p.period > 0).toList();

        // Month 13 from Jan -> Feb of next year, day clamped to last day of Feb.
        expect(installments[11].dueDate, DateTime(2027, 1, 31));
        expect(installments.length, 12);
      });
    });

    test('down payment period keeps firstDueDate unchanged (period 0)', () {
      final sale = installmentSale(firstDueDate: DateTime(2026, 1, 31));
      final periods = AmortizationService.buildSchedule(
        sale: sale, firstDueDate: DateTime(2026, 1, 31),
        createdBy: createdBy, saleSeq: 1,
      );
      final p0 = periods.firstWhere((p) => p.period == 0);
      expect(p0.dueDate, DateTime(2026, 1, 31));
      expect(p0.amount, closeTo(40000.0, 0.01));
    });
  });

  group('buildSchedule — cash', () {
    test('single lump-sum period equal to total price, balance 0', () {
      final sale = LotSaleModel(
        id: 'saleCash', lotId: 'lot9', lotNumber: '1', phase: '1', block: '1',
        buyerUid: 'buyer9', buyerName: 'Maria Clara',
        saleType: SaleType.cash, totalPrice: 150000, downPayment: 150000,
        financedAmount: 0, termMonths: 0, annualInterestRate: 0,
        monthlyPayment: 0, status: LotSaleStatus.active,
        soldDate: DateTime(2026, 1, 20), saleSeq: 5,
        createdBy: createdBy, createdAt: DateTime.now(), updatedAt: DateTime.now(),
      );
      final periods = AmortizationService.buildSchedule(
        sale: sale, firstDueDate: DateTime(2026, 1, 20),
        createdBy: createdBy, saleSeq: 5,
      );

      expect(periods.length, 1);
      final p = periods.first;
      expect(p.period, 0);
      expect(p.amount, closeTo(150000.0, 0.01));
      expect(p.principalPortion, closeTo(150000.0, 0.01));
      expect(p.interestPortion, 0.0);
      expect(p.remainingBalance, closeTo(0.0, 0.005));
      expect(p.transactionId, 'LP-2026-005-000');
    });
  });
}
