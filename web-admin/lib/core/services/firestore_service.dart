// core/services/firestore_service.dart
// UPDATED Phase 4 — adds staff, announcements, complaints

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/member_model.dart';
import '../models/payment_model.dart';
import '../models/lot_model.dart';
import '../models/document_model.dart';
import '../models/staff_model.dart';
import '../models/announcement_model.dart';
import '../models/complaint_model.dart';
import '../models/feedback_model.dart';
import '../models/user_model.dart';

/// Outcome of a generateMembershipFees() / generateMonthlyDues() call, for
/// showing a confirmation summary to the admin ("Created 42, skipped 8 who
/// already had one").
class GenerateDuesResult {
  final int created;
  final int skipped;

  /// Annual fees: number of billable members. Monthly dues: number of
  /// billable LOTS (a member with two lots counts twice).
  final int total;

  /// Monthly dues only: billable members who own no lot, so nothing could
  /// be generated for them.
  final int withoutLot;

  const GenerateDuesResult({
    required this.created,
    required this.skipped,
    required this.total,
    this.withoutLot = 0,
  });
}

/// Compares two numbers/labels naturally ("2" < "10").
int _naturalCompare(String a, String b) {
  final na = int.tryParse(a.trim());
  final nb = int.tryParse(b.trim());
  if (na != null && nb != null) return na.compareTo(nb);
  return a.trim().toLowerCase().compareTo(b.trim().toLowerCase());
}

/// The one ordering used everywhere a member's lots are listed. It also
/// defines a member's "first" lot, which inherits their pre-per-lot dues
/// records — so keep every caller on this function.
int compareLotsForBilling(LotModel a, LotModel b) {
  var c = _naturalCompare(a.phase, b.phase);
  if (c != 0) return c;
  c = _naturalCompare(a.block, b.block);
  return c != 0 ? c : _naturalCompare(a.lotNumber, b.lotNumber);
}

class _LotBill {
  final MemberModel member;
  final LotModel lot;
  const _LotBill(this.member, this.lot);
}

class FirestoreService {
  final FirebaseFirestore _db;

  FirestoreService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

  // Members who are billed dues. Delinquent members must keep being billed
  // (excluding them stopped the very members who owe money from accruing
  // and from showing on the dues screen); only inactive members are skipped.
  static final List<String> _billableStatuses = [
    MemberStatus.active.name,
    MemberStatus.delinquent.name,
  ];

  // Expose db for generating doc IDs externally
  FirebaseFirestore get db => _db;

  /// Firestore caps a WriteBatch at 500 operations. Runs [write] for indexes
  /// 0..total-1 in batches of [chunk] so bulk jobs keep working as the
  /// association grows. Not atomic across chunks — every caller here is
  /// safe to re-run (generators skip existing records; the sync/penalty
  /// jobs only touch records that still need changing).
  Future<void> _commitInChunks(
    int total,
    void Function(WriteBatch batch, int i) write, {
    int chunk = 400,
  }) async {
    for (var start = 0; start < total; start += chunk) {
      final end   = (start + chunk < total) ? start + chunk : total;
      final batch = _db.batch();
      for (var i = start; i < end; i++) {
        write(batch, i);
      }
      await batch.commit();
    }
  }

  CollectionReference<Map<String, dynamic>> get _users      => _db.collection('users');
  CollectionReference<Map<String, dynamic>> get _payments    => _db.collection('payments');
  CollectionReference<Map<String, dynamic>> get _docs       => _db.collection('documents');
  CollectionReference<Map<String, dynamic>> get _announcements => _db.collection('announcements');
  CollectionReference<Map<String, dynamic>> get _complaints  => _db.collection('complaints');
  CollectionReference<Map<String, dynamic>> get _feedbacks  => _db.collection('feedback');

  // Ledger: per-member snapshot of outstanding membership balance
  CollectionReference<Map<String, dynamic>> get _ledgers   => _db.collection('member_ledgers');

