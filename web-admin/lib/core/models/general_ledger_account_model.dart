// core/models/general_ledger_account_model.dart
//
// General Ledger account document — mirrors `general_ledger` collection.
// Stores only current balance state for each stable account id; updated
// atomically with every posted journal entry transaction.
//
// Collection: `general_ledger`

import 'package:cloud_firestore/cloud_firestore.dart';

class GeneralLedgerAccount {
  final String id;
  final double balance;
  final DateTime? lastUpdated;

  const GeneralLedgerAccount({
    required this.id,
    required this.balance,
    this.lastUpdated,
  });

  factory GeneralLedgerAccount.fromMap(Map<String, dynamic> map) {
    return GeneralLedgerAccount(
      id:            map['id'] as String? ?? '',
      balance:       (map['balance'] as num?)?.toDouble() ?? 0.0,
      lastUpdated:   map['lastUpdated'] == null ? null : (map['lastUpdated'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id':               id,
        'balance':           balance,
        'lastUpdated':       lastUpdated != null
            ? Timestamp.fromDate(lastUpdated!)
            : null,
      };
}
