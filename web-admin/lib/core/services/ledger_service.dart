// core/services/ledger_service.dart
//
// General Ledger service: owns the `general_ledger` and `journal_entries`
// collections, enforces double-entry posting rules, and provides balances
// queries. Writes are atomic via Firestore transactions so an unbalanced
// or partial write never reaches either collection partially.
//
// Collection: `general_ledger`, `journal_entries`

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chart_account_model.dart';
import '../models/general_ledger_account_model.dart';
import '../models/journal_entry_model.dart';
import 'chart_of_accounts_service.dart';

/// Thrown when a journal posting is rejected before or during atomic commit.
class LedgerPostingException implements Exception {
  final String message;
  const LedgerPostingException(this.message);
  @override
  String toString() => 'LedgerPostingException: $message';
}

/// Per (prefix, year) sequence counter. Prototype only — each instance tracks
/// its own counter; production may swap for a persisted counter document.
final Map<String, int> _seqCounters = {};

String _generateEntryId(JournalEntryType type, int year) {
  final prefix = switch (type) {
    JournalEntryType.PAYMENT => 'POS',
    JournalEntryType.ADJUSTMENT => 'ADJ',
    JournalEntryType.REVERSAL => 'REV',
  };
  final seq = _seqCounters[prefix] ?? 0;
  _seqCounters[prefix] = seq + 1;
  return '$prefix-$year-${seq.toString().padLeft(7, '0')}';
}

class LedgerService {
  final FirebaseFirestore _db;
  final ChartOfAccountsService _accounts;
  static const String _journalCollection = 'journal_entries';
  static const String _ledgerCollection = 'general_ledger';

  LedgerService({FirebaseFirestore? db, ChartOfAccountsService? accounts})
      : _db = db ?? FirebaseFirestore.instance,
        _accounts = accounts ?? ChartOfAccountsService();

  CollectionReference<Map<String, dynamic>> get _journalEntries =>
      _db.collection(_journalCollection);

  CollectionReference<Map<String, dynamic>> get _ledger =>
      _db.collection(_ledgerCollection);

  /// Atomically posts a balanced journal entry: validates against allowlist,
  /// writes immutable audit record, then updates balances for every line.
  /// Throws [LedgerPostingException] if any check fails or commit conflicts.
  Future<String> postJournalEntry({
    required String description,
    required List<JournalLine> lines,
    required DateTime timestamp,
    JournalEntryType type = JournalEntryType.PAYMENT,
    String? relatedTransactionId,
  }) async {
    if (lines.isEmpty) {
      throw const LedgerPostingException('Journal must contain at least one entry');
    }

    // --- Pre-validate outside the transaction for fast failure ---
    final debits = lines.where((l) => l.type == 'DEBIT').toList();
    final credits = lines.where((l) => l.type == 'CREDIT').toList();
    final debitTotal = debits.fold<double>(0.0, (s, l) => s + l.amount);
    final creditTotal = credits.fold<double>(0.0, (s, l) => s + l.amount);
    if ((debitTotal - creditTotal).abs() >= 0.01) {
      throw LedgerPostingException('Debit ($debitTotal) != Credit ($creditTotal)');
    }
    for (final l in lines) {
      if (!_accounts.isValidAccountId(l.accountId)) {
        throw LedgerPostingException('Unknown account id: ${l.accountId}');
      }
      if (l.amount <= 0) {
        throw LedgerPostingException('Line amounts must be positive: ${l.accountId}');
      }
    }

    final id = _generateEntryId(type, timestamp.year);
    final cleanDescription = description.isEmpty ? 'Unnamed entry' : description;
    final now = Timestamp.now();

    try {
      await _db.runTransaction((txn) async {
        // ── 1. ALL READS FIRST (Firestore requires reads before writes) ──
        final existing = await txn.get(_journalEntries.doc(id));
        if (existing.exists) {
          throw LedgerPostingException('Entry $id already exists');
        }

        final refs = <String, DocumentReference<Map<String, dynamic>>>{};
        final balances = <String, double>{};
        for (final l in lines) {
          if (refs.containsKey(l.accountId)) continue;
          final ref = _ledger.doc(l.accountId);
          final snap = await txn.get(ref);
          refs[l.accountId] = ref;
          balances[l.accountId] =
              (snap.data()?['balance'] as num?)?.toDouble() ?? 0.0;
        }

        // ── 2. Compute new balances ──
        for (final l in lines) {
          balances[l.accountId] = balances[l.accountId]! +
              (l.type == 'DEBIT' ? -l.amount : l.amount);
        }

        // ── 3. ALL WRITES ──
        txn.set(_journalEntries.doc(id), {
          'id':                   id,
          'timestamp':            Timestamp.fromDate(timestamp),
          'description':          cleanDescription,
          'type':                 type.name,
          'relatedTransactionId': relatedTransactionId,
          'entries':              lines.map((l) => l.toMap()).toList(),
          'demo':                 false,
        });

        for (final entry in refs.entries) {
          txn.set(
            entry.value,
            {
              'id':          entry.key,
              'balance':     balances[entry.key],
              'lastUpdated': now,
            },
            SetOptions(merge: true),
          );
        }
      });
    } catch (e) {
      throw LedgerPostingException('Posting rejected: $e');
    }

    return id;
  }

  /// Returns all account balances keyed by id.
  Future<Map<String, double>> getBalances() async {
    final snap = await _ledger.get();
    final out = <String, double>{};
    for (final d in snap.docs) {
      out[d.id] = (d.data()['balance'] as num?)?.toDouble() ?? 0.0;
    }
    return out;
  }

  /// Returns every ledger account row (id, balance, lastUpdated) sorted by
  /// account id, suitable for rendering a consolidated statement table.
  Future<List<GeneralLedgerAccount>> getLedgerRows() async {
    final snap = await _ledger.get();
    final out = snap.docs
        .map((d) => GeneralLedgerAccount.fromMap(d.data()))
        .toList()
      ..sort((a, b) => a.id.compareTo(b.id));
    return out;
  }

  /// Reads ledger entries for historical queries by date range.
  Future<List<JournalEntry>> getEntries({DateTime? from, DateTime? to}) async {
    Query<Map<String, dynamic>> q = _journalEntries;
    if (from != null) q = q.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(from));
    if (to != null) q = q.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(to));
    final snap = await q.orderBy('timestamp', descending: true).get();
    return snap.docs.map((d) => JournalEntry.fromMap(d.data())).toList();
  }
}