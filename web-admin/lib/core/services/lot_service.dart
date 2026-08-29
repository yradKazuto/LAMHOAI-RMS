import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/lot_model.dart';

/// Handles all Firestore reads/writes for the `lots` collection.
class LotService {
  final _db = FirebaseFirestore.instance;

  CollectionReference get _lots => _db.collection('lots');

  // ================================================================
  // LOT STREAMS
  // ================================================================

  Stream<List<LotModel>> streamLots() {
    return _lots
        .orderBy('phase')
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (d) => LotModel.fromMap(
                  d.id,
                  d.data() as Map<String, dynamic>,
                ),
              )
              .toList(),
        );
  }

  Stream<List<LotModel>> streamLotsByPhase(String phase) {
    return _lots
        .where('phase', isEqualTo: phase)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (d) => LotModel.fromMap(
                  d.id,
                  d.data() as Map<String, dynamic>,
                ),
              )
              .toList(),
        );
  }

  /// Streams ALL lots currently assigned to [uid] — a member can now own
  /// more than one lot, so this replaces the old single-lot lookup.
  /// Used to show a member's real, live list of owned lots on their
  /// profile — always in sync with the Location Mapping feature, no
  /// denormalized copy to go stale.
  Stream<List<LotModel>> streamLotsForMember(String uid) {
    if (uid.isEmpty) return Stream.value(<LotModel>[]);
    return _lots
        .where('uid', isEqualTo: uid)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) =>
                LotModel.fromMap(d.id, d.data() as Map<String, dynamic>))
            .toList());
  }

  Future<List<String>> getDistinctPhases() async {
    final snap = await _lots.get();

    final phases = snap.docs
        .map(
          (d) => (d.data() as Map<String, dynamic>)['phase']
              as String?,
        )
        .whereType<String>()
        .toSet()
        .toList();

    phases.sort();

    return phases;
  }

  // ================================================================
  // CREATE LOT
  // ================================================================

  Future<void> createLot(LotModel lot) async {
    await _lots
        .doc(lot.id.isEmpty ? null : lot.id)
        .set(lot.toMap());
  }

  /// Creates a brand-new lot pinned at a specific spot on the
  /// subdivision map image.
  Future<void> createLotAtPin({
    required String phase,
    required String block,
    required String lotNumber,
    required double mapX,
    required double mapY,
    required String updatedBy,
    LotStatus status = LotStatus.vacant,
    String? uid,
    String? ownerName,
    String? contactNumber,
    String? notes,
    double? price,
  }) async {
    await _lots.add({
      'phase': phase,
      'block': block,
      'lotNumber': lotNumber,
      'areaSqm': null,
      'status': status.name,
      'uid': uid,
      'ownerName': ownerName,
      'price': price,
      'contactNumber': contactNumber,
      'notes': notes,
      'updatedBy': updatedBy,
      'updatedAt': Timestamp.now(),
      'mapX': mapX,
      'mapY': mapY,
    });
  }

  // ================================================================
  // MAP PIN
  // ================================================================

  /// Moves an existing lot's pin to a new spot on the map image.
  Future<void> updatePinPosition({
    required String lotId,
    required double mapX,
    required double mapY,
    required String updatedBy,
  }) async {
    await _lots.doc(lotId).update({
      'mapX': mapX,
      'mapY': mapY,
      'updatedBy': updatedBy,
      'updatedAt': Timestamp.now(),
    });
  }

  // ================================================================
  // GENERAL LOT UPDATE
  // ================================================================

  Future<void> updateLot(
    String lotId,
    Map<String, dynamic> data,
  ) async {
    data['updatedAt'] = Timestamp.now();

    await _lots.doc(lotId).update(data);
  }

  // ================================================================
  // ASSIGN OWNER
  // ================================================================

  /// Assigns a member to a lot AND updates the member's record.
  ///
  /// The following are synchronized:
  ///
  /// LOT:
  ///   status
  ///   uid
  ///   ownerName
  ///
  /// MEMBER:
  ///   phase
  ///   lotNumber
  ///
  /// A member cannot be assigned to more than one lot.
  Future<void> assignOwner({
    required String lotId,
    required String uid,
    required String ownerName,
    required String updatedBy,
  }) async {
    final lotRef = _lots.doc(lotId);
    final users = _db.collection('users');
    final memberRef = users.doc(uid);

    // --------------------------------------------------------------
    // Get the lot
    // --------------------------------------------------------------

    final lotSnap = await lotRef.get();

    if (!lotSnap.exists) {
      throw Exception('Lot not found.');
    }

    final lotData =
        lotSnap.data() as Map<String, dynamic>;

    final phase =
        lotData['phase'] as String? ?? '';

    final lotNumber =
        lotData['lotNumber'] as String? ?? '';

    final previousUid =
        lotData['uid'] as String?;

    // --------------------------------------------------------------
    // Make sure the selected member exists
    // --------------------------------------------------------------

    final memberSnap = await memberRef.get();

    if (!memberSnap.exists) {
      throw Exception(
        'The selected member could not be found.',
      );
    }

    // --------------------------------------------------------------
    // Note: members are now allowed to own more than one lot (e.g.
    // Block 1 Lot 1 and Block 2 Lot 2 for the same member), so the
    // previous "already assigned to another lot" restriction has been
    // removed. Ownership across multiple lots is shown via
    // LotService.streamLotsForMember on the member's profile.
    // --------------------------------------------------------------

    // --------------------------------------------------------------
    // Batch update
    // --------------------------------------------------------------

    final batch = _db.batch();

    // --------------------------------------------------------------
    // If the lot had a previous owner, remove the old member's
    // lot assignment.
    // --------------------------------------------------------------

    if (previousUid != null &&
        previousUid.isNotEmpty &&
        previousUid != uid) {
      final previousMemberRef =
          users.doc(previousUid);

      final previousMemberSnap =
          await previousMemberRef.get();

      if (previousMemberSnap.exists) {
        batch.update(
          previousMemberRef,
          {
            'phase': '',
            'lotNumber': '',
          },
        );
      }
    }

    // --------------------------------------------------------------
    // Update LOT
    // --------------------------------------------------------------

    batch.update(
      lotRef,
      {
        'status': LotStatus.occupied.name,
        'uid': uid,
        'ownerName': ownerName,
        'price': null,
        'contactNumber': null,
        'updatedBy': updatedBy,
        'updatedAt': Timestamp.now(),
      },
    );

    // --------------------------------------------------------------
    // Update MEMBER
    // --------------------------------------------------------------

    batch.update(
      memberRef,
      {
        'phase': phase,
        'lotNumber': lotNumber,
      },
    );

    await batch.commit();
  }

  // ================================================================
  // UNASSIGN OWNER
  // ================================================================

  /// Makes a lot vacant AND removes the lot assignment
  /// from the member.
  Future<void> unassignOwner({
    required String lotId,
    required String updatedBy,
  }) async {
    final lotRef = _lots.doc(lotId);
    final users = _db.collection('users');

    // --------------------------------------------------------------
    // Get current lot
    // --------------------------------------------------------------

    final lotSnap = await lotRef.get();

    if (!lotSnap.exists) {
      throw Exception('Lot not found.');
    }

    final lotData =
        lotSnap.data() as Map<String, dynamic>;

    final uid =
        lotData['uid'] as String?;

    // --------------------------------------------------------------
    // Batch
    // --------------------------------------------------------------

    final batch = _db.batch();

    // --------------------------------------------------------------
    // Make lot vacant
    // --------------------------------------------------------------

    batch.update(
      lotRef,
      {
        'status': LotStatus.vacant.name,
        'uid': null,
        'ownerName': null,
        'updatedBy': updatedBy,
        'updatedAt': Timestamp.now(),
      },
    );

    // --------------------------------------------------------------
    // Clear member's lot information
    // --------------------------------------------------------------

    if (uid != null && uid.isNotEmpty) {
      final memberRef = users.doc(uid);

      final memberSnap =
          await memberRef.get();

      if (memberSnap.exists) {
        batch.update(
          memberRef,
          {
            'phase': '',
            'lotNumber': '',
          },
        );
      }
    }

    await batch.commit();
  }

  // ================================================================
  // MARK FOR SALE
  // ================================================================

  Future<void> markForSale({
    required String lotId,
    required double price,
    required String contactNumber,
    required String updatedBy,
    String? notes,
  }) async {
    await _lots.doc(lotId).update({
      'status': LotStatus.forSale.name,
      'price': price,
      'contactNumber': contactNumber,
      'notes': notes,
      'updatedBy': updatedBy,
      'updatedAt': Timestamp.now(),
    });
  }

  // ================================================================
  // DELIST
  // ================================================================

  Future<void> delist({
    required String lotId,
    required String updatedBy,
  }) async {
    await _lots.doc(lotId).update({
      'status': LotStatus.vacant.name,
      'price': null,
      'contactNumber': null,
      'updatedBy': updatedBy,
      'updatedAt': Timestamp.now(),
    });
  }

  // ================================================================
  // DELETE
  // ================================================================

  Future<void> deleteLot(String lotId) async {
    await _lots.doc(lotId).delete();
  }
}