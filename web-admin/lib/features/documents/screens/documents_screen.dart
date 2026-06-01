// features/documents/screens/documents_screen.dart
// UPDATED — uses Cloudinary for file uploads instead of Firebase Storage.
//
// Upload flow:
//   1. Admin picks a file via file_picker
//   2. Upload dialog collects member + document type
//   3. CloudinaryService.uploadFile() uploads bytes → returns secure_url
//   4. FirestoreService.saveDocumentMetadata() saves url + metadata to Firestore
//   5. Stream refreshes the grid automatically

import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/document_model.dart';
import '../../../core/models/member_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/cloudinary_service.dart';

class DocumentsScreen extends StatefulWidget {
  final String? filterMemberId;
  final String? filterMemberName;

  const DocumentsScreen({
    super.key,
    this.filterMemberId,
    this.filterMemberName,
  });

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  final _fs           = FirestoreService();
  final _cloudinary   = CloudinaryService();
  final _searchCtrl   = TextEditingController();

  String        _searchQuery  = '';
  DocumentType? _typeFilter;
  bool          _uploading    = false;
  String?       _uploadError;

  // ── Brand colours ──────────────────────────────────────────────────────────
  static const Color _navy   = Color(0xFF0D2A5C);
  static const Color _accent = Color(0xFF2E6BE6);
  static const Color _bg     = Color(0xFFF0F4FB);
  static const Color _red    = Color(0xFFCC2200);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Filter helper ──────────────────────────────────────────────────────────
  List<DocumentModel> _filtered(List<DocumentModel> all) {
    return all.where((d) {
      final q           = _searchQuery.toLowerCase();
      final matchSearch = q.isEmpty ||
          d.memberName.toLowerCase().contains(q) ||
          d.fileName.toLowerCase().contains(q) ||
          d.type.label.toLowerCase().contains(q);
      final matchType = _typeFilter == null || d.type == _typeFilter;
      return matchSearch && matchType;
    }).toList();
  }

  // ── MIME type helper ───────────────────────────────────────────────────────
  String _mimeType(String ext) {
    switch (ext.toLowerCase()) {
      case 'pdf':  return 'application/pdf';
      case 'jpg':
      case 'jpeg': return 'image/jpeg';
      case 'png':  return 'image/png';
      default:     return 'application/octet-stream';
    }
  }

  // ── Main upload flow ───────────────────────────────────────────────────────
  Future<void> _startUpload() async {
    setState(() { _uploadError = null; });

    // 1. Pick file
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null || file.bytes!.isEmpty) {
      setState(() => _uploadError = 'Could not read file. Please try again.');
      return;
    }

