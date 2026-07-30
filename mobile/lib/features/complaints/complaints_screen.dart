// lib/features/complaints/complaints_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/routing/app_router.dart';

class ComplaintsScreen extends StatefulWidget {
  const ComplaintsScreen({super.key});

  @override
  State<ComplaintsScreen> createState() => _ComplaintsScreenState();
}

class _ComplaintsScreenState extends State<ComplaintsScreen> {
  String _filter = 'All';

  static const _blue700   = Color(0xFF1A3D6B);
  static const _blue600   = Color(0xFF1E52A0);
  static const _blue200   = Color(0xFFBAD9FD);
  static const _gray50    = Color(0xFFF8FAFC);
  static const _gray100   = Color(0xFFEEF2F7);
  static const _gray200   = Color(0xFFD4DCE8);
  static const _gray400   = Color(0xFF8A9BB0);
  static const _gray600   = Color(0xFF4A5A6E);
  static const _gray800   = Color(0xFF1E2A3A);
  static const _success   = Color(0xFF16A34A);
  static const _successBg = Color(0xFFDCFCE7);
  static const _warning   = Color(0xFFB45309);
  static const _warningBg = Color(0xFFFEF9C3);
  static const _danger    = Color(0xFFDC2626);
  static const _dangerBg  = Color(0xFFFEE2E2);
  static const _purple    = Color(0xFF7C3AED);
  static const _purpleBg  = Color(0xFFEDE9FE);

  @override
  Widget build(BuildContext context) {
    final uid = context.watch<AuthProvider>().user?.uid ?? '';

    return Scaffold(
      backgroundColor: _gray50,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('complaints')
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
                  final data = d.data() as Map<String, dynamic>;
                  return _ComplaintItem(
                    id:          d.id,
                    title:       data['title']       as String? ?? '',
                    description: data['description'] as String? ?? '',
                    category:    data['category']    as String? ?? 'general',
                    status:      data['status']      as String? ?? 'pending',
                    createdAt:   (data['createdAt']  as Timestamp?)?.toDate(),
                    resolvedAt:  (data['resolvedAt'] as Timestamp?)?.toDate(),
                  );
                }).toList();

                final filtered = _filter == 'All'
                    ? all
                    : all.where((c) => c.status.toLowerCase() == _filter.toLowerCase()).toList();

                return Column(
                  children: [
                    _buildSummaryRow(all),
                    _buildFilterRow(),
                    Expanded(
                      child: filtered.isEmpty ? _buildEmpty() : _buildList(filtered),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(Routes.submitComplaint),
        backgroundColor: _blue600,
        elevation: 2,
        icon: const Icon(Icons.add, color: Colors.white, size: 18),
        label: const Text('New Complaint',
            style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _blue700,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => context.canPop() ? context.pop() : context.go('/home'),
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
                'My Complaints',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              const Text('Track and submit HOA complaints',
                  style: TextStyle(fontSize: 10, color: _blue200)),
            ],
          ),
        ),
      ),
    );
  }

  // ── Summary row ───────────────────────────────────────────────────────────

  Widget _buildSummaryRow(List<_ComplaintItem> all) {
    final pending   = all.where((c) => c.status == 'pending').length;
    final reviewing = all.where((c) => c.status == 'reviewing').length;
    final resolved  = all.where((c) => c.status == 'resolved').length;

    return Container(
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gray100),
      ),
      child: Row(
        children: [
          _sumItem('$pending',   'PENDING',   _purple),
          _divider(),
          _sumItem('$reviewing', 'REVIEWING', _warning),
          _divider(),
          _sumItem('$resolved',  'RESOLVED',  _success),
        ],
      ),
    );
  }

  Widget _sumItem(String value, String label, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: TextStyle(fontFamily: 'Georgia', fontSize: 20, fontWeight: FontWeight.w700, color: color)),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(fontSize: 9, color: _gray400, letterSpacing: 0.5)),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 32, color: _gray100);

  // ── Filter row ────────────────────────────────────────────────────────────

  Widget _buildFilterRow() {
    final filters = ['All', 'Pending', 'Reviewing', 'Resolved', 'Rejected'];
    return SizedBox(
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
        children: filters.map((f) {
          final active = _filter == f;
          return GestureDetector(
            onTap: () => setState(() => _filter = f),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: active ? _blue600 : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: active ? _blue600 : _gray200, width: 1.5),
              ),
              child: Text(f,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      color: active ? Colors.white : _gray600)),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── List ──────────────────────────────────────────────────────────────────

  Widget _buildList(List<_ComplaintItem> items) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 90),
      itemCount: items.length,
      itemBuilder: (context, i) => _buildCard(items[i]),
    );
  }

  Widget _buildCard(_ComplaintItem item) {
    final dateFmt     = DateFormat('MMM d, yyyy');
    final statusColor = _statusColor(item.status);
    final statusBg    = _statusBg(item.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _gray100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(item.title,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _gray800)),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(10)),
                child: Text(_statusLabel(item.status),
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: statusColor)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(item.description,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11, color: _gray600, height: 1.5)),
          const SizedBox(height: 8),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: _gray100, borderRadius: BorderRadius.circular(8)),
                child: Text(_categoryLabel(item.category),
                    style: const TextStyle(fontSize: 9, color: _gray600)),
              ),
              const Spacer(),
              const Icon(Icons.calendar_today_outlined, size: 10, color: _gray400),
              const SizedBox(width: 4),
              Text(
                item.createdAt != null ? dateFmt.format(item.createdAt!) : '—',
                style: const TextStyle(fontSize: 10, color: _gray400),
              ),
            ],
          ),
          if (item.resolvedAt != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.check_circle_outline, size: 11, color: _success),
                const SizedBox(width: 4),
                Text('Resolved ${dateFmt.format(item.resolvedAt!)}',
                    style: const TextStyle(fontSize: 10, color: _success)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Empty / Error ─────────────────────────────────────────────────────────

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('📋', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 12),
          Text(
            _filter == 'All' ? 'No complaints submitted yet.' : 'No ${_filter.toLowerCase()} complaints.',
            style: const TextStyle(fontSize: 12, color: _gray400),
          ),
          const SizedBox(height: 6),
          const Text('Tap "New Complaint" to submit one.',
              style: TextStyle(fontSize: 11, color: _gray400)),
        ],
      ),
    );
  }

  Widget _buildError(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 36, color: _danger),
            const SizedBox(height: 12),
            Text(msg, textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: _danger)),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'resolved':  return _success;
      case 'reviewing': return _warning;
      case 'rejected':  return _danger;
      case 'pending':   return _purple;
      default:          return _gray600;
    }
  }

  Color _statusBg(String s) {
    switch (s.toLowerCase()) {
      case 'resolved':  return _successBg;
      case 'reviewing': return _warningBg;
      case 'rejected':  return _dangerBg;
      case 'pending':   return _purpleBg;
      default:          return _gray100;
    }
  }

  String _statusLabel(String s) => s.isEmpty ? '' : s[0].toUpperCase() + s.substring(1);

  String _categoryLabel(String c) {
    switch (c.toLowerCase()) {
      case 'maintenance':  return 'Maintenance';
      case 'noise':        return 'Noise';
      case 'security':     return 'Security';
      case 'cleanliness':  return 'Cleanliness';
      case 'billing':      return 'Billing';
      default:             return 'General';
    }
  }
}

class _ComplaintItem {
  final String id, title, description, category, status;
  final DateTime? createdAt, resolvedAt;
  const _ComplaintItem({
    required this.id, required this.title, required this.description,
    required this.category, required this.status, this.createdAt, this.resolvedAt,
  });
}