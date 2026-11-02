import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:csv/csv.dart';
import '../../../core/services/lot_service.dart';
import '../../../core/theme/design_tokens.dart';

class BulkLotUpdateScreen extends StatefulWidget {
  const BulkLotUpdateScreen({super.key});

  @override
  State<BulkLotUpdateScreen> createState() => _BulkLotUpdateScreenState();
}

class _BulkLotUpdateScreenState extends State<BulkLotUpdateScreen> {
  final LotService _lotService = LotService();
  String? _phase;
  List<Map<String, dynamic>> _csvData = [];
  bool _isLoading = false;

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv']);
    if (result != null) {
      setState(() => _isLoading = true);
      final bytes = result.files.single.bytes!;
      final csvString = utf8.decode(bytes);
      final rows = const CsvToListConverter().convert(csvString);

      // Assume header: phase, block, lotNumber, areaSqm
      _csvData = rows.skip(1).map((row) => {
        'phase': row[0].toString(),
        'block': row[1].toString(),
        'lotNumber': row[2].toString(),
        'areaSqm': double.tryParse(row[3].toString()) ?? 0.0,
      }).toList();

      setState(() => _isLoading = false);
    }
  }

  Future<void> _upload() async {
    if (_csvData.isEmpty || _phase == null) return;
    setState(() => _isLoading = true);
    try {
      final count = await _lotService.bulkUpdateLotAreas(_phase!, _csvData, 'admin');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Updated $count lots')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bulk Lot Area Update')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Phase Name'),
              onChanged: (v) => setState(() => _phase = v),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _pickFile, child: const Text('Pick CSV')),
            const SizedBox(height: 16),
            if (_csvData.isNotEmpty) Text('Loaded ${_csvData.length} rows'),
            const SizedBox(height: 16),
            if (_isLoading) const CircularProgressIndicator(),
            if (!_isLoading && _csvData.isNotEmpty) ElevatedButton(onPressed: _upload, child: const Text('Upload')),
          ],
        ),
      ),
    );
  }
}
