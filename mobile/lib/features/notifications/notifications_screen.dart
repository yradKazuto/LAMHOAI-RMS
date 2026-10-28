// lib/features/notifications/notifications_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_header.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _filter = 'All';
  final Set<String> _locallyRead = {};

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final uid  = auth.user?.uid ?? '';

    // If uid is empty don't even try to query
    if (uid.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Column(
          children: [
            _buildHeader(context),
            const Expanded(child: Center(child: CircularProgressIndicator())),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              // Key forces stream to rebuild when uid changes
              key: ValueKey(uid),
              stream: FirebaseFirestore.instance
                  .collection('notifications')
                  .where('uid', isEqualTo: uid)
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snap.hasError) {
                  return _buildError(snap.error.toString());
                }

                final docs = snap.data?.docs ?? [];
                final all  = docs.map((d) {
                  final data   = d.data() as Map<String, dynamic>;
                  final fsRead = data['isRead'] as bool? ?? false;
                  final isRead = fsRead || _locallyRead.contains(d.id);
                  return _NotifItem(
                    id:        d.id,
                    title:     data['title']     as String? ?? '',
                    body:      data['body']      as String? ?? '',
                    type:      data['type']      as String? ?? 'general',
                    isRead:    isRead,
                    createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
                  );
                }).toList();

                final filtered = _filter == 'Unread'
                    ? all.where((n) => !n.isRead).toList()
                    : _filter == 'Read'
                        ? all.where((n) => n.isRead).toList()
                        : all;

                final unreadCount = all.where((n) => !n.isRead).length;

                return Column(
                  children: [
                    _buildFilterRow(unreadCount),
                    Expanded(
                      child: filtered.isEmpty
                          ? _buildEmpty()
                          : _buildList(filtered),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return AppHeader(
      title: 'Notifications',
      subtitle: 'HOA announcements and dues reminders',
      onBack: () => context.canPop() ? context.pop() : context.go('/home'),
      trailing: TextButton(
        onPressed: _markAllAsRead,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          'Mark all as read',
          style: AppTypography.button.copyWith(
            fontSize: 11,
            color: AppColors.textInverted,
          ),
        ),
      ),
    );
  }

  Future<void> _markAllAsRead() async {
    final uid = context.read<AuthProvider>().user?.uid;
    if (uid == null) return;

    final batch = FirebaseFirestore.instance.batch();
    final query = await FirebaseFirestore.instance
        .collection('notifications')
        .where('uid', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .get();

    final done = <String>[];
    try {
      for (var doc in query.docs) {
        batch.update(doc.reference, {'isRead': true});
        done.add(doc.id);
      }
      await batch.commit();
    } catch (e) {
      // Roll back local state on failure so UI doesn't report success for docs
      // that weren't actually updated.
      for (final id in done) {
        setState(() {
          _locallyRead.remove(id);
        });
      }
      return;
    }
    setState(() => _locallyRead.addAll(done));
  }

  // ── Filter row ────────────────────────────────────────────────────────────

  Widget _buildFilterRow(int unreadCount) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      child: Row(
        children: ['All', 'Unread', 'Read'].map((f) {
          final active = _filter == f;
          return GestureDetector(
            onTap: () => setState(() => _filter = f),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: active ? AppColors.primary : AppColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: active ? AppColors.primary : AppColors.border,
                    width: 1.5),
              ),
              child: Row(
                children: [
                  Text(f,
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                          color: active
                              ? AppColors.textInverted
                              : AppColors.textSecondary)),
                  if (f == 'Unread' && unreadCount > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.textInverted
                            : AppColors.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text('$unreadCount',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: active
                                  ? AppColors.primary
                                  : AppColors.textInverted)),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── List ──────────────────────────────────────────────────────────────────

  Widget _buildList(List<_NotifItem> items) {
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: items.length,
      itemBuilder: (context, i) => _buildCard(items[i]),
    );
  }

  Widget _buildCard(_NotifItem item) {
    final dateFmt  = DateFormat('MMM d, yyyy · h:mm a');
    final dotColor = _dotColor(item.type);

    return AppCard(
      margin: const EdgeInsets.only(bottom: 8),
      borderColor: item.isRead ? AppColors.border : AppColors.primary,
      onTap: () => _openNotification(item),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: item.isRead ? AppColors.border : dotColor,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.title,
                        style: AppTypography.bodyMedium.copyWith(
                          fontWeight: item.isRead
                              ? FontWeight.w400
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (!item.isRead)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(8)),
                        child: Text('NEW',
                            style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textInverted)),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.body,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.body.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(_typeIcon(item.type), size: 10, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      item.createdAt != null
                          ? dateFmt.format(item.createdAt!)
                          : '—',
                      style: AppTypography.caption,
                    ),
                    const Spacer(),
                    Text('Tap to read', style: AppTypography.caption),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Open notification ─────────────────────────────────────────────────────

  void _openNotification(_NotifItem item) {
    if (!item.isRead) {
      setState(() => _locallyRead.add(item.id));
      FirebaseFirestore.instance
          .collection('notifications')
          .doc(item.id)
          .update({'isRead': true});
    }

    final dateFmt = DateFormat('MMMM d, yyyy · h:mm a');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (ctx, scrollCtrl) => SingleChildScrollView(
          controller: scrollCtrl,
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppPrimitiveColors.blue50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppPrimitiveColors.blue200),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_typeIcon(item.type),
                        size: 11, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(_typeLabel(item.type),
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppColors.primary)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Text(item.title, style: AppTypography.pageTitle),
              const SizedBox(height: 6),
              Text(
                item.createdAt != null
                    ? dateFmt.format(item.createdAt!)
                    : '—',
                style: AppTypography.caption,
              ),
              const SizedBox(height: 16),
              const Divider(color: AppColors.borderSubtle),
              const SizedBox(height: 16),
              Text(
                item.body,
                style: AppTypography.body.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(vertical: 13),
                    side: const BorderSide(
                        color: AppColors.border, width: 1.5),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Close',
                      style: AppTypography.button
                          .copyWith(color: AppColors.textSecondary)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Empty / Error ─────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    return AppEmptyState(
      icon: Icons.notifications_none_outlined,
      message: _filter == 'All'
          ? 'No notifications yet.'
          : 'No ${_filter.toLowerCase()} notifications.',
    );
  }

  Widget _buildError(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 36, color: AppColors.error),
            const SizedBox(height: 12),
            Text(msg,
                textAlign: TextAlign.center,
                style: AppTypography.body.copyWith(color: AppColors.error)),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Color _dotColor(String type) {
    switch (type) {
      case 'dues':         return AppColors.primary;
      case 'announcement': return AppPrimitiveColors.gold;
      case 'complaint':    return AppColors.success;
      default:             return AppColors.textMuted;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'dues':         return Icons.receipt_long_outlined;
      case 'announcement': return Icons.campaign_outlined;
      case 'complaint':    return Icons.feedback_outlined;
      default:             return Icons.notifications_none_outlined;
    }
  }

  String _typeLabel(String type) {
    switch (type) {
      case 'dues':         return 'Dues Reminder';
      case 'announcement': return 'Announcement';
      case 'complaint':    return 'Complaint Update';
      default:             return 'Notification';
    }
  }
}

class _NotifItem {
  final String    id, title, body, type;
  final bool      isRead;
  final DateTime? createdAt;
  const _NotifItem({
    required this.id, required this.title, required this.body,
    required this.type, required this.isRead, this.createdAt,
  });
}
