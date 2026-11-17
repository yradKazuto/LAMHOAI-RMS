// core/models/sales_rate_model.dart
//
// The subdivision's sale price per square metre. The rate can change over
// time, so it lives as DATED ROWS in `sales_rates` (one row per effective
// date — per year, per season, whatever the HOA schedules); a sale is
// priced at the row in force on its sale date. `SalesRateModel` is the
// resolved "rate in force" handed to every existing caller. The legacy
// single-doc `sales_rate/config` is no longer written; it is read only as
// a first-row fallback until a dated row exists (see RateService).
//
// Each row can also carry an optional corner-lot rate; null means corner
// lots use the normal rate.
//
// Collection: `sales_rates` (one doc per dated rate).

import 'package:cloud_firestore/cloud_firestore.dart';

/// One dated rate row: [ratePerSqm] applies from [effectiveFrom] until the
/// next row's effective date.
class SalesRateEntry {
  final String id;
  final DateTime effectiveFrom;
  final double ratePerSqm;   // ₱ per square metre
  /// Optional ₱/sqm for corner lots on the same dated row.
  /// Null = corner lots use [ratePerSqm].
  final double? cornerRatePerSqm;
  final String setBy;        // uid of the staff who set it
  final DateTime createdAt;

  const SalesRateEntry({
    required this.id,
    required this.effectiveFrom,
    required this.ratePerSqm,
    this.cornerRatePerSqm,
    required this.setBy,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'effectiveFrom': Timestamp.fromDate(effectiveFrom),
        'ratePerSqm': ratePerSqm,
        'cornerRatePerSqm': cornerRatePerSqm,
        'setBy': setBy,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory SalesRateEntry.fromMap(Map<String, dynamic> map, String id) =>
      SalesRateEntry(
        id: id,
        effectiveFrom:
            (map['effectiveFrom'] as dynamic)?.toDate() ?? DateTime(2000),
        ratePerSqm: (map['ratePerSqm'] as num?)?.toDouble() ?? 0.0,
        cornerRatePerSqm: (map['cornerRatePerSqm'] as num?)?.toDouble(),
        setBy: map['setBy'] as String? ?? '',
        createdAt:
            (map['createdAt'] as dynamic)?.toDate() ?? DateTime(2000),
      );
}

/// The rate in force at a moment, as the flat value every existing caller
/// (wizards, lot dialog, sale recorder) already reads.
class SalesRateModel {
  final double ratePerSqm;   // ₱ per square metre
  /// Corner-lot rate in force; null = corner lots use [ratePerSqm].
  final double? cornerRatePerSqm;
  final String updatedBy;    // uid of the staff who set it
  final DateTime updatedAt;

  const SalesRateModel({
    required this.ratePerSqm,
    this.cornerRatePerSqm,
    required this.updatedBy,
    required this.updatedAt,
  });
}