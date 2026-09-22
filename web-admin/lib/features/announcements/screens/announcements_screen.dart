// features/announcements/screens/announcements_screen.dart
// UPDATED Phase 5 — sends FCM push notification when announcement is posted

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/announcement_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/notification_service.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_router.dart';

class AnnouncementsScreen extends StatelessWidget {
  const AnnouncementsScreen({super.key});

  static const Color _navy   = Color(0xFF1E293B);
  static const Color _accent = Color(0xFF2563EB);
  static const Color _bg     = Color(0xFFF4F7FB);

  @override
  Widget build(BuildContext context) {
    final auth     = context.watch<AuthProvider>();
    final _fs      = FirestoreService();
    final _notif   = NotificationService();
    final canPost  = auth.isAdmin || auth.isOfficer;
    final phoneScreen = MediaQuery.of(context).size.width < 560;

    return Scaffold(
      backgroundColor: _bg,
      body: Padding(
        padding: EdgeInsets.fromLTRB(
            phoneScreen ? 16 : 28,
            phoneScreen ? 14 : 28,
            phoneScreen ? 16 : 28,
            phoneScreen ? 16 : 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
LayoutBuilder(
  builder: (context, constraints) {
    final titleBlock = Row(
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_back, color: _navy),
          tooltip: 'Back to Dashboard',
          onPressed: () => context.go(AppRoutes.dashboard),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Announcements',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: _navy)),
              const SizedBox(height: 2),
              Text(
                  'Post notices visible to all homeowners',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600])),
            ],
          ),
        ),
      ],
    );

    final postButton = canPost
        ? ElevatedButton.icon(
            onPressed: () => _showPostDialog(
                context, _fs, _notif, auth),
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Post Announcement'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _navy,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(8)),
            ),
          )
        : null;

    // The title block plus the button's label don't both fit on one
    // line below this width — stack the button under the title instead.
    final narrow = constraints.maxWidth < 560;

    if (narrow) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleBlock,
          if (postButton != null) ...[
            const SizedBox(height: 12),
            SizedBox(
                width: double.infinity, child: postButton),
          ],
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: titleBlock),
        if (postButton != null) postButton,
      ],
    );
  },
),
            SizedBox(height: phoneScreen ? 14 : 24),

            Expanded(
              child: StreamBuilder<List<AnnouncementModel>>(
                stream: _fs.streamAnnouncements(),
                builder: (context, snap) {
                  if (snap.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }

                  final items = snap.data ?? [];

                  if (items.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.campaign_outlined,
                              size: 52,
                              color: Colors.grey[300]),
                          const SizedBox(height: 14),
                          Text('No announcements yet.',
                              style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500])),
                          if (canPost) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Click "Post Announcement" to create one.',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[400]),
                            ),
                          ],
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: 12),
                    itemBuilder: (_, i) => _AnnouncementCard(
                      announcement: items[i],
                      canEdit:      canPost,
                      canDelete:    auth.isAdmin,
                      fs:           _fs,
                      notif:        _notif,
                      onEdit: () => _showPostDialog(
                        context, _fs, _notif, auth,
                        existing: items[i],
                      ),
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

  void _showPostDialog(
    BuildContext context,
    FirestoreService fs,
    NotificationService notif,
    AuthProvider auth, {
    AnnouncementModel? existing,
  }) {
    showDialog(
      context: context,
      builder: (_) => _PostDialog(
        fs:       fs,
        notif:    notif,
        auth:     auth,
        existing: existing,
      ),
    );
  }
}

class _AnnouncementCard extends StatelessWidget {
  final AnnouncementModel  announcement;
  final bool               canEdit;
  final bool               canDelete;
  final FirestoreService   fs;
  final NotificationService notif;
  final VoidCallback       onEdit;

  static const Color _navy = Color(0xFF1E293B);

