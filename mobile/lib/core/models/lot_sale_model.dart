// core/models/lot_sale_model.dart
//
// Mirrors web-admin/lib/core/models/lot_sale_model.dart — one sale of a lot,
// cash or installment, plus its owner list (buyer + co-owners).
//
// Collection: `lot_sales`

import 'package:cloud_firestore/cloud_firestore.dart';

enum LotSaleType { cash, installment }

const Map<LotSaleType, String> _saleTypeLabels = {
  LotSaleType.cash: 'Cash',
  LotSaleType.installment: 'Installment',
};

const Map<String, LotSaleType> _saleTypeLookup = {
  'cash': LotSaleType.cash,
  'installment': LotSaleType.installment,
};

extension LotSaleTypeExt on LotSaleType {
  String get label => _saleTypeLabels[this] ?? name;

  static LotSaleType fromString(String? v) =>
      _saleTypeLookup[v?.toLowerCase()] ?? LotSaleType.cash;
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

/// `ownerUids` = [buyerUid, ...coOwnerUids] — the query index every
/// "this member's lots" lookup hits.
class LotSaleModel {
  final String id;
  final String lotId;
  final String lotNumber;
  final String phase;
  final String block;
  final String buyerUid;
  final String buyerName;
  final List<String> coOwnerUids;
  final List<String> ownerUids;
  final LotSaleType saleType;
  final double totalPrice;
  final double downPayment;
  final double financedAmount;
  final int termMonths;
  final double monthlyPayment;
  final LotSaleStatus status;
  final DateTime soldDate;

  const LotSaleModel({
    required this.id,
    required this.lotId,
    required this.lotNumber,
    required this.phase,
    required this.block,
    required this.buyerUid,
    required this.buyerName,
    this.coOwnerUids = const [],
    this.ownerUids = const [],
    required this.saleType,
    required this.totalPrice,
    required this.downPayment,
    required this.financedAmount,
    required this.termMonths,
    required this.monthlyPayment,
    required this.status,
    required this.soldDate,
  });

  factory LotSaleModel.fromMap(Map<String, dynamic> map, String id) {
    return LotSaleModel(
      id:             id,
      lotId:          map['lotId'] as String? ?? '',
      lotNumber:      map['lotNumber'] as String? ?? '',
      phase:          map['phase'] as String? ?? '',
      block:          map['block'] as String? ?? '',
      buyerUid:       map['buyerUid'] as String? ?? '',
      buyerName:      map['buyerName'] as String? ?? '',
      coOwnerUids:    List<String>.from(map['coOwnerUids'] as List? ?? const []),
      ownerUids:      List<String>.from(map['ownerUids'] as List? ?? const []),
      saleType:       LotSaleTypeExt.fromString(map['saleType'] as String?),
      totalPrice:     (map['totalPrice'] as num?)?.toDouble() ?? 0.0,
      downPayment:    (map['downPayment'] as num?)?.toDouble() ?? 0.0,
      financedAmount: (map['financedAmount'] as num?)?.toDouble() ?? 0.0,
      termMonths:     (map['termMonths'] as num?)?.toInt() ?? 0,
      monthlyPayment: (map['monthlyPayment'] as num?)?.toDouble() ?? 0.0,
      status:         LotSaleStatusExt.fromString(map['status'] as String?),
      soldDate:       (map['soldDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
