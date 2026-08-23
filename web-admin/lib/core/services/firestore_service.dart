// core/services/firestore_service.dart
// UPDATED Phase 4 — adds staff, announcements, complaints

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/member_model.dart';
import '../models/payment_model.dart';
import '../models/document_model.dart';
import '../models/staff_model.dart';
import '../models/announcement_model.dart';
import '../models/complaint_model.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Expose db for generating doc IDs externally
  FirebaseFirestore get db => _db;

  CollectionReference get _users         => _db.collection('users');
  CollectionReference get _payments      => _db.collection('payments');
  CollectionReference get _docs          => _db.collection('documents');
  CollectionReference get _announcements => _db.collection('announcements');
  CollectionReference get _complaints    => _db.collection('complaints');

  // ════════════════════════════════════════════════════════════════════════════
  // MEMBERS (role == 'member')
  // ════════════════════════════════════════════════════════════════════════════

  Stream<List<MemberModel>> streamMembers() {
    return _users
        .where('role', isEqualTo: 'member')
        .orderBy('displayName')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => MemberModel.fromMap(
                d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  Future<MemberModel?> getMember(String uid) async {
    final doc = await _users.doc(uid).get();
    if (!doc.exists) return null;
    return MemberModel.fromMap(
        doc.data() as Map<String, dynamic>, doc.id);
  }

  Future<void> addMember(MemberModel member) async {
    await _users.doc(member.uid).set(member.toMap());
  }

  Future<void> updateMember(MemberModel member) async {
    await _users.doc(member.uid).update(member.toMap());
  }

  Future<void> updateMemberStatus(
      String uid, MemberStatus status) async {
    await _users.doc(uid).update({'status': status.name});
  }

  // ── Updates only the photoUrl field — won't overwrite name, email, or
  // any other field that might be sitting unsaved in the edit form at
  // the same time.
  Future<void> updateMemberPhoto(String uid, String photoUrl) async {
    await _users.doc(uid).update({'photoUrl': photoUrl});
  }

  Future<void> deleteMember(String uid) async {
    await _users.doc(uid).delete();
  }

  // ════════════════════════════════════════════════════════════════════════════
  // STAFF (role != 'member')
  // ════════════════════════════════════════════════════════════════════════════

  Stream<List<StaffModel>> streamStaff() {
    return _users
        .where('role', whereNotIn: ['member'])
        .orderBy('role')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => StaffModel.fromMap(
                d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  Future<void> addStaff(StaffModel staff) async {
    await _users.doc(staff.uid).set(staff.toMap());
  }

  Future<void> updateStaffRole(String uid, UserRole role) async {
    await _users.doc(uid).update({'role': role.name});
  }

  Future<void> setStaffActive(String uid, bool isActive) async {
    await _users.doc(uid).update({'isActive': isActive});
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

  Stream<List<PaymentModel>> streamPaymentsForMember(
      String memberUid) {
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

  Stream<List<DocumentModel>> streamDocumentsForMember(
      String memberUid) {
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

  // ════════════════════════════════════════════════════════════════════════════
  // ANNOUNCEMENTS
  // ════════════════════════════════════════════════════════════════════════════

  Stream<List<AnnouncementModel>> streamAnnouncements() {
    return _announcements
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AnnouncementModel.fromMap(
                d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  Future<void> addAnnouncement(
      AnnouncementModel announcement) async {
    final ref = _announcements.doc();
    await ref.set({...announcement.toMap()});
  }

  Future<void> updateAnnouncement(
      String id, String title, String body) async {
    await _announcements.doc(id).update({
      'title': title,
      'body':  body,
    });
  }

  Future<void> toggleAnnouncementActive(
      String id, bool isActive) async {
    await _announcements.doc(id).update({'isActive': isActive});
  }

  Future<void> deleteAnnouncement(String id) async {
    await _announcements.doc(id).delete();
  }

  // ════════════════════════════════════════════════════════════════════════════
  // COMPLAINTS
  // ════════════════════════════════════════════════════════════════════════════

  Stream<List<ComplaintModel>> streamComplaints() {
    return _complaints
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => ComplaintModel.fromMap(
                d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  Future<void> updateComplaintStatus({
    required String          complaintId,
    required ComplaintStatus status,
    required String          resolvedBy,
    required String          resolutionNote,
  }) async {
    await _complaints.doc(complaintId).update({
      'status':         status.name,
      'resolvedBy':     resolvedBy,
      'resolutionNote': resolutionNote,
      'updatedAt':      Timestamp.fromDate(DateTime.now()),
    });
  }
}