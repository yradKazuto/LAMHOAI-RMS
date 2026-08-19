// core/services/cloudinary_service.dart
//
// Uses unsigned uploads via Cloudinary's REST API endpoint.
// Cloud name is hardcoded (not sensitive — it's visible in every
// uploaded file's public URL anyway). API Key and Secret are read
// from .env at runtime via flutter_dotenv.
//
// .env must contain:
//   CLOUDINARY_API_KEY=your_key
//   CLOUDINARY_API_SECRET=your_secret

import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CloudinaryService {
  // ── Config ─────────────────────────────────────────────────────────────────
  static const String cloudName = 'drmufa6ev';

  // Read from .env at call time (not a compile-time const — dotenv loads
  // asynchronously in main.dart before this is ever used).
  static String get _apiKey => dotenv.env['CLOUDINARY_API_KEY'] ?? '';
  static String get _apiSecret => dotenv.env['CLOUDINARY_API_SECRET'] ?? '';

  static const String _uploadFolder = 'lamhoai_rms/documents';

  // ── Upload endpoint ────────────────────────────────────────────────────────
  static String get _uploadUrl =>
      'https://api.cloudinary.com/v1_1/$cloudName/auto/upload';

  // ── Generate SHA-1 signature for authenticated upload ─────────────────────
  static String _generateSignature({
    required String folder,
    required String publicId,
    required String timestamp,
  }) {
    final paramsToSign =
        'folder=$folder&public_id=$publicId&timestamp=$timestamp$_apiSecret';
    final bytes = utf8.encode(paramsToSign);
    return sha1.convert(bytes).toString();
  }

  // ── Upload file bytes to Cloudinary ───────────────────────────────────────
  /// Returns the secure URL of the uploaded file.
  /// Throws [CloudinaryUploadException] on failure.
  Future<String> uploadFile({
    required Uint8List fileBytes,
    required String fileName,
    required String memberId,
    required String mimeType,
  }) async {
    if (_apiKey.isEmpty || _apiSecret.isEmpty) {
      throw CloudinaryUploadException(
        'Cloudinary API key or secret not configured. '
        'Check that .env contains CLOUDINARY_API_KEY and '
        'CLOUDINARY_API_SECRET, and that dotenv.load() ran in main.dart.',
      );
    }

    final timestamp =
        (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();

    // Use memberId subfolder for organisation
    final folder   = '$_uploadFolder/$memberId';
    final publicId = '${DateTime.now().millisecondsSinceEpoch}_'
        '${fileName.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_')}';

    final signature = _generateSignature(
      folder:    folder,
      publicId:  publicId,
      timestamp: timestamp,
    );

    final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl))
      ..fields['api_key']   = _apiKey
      ..fields['timestamp'] = timestamp
      ..fields['folder']    = folder
      ..fields['public_id'] = publicId
      ..fields['signature'] = signature
      ..files.add(http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
      ));

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final url  = json['secure_url'] as String?;
      if (url == null || url.isEmpty) {
        throw CloudinaryUploadException('Upload succeeded but no URL returned.');
      }
      return url;
    } else {
      final json    = jsonDecode(response.body) as Map<String, dynamic>;
      final message = (json['error'] as Map?)?['message'] as String?
          ?? 'Upload failed (${response.statusCode})';
      throw CloudinaryUploadException(message);
    }
  }

  // ── Delete by public ID ────────────────────────────────────────────────────
  /// Extracts the public_id from a Cloudinary URL and deletes the asset.
  Future<void> deleteFile(String secureUrl) async {
    if (_apiKey.isEmpty || _apiSecret.isEmpty) return;

    // Extract public_id from URL:
    // https://res.cloudinary.com/<cloud>/image/upload/v<ver>/<folder>/<id>.<ext>
    final uri       = Uri.parse(secureUrl);
    final segments  = uri.pathSegments;
    // Find the segment after 'upload'
    final uploadIdx = segments.indexOf('upload');
    if (uploadIdx == -1 || uploadIdx + 2 >= segments.length) return;

    // Skip the version segment (v1234567)
    final afterUpload = segments.sublist(uploadIdx + 1);
    final withoutVersion = afterUpload.first.startsWith('v')
        ? afterUpload.sublist(1)
        : afterUpload;

    // Remove file extension
    final rawId   = withoutVersion.join('/');
    final publicId = rawId.contains('.')
        ? rawId.substring(0, rawId.lastIndexOf('.'))
        : rawId;

    final timestamp = (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
    final sigStr    = 'public_id=$publicId&timestamp=$timestamp$_apiSecret';
    final signature = sha1.convert(utf8.encode(sigStr)).toString();

    final deleteUrl =
        'https://api.cloudinary.com/v1_1/$cloudName/image/destroy';

    await http.post(
      Uri.parse(deleteUrl),
      body: {
        'public_id': publicId,
        'api_key':   _apiKey,
        'timestamp': timestamp,
        'signature': signature,
      },
    );
  }
}

// ── Custom exception ──────────────────────────────────────────────────────────
class CloudinaryUploadException implements Exception {
  final String message;
  const CloudinaryUploadException(this.message);

  @override
  String toString() => 'CloudinaryUploadException: $message';
}