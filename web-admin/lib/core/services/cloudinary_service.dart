// core/services/cloudinary_service.dart
//
// Uses UNSIGNED uploads via Cloudinary's REST API.
//
// This intentionally does NOT use an API key/secret — those can never be
// safe in a Flutter *web* build, since anything the browser needs to run
// the app is readable by anyone who opens it (this is exactly how
// CLOUDINARY_API_KEY/SECRET previously ended up exposed in
// build/web/assets/env_config.txt on the deployed site).
//
// Setup required in the Cloudinary dashboard (Settings → Upload →
// Upload presets): create an unsigned preset named below, restricted to
// the `lamhoai_rms/documents` folder if you want to scope what it can
// write to.
//
// Deletion is NOT possible via the unsigned API (Cloudinary requires a
// signed request — i.e. the secret — to delete). See deleteFile() below
// for how that's handled instead.

import 'dart:typed_data';
import 'package:dio/dio.dart';

class CloudinaryService {
  // ── Config ─────────────────────────────────────────────────────────────────
  static const String cloudName = 'drmufa6ev';

  /// Create this in Cloudinary → Settings → Upload → Upload presets,
  /// with "Signing Mode" set to Unsigned.
  static const String _uploadPreset = 'lamhoai_rms_unsigned';

  static const String _uploadFolder = 'lamhoai_rms/documents';

  static String get _uploadUrl =>
      'https://api.cloudinary.com/v1_1/$cloudName/auto/upload';

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
    // Use memberId subfolder for organisation
    final folder   = '$_uploadFolder/$memberId';
    final publicId = '${DateTime.now().millisecondsSinceEpoch}_'
        '${fileName.replaceAll(RegExp(r'[^a-zA-Z0-9_.-]'), '_')}';

    final formData = FormData.fromMap({
      'upload_preset': _uploadPreset,
      'folder':        folder,
      'public_id':     publicId,
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

  // ── "Delete" ──────────────────────────────────────────────────────────────
  /// Cloudinary's unsigned API can't delete assets — deleting requires a
  /// signed request, which requires the API secret, which can't live in
  /// this client. So this is a soft delete: callers already remove the
  /// Firestore document that references this file before/around calling
  /// this (see member_detail_screen.dart / documents_screen.dart), which
  /// is what actually makes the file inaccessible from the app. The file
  /// itself is left in Cloudinary as an orphan.
  ///
  /// If you outgrow this, the fix isn't a client-side one: stand up a tiny
  /// server-side endpoint (Vercel/Netlify function, or similar) that holds
  /// the API secret and performs the signed destroy call — never do this
  /// signing in the browser again.
  ///
  /// Periodically clean up orphaned files from the Cloudinary dashboard
  /// (Media Library → filter by folder `lamhoai_rms/documents`), or set
  /// up Cloudinary's own auto-backup/expiry rules if upload volume grows.
  Future<void> deleteFile(String secureUrl) async {
    // Intentionally a no-op — see doc comment above.
  }
}

// ── Custom exception ──────────────────────────────────────────────────────────
class CloudinaryUploadException implements Exception {
  final String message;
  const CloudinaryUploadException(this.message);

  @override
  String toString() => 'CloudinaryUploadException: $message';
}