// lib/features/announcements/announcements_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AnnouncementsScreen extends StatelessWidget {
  const AnnouncementsScreen({super.key});

  static const _blue700  = Color(0xFF1A3D6B);
  static const _blue600  = Color(0xFF1E52A0);
  static const _blue200  = Color(0xFFBAD9FD);
  static const _blue50   = Color(0xFFEFF6FF);
  static const _gray50   = Color(0xFFF8FAFC);
  static const _gray100  = Color(0xFFEEF2F7);
  static const _gray200  = Color(0xFFD4DCE8);
  static const _gray400  = Color(0xFF8A9BB0);
  static const _gray600  = Color(0xFF4A5A6E);
  static const _gray800  = Color(0xFF1E2A3A);
  static const _gold     = Color(0xFFC9A84C);
  static const _goldBg   = Color(0xFFFEF9C3);
  static const _danger   = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _gray50,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('announcements')
                    .where('isActive', isEqualTo: true)
                    .orderBy('createdAt', descending: true)
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return _buildError(snap.error.toString());
                  }
                  final docs = snap.data?.docs ?? [];
                  if (docs.isEmpty) return _buildEmpty();
                  return _buildList(context, docs);
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
                Icon(Icons.arrow_back_ios_new,
                    size: 12, color: _blue200),
                SizedBox(width: 4),
                Text('Back',
                    style: TextStyle(fontSize: 10, color: _blue200)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Announcements',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Official notices from La Milagrosa HOA',
            style: TextStyle(fontSize: 10, color: _blue200),
          ),
        ],
      ),
    );
  }

  // ── List ──────────────────────────────────────────────────────────────────

  Widget _buildList(
      BuildContext context, List<QueryDocumentSnapshot> docs) {
    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: docs.length,
      itemBuilder: (context, i) {
        final data = docs[i].data() as Map<String, dynamic>;
        return _buildAnnouncementCard(context, data);
      },
    );
  }

  Widget _buildAnnouncementCard(
      BuildContext context, Map<String, dynamic> data) {
    // ── field names match your Firestore doc ──
    final title     = data['title']       as String? ?? '';
    final body      = data['body']        as String? ?? '';
    final postedBy  = data['postedByName'] as String? ?? 'HOA Admin';
    final createdAt = (data['createdAt']  as Timestamp?)?.toDate();
    final dateFmt   = DateFormat('MMMM d, yyyy');
    final timeFmt   = DateFormat('h:mm a');

    return GestureDetector(
      onTap: () => _showDetail(context, data),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _gray100),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E2A3A).withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 3,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                    colors: [_blue600, _blue700]),
                borderRadius: BorderRadius.vertical(
                    top: Radius.circular(10)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _goldBg,
                          borderRadius:
                              BorderRadius.circular(10),
                        ),
                        child: const Center(
                          child: Text('📢',
                              style: TextStyle(fontSize: 16)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _gray800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(
                                    Icons.person_outline,
                                    size: 10,
                                    color: _gray400),
                                const SizedBox(width: 3),
                                Text(postedBy,
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: _gray400)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: _blue50,
                          borderRadius:
                              BorderRadius.circular(6),
                          border: Border.all(
                              color: const Color(0xFFBAD9FD),
                              width: 1),
                        ),
                        child: const Text(
                          'OFFICIAL',
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w600,
                            color: _blue600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    body,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: _gray600,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      const Icon(
                          Icons.calendar_today_outlined,
                          size: 10,
                          color: _gray400),
                      const SizedBox(width: 4),
                      Text(
                        createdAt != null
                            ? '${dateFmt.format(createdAt)}  ·  ${timeFmt.format(createdAt)}'
                            : '—',
                        style: const TextStyle(
                            fontSize: 10, color: _gray400),
                      ),
                      const Spacer(),
                      const Text(
                        'Read more',
                        style: TextStyle(
                          fontSize: 10,
                          color: _blue600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const Icon(Icons.chevron_right,
                          size: 12, color: _blue600),
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

  // ── Detail bottom sheet ───────────────────────────────────────────────────

  void _showDetail(
      BuildContext context, Map<String, dynamic> data) {
    final title     = data['title']        as String? ?? '';
    final body      = data['body']         as String? ?? '';
    final postedBy  = data['postedByName'] as String? ?? 'HOA Admin';
    final createdAt = (data['createdAt']   as Timestamp?)?.toDate();
    final dateFmt   = DateFormat('MMMM d, yyyy · h:mm a');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (ctx, scrollCtrl) {
            return SingleChildScrollView(
              controller: scrollCtrl,
              padding:
                  const EdgeInsets.fromLTRB(24, 12, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin:
                          const EdgeInsets.only(bottom: 20),
                      decoration: BoxDecoration(
                        color: _gray200,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _goldBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _gold.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Text('📢',
                            style: TextStyle(fontSize: 10)),
                        SizedBox(width: 4),
                        Text(
                          'Official Announcement',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: _gold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: _gray800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.person_outline,
                          size: 12, color: _gray400),
                      const SizedBox(width: 4),
                      Text(postedBy,
                          style: const TextStyle(
                              fontSize: 11, color: _gray400)),
                      const SizedBox(width: 12),
                      const Icon(
                          Icons.calendar_today_outlined,
                          size: 12,
                          color: _gray400),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          createdAt != null
                              ? dateFmt.format(createdAt)
                              : '—',
                          style: const TextStyle(
                              fontSize: 11, color: _gray400),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: _gray100),
                  const SizedBox(height: 16),
                  Text(
                    body,
                    style: const TextStyle(
                      fontSize: 13,
                      color: _gray600,
                      height: 1.8,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            vertical: 13),
                        side: const BorderSide(
                            color: _gray200, width: 1.5),
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(8)),
                      ),
                      child: const Text(
                        'Close',
                        style: TextStyle(
                            fontSize: 13, color: _gray600),
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
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('📢', style: TextStyle(fontSize: 36)),
          SizedBox(height: 12),
          Text(
            'No announcements at this time.',
            style: TextStyle(fontSize: 12, color: _gray400),
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
            style: const TextStyle(
                fontSize: 12, color: _danger)),
      ),
    );
  }
}