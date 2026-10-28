// core/models/feedback_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/enum_utils.dart';

enum FeedbackStatus { pending, reviewed, resolved }

const Map<FeedbackStatus, String> _feedbackStatusLabels = {
  FeedbackStatus.pending: 'Pending',
  FeedbackStatus.reviewed: 'Reviewed',
  FeedbackStatus.resolved: 'Resolved',
};

const Map<String, FeedbackStatus> _feedbackStatusLookup = {
  'pending': FeedbackStatus.pending,
  'reviewed': FeedbackStatus.reviewed,
  'resolved': FeedbackStatus.resolved,
};

extension FeedbackStatusExt on FeedbackStatus {
  String get label => enumLabel(this, _feedbackStatusLabels);

  static FeedbackStatus fromString(String? v) =>
      enumFromString(v, _feedbackStatusLookup, defaultValue: FeedbackStatus.pending);
}

class FeedbackModel {
  final String id;
  final String uid;                    // member who submitted
  final String memberName;
  final String email;
  final String title;                  // '' when the member left it blank
  final String message;
  final String category;
  final int? rating;
  final FeedbackStatus status;
  final String resolvedBy;             // uid of staff
  final String resolutionNote;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final String? platform;

  const FeedbackModel({
    required this.id,
    required this.uid,
    required this.memberName,
    required this.email,
    required this.title,
    required this.message,
    required this.category,
    required this.rating,
    required this.status,
    required this.resolvedBy,
    required this.resolutionNote,
    required this.createdAt,
    this.updatedAt,
    this.platform,
  });

  factory FeedbackModel.fromMap(
      Map<String, dynamic> map, String id) {
    return FeedbackModel(
      id:           id,
      uid:          map['uid'] as String? ?? '',
      memberName:   map['memberName'] as String? ?? '',
      email:        map['email'] as String? ?? '',
      title:        map['title'] as String? ?? '',
      message:      map['message'] as String? ?? '',
      category:     map['category'] as String? ?? 'general',
      rating:       map['rating'] as int?,
      status:       FeedbackStatusExt.fromString(map['status'] as String?),
      resolvedBy:   map['resolvedBy'] as String? ?? '',
      resolutionNote: map['resolutionNote'] as String? ?? '',
      createdAt:    (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:    (map['updatedAt'] as Timestamp?)?.toDate(),
      platform:     map['platform'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
    'uid':            uid,
    'memberName':     memberName,
    'email':          email,
    'title':          title,
    'message':        message,
    'category':       category,
    'rating':         rating,
    'status':         status.name,
    'resolvedBy':     resolvedBy,
    'resolutionNote': resolutionNote,
    'createdAt':      Timestamp.fromDate(createdAt),
    'updatedAt':      updatedAt != null
        ? Timestamp.fromDate(updatedAt!)
        : null,
    'platform':       platform,
  };
}