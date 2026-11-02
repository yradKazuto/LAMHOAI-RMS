import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/lot_model.dart';

/// Handles all Firestore reads/writes for the `lots` collection.
class LotService {
  final FirebaseFirestore _db;

  LotService({FirebaseFirestore? db}) : _db = db ?? FirebaseFirestore.instance;

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

  Future<void> assignOwner({
    required String lotId,
    required String uid,
    required String ownerName,
    required String updatedBy,
  }) async {
    final lotRef = _lots.doc(lotId);
    final users = _db.collection('users');
    final memberRef = users.doc(uid);

    final lotSnap = await lotRef.get();
    if (!lotSnap.exists) throw Exception('Lot not found.');
    final lotData = lotSnap.data() as Map<String, dynamic>;
    final phase = lotData['phase'] as String? ?? '';
    final lotNumber = lotData['lotNumber'] as String? ?? '';
    final previousUid = lotData['uid'] as String?;

    final memberSnap = await memberRef.get();
    if (!memberSnap.exists) throw Exception('The selected member could not be found.');

    final batch = _db.batch();

    if (previousUid != null && previousUid.isNotEmpty && previousUid != uid) {
      final previousMemberRef = users.doc(previousUid);
      final previousMemberSnap = await previousMemberRef.get();
      if (previousMemberSnap.exists) {
        batch.update(previousMemberRef, {'phase': '', 'lotNumber': ''});
      }
    }

    batch.update(lotRef, {
      'status': LotStatus.occupied.name,
      'uid': uid,
      'ownerName': ownerName,
      'price': null,
      'contactNumber': null,
      'updatedBy': updatedBy,
      'updatedAt': Timestamp.now(),
    });

    batch.update(memberRef, {'phase': phase, 'lotNumber': lotNumber});

    await batch.commit();
  }

  // ================================================================
  // UNASSIGN OWNER
  // ================================================================