    // 2. Show upload dialog — collect member + doc type
    final auth      = context.read<AuthProvider>();
    final selection = await showDialog<_UploadSelection>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _UploadDialog(
        fs:                    _fs,
        fileName:              file.name,
        preselectedMemberId:   widget.filterMemberId,
        preselectedMemberName: widget.filterMemberName,
      ),
    );
    if (selection == null) return;

    // 3. Upload to Cloudinary
    setState(() { _uploading = true; _uploadError = null; });
    try {
      final fileUrl = await _cloudinary.uploadFile(
        fileBytes: file.bytes!,
        fileName:  file.name,
        memberId:  selection.memberId,
        mimeType:  _mimeType(file.extension ?? ''),
      );

      // 4. Save metadata to Firestore
      await _fs.saveDocumentMetadata(
        memberUid:  selection.memberId,
        memberName: selection.memberName,
        uploadedBy: auth.userModel?.uid ?? '',
        type:       selection.docType,
        fileName:   file.name,
        fileUrl:    fileUrl,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document uploaded successfully.'),
            backgroundColor: Color(0xFF1A7A4A),
          ),
        );
      }
    } on CloudinaryUploadException catch (e) {
      setState(() => _uploadError = e.message);
    } catch (e) {
      setState(() => _uploadError = 'Upload failed: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth      = context.watch<AuthProvider>();
    final canUpload = auth.isAdmin || auth.isOfficer;
    final isFiltered = widget.filterMemberId != null;

    return Scaffold(
      backgroundColor: _bg,
      appBar: isFiltered
          ? AppBar(
              backgroundColor: Colors.white,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back, color: _navy),
                onPressed: () => Navigator.pop(context),
              ),
              title: Text(
                'Documents — ${widget.filterMemberName ?? ''}',
                style: const TextStyle(
                    color: _navy,
                    fontWeight: FontWeight.w700,
                    fontSize: 17),
              ),
            )
          : null,
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Page header (full page only) ──────────────────────────────
            if (!isFiltered) ...[
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Documents',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: _navy),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Property titles, IDs, and uploaded files',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (canUpload) _UploadButton(
                    uploading: _uploading,
                    onTap: _startUpload,
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // ── Upload button (member-filtered view) ──────────────────────
            if (isFiltered && canUpload)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _UploadButton(
                      uploading: _uploading, onTap: _startUpload),
                ),
              ),

            // ── Upload progress bar ────────────────────────────────────────
            if (_uploading) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(
                  backgroundColor: Color(0xFFD0DBEE),
                  color: Color(0xFF2E6BE6),
                  minHeight: 3,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Uploading to Cloudinary…',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(height: 12),
            ],

            // ── Error banner ───────────────────────────────────────────────
            if (_uploadError != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0EE),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: _red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline,
                        size: 16, color: _red),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_uploadError!,
                          style: const TextStyle(
                              fontSize: 13, color: _red)),
                    ),
                    InkWell(
                      onTap: () => setState(() => _uploadError = null),
                      child: const Icon(Icons.close,
                          size: 15, color: _red),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            // ── Filters ───────────────────────────────────────────────────
            Row(
              children: [
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Search member or file name…',
                      hintStyle: TextStyle(
                          fontSize: 13, color: Colors.grey[400]),
                      prefixIcon:
                          const Icon(Icons.search, size: 18),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                              color: Color(0xFFD0DBEE))),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                              color: Color(0xFFD0DBEE))),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(
                              color: _accent, width: 1.5)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _TypeFilterDropdown(
                  value: _typeFilter,
                  onChanged: (v) => setState(() => _typeFilter = v),
                ),
                if (_searchQuery.isNotEmpty || _typeFilter != null) ...[
                  const SizedBox(width: 10),
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _searchCtrl.clear();
                      _searchQuery = '';
                      _typeFilter  = null;
                    }),
                    icon: const Icon(Icons.clear, size: 15),
                    label: const Text('Clear'),
                    style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[600]),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 20),

            // ── Document grid ─────────────────────────────────────────────
            Expanded(
              child: StreamBuilder<List<DocumentModel>>(
                stream: widget.filterMemberId != null
                    ? _fs.streamDocumentsForMember(
                        widget.filterMemberId!)
                    : _fs.streamDocuments(),
                builder: (context, snap) {
                  if (snap.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }

                  final docs = _filtered(snap.data ?? []);

                  if (docs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.folder_open_outlined,
                              size: 52, color: Colors.grey[300]),
                          const SizedBox(height: 14),
                          Text(
                            'No documents found.',
                            style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500]),
                          ),
                          if (canUpload) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Click "Upload Document" to add one.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[400]),
                            ),
                          ],
                        ],
                      ),
                    );
                  }

                  return GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 240,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      childAspectRatio: 1.05,
                    ),
                    itemCount: docs.length,
                    itemBuilder: (_, i) => _DocumentCard(
                      doc:       docs[i],
                      fs:        _fs,
                      cloudinary: _cloudinary,
                      canDelete: canUpload,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Upload button ─────────────────────────────────────────────────────────────
class _UploadButton extends StatelessWidget {
  final bool uploading;
  final VoidCallback onTap;

  static const Color _navy = Color(0xFF0D2A5C);

  const _UploadButton({required this.uploading, required this.onTap});

  @override
  Widget build(BuildContext context) => ElevatedButton.icon(
    onPressed: uploading ? null : onTap,
    icon: uploading
        ? const SizedBox(
            width: 16, height: 16,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: Colors.white))
        : const Icon(Icons.upload_file_outlined, size: 18),
    label: Text(uploading ? 'Uploading…' : 'Upload Document'),
    style: ElevatedButton.styleFrom(
      backgroundColor: _navy,
      foregroundColor: Colors.white,
      disabledBackgroundColor: _navy.withOpacity(0.5),
      padding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8)),
    ),
  );
}

// ── Type filter dropdown ──────────────────────────────────────────────────────
class _TypeFilterDropdown extends StatelessWidget {
  final DocumentType? value;
  final void Function(DocumentType?) onChanged;

  const _TypeFilterDropdown(
      {required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Container(
    height: 42,
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: const Color(0xFFD0DBEE)),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<DocumentType?>(
        value: value,
        hint: Text('All Types',
            style: TextStyle(
                fontSize: 13, color: Colors.grey[500])),
        style: const TextStyle(
            fontSize: 13, color: Color(0xFF1A2B4A)),
        icon: const Icon(Icons.expand_more, size: 18),
        items: [
          const DropdownMenuItem<DocumentType?>(
              value: null, child: Text('All Types')),
          ...DocumentType.values.map((t) =>
              DropdownMenuItem<DocumentType?>(
                  value: t, child: Text(t.label))),
        ],
        onChanged: onChanged,
      ),
    ),
  );
}

