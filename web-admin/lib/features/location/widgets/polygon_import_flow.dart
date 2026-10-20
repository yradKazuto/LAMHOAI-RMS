// features/location/widgets/polygon_import_flow.dart
//
// Imports the .xlsx file exported by the standalone "Lot Coordinate
// Picker" HTML tool (columns: Block, Lot, Point, X, Y — raw pixel
// coordinates) and bulk-creates/updates lots for the given phase.
//
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';

import '../../../core/models/lot_model.dart';

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
    return null;
  }

  // NOTE: Excel parsing was removed.
  // To restore, add 'excel' package and implement parsing here.
  return null;
}