  Future<void> unassignOwner({
    required String lotId,
    required String updatedBy,
  }) async {
    final lotRef = _lots.doc(lotId);
    final users = _db.collection('users');
    final lotSnap = await lotRef.get();
    if (!lotSnap.exists) throw Exception('Lot not found.');
    final lotData = lotSnap.data() as Map<String, dynamic>;
    final uid = lotData['uid'] as String?;

    final batch = _db.batch();
    batch.update(lotRef, {
      'status': LotStatus.vacant.name,
      'uid': null,
      'ownerName': null,
      'updatedBy': updatedBy,
      'updatedAt': Timestamp.now(),
    });

    if (uid != null && uid.isNotEmpty) {
      final memberRef = users.doc(uid);
      final memberSnap = await memberRef.get();
      if (memberSnap.exists) {
        batch.update(memberRef, {'phase': '', 'lotNumber': ''});
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
  // GEOMETRY
  // ================================================================

  static bool _segmentsIntersect(LotPoint p1, LotPoint q1, LotPoint p2, LotPoint q2) {
    int orientation(LotPoint p, LotPoint q, LotPoint r) {
      final val = (q.y - p.y) * (r.x - q.x) - (q.x - p.x) * (r.y - q.y);
      if (val.abs() < 1e-9) return 0;
      return val > 0 ? 1 : 2;
    }
    bool onSegment(LotPoint p, LotPoint q, LotPoint r) {
      return q.x <= (p.x > r.x ? p.x : r.x) && q.x >= (p.x < r.x ? p.x : r.x) &&
             q.y <= (p.y > r.y ? p.y : r.y) && q.y >= (p.y < r.y ? p.y : r.y);
    }
    final o1 = orientation(p1, q1, p2);
    final o2 = orientation(p1, q1, q2);
    final o3 = orientation(p2, q2, p1);
    final o4 = orientation(p2, q2, q1);
    if (o1 != o2 && o3 != o4) return true;
    if (o1 == 0 && onSegment(p1, p2, q1)) return true;
    if (o2 == 0 && onSegment(p1, q2, q1)) return true;
    if (o3 == 0 && onSegment(p2, p1, q2)) return true;
    if (o4 == 0 && onSegment(p2, q1, q2)) return true;
    return false;
  }

  static bool isSelfIntersecting(List<LotPoint> points) {
    final n = points.length;
    if (n < 4) return false;
    for (var i = 0; i < n; i++) {
      final a1 = points[i];
      final a2 = points[(i + 1) % n];
      for (var j = i + 1; j < n; j++) {
        final isAdjacent = (j == i + 1) || (i == 0 && j == n - 1);
        if (isAdjacent) continue;
        final b1 = points[j];
        final b2 = points[(j + 1) % n];
        if (_segmentsIntersect(a1, a2, b1, b2)) return true;
      }
    }
    return false;
  }

  static bool _segmentsProperlyCross(LotPoint p1, LotPoint q1, LotPoint p2, LotPoint q2) {
    int orientation(LotPoint p, LotPoint q, LotPoint r) {
      final val = (q.y - p.y) * (r.x - q.x) - (q.x - p.x) * (r.y - q.y);
      if (val.abs() < 1e-9) return 0;
      return val > 0 ? 1 : 2;
    }
    final o1 = orientation(p1, q1, p2);
    final o2 = orientation(p1, q1, q2);
    final o3 = orientation(p2, q2, p1);
    final o4 = orientation(p2, q2, q1);
    return o1 != 0 && o2 != 0 && o3 != 0 && o4 != 0 && o1 != o2 && o3 != o4;
  }

  static bool _pointInPolygon(LotPoint p, List<LotPoint> poly) {
    var inside = false;
    final n = poly.length;
    for (var i = 0, j = n - 1; i < n; j = i++) {
      final pi = poly[i], pj = poly[j];
      if (((pi.y > p.y) != (pj.y > p.y)) &&
          (p.x < (pj.x - pi.x) * (p.y - pi.y) / (pj.y - pi.y) + pi.x)) {
        inside = !inside;
      }
    }
    return inside;
  }

  static bool polygonsOverlap(List<LotPoint> a, List<LotPoint> b) {
    double minX(List<LotPoint> p) => p.map((o) => o.x).reduce((x, y) => x < y ? x : y);
    double maxX(List<LotPoint> p) => p.map((o) => o.x).reduce((x, y) => x > y ? x : y);
    double minY(List<LotPoint> p) => p.map((o) => o.y).reduce((x, y) => x < y ? x : y);
    double maxY(List<LotPoint> p) => p.map((o) => o.y).reduce((x, y) => x > y ? x : y);
    if (maxX(a) < minX(b) || maxX(b) < minX(a) || maxY(a) < minY(b) || maxY(b) < minY(a)) return false;
    final an = a.length, bn = b.length;
    for (var i = 0; i < an; i++) {
      final a1 = a[i], a2 = a[(i + 1) % an];
      for (var j = 0; j < bn; j++) {
        final b1 = b[j], b2 = b[(j + 1) % bn];
        if (_segmentsProperlyCross(a1, a2, b1, b2)) return true;
      }
    }
    if (_pointInPolygon(a.first, b)) return true;
    if (_pointInPolygon(b.first, a)) return true;
    return false;
  }

  Future<List<LotModel>> findOverlappingLots({
    required String phase,
    required List<LotPoint> points,
    String? excludeLotId,
  }) async {
    final normalizedPhase = phase.trim().toLowerCase();
    final snap = await _lots.get();
    final conflicts = <LotModel>[];
    for (final doc in snap.docs) {
      if (doc.id == excludeLotId) continue;
      final data = doc.data() as Map<String, dynamic>;
      final docPhase = (data['phase'] as String? ?? '').trim().toLowerCase();
      if (docPhase != normalizedPhase) continue;
      final lot = LotModel.fromMap(doc.id, data);
      if (!lot.hasPolygon) continue;
      if (polygonsOverlap(points, lot.polygonPoints!)) conflicts.add(lot);
    }
    return conflicts;
  }

  // ================================================================
  // BULK IMPORT / UPDATES
  // ================================================================

  Future<int> importPolygonLots({
    required String phase,
    required Map<String, List<LotPoint>> lotsData,
    required String updatedBy,
  }) async {
    final normalizedPhase = phase.trim().toLowerCase();
    final existingSnap = await _lots.get();
    final existingByKey = <String, String>{};
    final existingLots = <LotModel>[];
    for (final doc in existingSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final docPhase = (data['phase'] as String? ?? '').trim().toLowerCase();
      if (docPhase != normalizedPhase) continue;
      existingLots.add(LotModel.fromMap(doc.id, data));
      final block = (data['block'] as String? ?? '').trim().toLowerCase();
      final lotNumber = (data['lotNumber'] as String? ?? '').trim().toLowerCase();
      existingByKey['$block|$lotNumber'] = doc.id;
    }
    final entries = lotsData.entries.toList();
    final errors = <String>[];
    for (var i = 0; i < entries.length; i++) {
      final key = entries[i].key;
      final points = entries[i].value;
      if (points.isEmpty) continue;
      if (isSelfIntersecting(points)) {
        errors.add('$key: boundary crosses itself.');
        continue;
      }
      final parts = key.split('|');
      final matchKey = parts.length == 2 ? '${parts[0].trim().toLowerCase()}|${parts[1].trim().toLowerCase()}' : key;
      final existingId = existingByKey[matchKey];
      for (final existing in existingLots) {
        if (existing.id == existingId) continue;
        if (!existing.hasPolygon) continue;
        if (polygonsOverlap(points, existing.polygonPoints!)) {
          errors.add('$key: overlaps existing Block ${existing.block} Lot ${existing.lotNumber}.');
        }
      }
      for (var j = 0; j < entries.length; j++) {
        if (j == i) continue;
        final otherPoints = entries[j].value;
        if (otherPoints.isEmpty) continue;
        if (polygonsOverlap(points, otherPoints)) {
          errors.add('$key: overlaps ${entries[j].key} in this same import.');
        }
      }
    }
    if (errors.isNotEmpty) throw LotOverlapException(errors);
    final batch = _db.batch();
    int count = 0;
    for (final entry in entries) {
      final parts = entry.key.split('|');
      if (parts.length != 2) continue;
      final block = parts[0];
      final lotNumber = parts[1];
      final points = entry.value;
      if (points.isEmpty) continue;
      final cx = points.map((p) => p.x).reduce((a, b) => a + b) / points.length;
      final cy = points.map((p) => p.y).reduce((a, b) => a + b) / points.length;
      final polygonMaps = points.map((p) => p.toMap()).toList();
      final matchKey = '${block.trim().toLowerCase()}|${lotNumber.trim().toLowerCase()}';
      final existingId = existingByKey[matchKey];
      if (existingId != null) {
        batch.update(_lots.doc(existingId), {
          'polygonPoints': polygonMaps,
          'mapX': cx,
          'mapY': cy,
          'updatedBy': updatedBy,
          'updatedAt': Timestamp.now(),
        });
      } else {
        batch.set(_lots.doc(), {
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
          'mapX': cx,
          'mapY': cy,
          'polygonPoints': polygonMaps,
        });
      }
      count++;
    }
    await batch.commit();
    return count;
  }

  Future<int> bulkUpdateLotAreas(
    String phase,
    List<Map<String, dynamic>> rows,
    String updatedBy,
  ) async {
    final normalizedPhase = phase.trim().toLowerCase();
    final snapshot = await _lots.where('phase', isEqualTo: normalizedPhase).get();
    final lotMap = {
      for (var doc in snapshot.docs)
        '${(doc.data() as Map)['block']}|${(doc.data() as Map)['lotNumber']}': doc.reference
    };
    final batch = _db.batch();
    int count = 0;
    for (var row in rows) {
      final key = '${row['block']}|${row['lotNumber']}';
      final ref = lotMap[key];
      if (ref != null) {
        batch.update(ref, {
          'areaSqm': row['areaSqm'],
          'updatedAt': Timestamp.now(),
          'updatedBy': updatedBy,
        });
        count++;
      }
    }
    await batch.commit();
    return count;
  }

  Future<Phase1MigrationResult> migratePhase1FromHardcodedShapes({
    required String phaseName,
    required List<HardcodedLotShape> shapes,
    required double imageWidth,
    required double imageHeight,
    required String updatedBy,
  }) async {
    final normalizedPhase = phaseName.trim().toLowerCase();
    final existingSnap = await _lots.get();
    final existingByKey = <String, String>{};
    for (final doc in existingSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final docPhase = (data['phase'] as String? ?? '').trim().toLowerCase();
      if (docPhase != normalizedPhase) continue;
      final block = (data['block'] as String? ?? '').trim().toLowerCase();
      final lotNumber = (data['lotNumber'] as String? ?? '').trim().toLowerCase();
      existingByKey['$block|$lotNumber'] = doc.id;
    }
    final valid = <HardcodedLotShape>[];
    final warnings = <String>[];
    for (final shape in shapes) {
      if (shape.pixelPoints.length < 3) {
        warnings.add('Block ${shape.block} Lot ${shape.lotNumber}: fewer than 3 points, skipped.');
        continue;
      }
      valid.add(shape);
    }
    int created = 0;
    int updated = 0;
    const chunkSize = 400;
    for (var i = 0; i < valid.length; i += chunkSize) {
      final end = (i + chunkSize < valid.length) ? i + chunkSize : valid.length;
      final chunk = valid.sublist(i, end);
      final batch = _db.batch();
      for (final shape in chunk) {
        final normalizedPoints = shape.pixelPoints.map((p) => LotPoint(p.x / imageWidth, p.y / imageHeight)).toList();
        final cx = normalizedPoints.map((p) => p.x).reduce((a, b) => a + b) / normalizedPoints.length;
        final cy = normalizedPoints.map((p) => p.y).reduce((a, b) => a + b) / normalizedPoints.length;
        final polygonMaps = normalizedPoints.map((p) => p.toMap()).toList();
        final matchKey = '${shape.block.trim().toLowerCase()}|${shape.lotNumber.trim().toLowerCase()}';
        final existingId = existingByKey[matchKey];
        if (existingId != null) {
          batch.update(_lots.doc(existingId), {
            'polygonPoints': polygonMaps,
            'mapX': cx,
            'mapY': cy,
            'phase': phaseName,
            'block': shape.block,
            'updatedBy': updatedBy,
            'updatedAt': Timestamp.now(),
          });
          updated++;
        } else {
          batch.set(_lots.doc(), {
            'phase': phaseName,
            'block': shape.block,
            'lotNumber': shape.lotNumber,
            'areaSqm': null,
            'status': LotStatus.vacant.name,
            'uid': null,
            'ownerName': null,
            'price': null,
            'contactNumber': null,
            'notes': null,
            'updatedBy': updatedBy,
            'updatedAt': Timestamp.now(),
            'mapX': cx,
            'mapY': cy,
            'polygonPoints': polygonMaps,
          });
          created++;
        }
      }
      await batch.commit();
    }
    return Phase1MigrationResult(created: created, updated: updated, warnings: warnings);
  }

  // ================================================================
  // DELETE
  // ================================================================

  Future<void> deleteLot(String lotId) async {
    await _lots.doc(lotId).delete();
  }

  Future<int> deleteLotsByPhase(String phase, {bool dryRun = false}) async {
    final normalizedPhase = phase.trim().toLowerCase();
    final snap = await _lots.get();
    final toDelete = snap.docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final docPhase = (data['phase'] as String? ?? '').trim().toLowerCase();
      return docPhase == normalizedPhase;
    }).toList();
    if (dryRun) return toDelete.length;
    const chunkSize = 400;
    for (var i = 0; i < toDelete.length; i += chunkSize) {
      final end = (i + chunkSize < toDelete.length) ? i + chunkSize : toDelete.length;
      final batch = _db.batch();
      for (final doc in toDelete.sublist(i, end)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }
    return toDelete.length;
  }
}

class HardcodedLotShape {
  final String block;
  final String lotNumber;
  final List<LotPoint> pixelPoints;
  const HardcodedLotShape({required this.block, required this.lotNumber, required this.pixelPoints,});
}

class Phase1MigrationResult {
  final int created;
  final int updated;
  final List<String> warnings;
  const Phase1MigrationResult({required this.created, required this.updated, required this.warnings,});
}

class LotOverlapException implements Exception {
  final List<String> conflicts;
  const LotOverlapException(this.conflicts);
  @override
  String toString() => 'LotOverlapException: ${conflicts.join('; ')}';
}
