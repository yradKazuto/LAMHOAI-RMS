// core/models/document_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum DocumentType { propertyTitle, governmentId, proofOfResidency, other }

extension DocumentTypeExt on DocumentType {
  String get label {
    switch (this) {
      case DocumentType.propertyTitle:     return 'Property Title';
      case DocumentType.governmentId:      return 'Government ID';
      case DocumentType.proofOfResidency:  return 'Proof of Residency';
      case DocumentType.other:             return 'Other';
    }
  }

  static DocumentType fromString(String? v) {
    switch (v) {
      case 'propertyTitle':    return DocumentType.propertyTitle;
      case 'governmentId':     return DocumentType.governmentId;
      case 'proofOfResidency': return DocumentType.proofOfResidency;
      default:                 return DocumentType.other;
    }
  }
}

class DocumentModel {
  final String id;
  final String uid;          // member's uid
  final String memberName;
  final DocumentType type;
  final String fileName;
  final String fileUrl;
  final String uploadedBy;   // uid of staff who uploaded
  final DateTime createdAt;

  const DocumentModel({
    required this.id,
    required this.uid,         // fixed: was memberId
    required this.memberName,
    required this.type,
    required this.fileName,
    required this.fileUrl,
    required this.uploadedBy,
    required this.createdAt,
  });

  factory DocumentModel.fromMap(Map<String, dynamic> map, String id) {
    return DocumentModel(
      id:         id,
      uid:        map['uid']        as String? ?? '',
      memberName: map['memberName'] as String? ?? '',
      type:       DocumentTypeExt.fromString(map['type'] as String?),
      fileName:   map['fileName']   as String? ?? '',
      fileUrl:    map['fileUrl']    as String? ?? '',
      uploadedBy: map['uploadedBy'] as String? ?? '',
      createdAt:  (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'uid':        uid,
    'memberName': memberName,
    'type':       type.name,
    'fileName':   fileName,
    'fileUrl':    fileUrl,
    'uploadedBy': uploadedBy,
    'createdAt':  Timestamp.fromDate(createdAt),
  };
}