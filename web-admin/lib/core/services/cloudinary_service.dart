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

import 'dart:typed_data';
import 'package:crypto/crypto.dart';
import 'dart:convert' show utf8;
import 'package:dio/dio.dart';
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
  /// [onProgress] is called with a value from 0.0 to 1.0 as the upload
  /// progresses — hook this up to a progress bar in the UI.
  /// Throws [CloudinaryUploadException] on failure.
  Future<String> uploadFile({
    required Uint8List fileBytes,
    required String fileName,
    required String memberId,
    required String mimeType,
    void Function(double progress)? onProgress,
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

    final formData = FormData.fromMap({
      'api_key':   _apiKey,
      'timestamp': timestamp,
      'folder':    folder,
      'public_id': publicId,
      'signature': signature,
      'file': MultipartFile.fromBytes(
        fileBytes,
        filename: fileName,
      ),
    });

    try {
      final response = await Dio().post(
        _uploadUrl,
        data: formData,
        onSendProgress: (sent, total) {
          if (total > 0) onProgress?.call(sent / total);
        },
      );

      final data = response.data as Map<String, dynamic>;
      final url  = data['secure_url'] as String?;
      if (url == null || url.isEmpty) {
        throw CloudinaryUploadException('Upload succeeded but no URL returned.');
      }
      return url;
    } on DioException catch (e) {
      final message = _extractErrorMessage(e.response?.data) ??
          'Upload failed (${e.response?.statusCode ?? e.message})';
      throw CloudinaryUploadException(message);
    }
  }

  // ── Safely pull an error message out of Cloudinary's error response
  // shape ({"error": {"message": "..."}}) without relying on an inline
  // ternary + cast chain, which some Dart web build configurations
  // parse ambiguously.
  static String? _extractErrorMessage(dynamic data) {
    if (data is Map) {
      final error = data['error'];
      if (error is Map) {
        final msg = error['message'];
        if (msg is String) return msg;
      }
    }
    return null;
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

    try {
      await Dio().post(
        deleteUrl,
        data: FormData.fromMap({
          'public_id': publicId,
          'api_key':   _apiKey,
          'timestamp': timestamp,
          'signature': signature,
        }),
      );
    } catch (_) {
      // Best-effort delete — don't let a failed cleanup call surface
      // as an error to the user; the document record is already gone
      // from Firestore by the time this runs.
    }
  }
}

// ── Custom exception ──────────────────────────────────────────────────────────
class CloudinaryUploadException implements Exception {
  final String message;
  const CloudinaryUploadException(this.message);

  @override
  String toString() => 'CloudinaryUploadException: $message';
}