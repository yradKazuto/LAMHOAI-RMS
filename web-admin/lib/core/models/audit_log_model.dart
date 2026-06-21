// core/models/audit_log_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum AuditAction {
  created,
  updated,
  deleted,
  statusChanged,
  roleChanged,
  login,
}

extension AuditActionExt on AuditAction {
  String get label {
    switch (this) {
      case AuditAction.created:       return 'Created';
      case AuditAction.updated:       return 'Updated';
      case AuditAction.deleted:       return 'Deleted';
      case AuditAction.statusChanged: return 'Status Changed';
      case AuditAction.roleChanged:   return 'Role Changed';
      case AuditAction.login:         return 'Login';
    }
  }

  static AuditAction fromString(String? v) {
    switch (v) {
      case 'created':       return AuditAction.created;
      case 'updated':       return AuditAction.updated;
      case 'deleted':       return AuditAction.deleted;
      case 'statusChanged': return AuditAction.statusChanged;
      case 'roleChanged':   return AuditAction.roleChanged;
      case 'login':         return AuditAction.login;
      default:              return AuditAction.updated;
    }
  }
}

class AuditLogModel {
  final String      id;
  final String      performedBy;      // uid of staff
  final String      performedByName;
  final AuditAction action;
  final String      targetCollection; // e.g. 'users', 'payments'
  final String      targetId;
  final String      description;      // human-readable summary
  final DateTime    createdAt;

  const AuditLogModel({
    required this.id,
    required this.performedBy,
    required this.performedByName,
    required this.action,
    required this.targetCollection,
    required this.targetId,
    required this.description,
    required this.createdAt,
  });

  factory AuditLogModel.fromMap(
      Map<String, dynamic> map, String id) {
    return AuditLogModel(
      id:                id,
      performedBy:       map['performedBy']       as String? ?? '',
      performedByName:   map['performedByName']   as String? ?? '',
      action:            AuditActionExt.fromString(
                             map['action'] as String?),
      targetCollection:  map['targetCollection']  as String? ?? '',
      targetId:          map['targetId']          as String? ?? '',
      description:       map['description']       as String? ?? '',
      createdAt:         (map['createdAt'] as Timestamp?)
                             ?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'performedBy':      performedBy,
    'performedByName':  performedByName,
    'action':           action.name,
    'targetCollection': targetCollection,
    'targetId':         targetId,
    'description':      description,
    'createdAt':        Timestamp.fromDate(createdAt),
  };
}