  // ════════════════════════════════════════════════════════════════════════════
  // COMPLAINTS
  // ════════════════════════════════════════════════════════════════════════════

  Stream<List<ComplaintModel>> streamPendingComplaints() {
    return _complaints
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.map((d) => ComplaintModel.fromMap(d.data(), d.id)).toList());
  }

  // ════════════════════════════════════════════════════════════════════════════
  // FEEDBACK
  // ════════════════════════════════════════════════════════════════════════════

  Stream<List<FeedbackModel>> streamPendingFeedbacks() {
    return _feedbacks
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snap) => snap.docs.map((d) => FeedbackModel.fromMap(d.data(), d.id)).toList());
  }

  // ════════════════════════════════════════════════════════════════════════════
  // LEDGER
  // ════════════════════════════════════════════════════════════════════════════

  Stream<List<Map<String, dynamic>>> streamMemberLedgers() {
    return _ledgers
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }

  Future<void> createOrUpdateLedger(String uid, double target, double balance, int year) async {
    final docRef = _ledgers.doc(uid);
    final doc = await docRef.get();
    if (!doc.exists) {
      await docRef.set({
        'uid': uid,
        'annualTarget': target,
        'currentBalance': balance,
        'year': year,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
    } else {
      await docRef.update({
        'annualTarget': target,
        'currentBalance': balance,
        'year': year,
        'updatedAt': Timestamp.now(),
      });
    }
  }

  Future<void> updateLedgerBalance(String uid, double amountDelta) async {
    final docRef = _ledgers.doc(uid);
    await _db.runTransaction((transaction) async {
      final doc = await transaction.get(docRef);
      if (!doc.exists) return; // Lazy init will handle it later if needed
      final current = (doc.data()?['currentBalance'] as num?)?.toDouble() ?? 0.0;
      transaction.update(docRef, {
        'currentBalance': current + amountDelta,
        'updatedAt': Timestamp.now(),
      });
    });
  }

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
    // Adjust outstanding balance for membership-type payments
    if (payment.type == PaymentType.membershipFee ||
        payment.type == PaymentType.monthlyMembership) {
      final delta = (payment.type == PaymentType.monthlyMembership)
          ? payment.amount
          : (payment.status == PaymentStatus.paid ? -payment.amount : 0.0);

      if (delta != 0.0) {
        await _db.runTransaction((transaction) async {
          final doc = await transaction.get(_ledgers.doc(payment.uid));
          if (!doc.exists) return; // Lazy init will handle it
          final current = (doc.data()?['currentBalance'] as num?)?.toDouble() ?? 0.0;
          transaction.update(_ledgers.doc(payment.uid), {
            'currentBalance': current + delta,
            'updatedAt': Timestamp.now(),
          });
        });
      }
    }
  }

  Future<void> updatePayment(PaymentModel payment) async {
    await _payments.doc(payment.id).update(payment.toMap());
  }

  Future<void> markPaymentPaid(String paymentId) async {
    final ref = _payments.doc(paymentId);
    final data = await ref.get();
    if (!data.exists) return;
    final type = PaymentTypeExt.fromString(data['type'] as String?);
    var amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
    final uid = data['uid'] as String? ?? '';

    // Annual fee: monthly payments already reduced the ledger, so only the
    // remaining balance is actually being paid now (e.g. 2000 fee with
    // 150 already paid via monthly → this payment is 1850). The
    // `bal < amount` check keeps a penalty-inflated amount from being
    // lowered by mistake.
    if (type == PaymentType.membershipFee && uid.isNotEmpty) {
      final ledgerSnap = await _ledgers.doc(uid).get();
      final bal =
          (ledgerSnap.data()?['currentBalance'] as num?)?.toDouble();
      if (bal != null && bal >= 0 && bal < amount) amount = bal;
    }

    await ref.update({
      'amount':   amount,
      'status':   PaymentStatus.paid.name,
      'paidDate': Timestamp.fromDate(DateTime.now()),
    });

    // Both annual and monthly membership payments reduce the member's
    // outstanding balance.
    final reducesBalance = type == PaymentType.monthlyMembership ||
        type == PaymentType.membershipFee;
    if (reducesBalance && amount > 0) {
      await _db.runTransaction((transaction) async {
        final ledgerRef = _ledgers.doc(data['uid'] as String? ?? '');
        final ledgerDoc = await transaction.get(ledgerRef);
        if (!ledgerDoc.exists) return;
        final current =
            (ledgerDoc.data()?['currentBalance'] as num?)?.toDouble() ?? 0.0;

        // Paying the annual fee settles the whole balance, so it can
        // never go below zero (e.g. 1875 left - 2000 paid = 0, not -125).
        final next = type == PaymentType.membershipFee
            ? (current - amount).clamp(0.0, double.infinity).toDouble()
            : current - amount;

        transaction.update(ledgerRef, {
          'currentBalance': next,
          'updatedAt': Timestamp.now(),
        });
      });
    }
  }

  Future<void> deletePayment(String paymentId) async {
    final ref = _payments.doc(paymentId);
    final data = await ref.get();
    if (!data.exists) return;
    // Restore outstanding balance for membership-type payments
    final type = PaymentTypeExt.fromString(data['type'] as String?);
    final status = PaymentStatusExt.fromString(data['status'] as String?);
    if (type == PaymentType.membershipFee ||
        type == PaymentType.monthlyMembership) {
      final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
      // Inverse of addPayment logic:
      // If addPayment did -amount (paid fee), restore by +amount
      // If addPayment did +amount (monthly), restore by -amount
      final delta = (type == PaymentType.monthlyMembership)
          ? -amount
          : (status == PaymentStatus.paid ? amount : 0.0);

      final uid = data['uid'] as String?;
      if (uid != null && delta != 0.0) {
        await _db.runTransaction((transaction) async {
          final ledgerRef = _ledgers.doc(uid);
          final ledgerDoc = await transaction.get(ledgerRef);
          if (ledgerDoc.exists) {
            final current = (ledgerDoc.data()?['currentBalance'] as num?)?.toDouble() ?? 0.0;
            transaction.update(ledgerRef, {
              'currentBalance': current + delta,
              'updatedAt': Timestamp.now(),
            });
          }
        });
      }
    }
    await ref.delete();
  }

  /// Free-tier alternative to a scheduled Cloud Function (those require the
  /// paid Blaze plan). Call this from a screen's initState — each time an
  /// admin opens Payments, any `unpaid` record whose dueDate has passed
  /// gets its stored `status` flipped to `overdue` for real. This keeps
  /// the Firestore field itself accurate (unlike the display-only
  /// `displayStatus` getter), so future reports/queries that filter
  /// directly on `status` will see it too.
  ///
  /// Trade-off vs. a Cloud Function: this only runs while someone with
  /// write access has the app open — there's no background update while
  /// the app is closed. For an admin-facing screen that's opened
  /// regularly, that's usually close enough in practice.
  ///
  /// Requires a composite index on (status ==, dueDate <) — Firestore will
  /// give you a console link to create it the first time this runs.
  Future<int> syncOverdueStatuses() async {
    // Start of today, NOT now: dueDate is stored at midnight, so comparing
    // with the current time flipped a record to overdue at 12:00 AM of its
    // own due date. This matches PaymentModel.displayStatus.
    final now   = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final snap = await _payments
        .where('status', isEqualTo: PaymentStatus.unpaid.name)
        .where('dueDate', isLessThan: Timestamp.fromDate(today))
        .get();

    if (snap.docs.isEmpty) return 0;

    final docs = snap.docs;
    await _commitInChunks(docs.length, (batch, i) {
      batch.update(docs[i].reference, {'status': PaymentStatus.overdue.name});
    });
    return docs.length;
  }

  /// Adds the flat overdue penalty to any `dues`/`membershipFee` record
  /// that is past its grace period and hasn't been penalized yet. Call
  /// this alongside syncOverdueStatuses() (e.g. in a screen's initState) —
  /// the two are separate concerns: a record flips to `overdue` display
  /// status the moment its dueDate passes (no grace period), but the
  /// [penaltyAmount] itself is only added once dueDate + [graceDays] has
  /// elapsed and only if it hasn't already been applied.
  ///
  /// Intentionally does NOT filter on `penaltyApplied` in the query
  /// itself — an equality filter on a field would silently exclude any
  /// payment doc created before that field existed (Firestore equality
  /// filters require the field to be present). Filtering client-side
  /// after a broader dueDate query handles old and new docs correctly,
  /// at the cost of reading somewhat more docs than strictly necessary.
  ///
  /// The query is limited to still-open records (unpaid/overdue) so it does
  /// not re-read every paid record in the collection each time an admin
  /// opens Payments (that grows without bound and eats the free read
  /// quota). Requires a composite index on (status, dueDate) — Firestore
  /// will give you a console link the first time this runs.
  Future<int> applyOverduePenalties({
    required double penaltyAmount,
    required int    graceDays,
  }) async {
    if (penaltyAmount <= 0) return 0;

    final cutoff = DateTime.now().subtract(Duration(days: graceDays));
    final snap = await _payments
        .where('status', whereIn: [
          PaymentStatus.unpaid.name,
          PaymentStatus.overdue.name,
        ])
        .where('dueDate', isLessThan: Timestamp.fromDate(cutoff))
        .get();

    final toPenalize = snap.docs.where((doc) {
      final data           = doc.data() as Map<String, dynamic>;
      final type            = PaymentTypeExt.fromString(data['type'] as String?);
      final status           = PaymentStatusExt.fromString(data['status'] as String?);
      final penaltyApplied   = data['penaltyApplied'] as bool? ?? false;
      return !penaltyApplied &&
          (type == PaymentType.dues || type == PaymentType.membershipFee || type == PaymentType.monthlyMembership) &&
          (status == PaymentStatus.unpaid || status == PaymentStatus.overdue);
    }).toList();

    if (toPenalize.isEmpty) return 0;

    await _commitInChunks(toPenalize.length, (batch, i) {
      final doc    = toPenalize[i];
      final data   = doc.data() as Map<String, dynamic>;
      final amount = (data['amount'] as num?)?.toDouble() ?? 0.0;
      batch.update(doc.reference, {
        'amount':         amount + penaltyAmount,
        'penaltyApplied': true,
      });
    });
    return toPenalize.length;
  }

  // ── Membership Fee (annual, org-wide — distinct from per-lot monthly dues) ─

  /// Membership fee payment records for a given calendar year, keyed by
  /// dueDate falling within [year]. Requires a composite index on
  /// (type ==, dueDate range) — Firestore will surface a console link the
  /// first time this runs if the index doesn't exist yet.
  Stream<List<PaymentModel>> streamMembershipFeesForYear(int year) {
    final start = DateTime(year, 1, 1);
    final end   = DateTime(year + 1, 1, 1);
    return _payments
        .where('type', isEqualTo: PaymentType.membershipFee.name)
        .where('dueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('dueDate', isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => PaymentModel.fromMap(
                d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  /// Creates one unpaid membership-fee record per active member who doesn't
  /// already have one for [year]. Skips members who already have a record
  /// (duplicate prevention is by calendar year of dueDate). Uses a single
  /// WriteBatch — fine for typical HOA member counts, but batches cap at
  /// 500 writes, so a very large association would need chunking.
  ///
  /// dueDate: intended to be Jan 31 of [year], but if this is run any time
  /// after that (e.g. the fee is generated late), the record would be born
  /// already overdue — and, with the Stage 3 penalty flow, could start
  /// accruing a penalty before anyone's even had a chance to pay it. To
  /// avoid that, the due date is pushed to [generationGraceDays] days from
  /// whenever this actually runs, but only when that gives more time than
  /// the intended Jan 31 date would — an on-time run in January still gets
  /// the normal Jan 31 due date.
  Future<GenerateDuesResult> generateMembershipFees({
    required int    year,
    required double amount,
    required String recordedBy,
    List<String>?   targetUids,
    int             generationGraceDays = 30,
  }) async {
    final membersSnap = await _users
        .where('role', isEqualTo: 'member')
        .where('status', whereIn: _billableStatuses)
        .get();
    var members = membersSnap.docs
        .map((d) => MemberModel.fromMap(
            d.data() as Map<String, dynamic>, d.id))
        .toList();

    if (targetUids != null) {
      members = members.where((m) => targetUids.contains(m.uid)).toList();
    }

    final start = DateTime(year, 1, 1);
    final end   = DateTime(year + 1, 1, 1);
    final existingSnap = await _payments
        .where('type', isEqualTo: PaymentType.membershipFee.name)
        .where('dueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('dueDate', isLessThan: Timestamp.fromDate(end))
        .get();
    final existingUids = existingSnap.docs
        .map((d) => (d.data() as Map<String, dynamic>)['uid'] as String? ?? '')
        .toSet();

    final toCreate = members
        .where((m) => !existingUids.contains(m.uid))
        .toList();

    if (toCreate.isEmpty) {
      return GenerateDuesResult(
        created: 0,
        skipped: members.length,
        total: members.length,
      );
    }

    final now   = DateTime.now();
    final intendedDueDate = DateTime(year, 1, 31);
    final graceDueDate    = now.add(Duration(days: generationGraceDays));
    // The year's records are looked up by dueDate falling inside [year]
    // (see streamMembershipFeesForYear and the duplicate check above), so
    // the pushed-back due date must never spill into the next year — a fee
    // generated in December used to land in January and vanish from its own
    // year's list (and could be generated a second time).
    final lastDayOfYear = DateTime(year, 12, 31);
    final pushedDueDate =
        graceDueDate.isAfter(lastDayOfYear) ? lastDayOfYear : graceDueDate;
    final dueDate = intendedDueDate.isAfter(now) ? intendedDueDate : pushedDueDate;
    await _commitInChunks(toCreate.length, (batch, i) {
      final member = toCreate[i];
      final ref = _payments.doc();
      final payment = PaymentModel(
        id:         ref.id,
        uid:        member.uid,
        memberName: member.name,
        type:       PaymentType.membershipFee,
        amount:     amount,
        status:     PaymentStatus.unpaid,
        dueDate:    dueDate,
        recordedBy: recordedBy,
        notes:      'Auto-generated annual membership fee for $year',
        createdAt:  DateTime.now(),
      );
      batch.set(ref, payment.toMap());
      // Initialize ledger for new annual fee
      batch.set(_ledgers.doc(member.uid), {
        'uid': member.uid,
        'annualTarget': amount,
        'currentBalance': amount,
        'year': year,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      });
    });

    return GenerateDuesResult(
      created: toCreate.length,
      skipped: members.length - toCreate.length,
      total: members.length,
    );
  }

  // ── Monthly Dues (per-lot — rate is locked to whichever month it's for) ────

  /// Monthly dues payment records for a given [year]/[month], keyed by
  /// dueDate falling within that month. Same shape as
  /// streamMembershipFeesForYear, scoped to a month instead of a year.
  /// Requires a composite index on (type ==, dueDate range).
  Stream<List<PaymentModel>> streamMonthlyDuesForMonth(int year, int month) {
    final start = DateTime(year, month, 1);
    final end   = DateTime(year, month + 1, 1);
    return _payments
        .where('type', isEqualTo: PaymentType.dues.name)
        .where('dueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('dueDate', isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => PaymentModel.fromMap(
                d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  /// Creates one unpaid monthly-dues record per LOT for [year]/[month], at
  /// [amount] (every lot pays the same rate). A lot is billed to its owner
  /// (`lot.uid`) when that owner is an active or delinquent member — a member
  /// with two lots therefore gets two records, each carrying its `lotId`.
  ///
  /// [lots] is the current contents of the lots collection (the caller
  /// fetches it, e.g. `LotService().streamLots().first`). Members who own no
  /// lot can't be billed and are counted in `withoutLot`.
  ///
  /// The caller resolves [amount] via RateHistoryService.getRateForMonth()
  /// *before* calling this — that locks the obligation to the rate active
  /// when the month began, independent of whether/when it's paid.
  ///
  /// Duplicate prevention is per (member, lot, calendar month of dueDate).
  /// A record made before per-lot billing existed has no `lotId`; it is
  /// treated as belonging to that member's FIRST lot (compareLotsForBilling
  /// order) so the switch doesn't re-bill the current month. Uses chunked
  /// batches, so any number of lots works.
  Future<GenerateDuesResult> generateMonthlyDues({
    required int    year,
    required int    month,
    required double amount,
    required String recordedBy,
    required List<LotModel> lots,
    List<String>?   targetUids,
    int             dueDay = 15,
  }) async {
    final membersSnap = await _users
        .where('role', isEqualTo: 'member')
        .where('status', whereIn: _billableStatuses)
        .get();
    var members = membersSnap.docs
        .map((d) => MemberModel.fromMap(
            d.data() as Map<String, dynamic>, d.id))
        .toList();

    if (targetUids != null) {
      members = members.where((m) => targetUids.contains(m.uid)).toList();
    }

    final lotsByUid = <String, List<LotModel>>{};
    for (final lot in lots) {
      final uid = lot.uid?.trim() ?? '';
      if (uid.isEmpty) continue;
      lotsByUid.putIfAbsent(uid, () => []).add(lot);
    }
    for (final list in lotsByUid.values) {
      list.sort(compareLotsForBilling);
    }

    final start = DateTime(year, month, 1);
    final end   = DateTime(year, month + 1, 1);
    final existingSnap = await _payments
        .where('type', isEqualTo: PaymentType.dues.name)
        .where('dueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('dueDate', isLessThan: Timestamp.fromDate(end))
        .get();

    final existingLotKeys = <String>{}; // "uid|lotId"
    final legacyUids      = <String>{}; // records with no lotId
    for (final d in existingSnap.docs) {
      final data  = d.data() as Map<String, dynamic>;
      final uid   = data['uid']   as String? ?? '';
      final lotId = data['lotId'] as String? ?? '';
      if (lotId.isEmpty) {
        legacyUids.add(uid);
      } else {
        existingLotKeys.add('$uid|$lotId');
      }
    }

    final toCreate = <_LotBill>[];
    var billable   = 0;
    var withoutLot = 0;
    for (final m in members) {
      final owned = lotsByUid[m.uid] ?? const <LotModel>[];
      if (owned.isEmpty) {
        withoutLot++;
        continue;
      }
      for (var i = 0; i < owned.length; i++) {
        billable++;
        final lot = owned[i];
        final covered = existingLotKeys.contains('${m.uid}|${lot.id}') ||
            (i == 0 && legacyUids.contains(m.uid));
        if (!covered) toCreate.add(_LotBill(m, lot));
      }
    }

    if (toCreate.isEmpty) {
      return GenerateDuesResult(
        created: 0,
        skipped: billable,
        total: billable,
        withoutLot: withoutLot,
      );
    }

    final dueDate = DateTime(year, month, dueDay);
    final period  = '${month.toString().padLeft(2, '0')}/$year';
    await _commitInChunks(toCreate.length, (batch, i) {
      final bill  = toCreate[i];
      final ref   = _payments.doc();
      final label = buildLotLabel(
          phase: bill.lot.phase,
          block: bill.lot.block,
          lotNumber: bill.lot.lotNumber);
      final payment = PaymentModel(
        id:         ref.id,
        uid:        bill.member.uid,
        memberName: bill.member.name,
        type:       PaymentType.dues,
        amount:     amount, // rate locked to this month
        status:     PaymentStatus.unpaid,
        dueDate:    dueDate,
        recordedBy: recordedBy,
        notes:      'Auto-generated monthly dues for $period'
            '${label.isEmpty ? '' : ' — $label'}',
        createdAt:  DateTime.now(),
        lotId:      bill.lot.id,
        lotLabel:   label,
      );
      batch.set(ref, payment.toMap());
    });

    return GenerateDuesResult(
      created: toCreate.length,
      skipped: billable - toCreate.length,
      total: billable,
      withoutLot: withoutLot,
    );
  }

  // ── Monthly Membership Fees (flat per member) ─────────────────────────────

  Future<GenerateDuesResult> generateMonthlyMemberships({
    required int    year,
    required int    month,
    required double amount,
    required String recordedBy,
    List<String>?   targetUids,
  }) async {
    final membersSnap = await _users
        .where('role', isEqualTo: 'member')
        .where('status', whereIn: _billableStatuses)
        .get();
    var members = membersSnap.docs
        .map((d) => MemberModel.fromMap(
            d.data() as Map<String, dynamic>, d.id))
        .toList();

    if (targetUids != null) {
      members = members.where((m) => targetUids.contains(m.uid)).toList();
    }

    final start = DateTime(year, month, 1);
    final end   = DateTime(year, month + 1, 1);
    final existingSnap = await _payments
        .where('type', isEqualTo: PaymentType.monthlyMembership.name)
        .where('dueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('dueDate', isLessThan: Timestamp.fromDate(end))
        .get();
    final existingUids = existingSnap.docs
        .map((d) => (d.data() as Map<String, dynamic>)['uid'] as String? ?? '')
        .toSet();

    final toCreate = members
        .where((m) => !existingUids.contains(m.uid))
        .toList();

    if (toCreate.isEmpty) {
      return GenerateDuesResult(
        created: 0,
        skipped: members.length,
        total: members.length,
      );
    }

    final dueDate = DateTime(year, month, 25); // Arbitrary day
    await _commitInChunks(toCreate.length, (batch, i) {
      final member = toCreate[i];
      final ref = _payments.doc();
      final payment = PaymentModel(
        id:         ref.id,
        uid:        member.uid,
        memberName: member.name,
        type:       PaymentType.monthlyMembership,
        amount:     amount,
        status:     PaymentStatus.unpaid,
        dueDate:    dueDate,
        recordedBy: recordedBy,
        notes:      'Auto-generated monthly membership',
        createdAt:  DateTime.now(),
      );
      batch.set(ref, payment.toMap());
      // Do NOT touch the ledger here — it holds the ANNUAL target balance
      // (set by generateMembershipFees). Monthly membership records deduct
      // from it via markPaymentPaid, never overwrite it.
    });
    return GenerateDuesResult(
      created: toCreate.length,
      skipped: members.length - toCreate.length,
      total: members.length,
    );
  }

  /// Monthly membership payment records for a given [year]/[month].
  Stream<List<PaymentModel>> streamMonthlyFeesForMonth(int year, int month) {
    final start = DateTime(year, month, 1);
    final end   = DateTime(year, month + 1, 1);
    return _payments
        .where('type', isEqualTo: PaymentType.monthlyMembership.name)
        .where('dueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('dueDate', isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => PaymentModel.fromMap(
                d.data() as Map<String, dynamic>, d.id))
            .toList());
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

  // ════════════════════════════════════════════════════════════════════════════
  // FEEDBACK
  // ════════════════════════════════════════════════════════════════════════════

  Stream<List<FeedbackModel>> streamFeedback() {
    return _feedbacks
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => FeedbackModel.fromMap(
                d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  Future<void> updateFeedbackStatus({
    required String          feedbackId,
    required FeedbackStatus  status,
    required String          resolvedBy,
    required String          resolutionNote,
  }) async {
    await _feedbacks.doc(feedbackId).update({
      'status':           status.name,
      'resolvedBy':       resolvedBy,
      'resolutionNote':   resolutionNote,
      'updatedAt':        Timestamp.fromDate(DateTime.now()),
    });
  }
}