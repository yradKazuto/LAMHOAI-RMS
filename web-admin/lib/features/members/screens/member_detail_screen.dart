// features/members/screens/member_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:file_picker/file_picker.dart';
import '../../../core/models/member_model.dart';
import '../../../core/models/payment_model.dart';
import '../../../core/models/document_model.dart';
import '../../../core/models/audit_log_model.dart';
import '../../../core/models/lot_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/cloudinary_service.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/lot_service.dart';
import '../../location/screens/location_mapping_screen.dart';
import '../../payments/screens/add_payment_screen.dart';
import '../../documents/widgets/document_upload_flow.dart';

class MemberDetailScreen extends StatefulWidget {
  final MemberModel member;
  const MemberDetailScreen({super.key, required this.member});

  @override
  State<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends State<MemberDetailScreen>
    with SingleTickerProviderStateMixin {
  final _fs         = FirestoreService();
  final _cloudinary = CloudinaryService();
  final _lotService = LotService();
  late TabController _tabs;
  bool _editMode = false;
  bool _saving   = false;

  late String _photoUrl;

  late TextEditingController _name;
  late TextEditingController _email;
  late TextEditingController _lot;
  late TextEditingController _contact;
  late TextEditingController _address;
  late MemberStatus _status;

  static const Color _navy   = Color(0xFF0D2A5C);
  static const Color _accent = Color(0xFF2E6BE6);
  static const Color _bg     = Color(0xFFF0F4FB);

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    _photoUrl = widget.member.photoUrl;
    _initControllers(widget.member);
  }

  void _initControllers(MemberModel m) {
    _name    = TextEditingController(text: m.name);
    _email   = TextEditingController(text: m.email);
    _lot     = TextEditingController(text: m.lotNumber);
    _contact = TextEditingController(text: m.contactNumber);
    _address = TextEditingController(text: m.address);
    _status  = m.status;
  }

  @override
  void dispose() {
    _tabs.dispose();
    _name.dispose(); _email.dispose(); _lot.dispose();
    _contact.dispose(); _address.dispose();
    super.dispose();
  }

