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
  /// uploaded later via setPhaseImage() once it's ready. [blockCount]
  /// generates that many blocks up front, numbered "1".."blockCount"
  /// — more can be added later via addBlocks().
  Future<void> createPhase({
    required String name,
    required String createdBy,
    required int blockCount,
  }) async {
    final blocks = List.generate(blockCount, (i) => '${i + 1}');
    await _phaseMaps.add({
      'name': name,
      'imageUrl': '',
      'blocks': blocks,
      'createdBy': createdBy,
      'createdAt': Timestamp.now(),
    });
  }

  Future<void> setPhaseImage(String phaseMapId, String imageUrl) async {
    await _phaseMaps.doc(phaseMapId).update({'imageUrl': imageUrl});
  }

  /// Creates the phase entry named [name] if none exists yet, or
  /// updates its imageUrl/blocks in place if it does — matched by
  /// name (case-insensitive, trimmed), same as everywhere else phase
  /// names get compared in this app. Used by the one-time Phase 1
  /// migration, which needs to be safely re-runnable without creating
  /// a second "Phase 1" entry each time. Returns the phase's doc ID.
  Future<String> upsertPhaseByName({
    required String name,
    required String imageUrl,
    required List<String> blocks,
    required String createdBy,
  }) async {
    final normalized = name.trim().toLowerCase();
    final snap = await _phaseMaps.get();

    for (final doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final docName = (data['name'] as String? ?? '').trim().toLowerCase();
      if (docName == normalized) {
        await _phaseMaps.doc(doc.id).update({
          'imageUrl': imageUrl,
          'blocks': blocks,
        });
        return doc.id;
      }
    }

    final ref = await _phaseMaps.add({
      'name': name,
      'imageUrl': imageUrl,
      'blocks': blocks,
      'createdBy': createdBy,
      'createdAt': Timestamp.now(),
    });
    return ref.id;
  }

  Future<List<String>> _currentBlocks(String phaseMapId) async {
    final doc = await _phaseMaps.doc(phaseMapId).get();
    final data = doc.data() as Map<String, dynamic>?;
    return (data?['blocks'] as List?)?.map((b) => b.toString()).toList() ??
        <String>[];
  }

  /// Adds [additionalCount] new blocks to a phase, continuing the
  /// numbering from the highest existing numeric block (e.g. adding 2
  /// to a phase that already has blocks "1".."5" produces "6" and
  /// "7"). Non-numeric existing block labels are ignored for the
  /// purpose of picking the next number, but are left untouched.
  Future<void> addBlocks(String phaseMapId, int additionalCount) async {
    if (additionalCount <= 0) return;
    final current = await _currentBlocks(phaseMapId);
    final existingNumbers = current.map(int.tryParse).whereType<int>();
    final startAt =
        (existingNumbers.isEmpty ? 0 : existingNumbers.reduce((a, b) => a > b ? a : b)) + 1;
    final updated = [
      ...current,
      for (var i = 0; i < additionalCount; i++) '${startAt + i}',
    ];
    await _phaseMaps.doc(phaseMapId).update({'blocks': updated});
  }

  /// Renames a block. Callers are responsible for confirming the
  /// block has no lots assigned to it first (see LotService) — this
  /// method just performs the raw update.
  Future<void> renameBlock(
    String phaseMapId,
    String oldLabel,
    String newLabel,
  ) async {
    final current = await _currentBlocks(phaseMapId);
    final idx = current.indexOf(oldLabel);
    if (idx == -1) return;
    current[idx] = newLabel;
    await _phaseMaps.doc(phaseMapId).update({'blocks': current});
  }

  /// Removes a block from a phase's defined list. Callers are
  /// responsible for confirming the block has no lots assigned to it
  /// first (see LotService) — this method just performs the raw
  /// update.
  Future<void> removeBlock(String phaseMapId, String label) async {
    final current = await _currentBlocks(phaseMapId);
    current.remove(label);
    await _phaseMaps.doc(phaseMapId).update({'blocks': current});
  }

  Future<void> deletePhase(String phaseMapId) async {
    await _phaseMaps.doc(phaseMapId).delete();
  }
}