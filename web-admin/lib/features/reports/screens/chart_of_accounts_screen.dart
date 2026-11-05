// features/reports/screens/chart_of_accounts_screen.dart
//
// Chart of Accounts screen — lists all valid account IDs with their
// current balances. Read-only; taps navigate to General Ledger detail.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/chart_account_model.dart';
import '../../../core/models/general_ledger_account_model.dart';
import '../../../core/services/chart_of_accounts_service.dart';
import '../../../core/services/ledger_service.dart';
import '../../../core/theme/design_tokens.dart';

class ChartOfAccountsScreen extends StatefulWidget {
  const ChartOfAccountsScreen({super.key});

  @override
  State<ChartOfAccountsScreen> createState() => _ChartOfAccountsScreenState();
}

class _ChartOfAccountsScreenState extends State<ChartOfAccountsScreen> {
  late ChartOfAccountsService _accounts;
  late LedgerService _ledger;
  List<ChartAccount> _accountsList = [];
  Map<String, double> _balances = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final db = FirebaseFirestore.instance;
    _accounts = ChartOfAccountsService(db: db);
    _ledger = LedgerService(db: db, accounts: _accounts);
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      await _accounts.seedDemoAccounts();
      _accountsList = await _accounts.getAll();
      _balances = await _ledger.getBalances();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chart of Accounts')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.separated(
              itemCount: _accountsList.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final acct = _accountsList[i];
                final balance = _balances[acct.id] ?? 0.0;
                final categoryColor = _categoryColor(acct.category);
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: categoryColor.withOpacity(0.1),
                    child: Icon(_categoryIcon(acct.category),
                        color: categoryColor, size: 20),
                  ),
                  title: Text(acct.name),
                  subtitle: Text(acct.category.label),
                  trailing: Text(
                    balance.toStringAsFixed(2),
                    style: TextStyle(
                      color: balance >= 0 ? AppColors.success : AppColors.danger,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {
                    // Could navigate to T-Account or General Ledger detail
                  },
                );
              },
            ),
    );
  }

  Color _categoryColor(AccountCategory c) {
    switch (c) {
      case AccountCategory.ASSETS:
        return AppColors.primary;
      case AccountCategory.LIABILITIES:
        return Colors.orange;
      case AccountCategory.EQUITY:
        return AppColors.success;
      case AccountCategory.REVENUE:
        return Colors.blue;
      case AccountCategory.EXPENSES:
        return Colors.red;
    }
  }

  IconData _categoryIcon(AccountCategory c) {
    switch (c) {
      case AccountCategory.ASSETS:
        return Icons.account_balance_wallet;
      case AccountCategory.LIABILITIES:
        return Icons.trending_down;
      case AccountCategory.EQUITY:
        return Icons.group;
      case AccountCategory.REVENUE:
        return Icons.attach_money;
      case AccountCategory.EXPENSES:
        return Icons.money_off;
    }
  }
}