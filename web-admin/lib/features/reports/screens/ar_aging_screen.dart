// features/reports/screens/ar_aging_screen.dart
//
// AR Aging Report screen — per-bucket overdue balance overview of outstanding
// membership dues and lot installment receivables. Pure read; no writes.
// Uses PaymentModel with cumulative paidAmount to avoid double counting.

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/ar_aging_report_service.dart';

class ArAgingScreen extends StatefulWidget {
  const ArAgingScreen({super.key});
  @override
  State<ArAgingScreen> createState() => _ArAgingScreenState();
}

class _ArAgingScreenState extends State<ArAgingScreen> {
  static const _buckets = [
    'Current',
    '1-30 days',
    '31-60 days',
    '61-90 days',
    '90+ days',
  ];

  late FirebaseFirestore db;
  late ArAgingReportService service;
  ArAgingReport? _report;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    db = FirebaseFirestore.instance;
    service = ArAgingReportService(db: db);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await service.generateReport();
      _report = r;
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

  double _sum(Map<String, double>? m) =>
      m?.values.fold<double>(0.0, (s, v) => s + v) ?? 0.0;

  double _bucketValue(String key) {
    switch (key) {
      case 'Current':     return _sum(_report?.bucketCurrent);
      case '1-30 days':   return _sum(_report?.bucket1To30);
      case '31-60 days':  return _sum(_report?.bucket31To60);
      case '61-90 days':  return _sum(_report?.bucket61To90);
      default:            return _sum(_report?.bucket90Plus);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _buckets.fold<double>(0.0, (s, k) => s + _bucketValue(k));

    return Scaffold(
      appBar: AppBar(title: const Text('AR Aging')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Outstanding: ₱${total.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  for (final key in _buckets) _buildRow(key, _bucketValue(key)),
                ],
              ),
            ),
    );
  }

  Widget _buildRow(String label, double value) {
    return ListTile(
      leading: const Icon(Icons.today_outlined, color: Colors.orange),
      title: Text(label),
      trailing: Text('₱${value.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }
}