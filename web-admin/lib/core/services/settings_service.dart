// core/services/settings_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/hoa_settings_model.dart';
import '../models/audit_log_model.dart';

class SettingsService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String _settingsDoc  = 'hoa_settings';
  static const String _settingsColl = 'settings';
  static const String _auditColl    = 'audit_logs';

  // ── HOA Settings ──────────────────────────────────────────────────────────

  Stream<HoaSettingsModel> streamSettings() {
    return _db
        .collection(_settingsColl)
        .doc(_settingsDoc)
        .snapshots()
        .map((snap) {
      if (!snap.exists || snap.data() == null) {
        return HoaSettingsModel.defaults;
      }
      return HoaSettingsModel.fromMap(
          snap.data() as Map<String, dynamic>);
    });
  }

  Future<HoaSettingsModel> getSettings() async {
    final doc = await _db
        .collection(_settingsColl)
        .doc(_settingsDoc)
        .get();
    if (!doc.exists || doc.data() == null) {
      return HoaSettingsModel.defaults;
    }
    return HoaSettingsModel.fromMap(
        doc.data() as Map<String, dynamic>);
  }

  Future<void> saveSettings(
      HoaSettingsModel settings) async {
    await _db
        .collection(_settingsColl)
        .doc(_settingsDoc)
        .set(settings.toMap(), SetOptions(merge: true));
  }

  // ── Audit Logs ────────────────────────────────────────────────────────────

  Stream<List<AuditLogModel>> streamAuditLogs({
    int limit = 50,
  }) {
    return _db
        .collection(_auditColl)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => AuditLogModel.fromMap(
                d.data() as Map<String, dynamic>, d.id))
            .toList());
  }

  Future<void> logAction({
    required String      performedBy,
    required String      performedByName,
    required AuditAction action,
    required String      targetCollection,
    required String      targetId,
    required String      description,
  }) async {
    final ref = _db.collection(_auditColl).doc();
    await ref.set(AuditLogModel(
      id:                ref.id,
      performedBy:       performedBy,
      performedByName:   performedByName,
      action:            action,
      targetCollection:  targetCollection,
      targetId:          targetId,
      description:       description,
      createdAt:         DateTime.now(),
    ).toMap());
  }
}