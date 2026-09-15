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

  const PhaseMapModel({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.createdBy,
    required this.createdAt,
    this.blocks = const [],
  });

  bool get hasImage => imageUrl.trim().isNotEmpty;

  factory PhaseMapModel.fromMap(String id, Map<String, dynamic> map) {
    return PhaseMapModel(
      id: id,
      name: map['name'] as String? ?? '',
      imageUrl: map['imageUrl'] as String? ?? '',
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: map['createdAt'] as Timestamp? ?? Timestamp.now(),
      blocks: (map['blocks'] as List?)?.map((b) => b.toString()).toList() ??
          const [],
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'imageUrl': imageUrl,
    'createdBy': createdBy,
    'createdAt': createdAt,
    'blocks': blocks,
  };

  PhaseMapModel copyWith({
    String? name,
    String? imageUrl,
    List<String>? blocks,
  }) {
    return PhaseMapModel(
      id: id,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      createdBy: createdBy,
      createdAt: createdAt,
      blocks: blocks ?? this.blocks,
    );
  }
}