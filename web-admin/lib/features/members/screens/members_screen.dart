// features/members/screens/members_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import '../../../core/models/member_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/firestore_service.dart';
import 'member_detail_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});
  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final _search = TextEditingController();
  final _fs = FirestoreService();

  String _searchQuery = '';
  MemberStatus? _statusFilter;
  String? _phaseFilter;

  static const Color _navy   = Color(0xFF0D2A5C);
  static const Color _accent = Color(0xFF2E6BE6);
  static const Color _bg     = Color(0xFFF0F4FB);
  static const Color _white  = Colors.white;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<MemberModel> _filtered(List<MemberModel> all) {
    return all.where((m) {
      final q = _searchQuery.toLowerCase();
      final matchSearch = q.isEmpty ||
          m.name.toLowerCase().contains(q) ||
          m.email.toLowerCase().contains(q) ||
          m.lotNumber.toLowerCase().contains(q);
      final matchStatus = _statusFilter == null || m.status == _statusFilter;
      final matchPhase  = _phaseFilter  == null || m.phase  == _phaseFilter;
      return matchSearch && matchStatus && matchPhase;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final canEdit = auth.isAdmin || auth.isOfficer;

    return Scaffold(
      backgroundColor: _bg,
      body: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ───────────────────────────────────────────────────────
            Row(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Homeowner Records',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: _navy)),
                    const SizedBox(height: 2),
                    Text('Manage and view all registered homeowners',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                  ],
                ),
                const Spacer(),
                if (canEdit)
                  ElevatedButton.icon(
                    onPressed: () => _showAddMemberDialog(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Member'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: _white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Filters ───────────────────────────────────────────────────────
            Row(
              children: [
                // Search
                SizedBox(
                  width: 280,
                  child: TextField(
                    controller: _search,
                    onChanged: (v) => setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Search name, email, lot...',
                      hintStyle:
                          TextStyle(fontSize: 13, color: Colors.grey[400]),
                      prefixIcon: const Icon(Icons.search, size: 18),
                      filled: true,
                      fillColor: _white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
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
                          borderSide:
                              const BorderSide(color: _accent, width: 1.5)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Status filter
                _FilterDropdown<MemberStatus?>(
                  value: _statusFilter,
                  hint: 'All Statuses',
                  items: const [null, ...MemberStatus.values],
                  labelOf: (v) => v == null ? 'All Statuses' : v.label,
                  onChanged: (v) => setState(() => _statusFilter = v),
                ),
                const SizedBox(width: 12),

                // Phase filter
                _FilterDropdown<String?>(
                  value: _phaseFilter,
                  hint: 'All Phases',
                  items: const [null, 'Phase 1', 'Phase 2', 'Phase 3'],
                  labelOf: (v) => v ?? 'All Phases',
                  onChanged: (v) => setState(() => _phaseFilter = v),
                ),

                if (_searchQuery.isNotEmpty ||
                    _statusFilter != null ||
                    _phaseFilter != null) ...[
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _search.clear();
                      _searchQuery = '';
                      _statusFilter = null;
                      _phaseFilter = null;
                    }),
                    icon: const Icon(Icons.clear, size: 15),
                    label: const Text('Clear'),
                    style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[600]),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // ── Table ─────────────────────────────────────────────────────────
            Expanded(
              child: StreamBuilder<List<MemberModel>>(
                stream: _fs.streamMembers(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(
                        child: Text('Error: ${snap.error}',
                            style: const TextStyle(color: Colors.red)));
                  }

                  final members = _filtered(snap.data ?? []);

                  return Container(
                    decoration: BoxDecoration(
                      color: _white,
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: const Color(0xFFE0E8F4)),
                    ),
                    child: Column(
                      children: [
                        // Table header
                        _TableHeader(),
                        const Divider(height: 1, color: Color(0xFFE0E8F4)),

                        // Rows
                        if (members.isEmpty)
                          const Expanded(
                            child: Center(
                              child: Text('No members found.',
                                  style: TextStyle(color: Colors.grey)),
                            ),
                          )
                        else
                          Expanded(
                            child: ListView.separated(
                              itemCount: members.length,
                              separatorBuilder: (_, __) => const Divider(
                                  height: 1, color: Color(0xFFEEF2F9)),
                              itemBuilder: (context, i) => _MemberRow(
                                member: members[i],
                                canEdit: canEdit,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => MemberDetailScreen(
                                        member: members[i]),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
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

  void _showAddMemberDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => _AddMemberDialog(fsService: _fs),
    );
  }
}

// ── Table header row ──────────────────────────────────────────────────────────
class _TableHeader extends StatelessWidget {
  static const Color _navy = Color(0xFF0D2A5C);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const BoxDecoration(
        color: Color(0xFFF7F9FC),
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        children: const [
          Expanded(flex: 3, child: _TH('Name')),
          Expanded(flex: 3, child: _TH('Email')),
          Expanded(flex: 2, child: _TH('Lot No.')),
          Expanded(flex: 2, child: _TH('Phase')),
          Expanded(flex: 2, child: _TH('Status')),
          SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _TH extends StatelessWidget {
  final String text;
  const _TH(this.text);
  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF5A7099),
            letterSpacing: 0.4),
      );
}

// ── Member row ────────────────────────────────────────────────────────────────
class _MemberRow extends StatelessWidget {
  final MemberModel member;
  final bool canEdit;
  final VoidCallback onTap;

  const _MemberRow(
      {required this.member, required this.canEdit, required this.onTap});

  Color _statusColor(MemberStatus s) {
    switch (s) {
      case MemberStatus.active:     return const Color(0xFF1A7A4A);
      case MemberStatus.inactive:   return const Color(0xFF7A6A1A);
      case MemberStatus.delinquent: return const Color(0xFFCC2200);
    }
  }

  Color _statusBg(MemberStatus s) {
    switch (s) {
      case MemberStatus.active:     return const Color(0xFFEAF7F0);
      case MemberStatus.inactive:   return const Color(0xFFFFF8E0);
      case MemberStatus.delinquent: return const Color(0xFFFFF0EE);
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      hoverColor: const Color(0xFFF0F4FB),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          children: [
            // Name + avatar
            Expanded(
              flex: 3,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFF2E6BE6).withOpacity(0.12),
                    child: Text(
                      member.name.isNotEmpty
                          ? member.name[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF2E6BE6)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(member.name,
                        style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF0D2A5C)),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 3,
              child: Text(member.email,
                  style:
                      TextStyle(fontSize: 13, color: Colors.grey[600]),
                  overflow: TextOverflow.ellipsis),
            ),
            Expanded(
              flex: 2,
              child: Text(member.lotNumber,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF1A2B4A))),
            ),
            Expanded(
              flex: 2,
              child: Text(member.phase,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF1A2B4A))),
            ),
            Expanded(
              flex: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusBg(member.status),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  member.status.label,
                  style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: _statusColor(member.status)),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            SizedBox(
              width: 48,
              child: Icon(Icons.chevron_right,
                  size: 18, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Generic filter dropdown ───────────────────────────────────────────────────
class _FilterDropdown<T> extends StatelessWidget {
  final T value;
  final String hint;
  final List<T> items;
  final String Function(T) labelOf;
  final void Function(T) onChanged;

  const _FilterDropdown({
    required this.value,
    required this.hint,
    required this.items,
    required this.labelOf,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD0DBEE)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint,
              style:
                  TextStyle(fontSize: 13, color: Colors.grey[500])),
          style: const TextStyle(fontSize: 13, color: Color(0xFF1A2B4A)),
          icon: const Icon(Icons.expand_more, size: 18),
          items: items
              .map((item) => DropdownMenuItem<T>(
                    value: item,
                    child: Text(labelOf(item)),
                  ))
              .toList(),
          onChanged: (v) {
            if (v != null || T == MemberStatus || T == String) {
              onChanged(v as T);
            }
          },
        ),
      ),
    );
  }
}

// ── Add Member dialog ─────────────────────────────────────────────────────────
class _AddMemberDialog extends StatefulWidget {
  final FirestoreService fsService;
  const _AddMemberDialog({required this.fsService});

  @override
  State<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends State<_AddMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name    = TextEditingController();
  final _email   = TextEditingController();
  final _lot     = TextEditingController();
  final _contact = TextEditingController();
  final _address = TextEditingController();
  String _phase  = 'Phase 1';
  bool _loading  = false;

  static const Color _navy = Color(0xFF0D2A5C);

  @override
  void dispose() {
    _name.dispose(); _email.dispose(); _lot.dispose();
    _contact.dispose(); _address.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final uid = _db.collection('users').doc().id;
      await widget.fsService.addMember(MemberModel(
        uid:           uid,
        name:          _name.text.trim(),
        email:         _email.text.trim(),
        role:          'member',
        lotNumber:     _lot.text.trim(),
        phase:         _phase,
        status:        MemberStatus.active,
        contactNumber: _contact.text.trim(),
        address:       _address.text.trim(),
        createdAt:     DateTime.now(),
      ));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')));
    }
  }

  final _db = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: SizedBox(
        width: 520,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Add New Member',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _navy)),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: _DialogField(controller: _name, label: 'Full Name', hint: 'Juan dela Cruz',
                      validator: (v) => v!.isEmpty ? 'Required' : null)),
                  const SizedBox(width: 14),
                  Expanded(child: _DialogField(controller: _email, label: 'Email', hint: 'juan@email.com',
                      validator: (v) => v!.isEmpty ? 'Required' : null)),
                ]),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(child: _DialogField(controller: _lot, label: 'Lot Number', hint: 'Lot 12 Blk 3',
                      validator: (v) => v!.isEmpty ? 'Required' : null)),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Phase', style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w600,
                            color: _navy)),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<String>(
                          value: _phase,
                          items: ['Phase 1', 'Phase 2', 'Phase 3']
                              .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                              .toList(),
                          onChanged: (v) => setState(() => _phase = v!),
                          decoration: _inputDec('Select phase'),
                        ),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 14),
                _DialogField(controller: _contact, label: 'Contact Number', hint: '09XX-XXX-XXXX'),
                const SizedBox(height: 14),
                _DialogField(controller: _address, label: 'Address', hint: 'House number, street...'),
                const SizedBox(height: 24),
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
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: _navy,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12)),
                      child: _loading
                          ? const SizedBox(
                              width: 16, height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Save Member'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
    filled: true, fillColor: const Color(0xFFF7F9FC),
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD0DBEE))),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD0DBEE))),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF2E6BE6), width: 1.5)),
  );
}

class _DialogField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String? Function(String?)? validator;

  const _DialogField({
    required this.controller,
    required this.label,
    required this.hint,
    this.validator,
  });

  static const Color _navy = Color(0xFF0D2A5C);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: _navy)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
            filled: true, fillColor: const Color(0xFFF7F9FC),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFD0DBEE))),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFD0DBEE))),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(
                    color: Color(0xFF2E6BE6), width: 1.5)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0xFFCC2200))),
          ),
        ),
      ],
    );
  }
}