// core/models/sales_rate_model.dart
//
// The subdivision's sale price per square metre — the rate used to DERIVE a
// lot's asking price (areaSqm x ratePerSqm) instead of letting an admin
// hand-type it. Stored as its own settings doc (`sales_rate/config`) so it
// can change over time like the monthly membership rate history.
//
// Collection: `sales_rate` (single config document, id `config`).

class SalesRateModel {
  final double ratePerSqm;   // ₱ per square metre
  final String updatedBy;    // uid of the staff who last changed it
  final DateTime updatedAt;

  const SalesRateModel({
    required this.ratePerSqm,
    required this.updatedBy,
    required this.updatedAt,
  });

  factory SalesRateModel.fromMap(Map<String, dynamic> map) {
    return SalesRateModel(
      ratePerSqm: (map['ratePerSqm'] as num?)?.toDouble() ?? 0.0,
      updatedBy:  map['updatedBy'] as String? ?? '',
      updatedAt:  (map['updatedAt'] as dynamic)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'ratePerSqm': ratePerSqm,
        'updatedBy': updatedBy,
        'updatedAt': updatedAt,
      };

  SalesRateModel copyWith({
    double? ratePerSqm,
    String? updatedBy,
    DateTime? updatedAt,
  }) =>
      SalesRateModel(
        ratePerSqm: ratePerSqm ?? this.ratePerSqm,
        updatedBy: updatedBy ?? this.updatedBy,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}