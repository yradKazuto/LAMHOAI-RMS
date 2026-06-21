// core/services/notification_service.dart
// Sends FCM push notifications to all members when an announcement is posted.
// Uses Firebase Cloud Messaging via a Cloud Functions HTTP endpoint.
// The Cloud Function reads all member FCM tokens and sends multicast messages.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Cloud Function URL ─────────────────────────────────────────────────────
  // Replace with your actual Firebase project region and project ID
  // after deploying the Cloud Function (see README for deploy steps)
  static const String _functionUrl =
      'https://us-central1-lamhoai-rms.cloudfunctions.net/sendAnnouncementNotification';

  // ── Send announcement notification to all members ─────────────────────────
  Future<NotificationResult> sendAnnouncementToAll({
    required String announcementId,
    required String title,
    required String body,
  }) async {
    try {
      // Collect all active member FCM tokens from Firestore
      final snap = await _db
          .collection('users')
          .where('role', isEqualTo: 'member')
          .where('fcmToken', isNotEqualTo: '')
          .get();

      final tokens = snap.docs
          .map((d) =>
              (d.data() as Map<String, dynamic>)['fcmToken']
                  as String? ??
              '')
          .where((t) => t.isNotEmpty)
          .toList();

      if (tokens.isEmpty) {
        return NotificationResult(
          success:   false,
          sent:      0,
          failed:    0,
          message:   'No members with FCM tokens found.',
        );
      }

      // Call Cloud Function
      final response = await http.post(
        Uri.parse(_functionUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'announcementId': announcementId,
          'title':          title,
          'body':           body,
          'tokens':         tokens,
        }),
      );

      if (response.statusCode == 200) {
        final json =
            jsonDecode(response.body) as Map<String, dynamic>;
        return NotificationResult(
          success: true,
          sent:    (json['successCount'] as num?)?.toInt() ?? 0,
          failed:  (json['failureCount'] as num?)?.toInt() ?? 0,
          message: 'Notifications sent successfully.',
        );
      } else {
        return NotificationResult(
          success: false,
          sent:    0,
          failed:  tokens.length,
          message: 'Cloud Function error: ${response.statusCode}',
        );
      }
    } catch (e) {
      return NotificationResult(
        success: false,
        sent:    0,
        failed:  0,
        message: 'Error sending notifications: $e',
      );
    }
  }

  // ── Get member token count (for UI preview) ────────────────────────────────
  Future<int> getMemberTokenCount() async {
    final snap = await _db
        .collection('users')
        .where('role', isEqualTo: 'member')
        .where('fcmToken', isNotEqualTo: '')
        .get();
    return snap.docs.length;
  }
}

class NotificationResult {
  final bool   success;
  final int    sent;
  final int    failed;
  final String message;

  const NotificationResult({
    required this.success,
    required this.sent,
    required this.failed,
    required this.message,
  });
}