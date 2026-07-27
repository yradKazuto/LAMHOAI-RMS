// lib/features/notifications/notifications_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/providers/auth_provider.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _filter = 'All';

  // Tracks IDs marked read this session — prevents flicker when
  // stream rebuilds before Firestore confirms the write
  final Set<String> _locallyRead = {};

  static const _blue700   = Color(0xFF1A3D6B);
  static const _blue600   = Color(0xFF1E52A0);
  static const _blue500   = Color(0xFF2563EB);
  static const _blue200   = Color(0xFFBAD9FD);
  static const _blue50    = Color(0xFFEFF6FF);
  static const _gray50    = Color(0xFFF8FAFC);
  static const _gray100   = Color(0xFFEEF2F7);
  static const _gray200   = Color(0xFFD4DCE8);
  static const _gray400   = Color(0xFF8A9BB0);
  static const _gray600   = Color(0xFF4A5A6E);
  static const _gray800   = Color(0xFF1E2A3A);
  static const _gold      = Color(0xFFC9A84C);
  static const _danger    = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().user?.uid ?? '';

    return Scaffold(
      backgroundColor: _gray50,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
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
                  final all = docs.map((d) {
                    final data    = d.data() as Map<String, dynamic>;
                    final fsRead  = data['isRead'] as bool? ?? false;
                    // Use local set to prevent flicker
                    final isRead  = fsRead || _locallyRead.contains(d.id);
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
                            : _buildList(filtered, uid),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      color: _blue700,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () =>
                context.canPop() ? context.pop() : context.go('/home'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.arrow_back_ios_new, size: 12, color: _blue200),
                SizedBox(width: 4),
                Text('Back', style: TextStyle(fontSize: 10, color: _blue200)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Notifications',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'HOA announcements and dues reminders',
            style: TextStyle(fontSize: 10, color: _blue200),
          ),
        ],
      ),
    );
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: active ? _blue600 : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: active ? _blue600 : _gray200,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    f,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: active ? Colors.white : _gray600,
                    ),
                  ),
                  if (f == 'Unread' && unreadCount > 0) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: active ? Colors.white : _blue500,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$unreadCount',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: active ? _blue600 : Colors.white,
                        ),
                      ),
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

  Widget _buildList(List<_NotifItem> items, String uid) {
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: items.length,
      itemBuilder: (context, i) => _buildNotifCard(items[i], uid),
    );
  }

  Widget _buildNotifCard(_NotifItem item, String uid) {
    final dateFmt  = DateFormat('MMM d, yyyy · h:mm a');
    final dotColor = _dotColor(item.type);

    return GestureDetector(
      onTap: () => _openNotification(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: item.isRead ? Colors.white : _blue50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: item.isRead ? _gray100 : _blue200,
            width: item.isRead ? 1 : 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Unread dot
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: item.isRead ? _gray200 : dotColor,
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
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: item.isRead
                                ? FontWeight.w400
                                : FontWeight.w600,
                            color: _gray800,
                          ),
                        ),
                      ),
                      if (!item.isRead)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _blue500,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'NEW',
                            style: TextStyle(
                              fontSize: 8,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: _gray600, height: 1.5),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(_typeIcon(item.type), size: 10, color: _gray400),
                      const SizedBox(width: 4),
                      Text(
                        item.createdAt != null
                            ? dateFmt.format(item.createdAt!)
                            : '—',
                        style: const TextStyle(fontSize: 10, color: _gray400),
                      ),
                      const Spacer(),
                      const Text(
                        'Tap to read',
                        style: TextStyle(fontSize: 9, color: _gray400),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Open notification bottom sheet ────────────────────────────────────────

  void _openNotification(_NotifItem item) {
    // Mark locally first — no flicker
    if (!item.isRead) {
      setState(() => _locallyRead.add(item.id));
      // Write to Firestore in background
      FirebaseFirestore.instance
          .collection('notifications')
          .doc(item.id)
          .update({'isRead': true});
    }

    final dateFmt = DateFormat('MMMM d, yyyy · h:mm a');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (ctx, scrollCtrl) {
            return SingleChildScrollView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Drag handle
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: _gray200,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  // Type badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _blue50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _blue200),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(_typeIcon(item.type),
                            size: 11, color: _blue600),
                        const SizedBox(width: 4),
                        Text(
                          _typeLabel(item.type),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: _blue600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Title
                  Text(
                    item.title,
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: _gray800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Date
                  Text(
                    item.createdAt != null
                        ? dateFmt.format(item.createdAt!)
                        : '—',
                    style: const TextStyle(fontSize: 10, color: _gray400),
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: _gray100),
                  const SizedBox(height: 16),
                  // Full body
                  Text(
                    item.body,
                    style: const TextStyle(
                      fontSize: 13,
                      color: _gray600,
                      height: 1.7,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Close button
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 13),
                        side: const BorderSide(
                            color: _gray200, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(fontSize: 13, color: _gray600),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Empty / Error ─────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔔', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 12),
          Text(
            _filter == 'All'
                ? 'No notifications yet.'
                : 'No ${_filter.toLowerCase()} notifications.',
            style: const TextStyle(fontSize: 12, color: _gray400),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(msg,
            style: const TextStyle(fontSize: 12, color: _danger)),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Color _dotColor(String type) {
    switch (type) {
      case 'dues':         return _blue500;
      case 'announcement': return _gold;
      case 'complaint':    return const Color(0xFF16A34A);
      default:             return _gray400;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'dues':         return Icons.receipt_long_outlined;
      case 'announcement': return Icons.campaign_outlined;
      case 'complaint':    return Icons.feedback_outlined;
      default:             return Icons.notifications_outlined;
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

// ── Data class ────────────────────────────────────────────────────────────────

class _NotifItem {
  final String    id;
  final String    title;
  final String    body;
  final String    type;
  final bool      isRead;
  final DateTime? createdAt;

  const _NotifItem({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    this.createdAt,
  });
}