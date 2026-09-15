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
  // GEOMETRY — polygon self-intersection and overlap checks, shared
  // by every write path (digitize-and-save, bulk Excel import, and
  // any future caller) so they all enforce the exact same rules
  // instead of duplicating this logic per-screen.
  // ================================================================

  /// Whether segment (p1,q1) intersects (p2,q2), INCLUDING
  /// collinear/touching cases — used for self-intersection, where a
  /// segment lying on top of another segment of the SAME polygon is
  /// itself a degenerate shape.
  static bool _segmentsIntersect(
      LotPoint p1, LotPoint q1, LotPoint p2, LotPoint q2) {
    int orientation(LotPoint p, LotPoint q, LotPoint r) {
      final val = (q.y - p.y) * (r.x - q.x) - (q.x - p.x) * (r.y - q.y);
      if (val.abs() < 1e-9) return 0;
      return val > 0 ? 1 : 2;
    }

    bool onSegment(LotPoint p, LotPoint q, LotPoint r) {
      return q.x <= (p.x > r.x ? p.x : r.x) &&
          q.x >= (p.x < r.x ? p.x : r.x) &&
          q.y <= (p.y > r.y ? p.y : r.y) &&
          q.y >= (p.y < r.y ? p.y : r.y);
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

  /// Whether a traced boundary crosses over itself anywhere.
  static bool isSelfIntersecting(List<LotPoint> points) {
    final n = points.length;
    if (n < 4) return false; // a triangle can't self-intersect
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

  /// Strict crossing only — excludes touching/collinear/shared-edge
  /// cases, since two adjacent lots sharing a border is normal and
  /// shouldn't count as "overlapping."
  static bool _segmentsProperlyCross(
      LotPoint p1, LotPoint q1, LotPoint p2, LotPoint q2) {
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

  /// Even-odd ray-casting point-in-polygon test — backup check for
  /// full containment (one polygon entirely inside another) when no
  /// edges actually cross.
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

  /// Whether polygon [a] genuinely overlaps polygon [b] in area — not
  /// just touching at a shared border.
  static bool polygonsOverlap(List<LotPoint> a, List<LotPoint> b) {
    double minX(List<LotPoint> p) =>
        p.map((o) => o.x).reduce((x, y) => x < y ? x : y);
    double maxX(List<LotPoint> p) =>
        p.map((o) => o.x).reduce((x, y) => x > y ? x : y);
    double minY(List<LotPoint> p) =>
        p.map((o) => o.y).reduce((x, y) => x < y ? x : y);
    double maxY(List<LotPoint> p) =>
        p.map((o) => o.y).reduce((x, y) => x > y ? x : y);

    // Quick bounding-box reject before the more expensive edge checks.
    if (maxX(a) < minX(b) ||
        maxX(b) < minX(a) ||
        maxY(a) < minY(b) ||
        maxY(b) < minY(a)) {
      return false;
    }

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

  /// Every already-saved, already-digitized lot in [phase] whose
  /// boundary genuinely overlaps [points]. Pin-only lots (no
  /// polygonPoints) have no real boundary to compare against, so
  /// they're skipped. [excludeLotId] leaves out a specific lot — e.g.
  /// when re-saving that same lot's own boundary, it shouldn't be
  /// flagged as overlapping itself.
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
  // BULK IMPORT — digitized polygon coordinates from the coordinate
  // picker tool (Block / Lot / Point / X / Y Excel export)
  // ================================================================

  /// Creates or updates lots for [phase] from digitized polygon data.
  /// [lotsData] maps "block|lotNumber" -> ordered list of normalized
  /// (0.0-1.0) points around that lot's boundary. mapX/mapY are set
  /// to the polygon's centroid so the simple pin display also works
  /// immediately, without waiting for separate polygon rendering.
  ///
  /// Validates EVERY incoming lot before writing anything: if any lot
  /// self-intersects, overlaps an existing lot, or overlaps another
  /// lot in this same batch, the WHOLE import is rejected — nothing
  /// gets saved, not even the clean rows — and a [LotOverlapException]
  /// listing every conflict is thrown, so a bad batch can be fixed and
  /// re-uploaded as one clean pass rather than leaving good and bad
  /// data mixed together.
  ///
  /// Returns the number of lots created or updated.
  Future<int> importPolygonLots({
    required String phase,
    required Map<String, List<LotPoint>> lotsData,
    required String updatedBy,
  }) async {
    // Fetch all lots and match phase with a trimmed, case-insensitive
    // comparison — same as how the rest of the app matches phase for
    // display — instead of an exact-match Firestore query. Phase names
    // are free text, so a stray whitespace or casing difference from
    // an earlier save would make an exact match silently miss the
    // existing lot and create a duplicate instead of updating it.
    final normalizedPhase = phase.trim().toLowerCase();
    final existingSnap = await _lots.get();

    final existingByKey = <String, String>{}; // "block|lot" -> docId
    final existingLots = <LotModel>[];
    for (final doc in existingSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final docPhase =
          (data['phase'] as String? ?? '').trim().toLowerCase();
      if (docPhase != normalizedPhase) continue;

      existingLots.add(LotModel.fromMap(doc.id, data));

      final block =
          (data['block'] as String? ?? '').trim().toLowerCase();
      final lotNumber =
          (data['lotNumber'] as String? ?? '').trim().toLowerCase();
      existingByKey['$block|$lotNumber'] = doc.id;
    }

    final entries = lotsData.entries.toList();

    // ── Validate everything first — reject the whole batch on any
    // conflict, before writing a single document.
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
      final matchKey = parts.length == 2
          ? '${parts[0].trim().toLowerCase()}|${parts[1].trim().toLowerCase()}'
          : key;
      final existingId = existingByKey[matchKey];

      for (final existing in existingLots) {
        if (existing.id == existingId) continue; // re-saving itself
        if (!existing.hasPolygon) continue;
        if (polygonsOverlap(points, existing.polygonPoints!)) {
          errors.add(
              '$key: overlaps existing Block ${existing.block} Lot ${existing.lotNumber}.');
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

    if (errors.isNotEmpty) {
      throw LotOverlapException(errors);
    }

    // ── All clear — write everything.
    final batch = _db.batch();
    int count = 0;

    for (final entry in entries) {
      final parts = entry.key.split('|');
      if (parts.length != 2) continue;
      final block = parts[0];
      final lotNumber = parts[1];
      final points = entry.value;
      if (points.isEmpty) continue;

      // Centroid — simple average of the polygon's points. Good
      // enough for pin placement; doesn't need to be geometrically
      // exact (e.g. for a concave shape) since it's just a marker.
      final cx = points.map((p) => p.x).reduce((a, b) => a + b) /
          points.length;
      final cy = points.map((p) => p.y).reduce((a, b) => a + b) /
          points.length;

      final polygonMaps = points.map((p) => p.toMap()).toList();

      final matchKey =
          '${block.trim().toLowerCase()}|${lotNumber.trim().toLowerCase()}';
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

  // ================================================================
  // ================================================================
  // PHASE 1 MIGRATION — one-time conversion of hardcoded, pixel-
  // coordinate polygon shapes (see map_pin_view.dart's
  // blockNLotPolygons constants) into real Firestore lot documents
  // with normalized polygonPoints, so Phase 1 can eventually render
  // through the same system as every other phase.
  // ================================================================

  /// Runs the one-time migration. Idempotent — matches existing lots
  // by phase + block + lot number (same forgiving trim/lowercase
  /// comparison used everywhere else in this service) and updates
  /// them in place rather than creating duplicates, so it's safe to
  /// re-run if something needs correcting. [imageWidth]/[imageHeight]
  /// are the ORIGINAL pixel dimensions the hardcoded points were
  /// traced against — get this wrong and every lot shifts.
  Future<Phase1MigrationResult> migratePhase1FromHardcodedShapes({
    required String phaseName,
    required List<HardcodedLotShape> shapes,
    required double imageWidth,
    required double imageHeight,
    required String updatedBy,
  }) async {
    final normalizedPhase = phaseName.trim().toLowerCase();
    final existingSnap = await _lots.get();

    final existingByKey = <String, String>{}; // "block|lot" -> docId
    for (final doc in existingSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final docPhase = (data['phase'] as String? ?? '').trim().toLowerCase();
      if (docPhase != normalizedPhase) continue;
      final block = (data['block'] as String? ?? '').trim().toLowerCase();
      final lotNumber =
          (data['lotNumber'] as String? ?? '').trim().toLowerCase();
      existingByKey['$block|$lotNumber'] = doc.id;
    }

    final valid = <HardcodedLotShape>[];
    final warnings = <String>[];
    for (final shape in shapes) {
      if (shape.pixelPoints.length < 3) {
        warnings.add(
            'Block ${shape.block} Lot ${shape.lotNumber}: fewer than 3 points, skipped.');
        continue;
      }
      valid.add(shape);
    }

    int created = 0;
    int updated = 0;

    // Firestore batches cap at 500 writes — chunk well under that so
    // a large migration (hundreds of lots) can't silently fail partway.
    const chunkSize = 400;
    for (var i = 0; i < valid.length; i += chunkSize) {
      final end = (i + chunkSize < valid.length) ? i + chunkSize : valid.length;
      final chunk = valid.sublist(i, end);
      final batch = _db.batch();

      for (final shape in chunk) {
        final normalizedPoints = shape.pixelPoints
            .map((p) => LotPoint(p.x / imageWidth, p.y / imageHeight))
            .toList();

        final cx = normalizedPoints.map((p) => p.x).reduce((a, b) => a + b) /
            normalizedPoints.length;
        final cy = normalizedPoints.map((p) => p.y).reduce((a, b) => a + b) /
            normalizedPoints.length;
        final polygonMaps = normalizedPoints.map((p) => p.toMap()).toList();

        final matchKey =
            '${shape.block.trim().toLowerCase()}|${shape.lotNumber.trim().toLowerCase()}';
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

    return Phase1MigrationResult(
      created: created,
      updated: updated,
      warnings: warnings,
    );
  }

  // ================================================================
  // DELETE
  // ================================================================

  Future<void> deleteLot(String lotId) async {
    await _lots.doc(lotId).delete();
  }

  /// Permanently deletes every lot whose phase matches [phase] (same
  /// trimmed, case-insensitive comparison used everywhere else in
  /// this service). Meant for clearing out test/throwaway data before
  /// a clean re-migration — there is no undo. Chunked at 400 deletes
  /// per batch to stay under Firestore's 500-write batch limit.
  /// Pass [dryRun] to just get the count without deleting anything,
  /// e.g. to show "X lots will be deleted" before asking for
  /// confirmation. Returns the number of lots (deleted, or that would
  /// be deleted).
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
      final end =
          (i + chunkSize < toDelete.length) ? i + chunkSize : toDelete.length;
      final batch = _db.batch();
      for (final doc in toDelete.sublist(i, end)) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    }

    return toDelete.length;
  }
}

/// A minimal description of one hardcoded Phase-1 lot shape, decoupled
/// from map_pin_view.dart's own LotPolygon (a UI-layer class) so this
/// service doesn't need to depend on a widget file. [pixelPoints] are
/// RAW pixel coordinates — not yet normalized to 0.0-1.0 — against
/// whatever imageWidth/imageHeight is passed to the migration.
class HardcodedLotShape {
  final String block;
  final String lotNumber;
  final List<LotPoint> pixelPoints;

  const HardcodedLotShape({
    required this.block,
    required this.lotNumber,
    required this.pixelPoints,
  });
}

/// Result summary from migratePhase1FromHardcodedShapes.
class Phase1MigrationResult {
  final int created;
  final int updated;
  final List<String> warnings;

  const Phase1MigrationResult({
    required this.created,
    required this.updated,
    required this.warnings,
  });
}

/// Thrown by importPolygonLots when one or more incoming lots would
/// self-intersect or overlap an existing/other-in-batch lot. The
/// whole import is rejected — [conflicts] lists every problem found,
/// so all of them can be fixed in one pass rather than discovering
/// them one re-upload at a time.
class LotOverlapException implements Exception {
  final List<String> conflicts;
  const LotOverlapException(this.conflicts);

  @override
  String toString() => 'LotOverlapException: ${conflicts.join('; ')}';
}