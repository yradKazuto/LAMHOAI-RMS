import '../models/lot_model.dart';
import '../services/amortization_service.dart';

class LotPricing {
  static const double areaThresholdSqm = 120;
  static const double monthlyLarge = 610; // area >= 120 sqm
  static const double monthlySmall = 590; // area < 120 sqm
  static const int years = 25;

  static int get totalMonths => years * 12;

  static double monthlyInstallment(double areaSqm) =>
      areaSqm >= areaThresholdSqm ? monthlyLarge : monthlySmall;

  static double totalInstallment(double areaSqm) =>
      monthlyInstallment(areaSqm) * totalMonths;

  /// Price used for a sale. Uses the area-based total installment.
  /// Falls back to the lot's saved price when the area is not set.
  static double priceFor(LotModel lot) {
    final area = (lot.areaSqm ?? 0).toDouble();
    if (area > 0) return totalInstallment(area);
    return (lot.price ?? 0).toDouble();
  }

  /// Monthly payment for a financed amount. Handles 0% interest.
  static double monthlyFor(double financed, double annualRate, int months) {
    if (months <= 0) return 0;
    if (annualRate <= 0) return financed / months;
    return AmortizationService.monthlyPayment(financed, annualRate, months);
  }

  /// 183000 -> ₱183,000   |   1234.5 -> ₱1,234.50
  static String peso(double v) {
    final whole = v == v.roundToDouble();
    final parts = v.toStringAsFixed(whole ? 0 : 2).split('.');
    final intPart = parts[0].replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (m) => ',',
    );
    return '₱$intPart${parts.length > 1 ? '.${parts[1]}' : ''}';
  }
}