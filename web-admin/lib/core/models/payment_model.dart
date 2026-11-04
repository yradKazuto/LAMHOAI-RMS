// core/models/payment_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/enum_utils.dart';

// Stored in Firestore by `name` — never rename a value once records exist.
// `dues` = per-lot MONTHLY dues, `membershipFee` = ANNUAL association fee,
// `monthlyMembership` = recurring monthly membership (different concept from
// per-lot dues but same frequency — stored as its own type so annual reports
// and duplicate-prevention logic keep correct grouping), `lotPayment` =
// payments made toward a lot (amortization / installments).
// Monthly dues and lot payments belong to ONE specific lot (lotId).
enum PaymentType { dues, membershipFee, monthlyMembership, lotPayment, penalty, specialAssessment, other }

const Map<PaymentType, String> _paymentTypeLabels = {
  PaymentType.dues: 'Monthly Dues',
  PaymentType.membershipFee: 'Annual Membership Fee',
  PaymentType.monthlyMembership: 'Monthly Membership Fee',
  PaymentType.lotPayment: 'Monthly Lot Dues',
  PaymentType.penalty: 'Penalty',
  PaymentType.specialAssessment: 'Special Assessment',
  PaymentType.other: 'Other',
};

const Map<String, PaymentType> _paymentTypeLookup = {
  'dues': PaymentType.dues,
  'membershipfee': PaymentType.membershipFee,
  'monthlymembership': PaymentType.monthlyMembership,
  'lotpayment': PaymentType.lotPayment,
  'penalty': PaymentType.penalty,
  'specialassessment': PaymentType.specialAssessment,
};

extension PaymentTypeExt on PaymentType {
  String get label => enumLabel(this, _paymentTypeLabels);

  static PaymentType fromString(String? v) =>
      enumFromString(v, _paymentTypeLookup, defaultValue: PaymentType.other);
}

enum PaymentStatus { paid, unpaid, overdue, waived }

const Map<PaymentStatus, String> _paymentStatusLabels = {
  PaymentStatus.paid: 'Paid',
  PaymentStatus.unpaid: 'Unpaid',
  PaymentStatus.overdue: 'Overdue',
  PaymentStatus.waived: 'Waived',
};

const Map<String, PaymentStatus> _paymentStatusLookup = {
  'paid': PaymentStatus.paid,
  'unpaid': PaymentStatus.unpaid,
  'overdue': PaymentStatus.overdue,
  'waived': PaymentStatus.waived,
};

extension PaymentStatusExt on PaymentStatus {
  String get label => enumLabel(this, _paymentStatusLabels);

  static PaymentStatus fromString(String? v) =>
      enumFromString(v, _paymentStatusLookup, defaultValue: PaymentStatus.unpaid);
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

  // Human-readable transaction reference, e.g. MF-2026-0001 — prefix per
  // type (see TransactionIdService). Empty on records created before IDs
  // existed. txnYear + txnSeq back the per-(type, year) sequence counter:
  // the next ID is max txnSeq among same type+year docs + 1.
  final String transactionId;
  final int txnYear;
  final int txnSeq;

  // penaltyAmount stored separately from principal (₱45 per overdue, once).
  // Default 0 on existing records — backward compatible.
  final double penaltyAmount;

  // Cumulative amount already allocated toward this obligation across all
  // payments. Used by FIFO allocation to support partial payments without
  // mutating `amount`. Defaults to 0.
  final double paidAmount;

  // Payment method for the obligation (e.g. 'cash'). Extensible enum/config
  // for future methods. Only 'cash' is enabled for current version.
  final String paymentMethod;

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
    this.transactionId = '',
    this.txnYear = 0,
    this.txnSeq = 0,
    this.penaltyAmount = 0.0,
    this.paidAmount = 0.0,
    this.paymentMethod = 'cash',
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
      transactionId: map['transactionId']?.toString() ?? '',
      txnYear:    (map['txnYear'] as num?)?.toInt() ?? 0,
      txnSeq:     (map['txnSeq'] as num?)?.toInt() ?? 0,
      penaltyAmount:  (map['penaltyAmount'] as num?)?.toDouble()   ?? 0.0,
      paidAmount:     (map['paidAmount'] as num?)?.toDouble()     ?? 0.0,
      paymentMethod: map['paymentMethod']?.toString() ?? 'cash',
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
    'transactionId': transactionId,
    'txnYear':    txnYear,
    'txnSeq':     txnSeq,
    'penaltyAmount': penaltyAmount,
    'paidAmount':  paidAmount,
    'paymentMethod': paymentMethod,
  };

  PaymentModel copyWith({
    String? id, String? uid, String? memberName,
    PaymentType? type, double? amount, PaymentStatus? status,
    DateTime? dueDate, DateTime? paidDate, String? recordedBy,
    String? notes, DateTime? createdAt, String? lotId, String? lotLabel,
    String? transactionId, int? txnYear, int? txnSeq,
    double? penaltyAmount, double? paidAmount, String? paymentMethod,
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
    transactionId: transactionId ?? this.transactionId,
    txnYear:    txnYear    ?? this.txnYear,
    txnSeq:     txnSeq     ?? this.txnSeq,
    penaltyAmount: penaltyAmount ?? this.penaltyAmount,
    paidAmount:  paidAmount ?? this.paidAmount,
    paymentMethod: paymentMethod ?? this.paymentMethod,
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