// ── Document card ─────────────────────────────────────────────────────────────
class _DocumentCard extends StatelessWidget {
  final DocumentModel    doc;
  final FirestoreService fs;
  final CloudinaryService cloudinary;
  final bool canDelete;

  const _DocumentCard({
    required this.doc,
    required this.fs,
    required this.cloudinary,
    required this.canDelete,
  });

  IconData _icon(DocumentType t) {
    switch (t) {
      case DocumentType.propertyTitle:    return Icons.home_work_outlined;
      case DocumentType.governmentId:     return Icons.badge_outlined;
      case DocumentType.proofOfResidency: return Icons.location_on_outlined;
      case DocumentType.other:            return Icons.insert_drive_file_outlined;
    }
  }

  Color _color(DocumentType t) {
    switch (t) {
      case DocumentType.propertyTitle:    return const Color(0xFF1A4A9C);
      case DocumentType.governmentId:     return const Color(0xFF1A7A4A);
      case DocumentType.proofOfResidency: return const Color(0xFF7A3A1A);
      case DocumentType.other:            return const Color(0xFF5A7099);
    }
  }

  String _ext(String fileName) {
    final parts = fileName.split('.');
    return parts.length > 1 ? parts.last.toUpperCase() : 'FILE';
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final color = _color(doc.type);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E8F4)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Card top row ────────────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_icon(doc.type), size: 20, color: color),
              ),
              const Spacer(),
              // Extension badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FB),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  _ext(doc.fileName),
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF5A7099)),
                ),
              ),
              // Cloudinary badge
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F4FF),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'CDN',
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF2E6BE6)),
                ),
              ),
              if (canDelete) ...[
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => _confirmDelete(context),
                  child: const Icon(Icons.delete_outline,
                      size: 17, color: Colors.grey),
                ),
              ],
            ],
          ),
          const Spacer(),

          // ── Doc type label ───────────────────────────────────────────────
          Text(
            doc.type.label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF5A7099),
                letterSpacing: 0.3),
          ),
          const SizedBox(height: 3),

          // ── File name ────────────────────────────────────────────────────
          Text(
            doc.fileName,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1A2B4A)),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),

          // ── Member name ──────────────────────────────────────────────────
          Text(
            doc.memberName,
            style: TextStyle(fontSize: 11.5, color: Colors.grey[500]),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),

          // ── Footer ───────────────────────────────────────────────────────
          Row(
            children: [
              Text(
                _fmt(doc.createdAt),
                style: TextStyle(
                    fontSize: 11, color: Colors.grey[400]),
              ),
              const Spacer(),
              InkWell(
                onTap: () async {
                  final uri = Uri.parse(doc.fileUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri,
                        mode: LaunchMode.externalApplication);
                  }
                },
                child: const Text(
                  'View',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF2E6BE6)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        title: const Text(
          'Delete Document',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0D2A5C)),
        ),
        content: Text(
          'Are you sure you want to delete "${doc.fileName}"?\n'
          'This will remove it from Cloudinary and Firestore.',
          style: const TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFCC2200),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Delete from Cloudinary first, then Firestore metadata
      await cloudinary.deleteFile(doc.fileUrl);
      await fs.deleteDocumentMetadata(doc.id);
    }
  }
}

// ── Upload selection model ────────────────────────────────────────────────────
class _UploadSelection {
  final String memberId;
  final String memberName;
  final DocumentType docType;

  _UploadSelection({
    required this.memberId,
    required this.memberName,
    required this.docType,
  });
}

// ── Upload dialog ─────────────────────────────────────────────────────────────
class _UploadDialog extends StatefulWidget {
  final FirestoreService fs;
  final String fileName;
  final String? preselectedMemberId;
  final String? preselectedMemberName;

  const _UploadDialog({
    required this.fs,
    required this.fileName,
    this.preselectedMemberId,
    this.preselectedMemberName,
  });

  @override
  State<_UploadDialog> createState() => _UploadDialogState();
}

class _UploadDialogState extends State<_UploadDialog> {
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
              // Header
              const Text(
                'Upload Document',
                style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: _navy),
              ),
              const SizedBox(height: 4),
              // File name chip
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
                      child: Text(
                        widget.fileName,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF5A7099)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Member selector
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
                  child: Text(
                    _memberName ?? '',
                    style: const TextStyle(
                        fontSize: 13.5,
                        color: Color(0xFF1A2B4A)),
                  ),
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

              // Document type
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
                          value: t,
                          child: Text(t.label),
                        ))
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _docType = v);
                },
              ),
              const SizedBox(height: 24),

              // Cloudinary notice
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F4FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF2E6BE6).withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cloud_upload_outlined,
                        size: 15, color: Color(0xFF2E6BE6)),
                    const SizedBox(width: 8),
                    const Expanded(
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

              // Actions
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
                              _UploadSelection(
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