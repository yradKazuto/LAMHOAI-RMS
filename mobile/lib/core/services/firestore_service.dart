// lib/core/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/payment_model.dart';
import '../models/ledger_model.dart';
import '../models/lot_sale_model.dart';
import '../models/lot_payment_model.dart';

class FirestoreService {
  final FirebaseFirestore _db;

  FirestoreService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  // ── Ledgers ───────────────────────────────────────────────────────────────

  /// Real-time stream of a member's ledger.
  Stream<LedgerModel?> ledgerStream(String uid) {
    return _db
        .collection('member_ledgers')
        .doc(uid)
        .snapshots()
        .map((snap) => snap.exists ? LedgerModel.fromFirestore(snap) : null);
  }

  // ── Users ─────────────────────────────────────────────────────────────────

  Future<UserModel> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (!doc.exists || doc.data() == null) {
      throw Exception('User profile not found.');
    }
    return UserModel.fromFirestore(doc.data()!, uid);
  }

  // ── Payments ──────────────────────────────────────────────────────────────

  /// Real-time stream of a member's payment records, newest first.
  Stream<List<PaymentModel>> paymentsStream(String uid) {
    return _db
        .collection('payments')
        .where('uid', isEqualTo: uid)
        .orderBy('dueDate', descending: true)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => PaymentModel.fromFirestore(d)).toList());
  }

  /// One-time fetch — used for summary totals.
  Future<List<PaymentModel>> getPayments(String uid) async {
    final snap = await _db
        .collection('payments')
        .where('uid', isEqualTo: uid)
        .orderBy('dueDate', descending: true)
        .get();
    return snap.docs.map((d) => PaymentModel.fromFirestore(d)).toList();
  }

  /// Single payment record by document ID.
  Future<PaymentModel> getPayment(String paymentId) async {
    final doc = await _db.collection('payments').doc(paymentId).get();
    if (!doc.exists) throw Exception('Payment record not found.');
    return PaymentModel.fromFirestore(doc);
  }

  // ── Lots ──────────────────────────────────────────────────────────────────

  /// Real-time stream of lots the member owns as buyer OR co-owner.
  /// `ownerUids` is the denormalized [buyerUid, ...coOwnerUids] index — the
  /// same field web-admin's SaleService.streamSalesForMember queries. Sorted
  /// client-side so no composite index is needed.
  Stream<List<LotSaleModel>> salesForMemberStream(String uid) {
    if (uid.isEmpty) return Stream.value(<LotSaleModel>[]);
    return _db
        .collection('lot_sales')
        .where('ownerUids', arrayContains: uid)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => LotSaleModel.fromMap(d.data(), d.id))
            .toList()
          ..sort((a, b) => b.soldDate.compareTo(a.soldDate)));
  }

  /// Real-time stream of every schedule row across the given sales — one
  /// query for all of them. `whereIn` caps at 10; a member with more than 10
  /// lots has never existed in this data.
  Stream<List<LotPaymentModel>> lotPaymentsForSalesStream(
      List<String> saleIds) {
    if (saleIds.isEmpty) return Stream.value(<LotPaymentModel>[]);
    return _db
        .collection('lot_payments')
        .where('saleId', whereIn: saleIds.take(10).toList())
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => LotPaymentModel.fromMap(d.data(), d.id))
            .toList());
  }

  /// Real-time stream of `payments` rows attached to the given sales — the
  /// lot-payment mirrors web-admin writes (they carry `saleId` as an extra
  /// key). Members can read a mirror row when they own the sale, see the
  /// `payments` rule's lotPayment exception.
  Stream<List<PaymentModel>> paymentsForSalesStream(List<String> saleIds) {
    if (saleIds.isEmpty) return Stream.value(<PaymentModel>[]);
    return _db
        .collection('payments')
        .where('saleId', whereIn: saleIds.take(10).toList())
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => PaymentModel.fromFirestore(d)).toList());
  }
}

/// Merges two payment lists, deduping by document id — a buyer's own mirror
/// rows match both the `uid` query and the `saleId` query.
List<PaymentModel> mergePaymentsById(
    Iterable<PaymentModel> a, Iterable<PaymentModel> b) {
  final byId = <String, PaymentModel>{};
  for (final p in [...a, ...b]) {
    byId.putIfAbsent(p.id, () => p);
  }
  return byId.values.toList();
}