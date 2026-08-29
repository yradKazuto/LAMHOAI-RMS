// features/members/screens/members_screen.dart
// UPDATED — Lot No. / Block now pulled live from the `lots` collection
// (matched by uid) instead of the member's own manually-typed fields.
// UPDATED — Add Member dialog now creates Firebase Auth account + Firestore doc

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:firebase_core/firebase_core.dart';
import '../../../core/models/member_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/models/lot_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/lot_service.dart';
import 'member_detail_screen.dart';

class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});
  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final _search      = TextEditingController();
  final _fs          = FirestoreService();
  final _lotService  = LotService();

  String  _searchQuery  = '';
  String? _statusFilter;
  String? _blockFilter;

  static const Color _navy   = Color(0xFF0D2A5C);
  static const Color _accent = Color(0xFF2E6BE6);
  static const Color _bg     = Color(0xFFF0F4FB);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Filters members using the REAL lot data (matched by uid), not the
  /// member's own manually-typed lotNumber/phase fields.
  List<MemberModel> _filtered(
    List<MemberModel> all,
    Map<String, LotModel> lotByUid,
  ) {
    return all.where((m) {
      final lot          = lotByUid[m.uid];
      final q            = _searchQuery.toLowerCase();
      final matchSearch  = q.isEmpty ||
          m.name.toLowerCase().contains(q) ||
          m.email.toLowerCase().contains(q) ||
          (lot?.lotNumber.toLowerCase().contains(q) ?? false);
      final matchStatus  = _statusFilter == null ||
          m.status.name == _statusFilter;
      final matchBlock   = _blockFilter == null ||
          lot?.block == _blockFilter;
      return matchSearch && matchStatus && matchBlock;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final auth    = context.watch<AuthProvider>();
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
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600])),
                  ],
                ),
                const Spacer(),
                if (canEdit)
                  ElevatedButton.icon(
                    onPressed: () =>
                        _showAddMemberDialog(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Member'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(8)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Filters ───────────────────────────────────────────────────────
            Row(
              children: [
                SizedBox(
                  width: 280,
                  child: TextField(
                    controller: _search,
                    onChanged: (v) =>
                        setState(() => _searchQuery = v),
                    decoration: InputDecoration(
                      hintText: 'Search name, email, lot...',
                      hintStyle: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[400]),
                      prefixIcon:
                          const Icon(Icons.search, size: 18),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding:
                          const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(8),
                          borderSide: const BorderSide(
                              color: Color(0xFFD0DBEE))),
                      enabledBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(8),
                          borderSide: const BorderSide(
                              color: Color(0xFFD0DBEE))),
                      focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(8),
                          borderSide: const BorderSide(
                              color: _accent, width: 1.5)),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _DropdownFilter(
                  value: _statusFilter,
                  hint:  'All Statuses',
                  items: const [
                    DropdownMenuItem(
                        value: null,
                        child: Text('All Statuses')),
                    DropdownMenuItem(
                        value: 'active',
                        child: Text('Active')),
                    DropdownMenuItem(
                        value: 'inactive',
                        child: Text('Inactive')),
                    DropdownMenuItem(
                        value: 'delinquent',
                        child: Text('Delinquent')),
                  ],
                  onChanged: (v) =>
                      setState(() => _statusFilter = v),
                ),
                const SizedBox(width: 12),
                _DropdownFilter(
                  value: _blockFilter,
                  hint:  'All Blocks',
                  items: const [
                    DropdownMenuItem(
                        value: null,
                        child: Text('All Blocks')),
                    DropdownMenuItem(
                        value: 'Block 1',
                        child: Text('Block 1')),
                    DropdownMenuItem(
                        value: 'Block 2',
                        child: Text('Block 2')),
                    DropdownMenuItem(
                        value: 'Block 3',
                        child: Text('Block 3')),
                    DropdownMenuItem(
                        value: 'Block 4',
                        child: Text('Block 4')),
                    DropdownMenuItem(
                        value: 'Block 5',
                        child: Text('Block 5')),
                    DropdownMenuItem(
                        value: 'Block 6',
                        child: Text('Block 6')),
                    DropdownMenuItem(
                        value: 'Block 7',
                        child: Text('Block 7')),
                    DropdownMenuItem(
                        value: 'Block 8',
                        child: Text('Block 8')),
                    DropdownMenuItem(
                        value: 'Block 9',
                        child: Text('Block 9')),
                  ],
                  onChanged: (v) =>
                      setState(() => _blockFilter = v),
                ),
                if (_searchQuery.isNotEmpty ||
                    _statusFilter != null ||
                    _blockFilter != null) ...[
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: () => setState(() {
                      _search.clear();
                      _searchQuery  = '';
                      _statusFilter = null;
                      _blockFilter  = null;
                    }),
                    icon: const Icon(Icons.clear,
                        size: 15),
                    label: const Text('Clear'),
                    style: TextButton.styleFrom(
                        foregroundColor:
                            Colors.grey[600]),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),

            // ── Table ─────────────────────────────────────────────────────────
            Expanded(
              child: StreamBuilder<List<LotModel>>(
                stream: _lotService.streamLots(),
                builder: (context, lotSnap) {
                  // Build a uid -> lot lookup from the real lots collection.
                  // This is the single source of truth for Lot No. / Block.
                  final lotByUid = <String, LotModel>{};
                  for (final lot in lotSnap.data ?? <LotModel>[]) {
                    final uid = lot.uid;
                    if (uid != null && uid.isNotEmpty) {
                      lotByUid[uid] = lot;
                    }
                  }

                  return StreamBuilder<List<MemberModel>>(
                    stream: _fs.streamMembers(),
                    builder: (context, snap) {
                      if (snap.connectionState ==
                              ConnectionState.waiting ||
                          lotSnap.connectionState ==
                              ConnectionState.waiting) {
                        return const Center(
                            child:
                                CircularProgressIndicator());
                      }
                      if (snap.hasError) {
                        return Center(
                            child: Text(
                                'Error: ${snap.error}',
                                style: const TextStyle(
                                    color: Colors.red)));
                      }

                      final members = _filtered(
                        snap.data ?? [],
                        lotByUid,
                      );

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius:
                              BorderRadius.circular(12),
                          border: Border.all(
                              color:
                                  const Color(0xFFE0E8F4)),
                        ),
                        child: Column(
                          children: [
                            _TableHeader(),
                            const Divider(
                                height: 1,
                                color: Color(0xFFE0E8F4)),
                            if (members.isEmpty)
                              const Expanded(
                                child: Center(
                                  child: Text(
                                      'No members found.',
                                      style: TextStyle(
                                          color:
                                              Colors.grey)),
                                ),
                              )
                            else
                              Expanded(
                                child: ListView.separated(
                                  itemCount: members.length,
                                  separatorBuilder:
                                      (_, __) =>
                                          const Divider(
                                              height: 1,
                                              color: Color(
                                                  0xFFEEF2F9)),
                                  itemBuilder:
                                      (context, i) {
                                    final member = members[i];
                                    final lot =
                                        lotByUid[member.uid];

                                    return _MemberRow(
                                      member:  member,
                                      lot:     lot,
                                      canEdit: canEdit,
                                      onTap: () =>
                                          Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              MemberDetailScreen(
                                                  member:
                                                      member),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                          ],
                        ),
                      );
                    },
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
      builder: (_) =>
          _AddMemberDialog(fsService: _fs),
    );
  }
}

// ── Dropdown filter ───────────────────────────────────────────────────────────
class _DropdownFilter extends StatelessWidget {
  final String?                            value;
  final String                             hint;
  final List<DropdownMenuItem<String?>>    items;
  final void Function(String?)             onChanged;

  const _DropdownFilter({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => Container(
    height: 42,
    padding:
        const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(
          color: const Color(0xFFD0DBEE)),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<String?>(
        value: value,
        hint: Text(hint,
            style: TextStyle(
                fontSize: 13,
                color: Colors.grey[500])),
        style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF1A2B4A)),
        icon: const Icon(Icons.expand_more,
            size: 18),
        items: items,
        onChanged: onChanged,
      ),
    ),
  );
}

// ── Table header ──────────────────────────────────────────────────────────────
class _TableHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(
        horizontal: 20, vertical: 14),
    decoration: const BoxDecoration(
      color: Color(0xFFF7F9FC),
      borderRadius: BorderRadius.vertical(
          top: Radius.circular(12)),
    ),
    child: const Row(
      children: [
        Expanded(flex: 3, child: _TH('Name')),
        Expanded(flex: 3, child: _TH('Email')),
        Expanded(flex: 2, child: _TH('Lot No.')),
        Expanded(flex: 2, child: _TH('Block')),
        Expanded(flex: 2, child: _TH('Status')),
        SizedBox(width: 48),
      ],
    ),
  );
}

class _TH extends StatelessWidget {
  final String text;
  const _TH(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF5A7099),
          letterSpacing: 0.4));
}

// ── Member row ────────────────────────────────────────────────────────────────
class _MemberRow extends StatelessWidget {
  final MemberModel  member;
  final LotModel?     lot;
  final bool         canEdit;
  final VoidCallback onTap;

  const _MemberRow({
    required this.member,
    required this.lot,
    required this.canEdit,
    required this.onTap,
  });

  Color _fg(MemberStatus s) {
    switch (s) {
      case MemberStatus.active:
        return const Color(0xFF1A7A4A);
      case MemberStatus.inactive:
        return const Color(0xFF7A6A1A);
      case MemberStatus.delinquent:
        return const Color(0xFFCC2200);
    }
  }

  Color _bg(MemberStatus s) {
    switch (s) {
      case MemberStatus.active:
        return const Color(0xFFEAF7F0);
      case MemberStatus.inactive:
        return const Color(0xFFFFF8E0);
      case MemberStatus.delinquent:
        return const Color(0xFFFFF0EE);
    }
  }

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    hoverColor: const Color(0xFFF0F4FB),
    child: Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 14),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor:
                      const Color(0xFF2E6BE6)
                          .withOpacity(0.12),
                  child: Text(
                    member.name.isNotEmpty
                        ? member.name[0]
                            .toUpperCase()
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
                          color:
                              Color(0xFF0D2A5C)),
                      overflow:
                          TextOverflow.ellipsis),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(member.email,
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600]),
                overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: 2,
            child: Text(
                lot?.lotNumber.isNotEmpty == true
                    ? 'Lot ${lot!.lotNumber}'
                    : '—',
                style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF1A2B4A))),
          ),
          Expanded(
            flex: 2,
            child: Text(
                lot?.block.isNotEmpty == true
                    ? lot!.block
                    : '—',
                style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF1A2B4A))),
          ),
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: _bg(member.status),
                borderRadius:
                    BorderRadius.circular(20),
              ),
              child: Text(
                member.status.label,
                style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: _fg(member.status)),
                textAlign: TextAlign.center,
              ),
            ),
          ),
          SizedBox(
            width: 48,
            child: Icon(Icons.chevron_right,
                size: 18,
                color: Colors.grey[400]),
          ),
        ],
      ),
    ),
  );
}

