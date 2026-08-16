// features/documents/widgets/document_upload_flow.dart

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../../core/models/document_model.dart';
import '../../../core/models/member_model.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/cloudinary_service.dart';

class UploadSelection {
  final String memberId;
  final String memberName;
  final DocumentType docType;
  UploadSelection({
    required this.memberId,
    required this.memberName,
    required this.docType,
  });
}

String documentMimeType(String ext) {
  switch (ext.toLowerCase()) {
    case 'pdf':  return 'application/pdf';
    case 'jpg':
    case 'jpeg': return 'image/jpeg';
    case 'png':  return 'image/png';
    default:     return 'application/octet-stream';
  }
}

/// Full upload flow: pick file -> collect member/type -> upload to
/// Cloudinary -> save metadata. Returns true on success, false if the
/// user cancelled at any step. Throws on upload/save failure — caller
/// should wrap in try/catch.
Future<bool> runDocumentUploadFlow({
  required BuildContext context,
  required FirestoreService fs,
  required CloudinaryService cloudinary,
  required String uploadedByUid,
  String? preselectedMemberId,
  String? preselectedMemberName,
}) async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    withData: true,
  );
  if (result == null || result.files.isEmpty) return false;

  final file = result.files.first;
  if (file.bytes == null || file.bytes!.isEmpty) {
    throw Exception('Could not read file. Please try again.');
  }

  if (!context.mounted) return false;
  final selection = await showDialog<UploadSelection>(
    context: context,
    barrierDismissible: false,
    builder: (_) => UploadDialog(
      fs: fs,
      fileName: file.name,
      preselectedMemberId: preselectedMemberId,
      preselectedMemberName: preselectedMemberName,
    ),
  );
  if (selection == null) return false;

  final fileUrl = await cloudinary.uploadFile(
    fileBytes: file.bytes!,
    fileName:  file.name,
    memberId:  selection.memberId,
    mimeType:  documentMimeType(file.extension ?? ''),
  );

  await fs.saveDocumentMetadata(
    memberUid:  selection.memberId,
    memberName: selection.memberName,
    uploadedBy: uploadedByUid,
    type:       selection.docType,
    fileName:   file.name,
    fileUrl:    fileUrl,
  );

  return true;
}

// ── Upload dialog (moved from documents_screen.dart, now public) ──────────────
class UploadDialog extends StatefulWidget {
  final FirestoreService fs;
  final String fileName;
  final String? preselectedMemberId;
  final String? preselectedMemberName;

  const UploadDialog({
    super.key,
    required this.fs,
    required this.fileName,
    this.preselectedMemberId,
    this.preselectedMemberName,
  });

  @override
  State<UploadDialog> createState() => _UploadDialogState();
}

class _UploadDialogState extends State<UploadDialog> {
  String?      _memberId;
  String?      _memberName;
  DocumentType _docType = DocumentType.other;

  static const Color _navy   = Color(0xFF0D2A5C);
  static const Color _accent = Color(0xFF2E6BE6);

  @override
  void initState() {
    super.initState();
    _memberId   = widget.preselectedMemberId;
    _memberName = widget.preselectedMemberName;
  }

  InputDecoration _dec([String? hint]) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
    filled: true,
    fillColor: const Color(0xFFF7F9FC),
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD0DBEE))),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD0DBEE))),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _accent, width: 1.5)),
  );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
      child: SizedBox(
        width: 440,
        child: Padding(
          padding: const EdgeInsets.all(26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Upload Document',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _navy)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FB),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.attach_file,
                        size: 14, color: Color(0xFF5A7099)),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(widget.fileName,
                          style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF5A7099)),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              const Text('Member',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _navy)),
              const SizedBox(height: 6),
              if (widget.preselectedMemberId != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F4FB),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(0xFFD0DBEE)),
                  ),
                  child: Text(_memberName ?? '',
                      style: const TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFF1A2B4A))),
                )
              else
                StreamBuilder<List<MemberModel>>(
                  stream: widget.fs.streamMembers(),
                  builder: (context, snap) {
                    final members = snap.data ?? [];
                    return DropdownButtonFormField<String>(
                      value: _memberId,
                      hint: Text('Select member',
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[400])),
                      style: const TextStyle(
                          fontSize: 13.5,
                          color: Color(0xFF1A2B4A)),
                      decoration: _dec(),
                      items: members
                          .map((m) => DropdownMenuItem<String>(
                                value: m.uid,
                                child: Text(
                                    '${m.name} — Lot ${m.lotNumber}'),
                              ))
                          .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        final m = members
                            .firstWhere((m) => m.uid == v);
                        setState(() {
                          _memberId   = m.uid;
                          _memberName = m.name;
                        });
                      },
                    );
                  },
                ),
              const SizedBox(height: 16),
              const Text('Document Type',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _navy)),
              const SizedBox(height: 6),
              DropdownButtonFormField<DocumentType>(
                value: _docType,
                style: const TextStyle(
                    fontSize: 13.5, color: Color(0xFF1A2B4A)),
                decoration: _dec(),
                items: DocumentType.values
                    .map((t) => DropdownMenuItem<DocumentType>(
                        value: t, child: Text(t.label)))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _docType = v);
                },
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F4FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF2E6BE6)
                          .withOpacity(0.2)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.cloud_upload_outlined,
                        size: 15, color: Color(0xFF2E6BE6)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'File will be uploaded to Cloudinary CDN.',
                        style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1A4A9C)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel',
                        style: TextStyle(color: Colors.grey)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _memberId == null
                        ? null
                        : () => Navigator.pop(
                              context,
                              UploadSelection(
                                memberId:   _memberId!,
                                memberName: _memberName!,
                                docType:    _docType,
                              ),
                            ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor:
                          _navy.withOpacity(0.4),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 22, vertical: 12),
                    ),
                    child: const Text('Upload',
                        style: TextStyle(
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}