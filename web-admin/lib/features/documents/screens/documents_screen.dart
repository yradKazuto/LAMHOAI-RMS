// features/documents/screens/documents_screen.dart
// UPDATED Phase 4 fixes:
//   - canUpload excludes Accountant (Admin + Officer only)
//   - canDelete is Admin only
// UPDATED — upload flow moved to shared document_upload_flow.dart
// UPDATED — audit logging on upload (inside the flow) and delete

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/models/document_model.dart';
import '../../../core/models/audit_log_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/services/settings_service.dart';
import '../widgets/document_upload_flow.dart';

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
  final _fs         = FirestoreService();
  final _cloudinary = CloudinaryService();
  final _searchCtrl = TextEditingController();

  String        _searchQuery = '';
  DocumentType? _typeFilter;
  bool          _uploading   = false;
  String?       _uploadError;

  static const Color _navy   = Color(0xFF0D2A5C);
  static const Color _accent = Color(0xFF2E6BE6);
  static const Color _bg     = Color(0xFFF0F4FB);
  static const Color _red    = Color(0xFFCC2200);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

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

  Future<void> _startUpload() async {
    setState(() { _uploadError = null; });

    final auth = context.read<AuthProvider>();
    setState(() { _uploading = true; });
    try {
      final success = await runDocumentUploadFlow(
        context: context,
        fs: _fs,
        cloudinary: _cloudinary,
        uploadedByUid: auth.userModel?.uid ?? '',
        uploadedByName: auth.userModel?.displayName ?? '',
        preselectedMemberId: widget.filterMemberId,
        preselectedMemberName: widget.filterMemberName,
      );

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Document uploaded successfully.'),
            backgroundColor: Color(0xFF1A7A4A),
          ),
        );
      }
    } catch (e) {
      setState(() => _uploadError = 'Upload failed: $e');
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    // Fix 3: canUpload — Admin + Officer only (Accountant excluded)
    final canUpload = auth.isAdmin || auth.isOfficer;

    // Fix 4: canDelete — Admin only
    final canDelete = auth.isAdmin;

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

            if (!isFiltered) ...[
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Documents',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: _navy)),
                      const SizedBox(height: 2),
                      Text(
                        'Property titles, IDs, and uploaded files',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const Spacer(),
                  if (canUpload)
                    _UploadButton(
                        uploading: _uploading,
                        onTap: _startUpload),
                ],
              ),
              const SizedBox(height: 16),
            ],

            if (isFiltered && canUpload)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _UploadButton(
                      uploading: _uploading, onTap: _startUpload),
                ),
              ),

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
              Text('Uploading to Cloudinary…',
                  style: TextStyle(
                      fontSize: 12, color: Colors.grey[500])),
              const SizedBox(height: 12),
            ],

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
                      onTap: () =>
                          setState(() => _uploadError = null),
                      child: const Icon(Icons.close,
                          size: 15, color: _red),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            Row(
              children: [
                SizedBox(
                  width: 260,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) =>
                        setState(() => _searchQuery = v),
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
                  onChanged: (v) =>
                      setState(() => _typeFilter = v),
                ),
                if (_searchQuery.isNotEmpty ||
                    _typeFilter != null) ...[
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
                              size: 52,
                              color: Colors.grey[300]),
                          const SizedBox(height: 14),
                          Text('No documents found.',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500])),
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
                      doc:        docs[i],
                      fs:         _fs,
                      cloudinary: _cloudinary,
                      canDelete:  canDelete,   // Fix 4: Admin only
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
            style:
                TextStyle(fontSize: 13, color: Colors.grey[500])),
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
  final DocumentModel     doc;
  final FirestoreService  fs;
  final CloudinaryService cloudinary;
  final bool              canDelete;

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

  String _ext(String f) {
    final p = f.split('.');
    return p.length > 1 ? p.last.toUpperCase() : 'FILE';
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
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F4FB),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(_ext(doc.fileName),
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF5A7099))),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F4FF),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text('CDN',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF2E6BE6))),
              ),
              // Fix 4: Only show delete icon for Admin
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
          Text(doc.type.label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5A7099),
                  letterSpacing: 0.3)),
          const SizedBox(height: 3),
          Text(doc.fileName,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF1A2B4A)),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text(doc.memberName,
              style: TextStyle(
                  fontSize: 11.5, color: Colors.grey[500]),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(_fmt(doc.createdAt),
                  style: TextStyle(
                      fontSize: 11, color: Colors.grey[400])),
              const Spacer(),
              InkWell(
                onTap: () async {
                  final uri = Uri.parse(doc.fileUrl);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri,
                        mode: LaunchMode.externalApplication);
                  }
                },
                child: const Text('View',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2E6BE6))),
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
        title: const Text('Delete Document',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0D2A5C))),
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
      await cloudinary.deleteFile(doc.fileUrl);
      await fs.deleteDocumentMetadata(doc.id);

      // ── Audit log ────────────────────────────────────────────────────
      if (context.mounted) {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        await SettingsService().logAction(
          performedBy:      auth.userModel?.uid ?? '',
          performedByName:  auth.userModel?.displayName ?? '',
          action:           AuditAction.deleted,
          targetCollection: 'documents',
          targetId:         doc.id,
          description:      'Deleted document "${doc.fileName}" '
                             'for ${doc.memberName}',
        );
      }
    }
  }
}