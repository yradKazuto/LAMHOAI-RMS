// core/models/lot_payment_model.dart
//
// One scheduled or recorded payment toward a lot sale (installment
// amortization period, or a cash lump sum). Each period carries its own
// principal / interest / balance split so the full trail is viewable
// without recomputation.
//
// Collection: `lot_payments`

import 'package:cloud_firestore/cloud_firestore.dart';

enum LotPaymentStatus { scheduled, paid, overdue, waived, void_ }
enum PaymentMethod { cash, cheque, bank }

const Map<LotPaymentStatus, String> _lotPaymentStatusLabels = {
  LotPaymentStatus.scheduled: 'Scheduled',
  LotPaymentStatus.paid: 'Paid',
  LotPaymentStatus.overdue: 'Overdue',
  LotPaymentStatus.waived: 'Waived',
  LotPaymentStatus.void_: 'Void',
};

const Map<String, LotPaymentStatus> _lotPaymentStatusLookup = {
  'scheduled': LotPaymentStatus.scheduled,
  'paid': LotPaymentStatus.paid,
  'overdue': LotPaymentStatus.overdue,
  'waived': LotPaymentStatus.waived,
  'void': LotPaymentStatus.void_,
};

extension LotPaymentStatusExt on LotPaymentStatus {
  String get label => _lotPaymentStatusLabels[this] ?? name;

  static LotPaymentStatus fromString(String? v) =>
      _lotPaymentStatusLookup[v?.toLowerCase()] ?? LotPaymentStatus.scheduled;
}

// void is a reserved Dart keyword so the enum value is void_.
class LotPaymentModel {
  final String saleId;
  final String lotId;
  final int period;          // 0 = down payment / cash lump; 1..N = installments
  final String transactionId; // LP-{year}-{seq}-{period}
  final DateTime dueDate;
  final double amount;
  final double principalPortion;
  final double interestPortion;
  final double remainingBalance; // balance owed after this period posts
  final LotPaymentStatus status; // scheduled | paid | overdue | waived | void
  final DateTime? paidAt;
  final String? paidBy;
  final String? payer;
  final PaymentMethod? paymentMethod;
  final DateTime? verifiedAt;
  final DateTime createdAt;

  const LotPaymentModel({
    required this.saleId,
    required this.lotId,
    required this.period,
    required this.transactionId,
    required this.dueDate,
    required this.amount,
    required this.principalPortion,
    required this.interestPortion,
    required this.remainingBalance,
    required this.status,
    this.paidAt,
    this.paidBy,
    this.payer,
    this.paymentMethod,
    this.verifiedAt,
    required this.createdAt,
  });

  factory LotPaymentModel.fromMap(Map<String, dynamic> map) {
    return LotPaymentModel(
      saleId:            map['saleId'] as String? ?? '',
      lotId:             map['lotId'] as String? ?? '',
      period:            (map['period'] as num?)?.toInt() ?? 0,
      transactionId:     map['transactionId'] as String? ?? '',
      dueDate:           (map['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      amount:            (map['amount'] as num?)?.toDouble() ?? 0.0,
      principalPortion:  (map['principalPortion'] as num?)?.toDouble() ?? 0.0,
      interestPortion:   (map['interestPortion'] as num?)?.toDouble() ?? 0.0,
      remainingBalance:  (map['remainingBalance'] as num?)?.toDouble() ?? 0.0,
      status:            LotPaymentStatusExt.fromString(map['status'] as String?),
      paidAt:            (map['paidAt'] as Timestamp?)?.toDate(),
      paidBy:            map['paidBy'] as String?,
      payer:             map['payer'] as String?,
      paymentMethod:     map['paymentMethod'] != null ? PaymentMethod.values.firstWhere((e) => e.name == map['paymentMethod']) : null,
      verifiedAt:        (map['verifiedAt'] as Timestamp?)?.toDate(),
      createdAt:         (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'saleId': saleId,
        'lotId': lotId,
        'period': period,
        'transactionId': transactionId,
        'dueDate': Timestamp.fromDate(dueDate),
        'amount': amount,
        'principalPortion': principalPortion,
        'interestPortion': interestPortion,
        'remainingBalance': remainingBalance,
        'status': status.name,
        'paidAt': paidAt != null ? Timestamp.fromDate(paidAt!) : null,
        'paidBy': paidBy,
        'payer': payer,
        'paymentMethod': paymentMethod?.name,
        'verifiedAt': verifiedAt != null ? Timestamp.fromDate(verifiedAt!) : null,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  LotPaymentModel copyWith({
    String? saleId, String? lotId, int? period, String? transactionId,
    DateTime? dueDate, double? amount, double? principalPortion,
    double? interestPortion, double? remainingBalance, LotPaymentStatus? status,
    DateTime? paidAt, String? paidBy, String? payer, PaymentMethod? paymentMethod,
    DateTime? verifiedAt, DateTime? createdAt,
  }) =>
      LotPaymentModel(
        saleId: saleId ?? this.saleId,
        lotId: lotId ?? this.lotId,
        period: period ?? this.period,
        transactionId: transactionId ?? this.transactionId,
        dueDate: dueDate ?? this.dueDate,
        amount: amount ?? this.amount,
        principalPortion: principalPortion ?? this.principalPortion,
        interestPortion: interestPortion ?? this.interestPortion,
        remainingBalance: remainingBalance ?? this.remainingBalance,
        status: status ?? this.status,
        paidAt: paidAt ?? this.paidAt,
        paidBy: paidBy ?? this.paidBy,
        payer: payer ?? this.payer,
        paymentMethod: paymentMethod ?? this.paymentMethod,
        verifiedAt: verifiedAt ?? this.verifiedAt,
        createdAt: createdAt ?? this.createdAt,
      );
}

/// Display-only status for a lot payment — never written back to Firestore.
/// A `scheduled` period whose `dueDate` is in the past renders `overdue`;
/// `paid` / `waived` / `void` periods are never affected. Mirrors the
/// existing `PaymentDisplayStatus` pattern on `PaymentModel`.
extension LotPaymentDisplayStatus on LotPaymentModel {
  LotPaymentStatus get displayStatus {
    if (status == LotPaymentStatus.scheduled) {
      final startOfToday = DateTime.now();
      final today = DateTime(startOfToday.year, startOfToday.month, startOfToday.day);
      if (dueDate.isBefore(today)) {
        return LotPaymentStatus.overdue;
      }
    }
    return status;
  }
}
