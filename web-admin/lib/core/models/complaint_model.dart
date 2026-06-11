// core/models/complaint_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum ComplaintStatus { pending, reviewing, resolved, rejected }

extension ComplaintStatusExt on ComplaintStatus {
  String get label {
    switch (this) {
      case ComplaintStatus.pending:   return 'Pending';
      case ComplaintStatus.reviewing: return 'Reviewing';
      case ComplaintStatus.resolved:  return 'Resolved';
      case ComplaintStatus.rejected:  return 'Rejected';
    }
  }

  static ComplaintStatus fromString(String? v) {
    switch (v?.toLowerCase()) {
      case 'reviewing': return ComplaintStatus.reviewing;
      case 'resolved':  return ComplaintStatus.resolved;
      case 'rejected':  return ComplaintStatus.rejected;
      default:          return ComplaintStatus.pending;
    }
  }
}

class ComplaintModel {
  final String          id;
  final String          uid;           // member who filed
  final String          memberName;
  final String          subject;
  final String          description;
  final ComplaintStatus status;
  final String          resolvedBy;    // uid of staff who resolved
  final String          resolutionNote;
  final DateTime        createdAt;
  final DateTime?       updatedAt;

  const ComplaintModel({
    required this.id,
    required this.uid,
    required this.memberName,
    required this.subject,
    required this.description,
    required this.status,
    required this.resolvedBy,
    required this.resolutionNote,
    required this.createdAt,
    this.updatedAt,
  });

  factory ComplaintModel.fromMap(
      Map<String, dynamic> map, String id) {
    return ComplaintModel(
      id:             id,
      uid:            map['uid']            as String? ?? '',
      memberName:     map['memberName']     as String? ?? '',
      subject:        map['subject']        as String? ?? '',
      description:    map['description']    as String? ?? '',
      status:         ComplaintStatusExt.fromString(
                          map['status'] as String?),
      resolvedBy:     map['resolvedBy']     as String? ?? '',
      resolutionNote: map['resolutionNote'] as String? ?? '',
      createdAt:      (map['createdAt']     as Timestamp?)?.toDate()
                      ?? DateTime.now(),
      updatedAt:      (map['updatedAt']     as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
    'uid':            uid,
    'memberName':     memberName,
    'subject':        subject,
    'description':    description,
    'status':         status.name,
    'resolvedBy':     resolvedBy,
    'resolutionNote': resolutionNote,
    'createdAt':      Timestamp.fromDate(createdAt),
    'updatedAt':      updatedAt != null
                      ? Timestamp.fromDate(updatedAt!)
                      : null,
  };
}