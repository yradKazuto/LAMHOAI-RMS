// core/services/firestore_service.dart
// UPDATED — uses uid instead of memberId, and displayName instead of name
// to stay compatible with mobile app field naming

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/member_model.dart';
import '../models/payment_model.dart';
import '../models/document_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference get _members  => _db.collection('users');
  CollectionReference get _payments => _db.collection('payments');
  CollectionReference get _docs     => _db.collection('documents');

  // ════════════════════════════════════════════════════════════════════════════
  // MEMBERS
  // ════════════════════════════════════════════════════════════════════════════

  Stream<List<MemberModel>> streamMembers() {
    return _members
        .where('role', isEqualTo: 'member')
        .orderBy('displayName')        // ← matches mobile field name
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => MemberModel.fromMap(
                d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  Future<MemberModel?> getMember(String uid) async {
    final doc = await _members.doc(uid).get();
    if (!doc.exists) return null;
    return MemberModel.fromMap(
        doc.data() as Map<String, dynamic>, doc.id);
  }

  Future<void> addMember(MemberModel member) async {
    await _members.doc(member.uid).set(member.toMap());
  }

  Future<void> updateMember(MemberModel member) async {
    await _members.doc(member.uid).update(member.toMap());
  }

  Future<void> updateMemberStatus(String uid, MemberStatus status) async {
    await _members.doc(uid).update({'status': status.name});
  }

  Future<void> deleteMember(String uid) async {
    await _members.doc(uid).delete();
  }

  // ════════════════════════════════════════════════════════════════════════════
  // PAYMENTS
  // ════════════════════════════════════════════════════════════════════════════

  Stream<List<PaymentModel>> streamPayments() {
    return _payments
        .orderBy('dueDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => PaymentModel.fromMap(
                d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  Stream<List<PaymentModel>> streamPaymentsForMember(String memberUid) {
    return _payments
        .where('uid', isEqualTo: memberUid)
        .orderBy('dueDate', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => PaymentModel.fromMap(
                d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  Future<void> addPayment(PaymentModel payment) async {
    await _payments.doc(payment.id).set(payment.toMap());
  }

  Future<void> updatePayment(PaymentModel payment) async {
    await _payments.doc(payment.id).update(payment.toMap());
  }

  Future<void> markPaymentPaid(String paymentId) async {
    await _payments.doc(paymentId).update({
      'status':   PaymentStatus.paid.name,
      'paidDate': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> deletePayment(String paymentId) async {
    await _payments.doc(paymentId).delete();
  }

  // ════════════════════════════════════════════════════════════════════════════
  // DOCUMENTS
  // ════════════════════════════════════════════════════════════════════════════

  Stream<List<DocumentModel>> streamDocuments() {
    return _docs
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => DocumentModel.fromMap(
                d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  Stream<List<DocumentModel>> streamDocumentsForMember(String memberUid) {
    return _docs
        .where('uid', isEqualTo: memberUid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => DocumentModel.fromMap(
                d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  Future<DocumentModel> saveDocumentMetadata({
    required String memberUid,
    required String memberName,
    required String uploadedBy,
    required DocumentType type,
    required String fileName,
    required String fileUrl,
  }) async {
    final docRef = _docs.doc();
    final model  = DocumentModel(
      id:         docRef.id,
      uid:        memberUid,
      memberName: memberName,
      type:       type,
      fileName:   fileName,
      fileUrl:    fileUrl,
      uploadedBy: uploadedBy,
      createdAt:  DateTime.now(),
    );
    await docRef.set(model.toMap());
    return model;
  }

  Future<void> deleteDocumentMetadata(String docId) async {
    await _docs.doc(docId).delete();
  }
}