  const _AnnouncementCard({
    required this.announcement,
    required this.canEdit,
    required this.canDelete,
    required this.fs,
    required this.notif,
    required this.onEdit,
  });

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, cardConstraints) {
        final compact = cardConstraints.maxWidth < 500;

        return Container(
      padding: EdgeInsets.all(compact ? 14 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: announcement.isActive
              ? const Color(0xFFE0E8F4)
              : const Color(0xFFEEEEEE),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1A4A9C).withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final dot = Container(
                width: 8, height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: announcement.isActive
                      ? const Color(0xFF1A7A4A)
                      : Colors.grey[400],
                ),
              );

              final title = Text(announcement.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: announcement.isActive
                          ? _navy
                          : Colors.grey[500]));

              final statusBadge = Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: announcement.isActive
                      ? const Color(0xFFEAF7F0)
                      : const Color(0xFFF4F7FB),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  announcement.isActive
                      ? 'Active'
                      : 'Inactive',
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: announcement.isActive
                          ? const Color(0xFF1A7A4A)
                          : Colors.grey),
                ),
              );

              // Up to four full-size icon buttons (~48px each) plus the
              // badge don't leave enough room for the title below this
              // width — collapse the actions into a single overflow menu.
              final narrow = constraints.maxWidth < 420;

              if (narrow) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    dot,
                    const SizedBox(width: 10),
                    Expanded(child: title),
                    const SizedBox(width: 8),
                    statusBadge,
                    if (canEdit || canDelete)
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert,
                            size: 18,
                            color: Colors.grey[600]),
                        padding: EdgeInsets.zero,
                        onSelected: (v) {
                          switch (v) {
                            case 'toggle':
                              fs.toggleAnnouncementActive(
                                  announcement.id,
                                  !announcement.isActive);
                              break;
                            case 'edit':
                              onEdit();
                              break;
                            case 'resend':
                              _resendNotification(context);
                              break;
                            case 'delete':
                              _confirmDelete(context);
                              break;
                          }
                        },
                        itemBuilder: (_) => [
                          if (canEdit) ...[
                            PopupMenuItem(
                              value: 'toggle',
                              child: Text(announcement.isActive
                                  ? 'Deactivate'
                                  : 'Activate'),
                            ),
                            const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit')),
                            const PopupMenuItem(
                                value: 'resend',
                                child: Text(
                                    'Resend notification')),
                          ],
                          if (canDelete)
                            const PopupMenuItem(
                                value: 'delete',
                                child: Text('Delete')),
                        ],
                      ),
                  ],
                );
              }

              return Row(
                children: [
                  dot,
                  const SizedBox(width: 10),
                  Expanded(child: title),
                  statusBadge,
                  if (canEdit) ...[
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        announcement.isActive
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18, color: Colors.grey[500],
                      ),
                      tooltip: announcement.isActive
                          ? 'Deactivate'
                          : 'Activate',
                      onPressed: () =>
                          fs.toggleAnnouncementActive(
                              announcement.id,
                              !announcement.isActive),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined,
                          size: 18, color: Color(0xFF2563EB)),
                      tooltip: 'Edit',
                      onPressed: onEdit,
                    ),
                    IconButton(
                      icon: const Icon(
                          Icons.notifications_outlined,
                          size: 18, color: Color(0xFF2563EB)),
                      tooltip: 'Resend notification',
                      onPressed: () =>
                          _resendNotification(context),
                    ),
                  ],
                  if (canDelete)
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          size: 18, color: Color(0xFFCC2200)),
                      tooltip: 'Delete',
                      onPressed: () => _confirmDelete(context),
                    ),
                ],
              );
            },
          ),
          SizedBox(height: compact ? 6 : 10),
          Text(announcement.body,
              style: TextStyle(
                  fontSize: compact ? 13 : 13.5,
                  color: announcement.isActive
                      ? const Color(0xFF1A2B4A)
                      : Colors.grey[400],
                  height: 1.5)),
          SizedBox(height: compact ? 8 : 12),
          Row(
            children: [
              Icon(Icons.person_outline,
                  size: 13, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(announcement.postedByName,
                  style: TextStyle(
                      fontSize: compact ? 11 : 12,
                      color: Colors.grey[500])),
              SizedBox(width: compact ? 10 : 14),
              Icon(Icons.calendar_today_outlined,
                  size: 13, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(_fmt(announcement.createdAt),
                  style: TextStyle(
                      fontSize: compact ? 11 : 12,
                      color: Colors.grey[500])),
            ],
          ),
        ],
      ),
    );
      },
    );
  }

  Future<void> _resendNotification(
      BuildContext context) async {
    final result = await notif.sendAnnouncementToAll(
      announcementId: announcement.id,
      title:          announcement.title,
      body:           announcement.body,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.success
              ? 'Sent to ${result.sent} members.'
              : result.message),
          backgroundColor: result.success
              ? const Color(0xFF1A7A4A)
              : const Color(0xFFCC2200),
        ),
      );
    }
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        title: const Text('Delete Announcement',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B))),
        content: Text(
            'Delete "${announcement.title}"? '
            'This cannot be undone.',
            style: const TextStyle(fontSize: 13.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogCtx, true),
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
      await fs.deleteAnnouncement(announcement.id);
    }
  }
}

