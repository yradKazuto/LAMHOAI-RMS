import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/lot_model.dart';

/// Handles all Firestore reads/writes for the `lots` collection.
class LotService {
  final _db = FirebaseFirestore.instance;
  CollectionReference get _lots => _db.collection('lots');

  Stream<List<LotModel>> streamLots() {
    return _lots.orderBy('phase').snapshots().map((snap) => snap.docs
        .map((d) => LotModel.fromMap(d.id, d.data() as Map<String, dynamic>))
        .toList());
  }

  Stream<List<LotModel>> streamLotsByPhase(String phase) {
    return _lots
        .where('phase', isEqualTo: phase)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) =>
                LotModel.fromMap(d.id, d.data() as Map<String, dynamic>))
            .toList());
  }

  Future<List<String>> getDistinctPhases() async {
    final snap = await _lots.get();
    final phases = snap.docs
        .map((d) => (d.data() as Map<String, dynamic>)['phase'] as String?)
        .whereType<String>()
        .toSet()
        .toList();
    phases.sort();
    return phases;
  }

  Future<void> createLot(LotModel lot) async {
    await _lots.doc(lot.id.isEmpty ? null : lot.id).set(lot.toMap());
  }

  /// Creates a brand-new vacant lot pinned at a specific spot on the
  /// subdivision map image (mapX/mapY normalized 0.0–1.0).
  Future<void> createLotAtPin({
    required String phase,
    required String block,
    required String lotNumber,
    required double mapX,
    required double mapY,
    required String updatedBy,
  }) async {
    await _lots.add({
      'phase': phase,
      'block': block,
      'lotNumber': lotNumber,
      'areaSqm': null,
      'status': LotStatus.vacant.name,
      'uid': null,
      'ownerName': null,
      'price': null,
      'contactNumber': null,
      'notes': null,
      'updatedBy': updatedBy,
      'updatedAt': Timestamp.now(),
      'mapX': mapX,
      'mapY': mapY,
    });
  }

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

  Future<void> updateLot(String lotId, Map<String, dynamic> data) async {
    data['updatedAt'] = Timestamp.now();
    await _lots.doc(lotId).update(data);
  }

  Future<void> assignOwner({
    required String lotId,
    required String uid,
    required String ownerName,
    required String updatedBy,
  }) async {
    await _lots.doc(lotId).update({
      'status': LotStatus.occupied.name,
      'uid': uid,
      'ownerName': ownerName,
      'price': null,
      'contactNumber': null,
      'updatedBy': updatedBy,
      'updatedAt': Timestamp.now(),
    });
  }

  Future<void> unassignOwner({
    required String lotId,
    required String updatedBy,
  }) async {
    await _lots.doc(lotId).update({
      'status': LotStatus.vacant.name,
      'uid': null,
      'ownerName': null,
      'updatedBy': updatedBy,
      'updatedAt': Timestamp.now(),
    });
  }

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

  Future<void> deleteLot(String lotId) async {
    await _lots.doc(lotId).delete();
  }
}