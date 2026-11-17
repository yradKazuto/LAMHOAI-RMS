// core/services/rate_service.dart
//
// Manages the sales rate per square metre: a table of DATED rows in
// `sales_rates` (per-year / seasonal pricing). A sale is priced at the row
// in force on its sale date; the wizards and lot dialog resolve today's
// row. Each row may also carry a corner-lot rate. Collection
// `rate_schedules` (year + area tiers) is an older shell —
// kept untouched, nothing prices from it yet.

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sales_rate_model.dart';
import '../models/rate_schedule_model.dart';
import '../utils/lot_pricing.dart';

class RateService {
  final FirebaseFirestore _db;

  RateService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  // ── Sales rate table (sales_rates) ────────────────────────────────────────

  /// All rate rows, ascending by effective date. When the table is empty,
  /// the legacy flat config (`sales_rate/config`, demo era) stands in as one
  /// always-on row, so a configured rate keeps applying until a dated row
  /// replaces it.
  Future<List<SalesRateEntry>> getSalesRates() async {
    final snap = await _db
        .collection('sales_rates')
        .orderBy('effectiveFrom')
        .get();
    if (snap.docs.isNotEmpty) {
      return snap.docs
          .map((d) => SalesRateEntry.fromMap(d.data(), d.id))
          .toList();
    }

    final cfg = await _db.collection('sales_rate').doc('config').get();
    if (!cfg.exists) return [];
    final legacy = (cfg.data()?['ratePerSqm'] as num?)?.toDouble() ?? 0.0;
    if (legacy <= 0) return [];
    return [
      SalesRateEntry(
        id: 'config',
        effectiveFrom: DateTime(2000),
        ratePerSqm: legacy,
        setBy: cfg.data()?['updatedBy'] as String? ?? '',
        createdAt:
            (cfg.data()?['updatedAt'] as dynamic)?.toDate() ?? DateTime(2000),
      ),
    ];
  }

  Stream<List<SalesRateEntry>> streamSalesRates() {
    return _db
        .collection('sales_rates')
        .orderBy('effectiveFrom')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => SalesRateEntry.fromMap(d.data(), d.id))
            .toList());
  }

  /// The rate in force today, as the flat model every caller already reads.
  /// Null when no row applies (empty table or all rows future-dated) —
  /// callers fall back to the DEMO sample rate.
  Future<SalesRateModel?> getSalesRate() => _resolveAt(DateTime.now());

  /// The rate in force on [date] — used when recording a sale, so a sale is
  /// priced at the rate of its own date, not today's.
  Future<SalesRateModel?> getSalesRateFor(DateTime date) => _resolveAt(date);

  Future<SalesRateModel?> _resolveAt(DateTime date) async {
    final entry = LotPricing.entryFor(date, await getSalesRates());
    if (entry == null) return null;
    return SalesRateModel(
      ratePerSqm: entry.ratePerSqm,
      cornerRatePerSqm: entry.cornerRatePerSqm,
      updatedBy: entry.setBy,
      updatedAt: entry.createdAt,
    );
  }

  /// Adds a dated rate row. [effectiveFrom] may be today or later — never
  /// the past, since days already priced keep their rate — and no two rows
  /// may share a date, which would make the lookup ambiguous.
  /// [cornerRatePerSqm] is optional; null means corner lots use the normal
  /// rate for this row.
  Future<void> addSalesRate({
    required double ratePerSqm,
    double? cornerRatePerSqm,
    required DateTime effectiveFrom,
    required String setBy,
  }) async {
    if (ratePerSqm.isNaN || ratePerSqm.isInfinite || ratePerSqm <= 0) {
      throw Exception('Rate must be greater than zero.');
    }
    if (cornerRatePerSqm != null &&
        (cornerRatePerSqm.isNaN ||
            cornerRatePerSqm.isInfinite ||
            cornerRatePerSqm <= 0)) {
      throw Exception('Corner rate must be greater than zero, or left blank.');
    }
    final day = _dayOnly(effectiveFrom);
    if (day.isBefore(_dayOnly(DateTime.now()))) {
      throw Exception('New rate must take effect today or later.');
    }
    final clash = await _db
        .collection('sales_rates')
        .where('effectiveFrom', isEqualTo: Timestamp.fromDate(day))
        .limit(1)
        .get();
    if (clash.docs.isNotEmpty) {
      throw Exception('A rate already starts on that date.');
    }
    await _db.collection('sales_rates').add(SalesRateEntry(
          id: '',
          effectiveFrom: day,
          ratePerSqm: ratePerSqm,
          cornerRatePerSqm: cornerRatePerSqm,
          setBy: setBy,
          createdAt: DateTime.now(),
        ).toMap());
  }

  /// Removes a row that has NOT started yet, so a typo in a scheduled rate
  /// can be corrected. A rate that has already started is history — sales
  /// already priced under it stay as recorded.
  Future<void> deleteSalesRate(String id) async {
    final doc = await _db.collection('sales_rates').doc(id).get();
    if (!doc.exists) return;
    final entry = SalesRateEntry.fromMap(doc.data()!, doc.id);
    if (!entry.effectiveFrom.isAfter(_dayOnly(DateTime.now()))) {
      throw Exception('Only a rate that has not started yet can be removed.');
    }
    await doc.reference.delete();
  }

  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  // ── Rate schedules (rate_schedules) — older shell, untouched ─────────────

  Future<void> activateSchedule(String scheduleId) async {
    await _db.collection('rate_schedules').doc(scheduleId).update({'isActive': true});
  }

  Future<List<RateScheduleModel>> getSchedules() async {
    final snap = await _db.collection('rate_schedules').get();
    return snap.docs
        .map((d) => RateScheduleModel.fromMap(d.id, d.data()))
        .toList();
  }

  Future<void> createSchedule(RateScheduleModel schedule) async {
    await _db.collection('rate_schedules').doc(schedule.id).set(schedule.toMap());
  }
}