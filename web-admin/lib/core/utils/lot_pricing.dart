import '../models/lot_model.dart';
import '../models/sales_rate_model.dart';
import '../services/amortization_service.dart';

class LotPricing {
  /// DEMO sample rate — ₱/sqm until the HOA confirms the real one.
  /// ponytail: sample pricing; a `sales_rates` row in force on the date
  /// overrides this wherever an admin has set one.
  static const double sampleRatePerSqm = 2000.0;

  static const int years = 25;

  static int get totalMonths => years * 12;

  /// Price used for a sale: area x rate. [ratePerSqm] and [cornerRatePerSqm]
  /// are from the row in force on the sale date (LotPricing.rateFor). A
  /// corner lot uses the corner rate when one is set (> 0), otherwise the
  /// normal rate; a null/zero normal rate falls back to the DEMO sample rate.
  /// [isCorner] overrides lot.isCorner (for previewing an unsaved choice).
  /// Falls back to the lot's saved price when the area is not set.
  static double priceFor(
    LotModel lot, {
    double? ratePerSqm,
    double? cornerRatePerSqm,
    bool? isCorner,
  }) {
    final area = (lot.areaSqm ?? 0).toDouble();
    if (area <= 0) return (lot.price ?? 0).toDouble();
    final corner = isCorner ?? lot.isCorner;
    final double rate;
    if (corner && cornerRatePerSqm != null && cornerRatePerSqm > 0) {
      rate = cornerRatePerSqm;
    } else if (ratePerSqm != null && ratePerSqm > 0) {
      rate = ratePerSqm;
    } else {
      rate = sampleRatePerSqm;
    }
    return area * rate;
  }

  /// The rate row in force on [date] — the latest row whose effective date
  /// is on or before it. Rows must be sorted by effectiveFrom ascending
  /// (RateService sorts). Null when the table is empty or every row starts
  /// in the future; callers then fall back to the DEMO sample rate.
  static SalesRateEntry? entryFor(
    DateTime date,
    List<SalesRateEntry> rows,
  ) {
    SalesRateEntry? current;
    for (final r in rows) {
      if (!r.effectiveFrom.isAfter(date)) current = r;
    }
    return current;
  }

  /// Rate in force on [date]; 0 when none applies.
  static double rateFor(DateTime date, List<SalesRateEntry> rows) =>
      entryFor(date, rows)?.ratePerSqm ?? 0.0;

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