// core/models/phase_map_model.dart
//
// Represents one "phase" of the subdivision as a map entry — a name
// plus an optional uploaded image. Phase 1 continues to use the
// existing hand-digitized polygon system in map_pin_view.dart and is
// NOT stored here. This collection is only for additional phases
// added later (e.g. Phase 2, Phase 3), which use simple tap-to-place
// pins instead of precise polygon boundaries, since polygon boundaries
// require manual digitizing work outside the app.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'lot_model.dart' show LotPoint;

class PhaseMapModel {
  final String id;
  final String name;
  final String imageUrl;   // '' until an image has been uploaded
  final String createdBy;
  final Timestamp createdAt;

  /// The defined set of blocks for this phase (e.g. ["1", "2", "3"]).
  /// Bare identifiers, no "Block " prefix — display code adds that
  /// itself. Defined up front (via block count at phase creation, or
  /// added to later via PhaseMapService.addBlocks) rather than
  /// inferred from whichever lots happen to exist, so a block can be
  /// selected from a dropdown before it has any lots in it yet, and a
  /// block can't accidentally be created via a typo in a free-text
  /// field.
  final List<String> blocks;

  /// Traced once per phase (via the "Set Boundary" tool, same
  /// tap-to-place mechanic as digitizing a lot) to mark the outer
  /// edge of the actual printed/scanned sketch on the uploaded image
  /// — everything outside it is just the image's blank margin. Empty
  /// means no boundary has been set yet, in which case digitizing is
  /// unrestricted (today's behavior) rather than blocked everywhere.
  final List<LotPoint> boundaryPoints;

  const PhaseMapModel({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.createdBy,
    required this.createdAt,
    this.blocks = const [],
    this.boundaryPoints = const [],
  });

  bool get hasImage => imageUrl.trim().isNotEmpty;
  bool get hasBoundary => boundaryPoints.length >= 3;

  factory PhaseMapModel.fromMap(String id, Map<String, dynamic> map) {
    return PhaseMapModel(
      id: id,
      name: map['name'] as String? ?? '',
      imageUrl: map['imageUrl'] as String? ?? '',
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: map['createdAt'] as Timestamp? ?? Timestamp.now(),
      blocks: (map['blocks'] as List?)?.map((b) => b.toString()).toList() ??
          const [],
      boundaryPoints: (map['boundaryPoints'] as List?)
              ?.map((p) => LotPoint.fromMap(p as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'imageUrl': imageUrl,
    'createdBy': createdBy,
    'createdAt': createdAt,
    'blocks': blocks,
    'boundaryPoints': boundaryPoints.map((p) => p.toMap()).toList(),
  };

  PhaseMapModel copyWith({
    String? name,
    String? imageUrl,
    List<String>? blocks,
    List<LotPoint>? boundaryPoints,
  }) {
    return PhaseMapModel(
      id: id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      createdBy: createdBy,
      createdAt: createdAt,
      blocks: blocks ?? this.blocks,
      boundaryPoints: boundaryPoints ?? this.boundaryPoints,
    );
  }
}