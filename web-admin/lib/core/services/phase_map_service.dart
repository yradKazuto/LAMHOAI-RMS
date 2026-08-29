// core/services/phase_map_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/phase_map_model.dart';

/// Handles Firestore reads/writes for the `phaseMaps` collection —
/// additional subdivision phases beyond the original hardcoded Phase 1.
class PhaseMapService {
  final _db = FirebaseFirestore.instance;

  CollectionReference get _phaseMaps => _db.collection('phaseMaps');

  Stream<List<PhaseMapModel>> streamPhaseMaps() {
    return _phaseMaps
        .orderBy('createdAt')
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => PhaseMapModel.fromMap(
                d.id, d.data() as Map<String, dynamic>))
            .toList());
  }

  /// Creates a new phase entry with no image yet — the image can be
  /// uploaded later via setPhaseImage() once it's ready.
  Future<void> createPhase({
    required String name,
    required String createdBy,
  }) async {
    await _phaseMaps.add({
      'name': name,
      'imageUrl': '',
      'createdBy': createdBy,
      'createdAt': Timestamp.now(),
    });
  }

  Future<void> setPhaseImage(String phaseMapId, String imageUrl) async {
    await _phaseMaps.doc(phaseMapId).update({'imageUrl': imageUrl});
  }

  Future<void> deletePhase(String phaseMapId) async {
    await _phaseMaps.doc(phaseMapId).delete();
  }
}