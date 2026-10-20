// core/models/complaint_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/enum_utils.dart';

enum ComplaintStatus { pending, reviewing, resolved, rejected }

const Map<ComplaintStatus, String> _complaintStatusLabels = {
  ComplaintStatus.pending: 'Pending',
  ComplaintStatus.reviewing: 'Reviewing',
  ComplaintStatus.resolved: 'Resolved',
  ComplaintStatus.rejected: 'Rejected',
};

const Map<String, ComplaintStatus> _complaintStatusLookup = {
  'pending': ComplaintStatus.pending,
  'reviewing': ComplaintStatus.reviewing,
  'resolved': ComplaintStatus.resolved,
  'rejected': ComplaintStatus.rejected,
};

extension ComplaintStatusExt on ComplaintStatus {
  String get label => enumLabel(this, _complaintStatusLabels);

  static ComplaintStatus fromString(String? v) =>
      enumFromString(v, _complaintStatusLookup, defaultValue: ComplaintStatus.pending);
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
      // The mobile app writes this field as 'title' (see
      // SubmitComplaintScreen._submit()) — 'subject' has never actually
      // been written by anything. Falling back to 'subject' too in case
      // a future writer uses that key instead.
      subject:        (map['title']    as String?) ??
                       (map['subject']  as String?) ?? '',
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