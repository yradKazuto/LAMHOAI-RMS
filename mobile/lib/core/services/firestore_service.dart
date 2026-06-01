// lib/core/services/firestore_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/payment_model.dart';

class FirestoreService {
  final FirebaseFirestore _db;

  FirestoreService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

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
}