// ── Add Member dialog — creates Auth + Firestore ───────────────────────────────
class _AddMemberDialog extends StatefulWidget {
  final FirestoreService fsService;
  const _AddMemberDialog({required this.fsService});

  @override
  State<_AddMemberDialog> createState() =>
      _AddMemberDialogState();
}

class _AddMemberDialogState
    extends State<_AddMemberDialog> {
  final _formKey  = GlobalKey<FormState>();
  final _name     = TextEditingController();
  final _email    = TextEditingController();
  final _password = TextEditingController();
  final _lot      = TextEditingController();
  final _contact  = TextEditingController();
  final _address  = TextEditingController();
  String  _block   = 'Block 1';
  bool    _loading = false;
  bool    _obscure = true;
  String? _error;

  static const Color _navy   = Color(0xFF0D2A5C);
  static const Color _accent = Color(0xFF2E6BE6);

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _lot.dispose();
    _contact.dispose();
    _address.dispose();
    super.dispose();
  }

  String _mapAuthError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      default:
        return 'Error: $code';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      // Use a secondary Firebase App instance so the
      // admin session is NOT affected when creating a new user
      final secondaryApp = await Firebase.initializeApp(
        name:    'secondary',
        options: Firebase.app().options,
      );

      final secondaryAuth =
          FirebaseAuth.instanceFor(app: secondaryApp);

      // 1. Create member Auth account in secondary app
      final cred = await secondaryAuth
          .createUserWithEmailAndPassword(
        email:    _email.text.trim(),
        password: _password.text,
      );
      final memberUid = cred.user!.uid;

      // 2. Send email verification to the new member
      await cred.user!.sendEmailVerification();

      // 3. Sign out from secondary app and delete it
      await secondaryAuth.signOut();
      await secondaryApp.delete();

      // 3. Save Firestore document — admin session untouched
      await widget.fsService.addMember(MemberModel(
        uid:           memberUid,
        name:          _name.text.trim(),
        email:         _email.text.trim(),
        role:          'member',
        lotNumber:     _lot.text.trim(),
        phase:         _block,
        status:        MemberStatus.active,
        contactNumber: _contact.text.trim(),
        address:       _address.text.trim(),
        createdAt:     DateTime.now(),
      ));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Member created. Verification email sent. '
                'Assign them to a lot from Location Mapping to '
                'show their Lot No. and Block in this list.'),
            backgroundColor: Color(0xFF1A7A4A),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      // Clean up secondary app if it exists
      try {
        await Firebase.app('secondary').delete();
      } catch (_) {}
      setState(() {
        _loading = false;
        _error   = _mapAuthError(e.code);
      });
    } catch (e) {
      try {
        await Firebase.app('secondary').delete();
      } catch (_) {}
      setState(() {
        _loading = false;
        _error   = 'An unexpected error occurred: $e';
      });
    }
  }

  InputDecoration _dec(String hint,
          {bool hasError = false}) =>
      InputDecoration(
        hintText:  hint,
        hintStyle: TextStyle(
            fontSize: 13, color: Colors.grey[400]),
        filled:    true,
        fillColor: const Color(0xFFF7F9FC),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 12),
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
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(
                color: Color(0xFFCC2200))),
      );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
      child: SizedBox(
        width: 540,
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                // ── Title ─────────────────────────────
                const Text('Add New Member',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _navy)),
                const SizedBox(height: 4),
                Text(
                  'Creates a login account for the mobile app.',
                  style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.grey[500]),
                ),
                const SizedBox(height: 20),

                // ── Error banner ──────────────────────
                if (_error != null) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10),
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFFFFF0EE),
                      borderRadius:
                          BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(
                                  0xFFCC2200)
                              .withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                            Icons.error_outline,
                            size: 15,
                            color:
                                Color(0xFFCC2200)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error!,
                              style:
                                  const TextStyle(
                                fontSize: 12.5,
                                color: Color(
                                    0xFFCC2200),
                              )),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // ── Name + Email ──────────────────────
                Row(children: [
                  Expanded(
                    child: _Field(
                      ctrl:  _name,
                      label: 'Full Name',
                      hint:  'Juan dela Cruz',
                      dec:   _dec,
                      validator: (v) =>
                          v!.isEmpty
                              ? 'Required'
                              : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _Field(
                      ctrl:  _email,
                      label: 'Email Address',
                      hint:  'juan@email.com',
                      dec:   _dec,
                      keyboardType:
                          TextInputType.emailAddress,
                      validator: (v) {
                        if (v!.isEmpty)
                          return 'Required';
                        if (!v.contains('@'))
                          return 'Invalid email';
                        return null;
                      },
                    ),
                  ),
                ]),
                const SizedBox(height: 14),

                // ── Password ──────────────────────────
                _FieldLabel('Temporary Password'),
                const SizedBox(height: 6),
                TextFormField(
                  controller:  _password,
                  obscureText: _obscure,
                  validator: (v) {
                    if (v == null || v.isEmpty)
                      return 'Required';
                    if (v.length < 6)
                      return 'Minimum 6 characters';
                    return null;
                  },
                  style: const TextStyle(
                      fontSize: 13),
                  decoration: _dec(
                          'Min. 6 characters')
                      .copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons
                                .visibility_outlined
                            : Icons
                                .visibility_off_outlined,
                        size: 18,
                        color: Colors.grey[500],
                      ),
                      onPressed: () => setState(
                          () =>
                              _obscure =
                                  !_obscure),
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // ── Lot + Phase ───────────────────────
                Row(children: [
                  Expanded(
                    child: _Field(
                      ctrl:  _lot,
                      label: 'Lot Number',
                      hint:  'Lot 12 Blk 3',
                      dec:   _dec,
                      validator: (v) =>
                          v!.isEmpty
                              ? 'Required'
                              : null,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        const _FieldLabel('Block'),
                        const SizedBox(height: 6),
                        DropdownButtonFormField<
                            String>(
                          value: _block,
                          items: [
                            'Block 1',
                            'Block 2',
                            'Block 3',
                            'Block 4',
                            'Block 5',
                            'Block 6',
                            'Block 7',
                            'Block 8',
                            'Block 9',
                          ]
                              .map((p) =>
                                  DropdownMenuItem(
                                    value: p,
                                    child: Text(p),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(
                                  () => _block =
                                      v!),
                          decoration:
                              _dec('Select block'),
                        ),
                      ],
                    ),
                  ),
                ]),
                const SizedBox(height: 14),

                // ── Contact ───────────────────────────
                _Field(
                  ctrl:  _contact,
                  label: 'Contact Number',
                  hint:  '09XX-XXX-XXXX',
                  dec:   _dec,
                ),
                const SizedBox(height: 14),

                // ── Address ───────────────────────────
                _Field(
                  ctrl:  _address,
                  label: 'Address',
                  hint:  'House number, street...',
                  dec:   _dec,
                ),
                const SizedBox(height: 20),

                // ── Info notice ───────────────────────
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        const Color(0xFFE8F4FF),
                    borderRadius:
                        BorderRadius.circular(8),
                    border: Border.all(
                        color: const Color(
                                0xFF2E6BE6)
                            .withOpacity(0.2)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 15,
                          color:
                              Color(0xFF2E6BE6)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'The member will use this email and password to log in on the mobile app. Lot Number and Block entered here are provisional — they will not appear in the Homeowner Records table until this member is assigned a lot from Location Mapping.',
                          style: TextStyle(
                              fontSize: 12.5,
                              color: Color(
                                  0xFF1A4A9C)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Actions ───────────────────────────
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
                      style:
                          ElevatedButton.styleFrom(
                        backgroundColor: _navy,
                        foregroundColor:
                            Colors.white,
                        shape:
                            RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                            8)),
                        padding: const EdgeInsets
                            .symmetric(
                            horizontal: 24,
                            vertical: 12),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(
                                      strokeWidth:
                                          2,
                                      color: Colors
                                          .white))
                          : const Text(
                              'Create Member'),
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
}

// ── Small shared widgets ──────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF0D2A5C)));
}

class _Field extends StatelessWidget {
  final TextEditingController           ctrl;
  final String                          label, hint;
  final InputDecoration Function(String) dec;
  final String? Function(String?)?       validator;
  final TextInputType                    keyboardType;

  const _Field({
    required this.ctrl,
    required this.label,
    required this.hint,
    required this.dec,
    this.validator,
    this.keyboardType = TextInputType.text,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _FieldLabel(label),
      const SizedBox(height: 6),
      TextFormField(
        controller:   ctrl,
        validator:    validator,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 13),
        decoration:   dec(hint),
      ),
    ],
  );
}