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
import '../models/payment_model.dart';

/// Formats a peso amount with thousands separators: 1234.5 → "1,234.50".
String formatPeso(double amount) {
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

/// Builds the reminder title and body for ONE member.
///
/// Pure — no Firestore, no clock — so it can be unit-tested on its own
/// (see test/notification_message_test.dart). A member can have overdue
/// payments, upcoming ones, or both; the combined case gets a single
/// message with the overdue part first, because that is the one that
/// matters.
({String title, String body}) buildReminderMessage({
  required String name,
  required List<Map<String, dynamic>> overdue,
  required List<Map<String, dynamic>> upcoming,
  required DateTime today,
}) {
  double total(List<Map<String, dynamic>> docs) => docs.fold<double>(
      0, (acc, d) => acc + ((d['amount'] as num?)?.toDouble() ?? 0));

  DateTime dueOf(Map<String, dynamic> d) =>
      (d['dueDate'] as Timestamp?)?.toDate() ?? today;

  final String dueWhen;
  final String daysLate;

  if (overdue.isNotEmpty) {
    // The OLDEST overdue record — that is how long they have been late.
    final oldest = overdue.map(dueOf).reduce((a, b) => a.isBefore(b) ? a : b);
    final days = today.difference(oldest).inDays;
    daysLate = days == 1 ? '1 day' : '$days days';

    final overdueCount = overdue.length;
    final overdueFmt = formatPeso(total(overdue));

    if (upcoming.isEmpty) {
      return (
        title: overdueCount == 1 ? 'Payment Overdue' : '$overdueCount Payments Overdue',
        body: overdueCount == 1
            ? 'Hi $name, your payment of $overdueFmt is $daysLate overdue. '
                'Please settle it at your earliest convenience.'
            : 'Hi $name, you have $overdueCount overdue payments totaling '
                '$overdueFmt, the oldest $daysLate overdue. '
                'Please settle them at your earliest convenience.',
      );
    }

    // Both — one message, overdue part first.
    final upcomingCount = upcoming.length;
    final upcomingFmt = formatPeso(total(upcoming));
    final soonest = upcoming.map(dueOf).reduce((a, b) => a.isBefore(b) ? a : b);
    final daysUntil = soonest.difference(today).inDays;
    if (daysUntil <= 0) {
      dueWhen = 'today';
    } else if (daysUntil == 1) {
      dueWhen = 'tomorrow';
    } else {
      dueWhen = 'in $daysUntil days';
    }

    return (
      title: 'Payment Overdue',
      body: 'Hi $name, you have $overdueCount overdue payment'
          '${overdueCount == 1 ? '' : 's'} totaling $overdueFmt '
          '(oldest $daysLate late), and $upcomingCount payment'
          '${upcomingCount == 1 ? '' : 's'} totaling $upcomingFmt due $dueWhen.',
    );
  }

  // Upcoming only.
  final dueCount = upcoming.length;
  final formatted = formatPeso(total(upcoming));
  final soonest = upcoming.map(dueOf).reduce((a, b) => a.isBefore(b) ? a : b);
  final daysUntil = soonest.difference(today).inDays;
  if (daysUntil <= 0) {
    dueWhen = 'today';
  } else if (daysUntil == 1) {
    dueWhen = 'tomorrow';
  } else {
    dueWhen = 'in $daysUntil days';
  }

  return (
    title: dueCount == 1 ? 'Payment Due Soon' : '$dueCount Payments Due Soon',
    body: dueCount == 1
        ? 'Hi $name, your payment of $formatted is due $dueWhen.'
        : 'Hi $name, you have $dueCount payments totaling $formatted, '
            'the soonest due $dueWhen.',
  );
}

/// One member's dues, split by urgency. Overdue first.
class _MemberDues {
  final List<Map<String, dynamic>> overdue = [];
  final List<Map<String, dynamic>> upcoming = [];
}

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

      // OneSignal no longer returns a recipient count in its create
      // response, so the server reports 0 for a broadcast. Treat 0/missing
      // as "unknown" and show the number of member accounts we sent to.
      final reported = (json['recipients'] as num?)?.toInt();
      final recipients =
          (reported != null && reported > 0) ? reported : memberUids.length;

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
        // Still write the Firestore history record even when the push
        // delivery failed, so the member has a visible trace of the reminder.
        await _db.collection('notifications').add({
          'uid': uid,
          'title': title,
          'body': body,
          'type': type,
          'isRead': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
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

  // ── Send dues reminders to members with unpaid dues due soon OR overdue ───
  //
  // Two queries, not one. An overdue record is excluded from the "due
  // soon" query TWICE: syncOverdueStatuses() (run when the Payments
  // screen opens) has already flipped its status to 'overdue', AND its
  // dueDate is in the past — outside the [today, today+daysAhead] window.
  // A single upcoming-only query therefore never reached overdue members.
  //
  // Both queries use the same (status, dueDate) composite index that
  // applyOverduePenalties() already needs — no new index required.
  Future<NotificationResult> sendDuesReminders({int daysAhead = 7}) async {
    try {
      final now = DateTime.now();
      // Start of today, NOT now: dueDate is stored at midnight, so
      // comparing with the current time excluded payments due TODAY from
      // the window. This matches PaymentModel.displayStatus and
      // syncOverdueStatuses(), which both use start-of-today.
      final today = DateTime(now.year, now.month, now.day);
      final cutoff = today.add(Duration(days: daysAhead));

      final upcomingSnap = await _db
          .collection('payments')
          .where('status', isEqualTo: PaymentStatus.unpaid.name)
          .where('dueDate', isGreaterThanOrEqualTo: Timestamp.fromDate(today))
          .where('dueDate', isLessThanOrEqualTo: Timestamp.fromDate(cutoff))
          .get();

      // Overdue includes 'unpaid' as well as 'overdue' — a record that is
      // past due but has not been flipped yet (sync hasn't run, or the
      // record was written after it) is still overdue to the member.
      final overdueSnap = await _db
          .collection('payments')
          .where('status', whereIn: [
            PaymentStatus.unpaid.name,
            PaymentStatus.overdue.name,
          ])
          .where('dueDate', isLessThan: Timestamp.fromDate(today))
          .get();

      if (upcomingSnap.docs.isEmpty && overdueSnap.docs.isEmpty) {
        return const NotificationResult(
          success: true,
          sent: 0,
          failed: 0,
          message: 'No upcoming or overdue dues found.',
        );
      }

      final Map<String, _MemberDues> byMember = {};

      void collect(List<Map<String, dynamic>> docs, bool isOverdue) {
        for (final data in docs) {
          final uid = data['uid'] as String?;
          if (uid == null || uid.isEmpty) continue;
          final dues = byMember.putIfAbsent(uid, () => _MemberDues());
          (isOverdue ? dues.overdue : dues.upcoming).add(data);
        }
      }

      collect(upcomingSnap.docs.map((d) => d.data()).toList(), false);
      collect(overdueSnap.docs.map((d) => d.data()).toList(), true);

      int sentCount = 0;
      int failedCount = 0;

      for (final entry in byMember.entries) {
        final uid = entry.key;
        final dues = entry.value;

        String name = 'Member';
        try {
          final userDoc = await _db.collection('users').doc(uid).get();
          name = (userDoc.data()?['displayName'] as String?)?.trim().isNotEmpty ==
                  true
              ? userDoc.data()!['displayName'] as String
              : 'Member';
        } catch (_) {}

        final message = buildReminderMessage(
          name: name,
          overdue: dues.overdue,
          upcoming: dues.upcoming,
          today: today,
        );

        final result = await sendToMember(
          uid: uid,
          title: message.title,
          body: message.body,
          type: 'dues',
        );

        if (result.success) {
          sentCount++;
        } else {
          failedCount++;
        }
      }

      return NotificationResult(
        success: failedCount == 0,
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