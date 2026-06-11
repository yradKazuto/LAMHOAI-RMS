// core/models/announcement_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class AnnouncementModel {
  final String   id;
  final String   title;
  final String   body;
  final String   postedBy;       // uid of staff who posted
  final String   postedByName;
  final bool     isActive;
  final DateTime createdAt;

  const AnnouncementModel({
    required this.id,
    required this.title,
    required this.body,
    required this.postedBy,
    required this.postedByName,
    required this.isActive,
    required this.createdAt,
  });

  factory AnnouncementModel.fromMap(
      Map<String, dynamic> map, String id) {
    return AnnouncementModel(
      id:           id,
      title:        map['title']        as String? ?? '',
      body:         map['body']         as String? ?? '',
      postedBy:     map['postedBy']     as String? ?? '',
      postedByName: map['postedByName'] as String? ?? '',
      isActive:     map['isActive']     as bool?   ?? true,
      createdAt:    (map['createdAt']   as Timestamp?)?.toDate()
                    ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'title':        title,
    'body':         body,
    'postedBy':     postedBy,
    'postedByName': postedByName,
    'isActive':     isActive,
    'createdAt':    Timestamp.fromDate(createdAt),
  };
}