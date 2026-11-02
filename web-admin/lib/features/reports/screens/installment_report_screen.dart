import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/sale_service.dart';
import '../../../core/theme/design_tokens.dart';
import '../widgets/report_widgets.dart';

class InstallmentReportScreen extends StatefulWidget {
  const InstallmentReportScreen({super.key});

  @override
  State<InstallmentReportScreen> createState() => _InstallmentReportScreenState();
}

class _InstallmentReportScreenState extends State<InstallmentReportScreen> {
  final SaleService _saleService = SaleService();
  final FirestoreService _fs = FirestoreService();

  DateTime? _startDate;
  DateTime? _endDate;
  String? _memberFilter;
  String? _memberFilterName;

  Future<void> _pickDate(bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        if (isStart) _startDate = picked; else _endDate = picked;
      });
    }
  }

  void _exportReport() {
    final filteredData = _currentFilteredData;
    if (filteredData.isEmpty) return;

    final rows = <List<dynamic>>[
      ['Buyer', 'Lot Number', 'Period', 'Amount', 'Status'],
      ...filteredData.map((row) => [
            row['buyerName'] ?? '',
            row['lotNumber'] ?? '',
            row['period'] ?? '',
            row['amount']?.toStringAsFixed(2) ?? '0.00',
            row['status'] ?? '',
          ]),
    ];

    final csvData = const ListToCsvConverter().convert(rows);
    final bytes = Uint8List.fromList(utf8.encode(csvData));
    Share.shareXFiles(
      [XFile.fromData(bytes, name: 'report.csv', mimeType: 'text/csv')],
      text: 'Installment Payments Report',
    );
  }

  List<Map<String, dynamic>> _currentFilteredData = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Installment Payments Report')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: AppRadius.cardBorderRadius),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: DateFilter(label: 'From Date', date: _startDate, onTap: () => _pickDate(true))),
                      const SizedBox(width: 14),
                      Expanded(child: DateFilter(label: 'To Date', date: _endDate, onTap: () => _pickDate(false))),
                      const Spacer(),
                      ElevatedButton.icon(
                        onPressed: _exportReport,
                        icon: const Icon(Icons.download),
                        label: const Text('Export'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  MemberDropdown(
                    fs: _fs,
                    selectedId: _memberFilter,
                    selectedName: _memberFilterName,
                    onSelected: (id, name) => setState(() {
                      _memberFilter = id;
                      _memberFilterName = name;
                    }),
                    onClear: () => setState(() {
                      _memberFilter = null;
                      _memberFilterName = null;
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _saleService.getPaymentsReportDataset(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snapshot.data ?? [];

                _currentFilteredData = data.where((row) {
                  final soldDate = row['soldDate'];
                  if (soldDate is DateTime) {
                    final d = soldDate;
                    if (_startDate != null && d.isBefore(_startDate!)) return false;
                    if (_endDate != null && d.isAfter(_endDate!)) return false;
                  }
                  final matchesMember = _memberFilter == null || row['buyerUid'] == _memberFilter;
                  return matchesMember;
                }).toList();

                if (_currentFilteredData.isEmpty) return const Center(child: Text('No installment records found.'));

                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _currentFilteredData.length,
                  itemBuilder: (context, index) {
                    final row = _currentFilteredData[index];
                    return Card(
                      child: ListTile(
                        title: Text('${row['buyerName']} - Lot ${row['lotNumber']}'),
                        subtitle: Text('Period: ${row['period']} | Status: ${row['status']}'),
                        trailing: Text('₱${(row['amount'] as double).toStringAsFixed(2)}'),
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
