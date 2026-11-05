// features/reports/screens/t_account_screen.dart
//
// T-Account view screen. For each ChartAccount, show debit column and credit
// column with individual line items and running balance. Port of concept from
// classical double-entry accounting layout.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/models/chart_account_model.dart';
import '../../../core/services/chart_of_accounts_service.dart';
import '../../../core/services/ledger_service.dart';

class TAccountScreen extends StatefulWidget {
  const TAccountScreen({super.key});
  @override
  State<TAccountScreen> createState() => _TAccountScreenState();
}

class _TAccountScreenState extends State<TAccountScreen> {
  late FirebaseFirestore db;
  late ChartOfAccountsService accountsService;
  late LedgerService ledger;
  List<ChartAccount> _accounts = [];
  Map<String, double> _balances = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    db = FirebaseFirestore.instance;
    accountsService = ChartOfAccountsService(db: db);
    ledger = LedgerService(db: db, accounts: accountsService);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final all = await ledger.getBalances();
      final seeds = await accountsService.getAll();
      _balances = all;
      _accounts = seeds;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Widget _cell(String text) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(text),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('T-Accounts')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _accounts.length,
              itemBuilder: (_, i) {
                final acct = _accounts[i];
                final balance = _balances[acct.id] ?? 0.0;

                // PLACEHOLDER rows for the prototype. Real line items should
                // come from ledger.getEntries() filtered by accountId.
                final debits = [250.0, 100.0];
                final credits = [175.0, 75.0];

                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(acct.name,
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('${acct.category.label} · balance ${balance.toStringAsFixed(2)}'),
                      const Divider(),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Debit',
                                    style: TextStyle(fontWeight: FontWeight.w600)),
                                ...debits.map((d) => _cell(d.toStringAsFixed(2))),
                              ],
                            ),
                          ),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Credit',
                                    style: TextStyle(fontWeight: FontWeight.w600)),
                                ...credits.map((c) => _cell(c.toStringAsFixed(2))),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('Running: ${balance.toStringAsFixed(2)}'),
                    ],
                  ),
                );
              },
            ),
    );
  }
}