// core/models/lot_sale_model.dart
//
// One sale of a lot — cash or installment — plus its full breakdown so the
// amortization schedule can be rebuilt from the stored record at any time.
//
// Collection: `lot_sales`

import 'package:cloud_firestore/cloud_firestore.dart';

enum SaleType { cash, installment }

const Map<SaleType, String> _saleTypeLabels = {
  SaleType.cash: 'Cash',
  SaleType.installment: 'Installment',
};

const Map<String, SaleType> _saleTypeLookup = {
  'cash': SaleType.cash,
  'installment': SaleType.installment,
};

extension SaleTypeExt on SaleType {
  String get label => _saleTypeLabels[this] ?? name;

  static SaleType fromString(String? v) =>
      _saleTypeLookup[v?.toLowerCase()] ?? SaleType.cash;
}

enum LotSaleStatus { active, paidOff, cancelled, assumed }

const Map<LotSaleStatus, String> _lotSaleStatusLabels = {
  LotSaleStatus.active: 'Active',
  LotSaleStatus.paidOff: 'Paid Off',
  LotSaleStatus.cancelled: 'Cancelled',
  LotSaleStatus.assumed: 'Assumed',
};

const Map<String, LotSaleStatus> _lotSaleStatusLookup = {
  'active': LotSaleStatus.active,
  'paidoff': LotSaleStatus.paidOff,
  'cancelled': LotSaleStatus.cancelled,
  'assumed': LotSaleStatus.assumed,
};

extension LotSaleStatusExt on LotSaleStatus {
  String get label => _lotSaleStatusLabels[this] ?? name;

  static LotSaleStatus fromString(String? v) =>
      _lotSaleStatusLookup[v?.toLowerCase()] ?? LotSaleStatus.active;
}

/// `financedAmount` = `totalPrice` - `downPayment`. `monthlyPayment` is the
/// computed amortization installment (zero for cash). `saleSeq` is the
/// per-year running number used to build transaction IDs
/// (`LP-{year}-{seq}-{period}`).
class LotSaleModel {
  final String id;
  final String lotId;
  final String lotNumber;
  final String phase;
  final String block;
  final String buyerUid;
  final String buyerName;
  final SaleType saleType;   // 'cash' | 'installment'
  final double totalPrice;
  final double downPayment;
  final double financedAmount; // totalPrice - downPayment
  final int termMonths;      // installment count; 0 for cash
  final double annualInterestRate; // e.g. 12.0 for 12% per annum
  final double monthlyPayment; // computed; 0 for cash
  final LotSaleStatus status; // 'active' | 'paidOff' | 'cancelled' | 'assumed'
  final DateTime soldDate;
  final int saleSeq;         // per-year running number
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const LotSaleModel({
    required this.id,
    required this.lotId,
    required this.lotNumber,
    required this.phase,
    required this.block,
    required this.buyerUid,
    required this.buyerName,
    required this.saleType,
    required this.totalPrice,
    required this.downPayment,
    required this.financedAmount,
    required this.termMonths,
    required this.annualInterestRate,
    required this.monthlyPayment,
    required this.status,
    required this.soldDate,
    required this.saleSeq,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory LotSaleModel.fromMap(Map<String, dynamic> map, String id) {
    return LotSaleModel(
      id:                 id,
      lotId:              map['lotId'] as String? ?? '',
      lotNumber:          map['lotNumber'] as String? ?? '',
      phase:              map['phase'] as String? ?? '',
      block:              map['block'] as String? ?? '',
      buyerUid:           map['buyerUid'] as String? ?? '',
      buyerName:          map['buyerName'] as String? ?? '',
      saleType:           SaleTypeExt.fromString(map['saleType'] as String?),
      totalPrice:         (map['totalPrice'] as num?)?.toDouble() ?? 0.0,
      downPayment:        (map['downPayment'] as num?)?.toDouble() ?? 0.0,
      financedAmount:     (map['financedAmount'] as num?)?.toDouble() ?? 0.0,
      termMonths:         (map['termMonths'] as num?)?.toInt() ?? 0,
      annualInterestRate: (map['annualInterestRate'] as num?)?.toDouble() ?? 0.0,
      monthlyPayment:     (map['monthlyPayment'] as num?)?.toDouble() ?? 0.0,
      status:             LotSaleStatusExt.fromString(map['status'] as String?),
      soldDate:           (map['soldDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      saleSeq:            (map['saleSeq'] as num?)?.toInt() ?? 0,
      createdBy:          map['createdBy'] as String? ?? '',
      createdAt:          (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:          (map['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'lotId': lotId,
        'lotNumber': lotNumber,
        'phase': phase,
        'block': block,
        'buyerUid': buyerUid,
        'buyerName': buyerName,
        'saleType': saleType.name,
        'totalPrice': totalPrice,
        'downPayment': downPayment,
        'financedAmount': financedAmount,
        'termMonths': termMonths,
        'annualInterestRate': annualInterestRate,
        'monthlyPayment': monthlyPayment,
        'status': status.name,
        'soldDate': Timestamp.fromDate(soldDate),
        'saleSeq': saleSeq,
        'createdBy': createdBy,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  LotSaleModel copyWith({
    String? id, String? lotId, String? lotNumber, String? phase,
    String? block, String? buyerUid, String? buyerName, SaleType? saleType,
    double? totalPrice, double? downPayment, double? financedAmount,
    int? termMonths, double? annualInterestRate, double? monthlyPayment,
    LotSaleStatus? status, DateTime? soldDate, int? saleSeq,
    String? createdBy, DateTime? createdAt, DateTime? updatedAt,
  }) =>
      LotSaleModel(
        id: id ?? this.id,
        lotId: lotId ?? this.lotId,
        lotNumber: lotNumber ?? this.lotNumber,
        phase: phase ?? this.phase,
        block: block ?? this.block,
        buyerUid: buyerUid ?? this.buyerUid,
        buyerName: buyerName ?? this.buyerName,
        saleType: saleType ?? this.saleType,
        totalPrice: totalPrice ?? this.totalPrice,
        downPayment: downPayment ?? this.downPayment,
        financedAmount: financedAmount ?? this.financedAmount,
        termMonths: termMonths ?? this.termMonths,
        annualInterestRate: annualInterestRate ?? this.annualInterestRate,
        monthlyPayment: monthlyPayment ?? this.monthlyPayment,
        status: status ?? this.status,
        soldDate: soldDate ?? this.soldDate,
        saleSeq: saleSeq ?? this.saleSeq,
        createdBy: createdBy ?? this.createdBy,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  /// Remaining balance owed on this sale at a given moment, derived from the
  /// schedule rather than stored. Computed elsewhere; kept here as a doc.
}
