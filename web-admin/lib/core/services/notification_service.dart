// core/services/notification_service.dart
// Sends push notifications through a small serverless function
// (send-notification, deployed on Vercel/Netlify — see /notify-server in
// the project root) instead of calling OneSignal directly. That function
// is the only place ONESIGNAL_REST_API_KEY exists now; this client only
// ever sends its own Firebase ID token, which the function verifies and
// checks for an admin role before it will send anything. Also writes a
// notification history document per member to Firestore, so
// NotificationsScreen shows the history even independent of push
// delivery success.

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class NotificationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Serverless function config ──────────────────────────────────────────
  // Not a secret — this is just the public URL of your deployed function.
  // Replace with your actual Vercel/Netlify deployment URL.
  static const String _sendNotificationUrl =
      'https://lamhoai-notify-server.vercel.app/api/send-notification';

  Future<String?> _idToken() =>
      FirebaseAuth.instance.currentUser?.getIdToken() ??
      Future.value(null);

  // ── Send announcement notification to all members ──────────────────────────
  Future<NotificationResult> sendAnnouncementToAll({
    required String announcementId,
    required String title,
    required String body,
  }) async {
    try {
      final snap = await _db
          .collection('users')
          .where('role', isEqualTo: 'member')
          .get();

      final memberUids = snap.docs.map((d) => d.id).toList();

      if (memberUids.isEmpty) {
        return NotificationResult(
          success: false,
          sent: 0,
          failed: 0,
          message: 'No members found.',
        );
      }

      final token = await _idToken();
      final response = await http.post(
        Uri.parse(_sendNotificationUrl),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'target': 'all',
          'title': title,
          'body': body,
          'data': {
            'type': 'announcement',
            'announcementId': announcementId,
          },
        }),
      );

      if (response.statusCode != 200) {
        return NotificationResult(
          success: false,
          sent: 0,
          failed: memberUids.length,
          message:
              'Send-notification error (${response.statusCode}): ${response.body}',
        );
      }

      Map<String, dynamic> json = {};
      try {
        json = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {}

      final batch = _db.batch();
      for (final uid in memberUids) {
        final ref = _db.collection('notifications').doc();
        batch.set(ref, {
          'uid': uid,
          'title': title,
          'body': body,
          'type': 'announcement',
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();

      final recipients =
          (json['recipients'] as num?)?.toInt() ?? memberUids.length;

      return NotificationResult(
        success: true,
        sent: recipients,
        failed: 0,
        message: 'Notifications sent successfully.',
      );
    } catch (e) {
      return NotificationResult(
        success: false,
        sent: 0,
        failed: 0,
        message: 'Error sending notifications: $e',
      );
    }
  }

  // ── Send to a single member (e.g. dues reminder, complaint update) ─────────
  Future<NotificationResult> sendToMember({
    required String uid,
    required String title,
    required String body,
    required String type,
    Map<String, dynamic> extraData = const {},
  }) async {
    try {
      final token = await _idToken();
      final response = await http.post(
        Uri.parse(_sendNotificationUrl),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'target': 'user',
          'externalUserIds': [uid],
          'title': title,
          'body': body,
          'data': {'type': type, ...extraData},
        }),
      );

      if (response.statusCode != 200) {
        return NotificationResult(
          success: false,
          sent: 0,
          failed: 1,
          message:
              'Send-notification error (${response.statusCode}): ${response.body}',
        );
      }

      await _db.collection('notifications').add({
        'uid': uid,
        'title': title,
        'body': body,
        'type': type,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });

      return const NotificationResult(
        success: true,
        sent: 1,
        failed: 0,
        message: 'Sent.',
      );
    } catch (e) {
      return NotificationResult(
        success: false,
        sent: 0,
        failed: 0,
        message: 'Error: $e',
      );
    }
  }

  // ── Send dues reminders to members with unpaid dues due soon ───────────────
  Future<NotificationResult> sendDuesReminders({int daysAhead = 7}) async {
    try {
      final now = DateTime.now();
      final cutoff = now.add(Duration(days: daysAhead));

      final paymentsSnap = await _db
          .collection('payments')
          .where('status', isEqualTo: 'unpaid')
          .where('dueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(now))
          .where('dueDate', isLessThanOrEqualTo: Timestamp.fromDate(cutoff))
          .get();

      if (paymentsSnap.docs.isEmpty) {
        return const NotificationResult(
          success: true,
          sent: 0,
          failed: 0,
          message: 'No upcoming dues found.',
        );
      }

      final Map<String, List<Map<String, dynamic>>> byMember = {};
      for (final doc in paymentsSnap.docs) {
        final data = doc.data();
        final uid = data['uid'] as String?;
        if (uid == null || uid.isEmpty) continue;
        byMember.putIfAbsent(uid, () => []).add(data);
      }

      int sentCount = 0;
      int failedCount = 0;

      for (final entry in byMember.entries) {
        final uid = entry.key;
        final dues = entry.value;

        final totalAmount = dues.fold<double>(
          0,
          (sum, d) => sum + ((d['amount'] as num?)?.toDouble() ?? 0),
        );
        final dueCount = dues.length;
        final formatted = _formatPeso(totalAmount);

        final soonestDueDate = dues
            .map((d) => (d['dueDate'] as Timestamp).toDate())
            .reduce((a, b) => a.isBefore(b) ? a : b);
        final daysUntilDue = soonestDueDate
            .difference(DateTime(now.year, now.month, now.day))
            .inDays;

        final String dueWhen;
        if (daysUntilDue <= 0) {
          dueWhen = 'today';
        } else if (daysUntilDue == 1) {
          dueWhen = 'tomorrow';
        } else {
          dueWhen = 'in $daysUntilDue days';
        }

        String name = 'Member';
        try {
          final userDoc = await _db.collection('users').doc(uid).get();
          name = (userDoc.data()?['displayName'] as String?)?.trim().isNotEmpty ==
                  true
              ? userDoc.data()!['displayName'] as String
              : 'Member';
        } catch (_) {}

        final title =
            dueCount == 1 ? 'Payment Due Soon' : '$dueCount Payments Due Soon';
        final body = dueCount == 1
            ? 'Hi $name, your payment of $formatted is due $dueWhen.'
            : 'Hi $name, you have $dueCount payments totaling $formatted, the soonest due $dueWhen.';

        final result = await sendToMember(
          uid: uid,
          title: title,
          body: body,
          type: 'dues',
        );

        if (result.success) {
          sentCount++;
        } else {
          failedCount++;
        }
      }

      return NotificationResult(
        success: true,
        sent: sentCount,
        failed: failedCount,
        message: 'Dues reminder sent to $sentCount member(s).',
      );
    } catch (e) {
      return NotificationResult(
        success: false,
        sent: 0,
        failed: 0,
        message: 'Error sending dues reminders: $e',
      );
    }
  }

  String _formatPeso(double amount) {
    final wholeStr = amount.toStringAsFixed(2);
    final parts = wholeStr.split('.');
    final intPart = parts[0];
    final decPart = parts[1];

    final buffer = StringBuffer();
    for (int i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buffer.write(',');
      buffer.write(intPart[i]);
    }
    return '₱${buffer.toString()}.$decPart';
  }

  Future<int> getMemberTokenCount() async {
    final snap =
        await _db.collection('users').where('role', isEqualTo: 'member').get();
    return snap.docs.length;
  }
}

class NotificationResult {
  final bool success;
  final int sent;
  final int failed;
  final String message;

  const NotificationResult({
    required this.success,
    required this.sent,
    required this.failed,
    required this.message,
  });
}