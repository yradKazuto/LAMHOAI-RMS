import 'package:cloud_firestore/cloud_firestore.dart';

/// Status of a single lot/parcel in the subdivision map.
enum LotStatus { occupied, vacant, forSale, reserved }

extension LotStatusX on LotStatus {
  String get label {
    switch (this) {
      case LotStatus.occupied:
        return 'Occupied';
      case LotStatus.vacant:
        return 'Vacant';
      case LotStatus.forSale:
        return 'For Sale';
      case LotStatus.reserved:
        return 'Reserved';
    }
  }

  static LotStatus fromString(String value) {
    return LotStatus.values.firstWhere(
      (e) => e.name == value,
      orElse: () => LotStatus.vacant,
    );
  }
}

/// A single normalized (0.0–1.0) point in a lot's digitized polygon
/// boundary, relative to its phase's map image width/height.
class LotPoint {
  final double x;
  final double y;
  const LotPoint(this.x, this.y);

  factory LotPoint.fromMap(Map<String, dynamic> map) => LotPoint(
        (map['x'] as num?)?.toDouble() ?? 0,
        (map['y'] as num?)?.toDouble() ?? 0,
      );

  Map<String, dynamic> toMap() => {'x': x, 'y': y};
}

/// Represents a single lot/parcel within the subdivision.
/// Collection: `lots`
class LotModel {
  final String id;
  final String phase;
  final String block;
  final String lotNumber;
  final double? areaSqm;
  final LotStatus status;

  final String? uid;
  final String? ownerName;

  final double? price;
  final String? contactNumber;

  final String? notes;
  final String updatedBy;
  final Timestamp updatedAt;

  /// Pin position on the subdivision map image, normalized 0.0–1.0
  /// relative to image width/height. Null if this lot hasn't been
  /// placed on the map yet. For lots with a digitized [polygonPoints]
  /// boundary, this is the polygon's centroid.
  final double? mapX;
  final double? mapY;

  /// Digitized boundary points for this lot, normalized 0.0–1.0
  /// relative to its phase's map image width/height, in order around
  /// the polygon. Null for lots placed with a simple pin only (no
  /// precise boundary digitized).
  final List<LotPoint>? polygonPoints;

  LotModel({
    required this.id,
    required this.phase,
    required this.block,
    required this.lotNumber,
    this.areaSqm,
    required this.status,
    this.uid,
    this.ownerName,
    this.price,
    this.contactNumber,
    this.notes,
    required this.updatedBy,
    required this.updatedAt,
    this.mapX,
    this.mapY,
    this.polygonPoints,
  });

  bool get hasPolygon => polygonPoints != null && polygonPoints!.length >= 3;

  factory LotModel.fromMap(String id, Map<String, dynamic> map) {
    final rawPoints = map['polygonPoints'] as List?;
    return LotModel(
      id: id,
      phase: map['phase'] ?? '',
      block: map['block'] ?? '',
      lotNumber: map['lotNumber'] ?? '',
      areaSqm: (map['areaSqm'] as num?)?.toDouble(),
      status: LotStatusX.fromString(map['status'] ?? 'vacant'),
      uid: map['uid'],
      ownerName: map['ownerName'],
      price: (map['price'] as num?)?.toDouble(),
      contactNumber: map['contactNumber'],
      notes: map['notes'],
      updatedBy: map['updatedBy'] ?? '',
      updatedAt: map['updatedAt'] ?? Timestamp.now(),
      mapX: (map['mapX'] as num?)?.toDouble(),
      mapY: (map['mapY'] as num?)?.toDouble(),
      polygonPoints: rawPoints == null
          ? null
          : rawPoints
              .map((p) => LotPoint.fromMap(p as Map<String, dynamic>))
              .toList(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'phase': phase,
      'block': block,
      'lotNumber': lotNumber,
      'areaSqm': areaSqm,
      'status': status.name,
      'uid': uid,
      'ownerName': ownerName,
      'price': price,
      'contactNumber': contactNumber,
      'notes': notes,
      'updatedBy': updatedBy,
      'updatedAt': updatedAt,
      'mapX': mapX,
      'mapY': mapY,
      'polygonPoints': polygonPoints?.map((p) => p.toMap()).toList(),
    };
  }

  LotModel copyWith({
    String? phase,
    String? block,
    String? lotNumber,
    double? areaSqm,
    LotStatus? status,
    String? uid,
    String? ownerName,
    double? price,
    String? contactNumber,
    String? notes,
    String? updatedBy,
    Timestamp? updatedAt,
    double? mapX,
    double? mapY,
    List<LotPoint>? polygonPoints,
  }) {
    return LotModel(
      id: id,
      phase: phase ?? this.phase,
      block: block ?? this.block,
      lotNumber: lotNumber ?? this.lotNumber,
      areaSqm: areaSqm ?? this.areaSqm,
      status: status ?? this.status,
      uid: uid ?? this.uid,
      ownerName: ownerName ?? this.ownerName,
      price: price ?? this.price,
      contactNumber: contactNumber ?? this.contactNumber,
      notes: notes ?? this.notes,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedAt: updatedAt ?? this.updatedAt,
      mapX: mapX ?? this.mapX,
      mapY: mapY ?? this.mapY,
      polygonPoints: polygonPoints ?? this.polygonPoints,
    );
  }

  bool get isPlottedOnMap => mapX != null && mapY != null;

  String get displayLabel => '$phase • $block • $lotNumber';
}