  Future<void> _sendPasswordReset(
      BuildContext context) async {
    final email = widget.member.email;
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'No email address found for this member.')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        title: const Text('Reset Password',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0D2A5C))),
        content: Text(
          'Send a password reset email to:\n$email',
          style: const TextStyle(fontSize: 13.5),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(context, false),
            child: const Text('Cancel',
                style:
                    TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  const Color(0xFF0D2A5C),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(8)),
            ),
            child: const Text('Send Reset Email'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseAuth.instance
          .sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Password reset email sent to $email'),
            backgroundColor:
                const Color(0xFF1A7A4A),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to send reset email: ${e.message}'),
            backgroundColor:
                const Color(0xFFCC2200),
          ),
        );
      }
    }
  }

  Future<void> _saveEdits() async {
    setState(() => _saving = true);
    try {
      final updated = widget.member.copyWith(
        name:          _name.text.trim(),
        email:         _email.text.trim(),
        lotNumber:     _lot.text.trim(),
        contactNumber: _contact.text.trim(),
        address:       _address.text.trim(),
        status:        _status,
      );
      await _fs.updateMember(updated);
      setState(() { _editMode = false; _saving = false; });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Member updated successfully.'),
            backgroundColor: Color(0xFF1A7A4A),
          ),
        );
      }
    } catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')));
    }
  }

  // ── Open a specific lot on the subdivision map ──────────────────────────
  // Takes the lot directly (from the already-loaded owned-lots list) so
  // there's no need for a separate Firestore lookup like before.
  Future<void> _viewLotOnMap(LotModel lot) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LocationMappingScreen(
          targetLotId: lot.id,
        ),
      ),
    );
  }

  Future<void> _changePhoto({
    required void Function(double progress) onProgress,
    required void Function(bool uploading) onUploadingChanged,
  }) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    if (file.bytes == null || file.bytes!.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not read image file.')),
        );
      }
      return;
    }

    onUploadingChanged(true);
    try {
      final url = await _cloudinary.uploadFile(
        fileBytes: file.bytes!,
        fileName:  file.name,
        memberId:  widget.member.uid,
        mimeType:  documentMimeType(file.extension ?? ''),
        onProgress: onProgress,
      );

      await _fs.updateMemberPhoto(widget.member.uid, url);

      final auth = context.read<AuthProvider>();
      await SettingsService().logAction(
        performedBy:      auth.userModel?.uid ?? '',
        performedByName:  auth.userModel?.displayName ?? '',
        action:           AuditAction.updated,
        targetCollection: 'users',
        targetId:         widget.member.uid,
        description:      'Updated profile photo for ${widget.member.name}',
      );

      if (mounted) {
        setState(() => _photoUrl = url);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile photo updated.'),
            backgroundColor: Color(0xFF1A7A4A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photo upload failed: $e')),
        );
      }
    } finally {
      onUploadingChanged(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth    = context.watch<AuthProvider>();
    final canEdit = auth.isAdmin || auth.isOfficer;

    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: _navy),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.member.name,
          style: const TextStyle(
              color: _navy, fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          if (canEdit && !_editMode) ...[
            TextButton.icon(
              onPressed: () => _sendPasswordReset(context),
              icon: const Icon(Icons.lock_reset_outlined,
                  size: 16, color: _accent),
              label: const Text('Reset Password',
                  style: TextStyle(
                      color: _accent,
                      fontWeight: FontWeight.w600)),
            ),
            TextButton.icon(
              onPressed: () =>
                  setState(() => _editMode = true),
              icon: const Icon(Icons.edit_outlined,
                  size: 16, color: _accent),
              label: const Text('Edit',
                  style: TextStyle(
                      color: _accent,
                      fontWeight: FontWeight.w600)),
            ),
          ],
          if (_editMode) ...[
            TextButton(
              onPressed: () => setState(() {
                _editMode = false;
                _initControllers(widget.member);
              }),
              child: const Text('Cancel',
                  style: TextStyle(color: Colors.grey)),
            ),
            Padding(
              padding:
                  const EdgeInsets.only(right: 12),
              child: ElevatedButton(
                onPressed:
                    _saving ? null : _saveEdits,
                style: ElevatedButton.styleFrom(
                    backgroundColor: _navy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                                8)),
                    padding:
                        const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 10)),
                child: _saving
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child:
                            CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white))
                    : const Text('Save'),
              ),
            ),
          ],
        ],
        bottom: TabBar(
          controller: _tabs,
          labelColor: _navy,
          unselectedLabelColor: Colors.grey,
          indicatorColor: _accent,
          labelStyle: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 13.5),
          tabs: const [
            Tab(text: 'Profile'),
            Tab(text: 'Payments'),
            Tab(text: 'Documents'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _ProfileTab(
            member: widget.member,
            photoUrl: _photoUrl,
            editMode: _editMode,
            canEditPhoto: canEdit,
            lotService: _lotService,
            name: _name, email: _email, lot: _lot,
            contact: _contact, address: _address,
            status: _status,
            onStatusChanged: (v) => setState(() => _status = v),
            onViewLot: _viewLotOnMap,
            onChangePhoto: _changePhoto,
          ),
          _PaymentsTab(memberId: widget.member.uid, memberName: widget.member.name, auth: auth),
          _DocumentsTab(memberId: widget.member.uid, memberName: widget.member.name, auth: auth),
        ],
      ),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  final MemberModel member;
  final String photoUrl;
  final bool editMode;
  final bool canEditPhoto;
  final LotService lotService;
  final TextEditingController name, email, lot, contact, address;
  final MemberStatus status;
  final void Function(MemberStatus) onStatusChanged;
  final Future<void> Function(LotModel lot) onViewLot;
  final Future<void> Function({
    required void Function(double progress) onProgress,
    required void Function(bool uploading) onUploadingChanged,
  }) onChangePhoto;

  static const Color _navy = Color(0xFF0D2A5C);

  const _ProfileTab({
    required this.member, required this.photoUrl, required this.editMode,
    required this.canEditPhoto, required this.lotService,
    required this.name, required this.email,
    required this.lot, required this.contact, required this.address,
    required this.status,
    required this.onStatusChanged,
    required this.onViewLot, required this.onChangePhoto,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: StreamBuilder<List<LotModel>>(
        stream: lotService.streamLotsForMember(member.uid),
        builder: (context, lotSnap) {
          final ownedLots = lotSnap.data ?? const <LotModel>[];

          return LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 760;

              final sidebar = _ProfileSidebarCard(
                member: member,
                photoUrl: photoUrl,
                canEditPhoto: canEditPhoto,
                ownedLots: ownedLots,
                onViewLot: onViewLot,
                onChangePhoto: onChangePhoto,
              );

              final infoCard = _MemberInfoCard(
                editMode: editMode,
                name: name, email: email, lot: lot,
                contact: contact, address: address,
                status: status,
                memberStatusLabel: member.status.label,
                onStatusChanged: onStatusChanged,
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    sidebar,
                    const SizedBox(height: 20),
                    infoCard,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: 300, child: sidebar),
                  const SizedBox(width: 20),
                  Expanded(child: infoCard),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _ProfileSidebarCard extends StatefulWidget {
  final MemberModel member;
  final String photoUrl;
  final bool canEditPhoto;
  final List<LotModel> ownedLots;
  final Future<void> Function(LotModel lot) onViewLot;
  final Future<void> Function({
    required void Function(double progress) onProgress,
    required void Function(bool uploading) onUploadingChanged,
  }) onChangePhoto;

  const _ProfileSidebarCard({
    required this.member,
    required this.photoUrl,
    required this.canEditPhoto,
    required this.ownedLots,
    required this.onViewLot,
    required this.onChangePhoto,
  });

  @override
  State<_ProfileSidebarCard> createState() => _ProfileSidebarCardState();
}

class _ProfileSidebarCardState extends State<_ProfileSidebarCard> {
  bool _uploading = false;
  double _progress = 0;

  static const Color _navy = Color(0xFF0D2A5C);

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final member = widget.member;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E8F4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 52,
                backgroundColor:
                    const Color(0xFF2E6BE6).withOpacity(0.12),
                backgroundImage: widget.photoUrl.isNotEmpty
                    ? NetworkImage(widget.photoUrl)
                    : null,
                child: widget.photoUrl.isEmpty
                    ? Text(
                        member.name.isNotEmpty
                            ? member.name[0].toUpperCase()
                            : '?',
                        style: const TextStyle(
                            fontSize: 34,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF2E6BE6)),
                      )
                    : null,
              ),
              if (_uploading)
                Positioned.fill(
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black45,
                    ),
                    child: Center(
                      child: SizedBox(
                        width: 34,
                        height: 34,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          value: _progress > 0 ? _progress : null,
                          valueColor:
                              const AlwaysStoppedAnimation(Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              if (widget.canEditPhoto && !_uploading)
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () => widget.onChangePhoto(
                      onProgress: (p) => setState(() => _progress = p),
                      onUploadingChanged: (u) => setState(() {
                        _uploading = u;
                        if (!u) _progress = 0;
                      }),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2E6BE6),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.camera_alt,
                          size: 14, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),

          Text(member.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: _navy)),
          const SizedBox(height: 4),
          Text(member.email,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[600])),
          const SizedBox(height: 10),
          _StatusBadge(status: member.status),

          const SizedBox(height: 20),
          const Divider(color: Color(0xFFE0E8F4)),
          const SizedBox(height: 16),

          // ── Owned Lots ─────────────────────────────────────────────────
          Row(
            children: [
              Text('Owned Lots',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[600])),
              const Spacer(),
              if (widget.ownedLots.isNotEmpty)
                Text('${widget.ownedLots.length}',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[500])),
            ],
          ),
          const SizedBox(height: 10),

          if (widget.ownedLots.isEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: Text('No lots assigned.',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey[400])),
            )
          else
            Column(
              children: widget.ownedLots
                  .map((lot) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _OwnedLotTile(
                          lot: lot,
                          onTap: () => widget.onViewLot(lot),
                        ),
                      ))
                  .toList(),
            ),

          const SizedBox(height: 10),
          _SidebarRow(label: 'Member since', value: _fmt(member.createdAt)),
        ],
      ),
    );
  }
}

