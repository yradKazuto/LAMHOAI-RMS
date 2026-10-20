// core/models/audit_log_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/enum_utils.dart';

enum AuditAction {
  created,
  updated,
  deleted,
  statusChanged,
  roleChanged,
  login,
}

const Map<AuditAction, String> _auditActionLabels = {
  AuditAction.created: 'Created',
  AuditAction.updated: 'Updated',
  AuditAction.deleted: 'Deleted',
  AuditAction.statusChanged: 'Status Changed',
  AuditAction.roleChanged: 'Role Changed',
  AuditAction.login: 'Login',
};

const Map<String, AuditAction> _auditActionLookup = {
  'created': AuditAction.created,
  'updated': AuditAction.updated,
  'deleted': AuditAction.deleted,
  'statuschanged': AuditAction.statusChanged,
  'rolechanged': AuditAction.roleChanged,
  'login': AuditAction.login,
};

extension AuditActionExt on AuditAction {
  String get label => enumLabel(this, _auditActionLabels);

  static AuditAction fromString(String? v) =>
      enumFromString(v, _auditActionLookup, defaultValue: AuditAction.updated);
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