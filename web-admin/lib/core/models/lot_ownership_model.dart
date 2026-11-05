// core/models/lot_ownership_model.dart
//
// One row per ownership period of a lot. The current owner has endedAt == null.
// Written by SaleService.recordSale (first owner) and
// SaleService.changeLotOwner (every later owner).

import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;

class LotOwnershipRecord {
  final String id;
  final String lotId;
  final String saleId; // '' when the lot has no sale on record
  final String ownerUid;
  final String ownerName;
  final DateTime startedAt;
  final DateTime? endedAt;

  /// 'sale' | 'transfer' | 'assignment'
  final String acquiredBy;

  /// Outstanding balance this owner took over when they acquired the lot.
  final double balanceTakenOver;

  /// Outstanding balance left on the lot when this owner gave it up.
  final double balanceLeftBehind;

  final String transferredBy;
  final String notes;

  const LotOwnershipRecord({
    this.id = '',
    required this.lotId,
    this.saleId = '',
    required this.ownerUid,
    required this.ownerName,
    required this.startedAt,
    this.endedAt,
    this.acquiredBy = 'sale',
    this.balanceTakenOver = 0,
    this.balanceLeftBehind = 0,
    this.transferredBy = '',
    this.notes = '',
  });

  bool get isCurrent => endedAt == null;

  factory LotOwnershipRecord.fromMap(Map<String, dynamic> m, String id) {
    DateTime? ts(dynamic v) => v is Timestamp ? v.toDate() : null;
    return LotOwnershipRecord(
      id: id,
      lotId: m['lotId'] as String? ?? '',
      saleId: m['saleId'] as String? ?? '',
      ownerUid: m['ownerUid'] as String? ?? '',
      ownerName: m['ownerName'] as String? ?? '',
      startedAt: ts(m['startedAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      endedAt: ts(m['endedAt']),
      acquiredBy: m['acquiredBy'] as String? ?? 'sale',
      balanceTakenOver: (m['balanceTakenOver'] as num?)?.toDouble() ?? 0,
      balanceLeftBehind: (m['balanceLeftBehind'] as num?)?.toDouble() ?? 0,
      transferredBy: m['transferredBy'] as String? ?? '',
      notes: m['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'lotId': lotId,
        'saleId': saleId,
        'ownerUid': ownerUid,
        'ownerName': ownerName,
        'startedAt': Timestamp.fromDate(startedAt),
        'endedAt': endedAt == null ? null : Timestamp.fromDate(endedAt!),
        'acquiredBy': acquiredBy,
        'balanceTakenOver': balanceTakenOver,
        'balanceLeftBehind': balanceLeftBehind,
        'transferredBy': transferredBy,
        'notes': notes,
        'createdAt': Timestamp.now(),
      };
}