// ── One owned-lot row (e.g. "Block 1 • Lot 1") ────────────────────────────
class _OwnedLotTile extends StatelessWidget {
  final LotModel lot;
  final VoidCallback onTap;

  const _OwnedLotTile({required this.lot, required this.onTap});

  static const Color _navy = Color(0xFF0D2A5C);

  @override
  Widget build(BuildContext context) {
    final block = lot.block.isEmpty ? '—' : lot.block;
    final lotNo = lot.lotNumber.isEmpty ? '—' : lot.lotNumber;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF0F4FB),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD0DBEE)),
        ),
        child: Row(
          children: [
            const Icon(Icons.location_on_outlined,
                size: 15, color: Color(0xFF2E6BE6)),
            const SizedBox(width: 8),
            Expanded(
              child: Text('Block $block • Lot $lotNo',
                  style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _navy),
                  overflow: TextOverflow.ellipsis),
            ),
            Icon(Icons.chevron_right, size: 16, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}

class _SidebarRow extends StatelessWidget {
  final String label;
  final String value;
  const _SidebarRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label,
          style: TextStyle(fontSize: 12.5, color: Colors.grey[500])),
      Flexible(
        child: Text(value.isEmpty ? '—' : value,
            textAlign: TextAlign.end,
            style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1A2B4A)),
            overflow: TextOverflow.ellipsis),
      ),
    ],
  );
}

