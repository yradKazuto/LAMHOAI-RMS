// features/reports/screens/general_ledger_screen.dart
//
// General Ledger screen — lists every posted journal entry and its two lines.
// Balanced entries only; unbalanced rejected upstream. T-Account view built in
// a separate screen to preserve shared layout concerns.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/ledger_service.dart';
import '../../../core/models/journal_entry_model.dart';
// TODO: replace with the file that defines `class JournalEntry`
// (Ctrl+Shift+F → "class JournalEntry"), for example:
// import '../../../core/models/journal_entry_model.dart';

class GeneralLedgerScreen extends StatefulWidget {
  const GeneralLedgerScreen({super.key});
  @override
  State<GeneralLedgerScreen> createState() => _GeneralLedgerScreenState();
}

class _GeneralLedgerScreenState extends State<GeneralLedgerScreen> {
  late final FirebaseFirestore db;
  late final LedgerService ledger;
  List<JournalEntry> _entries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    db = FirebaseFirestore.instance;
    ledger = LedgerService(db: db);
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    try {
      final all = await ledger.getEntries();
      _entries = all.reversed.toList();
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
      appBar: AppBar(title: const Text('General Ledger')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _entries.length,
              itemBuilder: (_, i) {
                final e = _entries[i];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      title: Text(e.description),
                      subtitle: Text('${e.id} · ${e.timestamp.toIso8601String().substring(0, 10)}'),
                      trailing: Icon(
                        Icons.check_circle,
                        color: e.isBalanced ? Colors.green : Colors.red,
                      ),
                    ),
                    for (final line in e.entries) ...[
                      const Divider(),
                      ListTile(
                        dense: true,
                        leading: Icon(line.type == 'DEBIT' ? Icons.arrow_forward : Icons.arrow_back),
                        title: Text('${line.accountId} (${line.amount.toStringAsFixed(2)})'),
                        subtitle: Text(line.type),
                      ),
                    ],
                  ],
                );
              },
            ),
    );
  }
}