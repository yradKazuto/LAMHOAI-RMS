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

  const PhaseMapModel({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.createdBy,
    required this.createdAt,
  });

  bool get hasImage => imageUrl.trim().isNotEmpty;

  factory PhaseMapModel.fromMap(String id, Map<String, dynamic> map) {
    return PhaseMapModel(
      id: id,
      name: map['name'] as String? ?? '',
      imageUrl: map['imageUrl'] as String? ?? '',
      createdBy: map['createdBy'] as String? ?? '',
      createdAt: map['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'name': name,
    'imageUrl': imageUrl,
    'createdBy': createdBy,
    'createdAt': createdAt,
  };
}