// ── Member information card (edit form) ─────────────────────────────────────
class _MemberInfoCard extends StatelessWidget {
  final bool editMode;
  final TextEditingController name, email, lot, contact, address;
  final MemberStatus status;
  final String memberStatusLabel;
  final void Function(MemberStatus) onStatusChanged;

  static const Color _navy = Color(0xFF0D2A5C);

  const _MemberInfoCard({
    required this.editMode,
    required this.name, required this.email,
    required this.lot, required this.contact, required this.address,
    required this.status,
    required this.memberStatusLabel,
    required this.onStatusChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E8F4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Member Information',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _navy)),
          const SizedBox(height: 4),
          Text(
            'Lot ownership is managed from Location Mapping — '
            'see "Owned Lots" on the left.',
            style: TextStyle(fontSize: 11.5, color: Colors.grey[500]),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: _DetailField(
                label: 'Full Name', controller: name,
                readOnly: !editMode)),
            const SizedBox(width: 16),
            Expanded(child: _DetailField(
                label: 'Email Address', controller: email,
                readOnly: !editMode)),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _DetailField(
                label: 'Contact Number', controller: contact,
                readOnly: !editMode)),
            const SizedBox(width: 16),
            Expanded(
              child: editMode
                  ? _DropdownField<MemberStatus>(
                      label: 'Status',
                      value: status,
                      items: MemberStatus.values,
                      labelOf: (v) => v.label,
                      onChanged: onStatusChanged,
                    )
                  : _ReadOnlyField(
                      label: 'Status', value: memberStatusLabel),
            ),
          ]),
          const SizedBox(height: 16),
          _DetailField(
              label: 'Address', controller: address,
              readOnly: !editMode, maxLines: 2),
        ],
      ),
    );
  }
}

class _PaymentsTab extends StatelessWidget {
  final String memberId;
  final String memberName;
  final AuthProvider auth;
  final _fs = FirestoreService();

  _PaymentsTab({
    required this.memberId,
    required this.memberName,
    required this.auth,
  });

  static const Color _navy = Color(0xFF0D2A5C);

