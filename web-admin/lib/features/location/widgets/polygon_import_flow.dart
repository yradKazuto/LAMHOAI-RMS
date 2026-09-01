// features/location/widgets/polygon_import_flow.dart
//
// Imports the .xlsx file exported by the standalone "Lot Coordinate
// Picker" HTML tool (columns: Block, Lot, Point, X, Y — raw pixel
// coordinates) and bulk-creates/updates lots for the given phase.
//
// Requires the `excel` package: run `flutter pub add excel`.

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as xlsx;

import '../../../core/models/lot_model.dart';
import '../../../core/services/lot_service.dart';

const _navy = Color(0xFF0D2A52);

/// Runs the full import flow: pick file -> parse -> confirm -> import.
/// [imageWidth]/[imageHeight] are the phase's actual map image pixel
/// dimensions, needed to normalize the tool's raw pixel coordinates
/// to the 0.0-1.0 range LotModel expects. Returns the number of lots
/// imported, or null if the user cancelled.
Future<int?> runPolygonImportFlow({
  required BuildContext context,
  required String phase,
  required double imageWidth,
  required double imageHeight,
  required String updatedBy,
}) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['xlsx'],
    withData: true,
  );
  if (result == null || result.files.isEmpty) return null;

  final bytes = result.files.first.bytes;
  if (bytes == null) {
    throw Exception('Could not read the file.');
  }

  final Map<String, List<LotPoint>> parsed;
  try {
    parsed = _parseWorkbook(bytes, imageWidth, imageHeight);
  } catch (e) {
    throw Exception(
        'Could not read this file. Make sure it was exported from the '
        'Lot Coordinate Picker tool. ($e)');
  }

  if (parsed.isEmpty) {
    throw Exception('No lot coordinate data found in this file.');
  }

  if (!context.mounted) return null;

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: const Text('Import Lot Coordinates',
          style: TextStyle(
              fontSize: 16, fontWeight: FontWeight.w700, color: _navy)),
      content: Text(
        'Found ${parsed.length} lot(s) in this file for "$phase".\n\n'
        'Existing lots with a matching Block + Lot Number will be '
        'updated; new ones will be created.',
        style: const TextStyle(fontSize: 13.5),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: _navy,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Import'),
        ),
      ],
    ),
  );

  if (confirmed != true) return null;

  final lotService = LotService();
  return lotService.importPolygonLots(
    phase: phase,
    lotsData: parsed,
    updatedBy: updatedBy,
  );
}

/// Parses the workbook into a map of "block|lotNumber" -> ordered
/// normalized points, matching the Block/Lot/Point/X/Y columns the
/// coordinate picker tool exports.
Map<String, List<LotPoint>> _parseWorkbook(
  List<int> bytes,
  double imageWidth,
  double imageHeight,
) {
  final workbook = xlsx.Excel.decodeBytes(bytes);
  final sheet = workbook.tables.values.first;

  final rows = sheet.rows;
  if (rows.isEmpty) return {};

  final header = rows.first
      .map((cell) => cell?.value?.toString().trim().toLowerCase() ?? '')
      .toList();

  final blockIdx = header.indexOf('block');
  final lotIdx = header.indexOf('lot');
  final xIdx = header.indexOf('x');
  final yIdx = header.indexOf('y');

  if (blockIdx == -1 || lotIdx == -1 || xIdx == -1 || yIdx == -1) {
    throw Exception('Missing expected columns (Block, Lot, X, Y).');
  }

  final result = <String, List<LotPoint>>{};

  for (var i = 1; i < rows.length; i++) {
    final row = rows[i];
    final maxIdx = [blockIdx, lotIdx, xIdx, yIdx].reduce((a, b) => a > b ? a : b);
    if (row.length <= maxIdx) continue;

    final block = row[blockIdx]?.value?.toString().trim() ?? '';
    final rawLot = row[lotIdx]?.value?.toString().trim() ?? '';
    final lotNumber =
        rawLot.replaceFirst(RegExp(r'^Lot\s+', caseSensitive: false), '');

    final xVal = row[xIdx]?.value;
    final yVal = row[yIdx]?.value;
    if (block.isEmpty || lotNumber.isEmpty || xVal == null || yVal == null) {
      continue;
    }

    final rawX = double.tryParse(xVal.toString());
    final rawY = double.tryParse(yVal.toString());
    if (rawX == null || rawY == null) continue;

    final nx = (rawX / imageWidth).clamp(0.0, 1.0);
    final ny = (rawY / imageHeight).clamp(0.0, 1.0);

    final key = '$block|$lotNumber';
    result.putIfAbsent(key, () => []).add(LotPoint(nx, ny));
  }

  return result;
}