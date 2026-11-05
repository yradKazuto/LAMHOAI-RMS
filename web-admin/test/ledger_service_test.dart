// test/ledger_service_test.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lamhoai_admin/core/services/chart_of_accounts_service.dart';
import 'package:lamhoai_admin/core/services/ledger_service.dart';
import 'package:lamhoai_admin/core/models/journal_entry_model.dart';

void main() {
  late FakeFirebaseFirestore instance;
  late ChartOfAccountsService accounts;
  late LedgerService ledger;

  setUp(() async {
    instance = FakeFirebaseFirestore();
    accounts = ChartOfAccountsService(db: instance);
    ledger = LedgerService(db: instance, accounts: accounts);
  });

  group('LedgerService', () {
    test('Balanced posting succeeds and updates balances', () async {
      final id = await ledger.postJournalEntry(
        description: 'Test balanced entry',
        lines: const [
          JournalLine(accountId: 'CASH', amount: 100, type: 'DEBIT'),
          JournalLine(accountId: 'CASH', amount: 100, type: 'CREDIT'),
        ],
        timestamp: DateTime(2026, 1, 5),
        type: JournalEntryType.PAYMENT,
      );
      final balanceMap = await ledger.getBalances();
      expect(balanceMap['CASH'], 0.0);
      final entries = await ledger.getEntries();
      expect(entries.length, 1);
      expect(entries.first.id, id);
      expect(entries.first.isBalanced, isTrue);
    });

    test('Unbalanced entry rejected with LedgerPostingException', () async {
      await expectLater(
        ledger.postJournalEntry(
          description: 'Unbalanced 2-line test',
          lines: const [
            JournalLine(accountId: 'CASH', amount: 100, type: 'DEBIT'),
            JournalLine(accountId: 'CASH', amount: 50, type: 'CREDIT'),
          ],
          timestamp: DateTime(2026, 2, 1),
        ),
        throwsA(isA<LedgerPostingException>()),
      );
      // Balances unchanged
      final balanceMap = await ledger.getBalances();
      expect(balanceMap['CASH'], 0.0);
    });

    test('Empty entry rejected', () async {
      await expectLater(
        ledger.postJournalEntry(
          description: 'Empty entry',
          lines: const [],
          timestamp: DateTime(2026, 3, 1),
        ),
        throwsA(isA<LedgerPostingException>()),
      );
    });

    test('Unknown account id rejected', () async {
      await expectLater(
        ledger.postJournalEntry(
          description: 'Unknown account test',
          lines: const [
            JournalLine(accountId: 'NOT_A_ACCOUNT', amount: 10, type: 'DEBIT'),
            JournalLine(accountId: 'CASH', amount: 10, type: 'CREDIT'),
          ],
          timestamp: DateTime(2026, 4, 1),
        ),
        throwsA(isA<LedgerPostingException>()),
      );
    });

    test('Multiple debits across different accounts handled', () async {
      await ledger.postJournalEntry(
        description: 'Multi-line test',
        lines: const [
          JournalLine(accountId: 'CASH', amount: 300, type: 'DEBIT'),
          JournalLine(accountId: 'REVENUE_DUES', amount: 300, type: 'DEBIT'),
          JournalLine(accountId: 'ASSETS', amount: 300, type: 'CREDIT'),
          JournalLine(accountId: 'REVENUE_DUES', amount: 300, type: 'CREDIT'),
        ],
        timestamp: DateTime(2026, 5, 1),
        type: JournalEntryType.PAYMENT,
      );
      final b = await ledger.getBalances();
      expect(b['CASH'], -300.0);
      expect(b['REVENUE_DUES'], 300.0);
      expect(b['ASSETS'], -300.0);
    });

    test('Duplicate posting prevented', () async {
      const lines = [
        JournalLine(accountId: 'CASH', amount: 50, type: 'DEBIT'),
        JournalLine(accountId: 'CASH', amount: 50, type: 'CREDIT'),
      ];
      await ledger.postJournalEntry(
        description: 'Original',
        lines: lines,
        timestamp: DateTime(2026, 6, 1),
      );
      await expectLater(
        ledger.postJournalEntry(
          description: 'Duplicate attempt',
          lines: lines,
          timestamp: DateTime(2026, 6, 1),
        ),
        throwsA(isA<LedgerPostingException>()),
      );
    });
  });
}