  @override
  Widget build(BuildContext context) {
    final canRecord = auth.isAdmin || auth.isAccountant;

    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Payment History',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _navy)),
              const Spacer(),
              if (canRecord)
                ElevatedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddPaymentScreen(
                        preselectedMemberId: memberId,
                        preselectedMemberName: memberName,
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('Add Payment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _navy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<PaymentModel>>(
              stream: _fs.streamPaymentsForMember(memberId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final payments = snap.data ?? [];
                if (payments.isEmpty) {
                  return const Center(
                      child: Text('No payment records found.',
                          style: TextStyle(color: Colors.grey)));
                }
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE0E8F4)),
                  ),
                  child: ListView.separated(
                    itemCount: payments.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, color: Color(0xFFEEF2F9)),
                    itemBuilder: (_, i) =>
                        _PaymentRow(payment: payments[i], fs: _fs),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentsTab extends StatelessWidget {
  final String memberId;
  final String memberName;
  final AuthProvider auth;
  final _fs         = FirestoreService();
  final _cloudinary = CloudinaryService();

  _DocumentsTab({
    required this.memberId,
    required this.memberName,
    required this.auth,
  });

  static const Color _navy = Color(0xFF0D2A5C);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Documents',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: _navy)),
              const Spacer(),
              if (auth.isAdmin || auth.isOfficer)
                ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      final success = await runDocumentUploadFlow(
                        context: context,
                        fs: _fs,
                        cloudinary: _cloudinary,
                        uploadedByUid: auth.userModel?.uid ?? '',
                        uploadedByName:
                            auth.userModel?.displayName ?? '',
                        preselectedMemberId: memberId,
                        preselectedMemberName: memberName,
                      );
                      if (success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content:
                                Text('Document uploaded successfully.'),
                            backgroundColor: Color(0xFF1A7A4A),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Upload failed: $e')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.upload_file_outlined, size: 16),
                  label: const Text('Upload Document'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _navy,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<DocumentModel>>(
              stream: _fs.streamDocumentsForMember(memberId),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data ?? [];
                if (docs.isEmpty) {
                  return const Center(
                      child: Text('No documents uploaded yet.',
                          style: TextStyle(color: Colors.grey)));
                }
                return GridView.builder(
                  gridDelegate:
                      const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 220,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 1.1,
                  ),
                  itemCount: docs.length,
                  itemBuilder: (_, i) => _DocCard(
                    doc:        docs[i],
                    fs:         _fs,
                    cloudinary: _cloudinary,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final MemberStatus status;
  const _StatusBadge({required this.status});

  Color get _fg {
    switch (status) {
      case MemberStatus.active:     return const Color(0xFF1A7A4A);
      case MemberStatus.inactive:   return const Color(0xFF7A6A1A);
      case MemberStatus.delinquent: return const Color(0xFFCC2200);
    }
  }

  Color get _bg {
    switch (status) {
      case MemberStatus.active:     return const Color(0xFFEAF7F0);
      case MemberStatus.inactive:   return const Color(0xFFFFF8E0);
      case MemberStatus.delinquent: return const Color(0xFFFFF0EE);
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
        color: _bg, borderRadius: BorderRadius.circular(20)),
    child: Text(status.label,
        style: TextStyle(
            fontSize: 11.5, fontWeight: FontWeight.w600, color: _fg)),
  );
}

class _DetailField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool readOnly;
  final int maxLines;
  static const Color _navy = Color(0xFF0D2A5C);

  const _DetailField({
    required this.label,
    required this.controller,
    this.readOnly = true,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(
          fontSize: 11.5, fontWeight: FontWeight.w600,
          color: Color(0xFF5A7099))),
      const SizedBox(height: 5),
      TextFormField(
        controller: controller,
        readOnly: readOnly,
        maxLines: maxLines,
        style: const TextStyle(fontSize: 13.5, color: Color(0xFF1A2B4A)),
        decoration: InputDecoration(
          filled: true,
          fillColor: readOnly
              ? const Color(0xFFF7F9FC)
              : Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD0DBEE))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD0DBEE))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                  color: Color(0xFF2E6BE6), width: 1.5)),
          disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE8EDF5))),
        ),
      ),
    ],
  );
}

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;
  const _ReadOnlyField({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(
          fontSize: 11.5, fontWeight: FontWeight.w600,
          color: Color(0xFF5A7099))),
      const SizedBox(height: 5),
      Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F9FC),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFD0DBEE)),
        ),
        child: Text(value,
            style: const TextStyle(
                fontSize: 13.5, color: Color(0xFF1A2B4A))),
      ),
    ],
  );
}

class _DropdownField<T> extends StatelessWidget {
  final String label;
  final T value;
  final List<T> items;
  final String Function(T) labelOf;
  final void Function(T) onChanged;

  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.labelOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(
          fontSize: 11.5, fontWeight: FontWeight.w600,
          color: Color(0xFF5A7099))),
      const SizedBox(height: 5),
      DropdownButtonFormField<T>(
        value: value,
        style: const TextStyle(fontSize: 13.5, color: Color(0xFF1A2B4A)),
        decoration: InputDecoration(
          filled: true, fillColor: Colors.white,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD0DBEE))),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFD0DBEE))),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(
                  color: Color(0xFF2E6BE6), width: 1.5)),
        ),
        items: items
            .map((i) => DropdownMenuItem<T>(
                value: i, child: Text(labelOf(i))))
            .toList(),
        onChanged: (v) { if (v != null) onChanged(v); },
      ),
    ],
  );
}

