// features/preview/screens/member_preview_screen.dart
// Admin can select a member and preview what they see on mobile

import 'package:flutter/material.dart';
import '../../../core/models/member_model.dart';
import '../../../core/models/payment_model.dart';
import '../../../core/models/document_model.dart';
import '../../../core/models/announcement_model.dart';
import '../../../core/models/complaint_model.dart';
import '../../../core/services/firestore_service.dart';

class MemberPreviewScreen extends StatefulWidget {
  const MemberPreviewScreen({super.key});

  @override
  State<MemberPreviewScreen> createState() =>
      _MemberPreviewScreenState();
}

class _MemberPreviewScreenState
    extends State<MemberPreviewScreen>
    with SingleTickerProviderStateMixin {
  final _fs = FirestoreService();

  MemberModel?   _selectedMember;
  String?        _selectedUid;
  late TabController _tabs;

  static const Color _navy   = Color(0xFF0D2A5C);
  static const Color _accent = Color(0xFF2E6BE6);
  static const Color _bg     = Color(0xFFF0F4FB);

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────────
            const Text('Member Portal Preview',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: _navy)),
            const SizedBox(height: 2),
            Text(
                'Preview what a member sees on the mobile app',
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600])),
            const SizedBox(height: 24),

            // ── Member selector ────────────────────────────────────────────
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: const Color(0xFFE0E8F4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.person_search_outlined,
                      color: _navy, size: 20),
                  const SizedBox(width: 12),
                  const Text('Select Member:',
                      style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: _navy)),
                  const SizedBox(width: 16),
                  Expanded(
                    child: StreamBuilder<List<MemberModel>>(
                      stream: _fs.streamMembers(),
                      builder: (context, snap) {
                        final members = snap.data ?? [];
                        if (members.isEmpty) {
                          return Text(
                            'No members found.',
                            style: TextStyle(
                                color: Colors.grey[500]),
                          );
                        }
                        return DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedUid,
                            hint: Text(
                              'Choose a member to preview',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[400]),
                            ),
                            isExpanded: true,
                            style: const TextStyle(
                                fontSize: 13.5,
                                color: Color(0xFF1A2B4A)),
                            items: members
                                .map((m) =>
                                    DropdownMenuItem<String>(
                                      value: m.uid,
                                      child: Text(
                                          '${m.name} — Lot ${m.lotNumber}'),
                                    ))
                                .toList(),
                            onChanged: (uid) {
                              if (uid == null) return;
                              final m = members.firstWhere(
                                  (m) => m.uid == uid);
                              setState(() {
                                _selectedUid    = uid;
                                _selectedMember = m;
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),
                  if (_selectedMember != null) ...[
                    const SizedBox(width: 16),
                    _StatusBadge(
                        status: _selectedMember!.status),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Preview content ────────────────────────────────────────────
            if (_selectedMember == null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.phone_android_outlined,
                          size: 64,
                          color: Colors.grey[300]),
                      const SizedBox(height: 16),
                      Text(
                        'Select a member above to preview\ntheir mobile app experience.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                            height: 1.6),
                      ),
                    ],
                  ),
                ),
              )
            else ...[
              // Preview banner
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F4FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                      color: const Color(0xFF2E6BE6)
                          .withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.visibility_outlined,
                        size: 16,
                        color: Color(0xFF2E6BE6)),
                    const SizedBox(width: 8),
                    Text(
                      'Previewing as: ${_selectedMember!.name}  ·  ${_selectedMember!.phase}  ·  Lot ${_selectedMember!.lotNumber}',
                      style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1A4A9C),
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Tabs
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFFE0E8F4)),
                ),
                child: TabBar(
                  controller: _tabs,
                  labelColor: _navy,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: _accent,
                  dividerColor: Colors.transparent,
                  labelStyle: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                  tabs: const [
                    Tab(text: 'Payments'),
                    Tab(text: 'Documents'),
                    Tab(text: 'Announcements'),
                    Tab(text: 'Complaints'),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _PaymentsPreview(
                        fs: _fs,
                        member: _selectedMember!),
                    _DocumentsPreview(
                        fs: _fs,
                        member: _selectedMember!),
                    _AnnouncementsPreview(fs: _fs),
                    _ComplaintsPreview(
                        fs: _fs,
                        member: _selectedMember!),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Payments preview ──────────────────────────────────────────────────────────
class _PaymentsPreview extends StatelessWidget {
  final FirestoreService fs;
  final MemberModel      member;

  const _PaymentsPreview(
      {required this.fs, required this.member});

  Color _fg(PaymentStatus s) {
    switch (s) {
      case PaymentStatus.paid:    return const Color(0xFF1A7A4A);
      case PaymentStatus.unpaid:  return const Color(0xFF7A6A1A);
      case PaymentStatus.overdue: return const Color(0xFFCC2200);
      case PaymentStatus.waived:  return const Color(0xFF5A7099);
    }
  }

  Color _bg(PaymentStatus s) {
    switch (s) {
      case PaymentStatus.paid:    return const Color(0xFFEAF7F0);
      case PaymentStatus.unpaid:  return const Color(0xFFFFF8E0);
      case PaymentStatus.overdue: return const Color(0xFFFFF0EE);
      case PaymentStatus.waived:  return const Color(0xFFF0F4FB);
    }
  }

  String _fmt(DateTime? d) => d == null
      ? '—'
      : '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<PaymentModel>>(
      stream: fs.streamPaymentsForMember(member.uid),
      builder: (context, snap) {
        final payments = snap.data ?? [];
        if (payments.isEmpty) {
          return _EmptyState(
            icon:    Icons.receipt_long_outlined,
            message: 'No payment records for this member.',
          );
        }

        final totalPaid = payments
            .where((p) => p.status == PaymentStatus.paid)
            .fold(0.0, (s, p) => s + p.amount);
        final pending = payments
            .where((p) =>
                p.status == PaymentStatus.unpaid ||
                p.status == PaymentStatus.overdue)
            .length;

        return Column(
          children: [
            // Summary
            Row(
              children: [
                Expanded(
                  child: _PreviewStat(
                    label: 'Total Paid',
                    value: '₱${totalPaid.toStringAsFixed(0)}',
                    color: const Color(0xFF1A7A4A),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _PreviewStat(
                    label: 'Pending',
                    value: '$pending records',
                    color: const Color(0xFFCC2200),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFFE0E8F4)),
                ),
                child: ListView.separated(
                  itemCount: payments.length,
                  separatorBuilder: (_, __) =>
                      const Divider(
                          height: 1,
                          color: Color(0xFFEEF2F9)),
                  itemBuilder: (_, i) {
                    final p = payments[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(p.type.label,
                                    style: const TextStyle(
                                        fontSize: 13.5,
                                        fontWeight:
                                            FontWeight.w500,
                                        color: Color(
                                            0xFF0D2A5C))),
                                Text(
                                    'Due: ${_fmt(p.dueDate)}',
                                    style: TextStyle(
                                        fontSize: 12,
                                        color: Colors
                                            .grey[500])),
                              ],
                            ),
                          ),
                          Text(
                            '₱${p.amount.toStringAsFixed(2)}',
                            style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1A2B4A)),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            padding:
                                const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4),
                            decoration: BoxDecoration(
                              color: _bg(p.status),
                              borderRadius:
                                  BorderRadius.circular(20),
                            ),
                            child: Text(p.status.label,
                                style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight:
                                        FontWeight.w600,
                                    color: _fg(p.status))),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ── Documents preview ─────────────────────────────────────────────────────────
class _DocumentsPreview extends StatelessWidget {
  final FirestoreService fs;
  final MemberModel      member;

  const _DocumentsPreview(
      {required this.fs, required this.member});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DocumentModel>>(
      stream: fs.streamDocumentsForMember(member.uid),
      builder: (context, snap) {
        final docs = snap.data ?? [];
        if (docs.isEmpty) {
          return _EmptyState(
            icon:    Icons.folder_open_outlined,
            message: 'No documents uploaded for this member.',
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: const Color(0xFFE0E8F4)),
          ),
          child: ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(
                height: 1, color: Color(0xFFEEF2F9)),
            itemBuilder: (_, i) {
              final d = docs[i];
              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E6BE6)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                      Icons.insert_drive_file_outlined,
                      size: 20,
                      color: Color(0xFF2E6BE6)),
                ),
                title: Text(d.fileName,
                    style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500)),
                subtitle: Text(d.type.label,
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500])),
                trailing: TextButton(
                  onPressed: () {},
                  child: const Text('View'),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ── Announcements preview ─────────────────────────────────────────────────────
class _AnnouncementsPreview extends StatelessWidget {
  final FirestoreService fs;
  const _AnnouncementsPreview({required this.fs});

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<AnnouncementModel>>(
      stream: fs.streamAnnouncements(),
      builder: (context, snap) {
        final all = snap.data ?? [];
        final active =
            all.where((a) => a.isActive).toList();

        if (active.isEmpty) {
          return _EmptyState(
            icon:    Icons.campaign_outlined,
            message: 'No active announcements.',
          );
        }

        return ListView.separated(
          itemCount: active.length,
          separatorBuilder: (_, __) =>
              const SizedBox(height: 10),
          itemBuilder: (_, i) {
            final a = active[i];
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: const Color(0xFFE0E8F4)),
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(a.title,
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0D2A5C))),
                  const SizedBox(height: 6),
                  Text(a.body,
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                          height: 1.5)),
                  const SizedBox(height: 8),
                  Text(
                    'Posted by ${a.postedByName} · ${_fmt(a.createdAt)}',
                    style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.grey[400]),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

// ── Complaints preview ────────────────────────────────────────────────────────
class _ComplaintsPreview extends StatelessWidget {
  final FirestoreService fs;
  final MemberModel      member;

  const _ComplaintsPreview(
      {required this.fs, required this.member});

  Color _fg(ComplaintStatus s) {
    switch (s) {
      case ComplaintStatus.pending:   return const Color(0xFF7A6A1A);
      case ComplaintStatus.reviewing: return const Color(0xFF1A4A9C);
      case ComplaintStatus.resolved:  return const Color(0xFF1A7A4A);
      case ComplaintStatus.rejected:  return const Color(0xFFCC2200);
    }
  }

  Color _bg(ComplaintStatus s) {
    switch (s) {
      case ComplaintStatus.pending:   return const Color(0xFFFFF8E0);
      case ComplaintStatus.reviewing: return const Color(0xFFEEF4FF);
      case ComplaintStatus.resolved:  return const Color(0xFFEAF7F0);
      case ComplaintStatus.rejected:  return const Color(0xFFFFF0EE);
    }
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ComplaintModel>>(
      stream: fs.streamComplaints(),
      builder: (context, snap) {
        final all = snap.data ?? [];
        final memberComplaints = all
            .where((c) => c.uid == member.uid)
            .toList();

        if (memberComplaints.isEmpty) {
          return _EmptyState(
            icon:    Icons.report_problem_outlined,
            message: 'No complaints filed by this member.',
          );
        }

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: const Color(0xFFE0E8F4)),
          ),
          child: ListView.separated(
            itemCount: memberComplaints.length,
            separatorBuilder: (_, __) => const Divider(
                height: 1, color: Color(0xFFEEF2F9)),
            itemBuilder: (_, i) {
              final c = memberComplaints[i];
              return Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Text(c.subject,
                              style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight:
                                      FontWeight.w500,
                                  color:
                                      Color(0xFF0D2A5C))),
                          const SizedBox(height: 3),
                          Text(
                            'Filed: ${_fmt(c.createdAt)}',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500]),
                          ),
                          if (c.resolutionNote
                              .isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Resolution: ${c.resolutionNote}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600]),
                            ),
                          ],
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _bg(c.status),
                        borderRadius:
                            BorderRadius.circular(20),
                      ),
                      child: Text(c.status.label,
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: _fg(c.status))),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

// ── Shared preview widgets ────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String   message;

  const _EmptyState(
      {required this.icon, required this.message});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 48, color: Colors.grey[300]),
        const SizedBox(height: 12),
        Text(message,
            style: TextStyle(
                fontSize: 13.5,
                color: Colors.grey[500])),
      ],
    ),
  );
}

class _PreviewStat extends StatelessWidget {
  final String label, value;
  final Color  color;

  const _PreviewStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(10),
      border:
          Border.all(color: const Color(0xFFE0E8F4)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12, color: Colors.grey[500])),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: color)),
      ],
    ),
  );
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
    padding: const EdgeInsets.symmetric(
        horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(20)),
    child: Text(status.label,
        style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: _fg)),
  );
}