class _PostDialog extends StatefulWidget {
  final FirestoreService    fs;
  final NotificationService notif;
  final AuthProvider        auth;
  final AnnouncementModel?  existing;

  const _PostDialog({
    required this.fs,
    required this.notif,
    required this.auth,
    this.existing,
  });

  @override
  State<_PostDialog> createState() => _PostDialogState();
}

class _PostDialogState extends State<_PostDialog> {
  late TextEditingController _title;
  late TextEditingController _body;
  bool _sendPush = true;
  bool _loading  = false;
  int  _tokenCount = 0;

  static const Color _navy = Color(0xFF1E293B);

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(
        text: widget.existing?.title ?? '');
    _body  = TextEditingController(
        text: widget.existing?.body ?? '');
    _loadTokenCount();
  }

  Future<void> _loadTokenCount() async {
    final count =
        await widget.notif.getMemberTokenCount();
    if (mounted) setState(() => _tokenCount = count);
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty ||
        _body.text.trim().isEmpty) return;
    setState(() => _loading = true);

    try {
      String announcementId;

      if (_isEdit) {
        await widget.fs.updateAnnouncement(
          widget.existing!.id,
          _title.text.trim(),
          _body.text.trim(),
        );
        announcementId = widget.existing!.id;
      } else {
        final ref = FirestoreService()
            .db
            .collection('announcements')
            .doc();
        announcementId = ref.id;
        await widget.fs.addAnnouncement(AnnouncementModel(
          id:           announcementId,
          title:        _title.text.trim(),
          body:         _body.text.trim(),
          postedBy:     widget.auth.userModel?.uid ?? '',
          postedByName:
              widget.auth.userModel?.displayName ?? '',
          isActive:  true,
          createdAt: DateTime.now(),
        ));
      }

      if (_sendPush && mounted) {
        final result =
            await widget.notif.sendAnnouncementToAll(
          announcementId: announcementId,
          title:          _title.text.trim(),
          body:           _body.text.trim(),
        );
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result.success
                  ? '${_isEdit ? 'Updated' : 'Posted'}. Sent to ${result.sent} members.'
                  : '${_isEdit ? 'Updated' : 'Posted'}. Notification failed: ${result.message}'),
              backgroundColor: result.success
                  ? const Color(0xFF1A7A4A)
                  : const Color(0xFF7A6A1A),
            ),
          );
        }
      } else {
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle:
        TextStyle(fontSize: 13, color: Colors.grey[400]),
    filled: true,
    fillColor: const Color(0xFFF7F9FC),
    contentPadding: const EdgeInsets.symmetric(
        horizontal: 14, vertical: 13),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:
            const BorderSide(color: Color(0xFFD0DBEE))),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide:
            const BorderSide(color: Color(0xFFD0DBEE))),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
            color: Color(0xFF2563EB), width: 1.5)),
  );

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth =
        screenSize.width > 580 ? 520.0 : screenSize.width * 0.92;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: dialogWidth,
          maxHeight: screenSize.height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEdit
                    ? 'Edit Announcement'
                    : 'Post Announcement',
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: _navy),
              ),
              const SizedBox(height: 20),

              const Text('Title',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _navy)),
              const SizedBox(height: 6),
              TextField(
                controller: _title,
                style: const TextStyle(fontSize: 13.5),
                decoration:
                    _dec('e.g. Monthly Dues Reminder'),
              ),
              const SizedBox(height: 16),

              const Text('Message',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: _navy)),
              const SizedBox(height: 6),
              TextField(
                controller: _body,
                maxLines: 4,
                style: const TextStyle(fontSize: 13.5),
                decoration:
                    _dec('Write your announcement here...'),
              ),
              const SizedBox(height: 16),

              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F4FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF2563EB)
                          .withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(
                        Icons.notifications_outlined,
                        size: 18,
                        color: Color(0xFF2563EB)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Send push notification',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A4A9C)),
                          ),
                          Text(
                            '$_tokenCount members will be notified',
                            style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: _sendPush,
                      activeColor: const Color(0xFF1A4A9C),
                      onChanged: (v) =>
                          setState(() => _sendPush = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              Row(
                mainAxisAlignment:
                    MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () =>
                        Navigator.pop(context),
                    child: const Text('Cancel',
                        style: TextStyle(
                            color: Colors.grey)),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed:
                        _loading ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(8)),
                      padding:
                          const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12),
                    ),
                    child: _loading
                        ? const SizedBox(
                            width: 16, height: 16,
                            child:
                                CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white))
                        : Text(_isEdit
                            ? 'Save'
                            : 'Post'),
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