class _PaymentRow extends StatelessWidget {
  final PaymentModel payment;
  final FirestoreService fs;
  const _PaymentRow({required this.payment, required this.fs});

  Color _statusColor(PaymentStatus s) {
    switch (s) {
      case PaymentStatus.paid:    return const Color(0xFF1A7A4A);
      case PaymentStatus.unpaid:  return const Color(0xFF7A6A1A);
      case PaymentStatus.overdue: return const Color(0xFFCC2200);
      case PaymentStatus.waived:  return const Color(0xFF5A7099);
    }
  }

  Color _statusBg(PaymentStatus s) {
    switch (s) {
      case PaymentStatus.paid:    return const Color(0xFFEAF7F0);
      case PaymentStatus.unpaid:  return const Color(0xFFFFF8E0);
      case PaymentStatus.overdue: return const Color(0xFFFFF0EE);
      case PaymentStatus.waived:  return const Color(0xFFF0F4FB);
    }
  }

  String _fmt(DateTime? d) => d == null ? '—' :
      '${d.day.toString().padLeft(2,'0')}/${d.month.toString().padLeft(2,'0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(payment.type.label,
              style: const TextStyle(fontSize: 13.5,
                  fontWeight: FontWeight.w500, color: Color(0xFF0D2A5C)))),
          Expanded(flex: 2, child: Text(
              '₱${payment.amount.toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 13.5, color: Color(0xFF1A2B4A)))),
          Expanded(flex: 2, child: Text(_fmt(payment.dueDate),
              style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
          Expanded(flex: 2, child: Text(_fmt(payment.paidDate),
              style: TextStyle(fontSize: 13, color: Colors.grey[600]))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _statusBg(payment.status),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(payment.status.label,
                style: TextStyle(fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: _statusColor(payment.status))),
          ),
          if (payment.status == PaymentStatus.unpaid ||
              payment.status == PaymentStatus.overdue) ...[
            const SizedBox(width: 10),
            TextButton(
              onPressed: () async {
                await fs.markPaymentPaid(payment.id);

                if (context.mounted) {
                  final auth =
                      Provider.of<AuthProvider>(context, listen: false);
                  await SettingsService().logAction(
                    performedBy:      auth.userModel?.uid ?? '',
                    performedByName:  auth.userModel?.displayName ?? '',
                    action:           AuditAction.updated,
                    targetCollection: 'payments',
                    targetId:         payment.id,
                    description:
                        'Marked payment for ${payment.memberName} as paid',
                  );
                }
              },
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF1A7A4A)),
              child: const Text('Mark Paid',
                  style: TextStyle(fontSize: 12)),
            ),
          ],
        ],
      ),
    );
  }
}

class _DocCard extends StatelessWidget {
  final DocumentModel doc;
  final FirestoreService fs;
  final CloudinaryService cloudinary;
  const _DocCard({
    required this.doc,
    required this.fs,
    required this.cloudinary,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE0E8F4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2E6BE6).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.insert_drive_file_outlined,
                    size: 20, color: Color(0xFF2E6BE6)),
              ),
              const Spacer(),
              InkWell(
                onTap: () async {
                  await cloudinary.deleteFile(doc.fileUrl);
                  await fs.deleteDocumentMetadata(doc.id);

                  if (context.mounted) {
                    final auth =
                        Provider.of<AuthProvider>(context, listen: false);
                    await SettingsService().logAction(
                      performedBy:      auth.userModel?.uid ?? '',
                      performedByName:  auth.userModel?.displayName ?? '',
                      action:           AuditAction.deleted,
                      targetCollection: 'documents',
                      targetId:         doc.id,
                      description:
                          'Deleted document "${doc.fileName}" '
                          'for ${doc.memberName}',
                    );
                  }
                },
                child: const Icon(Icons.delete_outline,
                    size: 18, color: Colors.grey),
              ),
            ],
          ),
          const Spacer(),
          Text(doc.type.label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF5A7099))),
          const SizedBox(height: 4),
          Text(doc.fileName,
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF1A2B4A)),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}