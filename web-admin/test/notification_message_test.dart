// Tests for the reminder message builder.
//
// The bug this guards against: the old "Send Dues Reminder" query only
// matched upcoming dues, so overdue members were never notified. See
// docs/bugs/2026-10-19-overdue-payment-reminders-not-sent.md.
//
// buildReminderMessage() is pure (no Firestore, no clock), so these run
// without Firebase initialization.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamhoai_admin/core/services/notification_service.dart';

final today = DateTime(2026, 10, 19);

Map<String, dynamic> due({
  required double amount,
  required DateTime dueDate,
  String status = 'unpaid',
}) =>
    {
      'amount': amount,
      'dueDate': Timestamp.fromDate(dueDate),
      'status': status,
      'uid': 'uid-1',
    };

void main() {
  group('buildReminderMessage', () {
    test('upcoming only — "due soon" title and body', () {
      final msg = buildReminderMessage(
        name: 'Maria',
        overdue: [],
        upcoming: [due(amount: 1500, dueDate: DateTime(2026, 10, 21))],
        today: today,
      );

      expect(msg.title, 'Payment Due Soon');
      expect(msg.body, contains('Maria'));
      expect(msg.body, contains('₱1,500.00'));
      expect(msg.body, contains('in 2 days'));
    });

    test('upcoming due TODAY is included (not silently dropped)', () {
      // The old query compared dueDate against DateTime.now() instead of
      // the start of today, so a payment due today was excluded.
      final msg = buildReminderMessage(
        name: 'Maria',
        overdue: [],
        upcoming: [due(amount: 500, dueDate: today)],
        today: today,
      );

      expect(msg.title, 'Payment Due Soon');
      expect(msg.body, contains('due today'));
    });

    test('overdue only — "overdue" title, days late, and the amount', () {
      final msg = buildReminderMessage(
        name: 'Maria',
        overdue: [
          due(amount: 2000, dueDate: DateTime(2026, 10, 14), status: 'overdue'),
        ],
        upcoming: [],
        today: today,
      );

      expect(msg.title, 'Payment Overdue');
      expect(msg.body, contains('₱2,000.00'));
      expect(msg.body, contains('5 days overdue'));
    });

    test('overdue — singular day wording for one day late', () {
      final msg = buildReminderMessage(
        name: 'Maria',
        overdue: [
          due(amount: 500, dueDate: DateTime(2026, 10, 18), status: 'overdue'),
        ],
        upcoming: [],
        today: today,
      );

      expect(msg.body, contains('1 day overdue'));
      expect(msg.body, isNot(contains('1 days')));
    });

    test('multiple overdue — plural title and total', () {
      final msg = buildReminderMessage(
        name: 'Maria',
        overdue: [
          due(amount: 1000, dueDate: DateTime(2026, 10, 14), status: 'overdue'),
          due(amount: 500, dueDate: DateTime(2026, 10, 17), status: 'overdue'),
        ],
        upcoming: [],
        today: today,
      );

      expect(msg.title, '2 Payments Overdue');
      expect(msg.body, contains('₱1,500.00'));
      // The OLDEST record drives the "how late" figure.
      expect(msg.body, contains('5 days overdue'));
    });

    test('both overdue and upcoming — ONE message, overdue part first', () {
      final msg = buildReminderMessage(
        name: 'Maria',
        overdue: [
          due(amount: 2000, dueDate: DateTime(2026, 10, 10), status: 'overdue'),
        ],
        upcoming: [due(amount: 500, dueDate: DateTime(2026, 10, 22))],
        today: today,
      );

      expect(msg.title, 'Payment Overdue');
      expect(msg.body, contains('₱2,000.00'));
      expect(msg.body, contains('9 days late'));
      expect(msg.body, contains('₱500.00'));
      expect(msg.body, contains('in 3 days'));
      // Overdue detail must come before the upcoming detail.
      expect(
        msg.body.indexOf('₱2,000.00'),
        lessThan(msg.body.indexOf('₱500.00')),
      );
    });

    test('overdue amount reflects the penalty added to the record', () {
      // applyOverduePenalties() folds the penalty into `amount`, so the
      // message quotes the penalized total.
      final msg = buildReminderMessage(
        name: 'Maria',
        overdue: [
          due(amount: 2500, dueDate: DateTime(2026, 10, 10), status: 'overdue'),
        ],
        upcoming: [],
        today: today,
      );

      expect(msg.body, contains('₱2,500.00'));
    });
  });

  group('formatPeso', () {
    test('groups thousands', () {
      expect(formatPeso(1234.5), '₱1,234.50');
      expect(formatPeso(1000000), '₱1,000,000.00');
      expect(formatPeso(0), '₱0.00');
    });
  });
}
