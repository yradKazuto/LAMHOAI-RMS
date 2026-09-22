// core/models/payment_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

// Stored in Firestore by `name` — never rename a value once records exist.
// `dues` = per-lot MONTHLY dues, `membershipFee` = ANNUAL association fee,
// `lotPayment` = payments made toward a lot (amortization / installments).
// Monthly dues and lot payments belong to ONE specific lot (lotId).
enum PaymentType { dues, membershipFee, lotPayment, penalty, specialAssessment, other }

extension PaymentTypeExt on PaymentType {
  String get label {
    switch (this) {
      case PaymentType.dues:              return 'Monthly Dues';
      case PaymentType.membershipFee:     return 'Annual Membership Fee';
      case PaymentType.lotPayment:        return 'Lot Amortization';
      case PaymentType.penalty:           return 'Penalty';
      case PaymentType.specialAssessment: return 'Special Assessment';
      case PaymentType.other:             return 'Other';
    }
  }

  static PaymentType fromString(String? v) {
    switch (v) {
      case 'dues':              return PaymentType.dues;
      case 'membershipFee':     return PaymentType.membershipFee;
      case 'lotPayment':        return PaymentType.lotPayment;
      case 'penalty':           return PaymentType.penalty;
      case 'specialAssessment': return PaymentType.specialAssessment;
      default:                  return PaymentType.other;
    }
  }
}

enum PaymentStatus { paid, unpaid, overdue, waived }

extension PaymentStatusExt on PaymentStatus {
  String get label {
    switch (this) {
      case PaymentStatus.paid:    return 'Paid';
      case PaymentStatus.unpaid:  return 'Unpaid';
      case PaymentStatus.overdue: return 'Overdue';
      case PaymentStatus.waived:  return 'Waived';
    }
  }

  static PaymentStatus fromString(String? v) {
    switch (v?.toLowerCase()) {
      case 'paid':    return PaymentStatus.paid;
      case 'unpaid':  return PaymentStatus.unpaid;
      case 'overdue': return PaymentStatus.overdue;
      case 'waived':  return PaymentStatus.waived;
      default:        return PaymentStatus.unpaid;
    }
  }
}

class PaymentModel {
  final String id;
  final String uid;          // member's uid — matches Firestore field
  final String memberName;
  final PaymentType type;
  final double amount;
  final PaymentStatus status;
  final DateTime dueDate;
  final DateTime? paidDate;
  final String recordedBy;
  final String notes;
  final DateTime createdAt;
  // The lot this payment is for (dues + lotPayment). `lotId` is the lots
  // collection document id — stable and unambiguous, unlike a lot number
  // ("Lot 12" exists in every block). `lotLabel` is display text such as
  // "Block 3 · Lot 12", stored so lists don't need a join. Both are ''
  // for records that aren't tied to a lot (and for old records made before
  // per-lot billing).
  final String lotId;
  final String lotLabel;

  const PaymentModel({
    required this.id,
    required this.uid,         // fixed: was memberId
    required this.memberName,
    required this.type,
    required this.amount,
    required this.status,
    required this.dueDate,
    this.paidDate,
    required this.recordedBy,
    required this.notes,
    required this.createdAt,
    this.lotId = '',
    this.lotLabel = '',
  });

  factory PaymentModel.fromMap(Map<String, dynamic> map, String id) {
    return PaymentModel(
      id:         id,
      uid:        map['uid']        as String? ?? '',
      memberName: map['memberName'] as String? ?? '',
      type:       PaymentTypeExt.fromString(map['type'] as String?),
      amount:     (map['amount'] as num?)?.toDouble() ?? 0.0,
      status:     PaymentStatusExt.fromString(map['status'] as String?),
      dueDate:    (map['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      paidDate:   (map['paidDate'] as Timestamp?)?.toDate(),
      recordedBy: map['recordedBy'] as String? ?? '',
      notes:      map['notes']      as String? ?? '',
      createdAt:  (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      lotId:      map['lotId']?.toString() ?? '',
      lotLabel:   map['lotLabel']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
    'uid':        uid,
    'memberName': memberName,
    'type':       type.name,
    'amount':     amount,
    'status':     status.name,
    'dueDate':    Timestamp.fromDate(dueDate),
    'paidDate':   paidDate != null ? Timestamp.fromDate(paidDate!) : null,
    'recordedBy': recordedBy,
    'notes':      notes,
    'createdAt':  Timestamp.fromDate(createdAt),
    'lotId':      lotId,
    'lotLabel':   lotLabel,
  };

  PaymentModel copyWith({
    String? id, String? uid, String? memberName,
    PaymentType? type, double? amount, PaymentStatus? status,
    DateTime? dueDate, DateTime? paidDate, String? recordedBy,
    String? notes, DateTime? createdAt, String? lotId, String? lotLabel,
  }) => PaymentModel(
    id:         id         ?? this.id,
    uid:        uid        ?? this.uid,
    memberName: memberName ?? this.memberName,
    type:       type       ?? this.type,
    amount:     amount     ?? this.amount,
    status:     status     ?? this.status,
    dueDate:    dueDate    ?? this.dueDate,
    paidDate:   paidDate   ?? this.paidDate,
    recordedBy: recordedBy ?? this.recordedBy,
    notes:      notes      ?? this.notes,
    createdAt:  createdAt  ?? this.createdAt,
    lotId:      lotId      ?? this.lotId,
    lotLabel:   lotLabel   ?? this.lotLabel,
  );
}

extension PaymentDisplayStatus on PaymentModel {
  /// Status for DISPLAY purposes only — never written back to Firestore.
  /// The stored `status` field only ever reflects what an admin explicitly
  /// set; nothing auto-flips it to `overdue` when a due date passes. This
  /// getter fills that gap client-side: an `unpaid` record whose dueDate
  /// is in the past is treated as overdue everywhere the UI shows or
  /// filters by status. `paid`/`waived` records are never affected.
  ///
  /// Use `displayStatus` for badges, totals, and filters. Use `status`
  /// directly only when you need the literal stored value (e.g. deciding
  /// whether to show "Mark Paid", or writing a status back to Firestore).
  PaymentStatus get displayStatus {
    // Compare against the START of today so a record is not "overdue"
    // on its own due date (dueDate is stored at midnight, so comparing
    // with DateTime.now() flipped it to overdue at 12:00 AM of the due day).
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    if (status == PaymentStatus.unpaid && dueDate.isBefore(startOfToday)) {
      return PaymentStatus.overdue;
    }
    return status;
  }
}

/// Display text for a lot, e.g. "Phase 1 · Block 3 · Lot 12". Blocks are
/// stored as a bare identifier ("3"), so the word "Block" is added here.
/// The phase is included because the same block/lot number can exist in
/// more than one phase.
String buildLotLabel({
  required String block,
  required String lotNumber,
  String phase = '',
}) {
  final parts = <String>[
    if (phase.trim().isNotEmpty) phase.trim(),
    if (block.trim().isNotEmpty) 'Block ${block.trim()}',
    if (lotNumber.trim().isNotEmpty) 'Lot ${lotNumber.trim()}',
  ];
  return parts.join(' · ');
}