// core/services/chart_of_accounts_service.dart
//
// Maintains the Chart of Accounts allowlist. Seed demo accounts on
// construction so every postJournalEntry validates its account ids strictly.
//
// Collection: `chart_accounts`

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/chart_account_model.dart';

class ChartOfAccountsService {
  final FirebaseFirestore _db;
  static const String _collection = 'chart_accounts';
  static const List<ChartAccount> _seedAccounts = [
    ChartAccount(id: 'ASSETS', name: 'Assets', category: AccountCategory.ASSETS, description: 'Cash, receivables, inventory'),
    ChartAccount(id: 'CASH', name: 'Cash on Hand', category: AccountCategory.ASSETS, description: 'Bank balances + petty cash inventory'),
    ChartAccount(id: 'AR_DUES', name: 'Membership Dues Receivables', category: AccountCategory.ASSETS, description: 'Outstanding annual/monthly dues billed but not paid'),
    ChartAccount(id: 'AR_LOT_INSTALLMENTS', name: 'Lot Installment Receivables', category: AccountCategory.ASSETS, description: 'Per-lot periodic receivables tied to LotSaleModel installments'),
    ChartAccount(id: 'LIABILITIES', name: 'Liabilities', category: AccountCategory.LIABILITIES, description: 'Deferred revenue, payables'),
    ChartAccount(id: 'DR_DUES_PAYABLE', name: 'Dues Payable', category: AccountCategory.LIABILITIES, description: 'Outstanding dues billed but not yet paid'),
    ChartAccount(id: 'DR_INSTALLMENT_REVENUE', name: 'Deferred Revenue - Installment Sales', category: AccountCategory.LIABILITIES, description: 'Unearned sale income recognized over installment term'),
    ChartAccount(id: 'EQUITY', name: 'Equity / Members', category: AccountCategory.EQUITY, description: 'Net assets attributable to members'),
    ChartAccount(id: 'EQUITY_MEMBERSHIP', name: 'Membership Equity', category: AccountCategory.EQUITY, description: 'Net assets attributable to members'),
    ChartAccount(id: 'REVENUE', name: 'Revenue', category: AccountCategory.REVENUE, description: 'Inflows recognized this period'),
    ChartAccount(id: 'REVENUE_SALES', name: 'Sales Revenue', category: AccountCategory.REVENUE, description: 'Cash + installment sale revenue'),
    ChartAccount(id: 'REVENUE_INTEREST', name: 'Interest Income', category: AccountCategory.REVENUE, description: 'Interest earned on financial assets'),
    ChartAccount(id: 'REVENUE_DUES', name: 'Membership Dues Revenue', category: AccountCategory.REVENUE, description: 'Recognized income from member dues payments'),
    ChartAccount(id: 'EXPENSES', name: 'Expenses', category: AccountCategory.EXPENSES, description: 'Costs incurred for HOA operations'),
    ChartAccount(id: 'EXPENSES_COGS', name: 'Cost of Goods Sold', category: AccountCategory.EXPENSES, description: 'Direct costs of goods sold'),
    ChartAccount(id: 'EXPENSES_UTILITIES', name: 'Utilities & Maintenance Expenses', category: AccountCategory.EXPENSES, description: 'Operational expense'),
  ];

  ChartOfAccountsService({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _chart =>
      _db.collection(_collection);

  /// Reads all chart accounts seeded on construction. If empty (fresh
  /// emulator), seeds demo accounts before returning.
  Future<List<ChartAccount>> getAll() async {
    final snap = await _chart.get();
    if (snap.docs.isEmpty) {
      await seedDemoAccounts();
      final reSnap = await _chart.get();
      return reSnap.docs
          .map((d) => ChartAccount.fromMap(d.data()))
          .toList();
    }
    return snap.docs
        .map((d) => ChartAccount.fromMap(d.data()))
        .toList();
  }

  /// Seeds demo accounts once. Idempotent: skips already existing docs.
  Future<void> seedDemoAccounts() async {
    final existing = await _chart.get();
    if (existing.docs.isNotEmpty) return;
    final batch = _db.batch();
    for (final acct in _seedAccounts) {
      batch.set(_chart.doc(acct.id), acct.toMap());
    }
    await batch.commit();
  }

  Future<List<ChartAccount>> getByCategory(String category) async {
    final all = await getAll();
    return all.where((a) => a.category.name == category.toUpperCase()).toList();
  }

  /// Throws if an account id is invalid; called from JournalLine validation.
  bool isValidAccountId(String id) =>
      _seedAccounts.any((a) => a.id == id);
}
