// core/models/journal_entry_model.dart
//
// Journal entry — immutable audit trail of one posted financial movement.
// Append-only; never mutated after commit. Balanced debit == credit enforced
// by caller before posting (LedgerService.postJournalEntry).
//
// Collection: `journal_entries`

import 'package:cloud_firestore/cloud_firestore.dart';

/// One debits/credits line in a posted journal entry. Debit increases the
/// referenced account; Credit decreases it. Amounts stored as positive
/// numbers; sign conveyed via `type`.
class JournalLine {
  final String accountId;
  final double amount; // positive number
  final String type; // 'DEBIT' | 'CREDIT'

  const JournalLine({
    required this.accountId,
    required this.amount,
    required this.type,
  });

  Map<String, dynamic> toMap() => {
        'accountId': accountId,
        'amount': amount,
        'type': type,
      };
}

enum JournalEntryType { PAYMENT, ADJUSTMENT, REVERSAL }

const Map<String, JournalEntryType> _typeLookup = {
  'PAYMENT': JournalEntryType.PAYMENT,
  'ADJUSTMENT': JournalEntryType.ADJUSTMENT,
  'REVERSAL': JournalEntryType.REVERSAL,
};

extension JournalEntryTypeExt on JournalEntryType {
  static JournalEntryType fromString(String? v) =>
      _typeLookup[v?.toUpperCase()] ?? JournalEntryType.PAYMENT;
}

class JournalEntry {
  final String id;
  final DateTime timestamp;
  final String description;
  final JournalEntryType type;
  final String? relatedTransactionId;
  final List<JournalLine> entries;

  const JournalEntry({
    required this.id,
    required this.timestamp,
    required this.description,
    required this.type,
    this.relatedTransactionId,
    required this.entries,
  });

  double get totalDebit =>
      entries.where((l) => l.type == 'DEBIT').fold(0.0, (s, l) => s + l.amount);

  double get totalCredit =>
      entries.where((l) => l.type == 'CREDIT').fold(0.0, (s, l) => s + l.amount);

  bool get isBalanced => (totalDebit - totalCredit).abs() < 0.01;

  factory JournalEntry.fromMap(Map<String, dynamic> map) {
    return JournalEntry(
      id:              map['id'] as String? ?? '',
      timestamp:        (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      description:     map['description'] as String? ?? '',
      type:            JournalEntryTypeExt.fromString(map['type'] as String?),
      relatedTransactionId: map['relatedTransactionId'] as String?,
      entries:         (map['entries'] as List?)
              ?.map((e) => JournalLine(
                    accountId:            e['accountId'] as String? ?? '',
                    amount:               (e['amount'] as num?)?.toDouble() ?? 0.0,
                    type:                 e['type'] as String? ?? 'DEBIT',
                  ))
              .toList() ?? const [],
    );
  }

  Map<String, dynamic> toMap() => {
        'id':               id,
        'timestamp':        Timestamp.fromDate(timestamp),
        'description':      description,
        'type':             type.name,
        'relatedTransactionId':  relatedTransactionId,
        'entries':          entries.map((l) => l.toMap()).toList(),
      };
}
