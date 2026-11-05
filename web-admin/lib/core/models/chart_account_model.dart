// core/models/chart_account_model.dart
//
// Chart of Accounts catalog entry. Provides the allowlist of valid account ids
// consumed by journal entries and ledger updates. Seed demo accounts on
// construction so any `postJournalEntry` with a bad account id fails loudly.
//
// Collection: `chart_accounts`

import 'package:cloud_firestore/cloud_firestore.dart';

enum AccountCategory { ASSETS, LIABILITIES, EQUITY, REVENUE, EXPENSES }

const Map<AccountCategory, String> _categoryLabels = {
  AccountCategory.ASSETS: 'Assets',
  AccountCategory.LIABILITIES: 'Liabilities',
  AccountCategory.EQUITY: 'Equity / Members',
  AccountCategory.REVENUE: 'Revenue',
  AccountCategory.EXPENSES: 'Expenses',
};

const Map<String, AccountCategory> _categoryLookup = {
  'ASSETS': AccountCategory.ASSETS,
  'LIABILITIES': AccountCategory.LIABILITIES,
  'EQUITY': AccountCategory.EQUITY,
  'REVENUE': AccountCategory.REVENUE,
  'EXPENSES': AccountCategory.EXPENSES,
};

extension AccountCategoryExt on AccountCategory {
  String get label => _categoryLabels[this]!;
  static AccountCategory fromString(String? v) =>
      _categoryLookup[v?.toUpperCase()] ?? AccountCategory.ASSETS;
}

class ChartAccount {
  final String id;
  final String name;
  final AccountCategory category;
  final String description;

  const ChartAccount({
    required this.id,
    required this.name,
    required this.category,
    this.description = '',
  });

  factory ChartAccount.fromMap(Map<String, dynamic> map) {
    return ChartAccount(
      id:                map['id'] as String? ?? '',
      name:               map['name'] as String? ?? '',
      category:           AccountCategoryExt.fromString(map['category'] as String?),
      description:        map['description'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() => {
        'id':               id,
        'name':              name,
        'category':           category.name,
        'description':       description,
      };
}
