// features/users/screens/user_management_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../../core/models/staff_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/providers/auth_provider.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/models/audit_log_model.dart';
import '../../../core/services/settings_service.dart';

class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() =>
      _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  final _fs     = FirestoreService();
  final _search = TextEditingController();

  String  _searchQuery  = '';
  String? _roleFilter;
  String? _statusFilter;

  static const Color _navy   = Color(0xFF1E293B);
  static const Color _accent = Color(0xFF2563EB);
  static const Color _bg     = Color(0xFFF4F7FB);

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<StaffModel> _filtered(List<StaffModel> all) {
    return all.where((s) {
      final q = _searchQuery.toLowerCase();
      final matchSearch = q.isEmpty ||
          s.displayName.toLowerCase().contains(q) ||
          s.email.toLowerCase().contains(q);
      final matchRole = _roleFilter == null ||
          s.role.name == _roleFilter;
      final matchStatus = _statusFilter == null ||
          (_statusFilter == 'active' ? s.isActive : !s.isActive);
      return matchSearch && matchRole && matchStatus;
    }).toList();
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
            // ── Header ───────────────────────────────────────────────────────
            LayoutBuilder(
              builder: (context, constraints) {
                final titleBlock = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('User Management',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: _navy)),
                    const SizedBox(height: 2),
                    Text('Manage admin panel staff accounts',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600])),
                  ],
                );

                final addButton = ElevatedButton.icon(
                  onPressed: () =>
                      _showAddStaffDialog(context, _fs),
                  icon: const Icon(Icons.person_add_outlined,
                      size: 18),
                  label: const Text('Add Staff'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _navy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(8)),
                  ),
                );

                if (constraints.maxWidth < 560) {
                  return Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      titleBlock,
                      const SizedBox(height: 12),
                      SizedBox(
                          width: double.infinity,
                          child: addButton),
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: titleBlock),
                    addButton,
                  ],
                );
              },
            ),
            const SizedBox(height: 24),

            // ── Filters ───────────────────────────────────────────────────────
            LayoutBuilder(
              builder: (context, constraints) {
                final searchField = TextField(
                  controller: _search,
                  onChanged: (v) =>
                      setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Search name or email...',
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
                );

                final hasActiveFilter =
                    _searchQuery.isNotEmpty ||
                    _roleFilter != null ||
                    _statusFilter != null;

                final clearButton = TextButton.icon(
                  onPressed: () => setState(() {
                    _search.clear();
                    _searchQuery  = '';
                    _roleFilter   = null;
                    _statusFilter = null;
                  }),
                  icon: const Icon(Icons.clear, size: 15),
                  label: const Text('Clear all'),
                  style: TextButton.styleFrom(
                      foregroundColor: Colors.grey[600]),
                );

                // A 280px search box plus two dropdowns can't share
                // one line below this width — stack the search field
                // full-width, then wrap the rest underneath.
                final narrow = constraints.maxWidth < 620;

                void openFilterSheet() {
                  String? tempRole = _roleFilter;
                  String? tempStatus = _statusFilter;

                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (sheetCtx) => StatefulBuilder(
                      builder: (sheetCtx, setSheetState) => SafeArea(
                        child: Padding(
                          padding:
                              const EdgeInsets.fromLTRB(20, 14, 20, 20),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Center(
                                child: Container(
                                  width: 36,
                                  height: 4,
                                  margin:
                                      const EdgeInsets.only(bottom: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[300],
                                    borderRadius:
                                        BorderRadius.circular(2),
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  const Text('Filter Staff',
                                      style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: _navy)),
                                  const Spacer(),
                                  if (tempRole != null ||
                                      tempStatus != null)
                                    TextButton(
                                      onPressed: () => setSheetState(() {
                                        tempRole = null;
                                        tempStatus = null;
                                      }),
                                      child: const Text('Reset'),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text('Role',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[600])),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: double.infinity,
                                child: _DropdownFilter(
                                  value: tempRole,
                                  hint: 'All Roles',
                                  items: const [
                                    DropdownMenuItem(
                                        value: null,
                                        child: Text('All Roles')),
                                    DropdownMenuItem(
                                        value: 'admin',
                                        child: Text('Admin')),
                                    DropdownMenuItem(
                                        value: 'accountant',
                                        child: Text('Accountant')),
                                    DropdownMenuItem(
                                        value: 'officer',
                                        child: Text('Officer')),
                                  ],
                                  onChanged: (v) =>
                                      setSheetState(() => tempRole = v),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text('Status',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[600])),
                              const SizedBox(height: 6),
                              SizedBox(
                                width: double.infinity,
                                child: _DropdownFilter(
                                  value: tempStatus,
                                  hint: 'All Statuses',
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
                                  ],
                                  onChanged: (v) =>
                                      setSheetState(() => tempStatus = v),
                                ),
                              ),
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _roleFilter = tempRole;
                                      _statusFilter = tempStatus;
                                    });
                                    Navigator.pop(sheetCtx);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _navy,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(8)),
                                  ),
                                  child: const Text('Apply Filters'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }

                final activeFilterCount =
                    (_roleFilter != null ? 1 : 0) +
                    (_statusFilter != null ? 1 : 0);

                // On phones, replace the two dropdowns with a single
                // "Filter" button that opens a bottom sheet — two
                // full-size dropdowns plus Clear was a lot of buttons
                // for a small screen.
                final filterButton = Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: openFilterSheet,
                    child: Container(
                      height: 42,
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: activeFilterCount > 0
                                ? _accent
                                : const Color(0xFFD0DBEE)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.filter_list,
                              size: 18,
                              color: activeFilterCount > 0
                                  ? _accent
                                  : Colors.grey[600]),
                          const SizedBox(width: 6),
                          Text(
                              activeFilterCount > 0
                                  ? 'Filter ($activeFilterCount)'
                                  : 'Filter',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: activeFilterCount > 0
                                      ? _accent
                                      : const Color(0xFF1A2B4A))),
                        ],
                      ),
                    ),
                  ),
                );

                if (narrow) {
                  return Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(child: searchField),
                          const SizedBox(width: 10),
                          filterButton,
                        ],
                      ),
                      if (hasActiveFilter) ...[
                        const SizedBox(height: 10),
                        clearButton,
                      ],
                    ],
                  );
                }

                return Row(
                  children: [
                    SizedBox(width: 280, child: searchField),
                    const SizedBox(width: 12),
                    _FilterPopoverButton(
                      activeFilterCount: activeFilterCount,
                      panelBuilder: (context, setPanelState, close) => [
                        _PopoverFilterField(
                          label: 'Role',
                          child: _FilterChipGroup<String?>(
                            value: _roleFilter,
                            options: const [
                              MapEntry(null, 'All Roles'),
                              MapEntry('admin', 'Admin'),
                              MapEntry('accountant', 'Accountant'),
                              MapEntry('officer', 'Officer'),
                            ],
                            onChanged: (v) {
                              setState(() => _roleFilter = v);
                              setPanelState(() {});
                            },
                          ),
                        ),
                        _PopoverFilterField(
                          label: 'Status',
                          child: _FilterChipGroup<String?>(
                            value: _statusFilter,
                            options: const [
                              MapEntry(null, 'All Statuses'),
                              MapEntry('active', 'Active'),
                              MapEntry('inactive', 'Inactive'),
                            ],
                            onChanged: (v) {
                              setState(() => _statusFilter = v);
                              setPanelState(() {});
                            },
                          ),
                        ),
                      ],
                      onReset: () => setState(() {
                        _roleFilter = null;
                        _statusFilter = null;
                      }),
                    ),
                    if (hasActiveFilter) ...[
                      const SizedBox(width: 12),
                      clearButton,
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 16),

            // ── Staff table ───────────────────────────────────────────────────
            Expanded(
              child: StreamBuilder<List<StaffModel>>(
                stream: _fs.streamStaff(),
                builder: (context, snap) {
                  if (snap.connectionState ==
                      ConnectionState.waiting) {
                    return const Center(
                        child: CircularProgressIndicator());
                  }
                  if (snap.hasError) {
                    return Center(
                        child: Text('Error: ${snap.error}',
                            style: const TextStyle(
                                color: Colors.red)));
                  }

                  final staff = _filtered(snap.data ?? []);

                  return LayoutBuilder(
                    builder: (context, constraints) {
                      // Name/Email/Role/Status plus a 100px action
                      // column can't stay readable below this width —
                      // switch each row to a stacked card instead.
                      final compact = constraints.maxWidth < 700;

                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: const Color(0xFFE0E8F4)),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1A4A9C)
                                  .withOpacity(0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            if (!compact) ...[
                              Container(
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
                                    Expanded(flex: 2, child: _TH('Role')),
                                    Expanded(flex: 2, child: _TH('Status')),
                                    SizedBox(width: 100),
                                  ],
                                ),
                              ),
                              const Divider(
                                  height: 1,
                                  color: Color(0xFFE0E8F4)),
                            ],

                            if (staff.isEmpty)
                              Expanded(
                                child: Center(
                                  child: Text(
                                      (snap.data ?? []).isEmpty
                                          ? 'No staff accounts found.'
                                          : 'No staff match these filters.',
                                      style: const TextStyle(
                                          color: Colors.grey)),
                                ),
                              )
                            else
                              Expanded(
                                child: ListView.separated(
                                  itemCount: staff.length,
                                  separatorBuilder: (_, __) =>
                                      const Divider(
                                          height: 1,
                                          color: Color(0xFFEEF2F9)),
                                  itemBuilder: (context, i) =>
                                      _StaffRow(
                                    staff:    staff[i],
                                    fs:       _fs,
                                    context:  context,
                                    compact:  compact,
                                  ),
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

  void _showAddStaffDialog(
      BuildContext context, FirestoreService fs) {
    showDialog(
      context: context,
      builder: (_) => _AddStaffDialog(fs: fs),
    );
  }
}

// ── Staff table row ───────────────────────────────────────────────────────────
class _StaffRow extends StatelessWidget {
  final StaffModel     staff;
  final FirestoreService fs;
  final BuildContext   context;
  final bool           compact;

  static const Color _navy = Color(0xFF1E293B);

  const _StaffRow({
    required this.staff,
    required this.fs,
    required this.context,
    this.compact = false,
  });

  Widget _avatarAndName(bool isSelf) => Row(
    children: [
      CircleAvatar(
        radius: 16,
        backgroundColor: _roleColor(staff.role)
            .withOpacity(0.12),
        child: Text(
          staff.displayName.isNotEmpty
              ? staff.displayName[0].toUpperCase()
              : '?',
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _roleColor(staff.role)),
        ),
      ),
      const SizedBox(width: 10),
      Flexible(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(staff.displayName,
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF1E293B)),
                overflow: TextOverflow.ellipsis),
            if (isSelf)
              const Text('(You)',
                  style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF2563EB))),
          ],
        ),
      ),
    ],
  );

  Widget _statusPill() => Container(
    padding: const EdgeInsets.symmetric(
        horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: staff.isActive
          ? const Color(0xFFEAF7F0)
          : const Color(0xFFF4F7FB),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      staff.isActive ? 'Active' : 'Inactive',
      textAlign: TextAlign.center,
      style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: staff.isActive
              ? const Color(0xFF1A7A4A)
              : Colors.grey),
    ),
  );

  List<Widget> _actionButtons(bool isSelf) => isSelf
      ? const []
      : [
          IconButton(
            icon: const Icon(Icons.manage_accounts_outlined,
                size: 18, color: Color(0xFF2563EB)),
            tooltip: 'Change role',
            onPressed: () =>
                _showChangeRoleDialog(context, staff, fs),
          ),
          IconButton(
            icon: Icon(
              staff.isActive
                  ? Icons.person_off_outlined
                  : Icons.person_outlined,
              size: 18,
              color: staff.isActive
                  ? const Color(0xFFCC2200)
                  : const Color(0xFF1A7A4A),
            ),
            tooltip:
                staff.isActive ? 'Deactivate' : 'Activate',
            onPressed: () => _toggleActive(context, staff, fs),
          ),
        ];

  @override
  Widget build(BuildContext context) {
    final auth   = context.read<AuthProvider>();
    final isSelf = staff.uid == auth.userModel?.uid;

    if (compact) {
      // Stacked card — Name/Email/Role/Status plus a 100px action
      // column don't have room to stay readable at phone widths.
      return Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: staff.isActive
                  ? const Color(0xFF1A7A4A)
                  : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _avatarAndName(isSelf)),
                ..._actionButtons(isSelf),
              ],
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 42),
              child: Text(staff.email,
                  style: TextStyle(
                      fontSize: 13, color: Colors.grey[600]),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.only(left: 42),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _RoleBadge(role: staff.role),
                  _statusPill(),
                ],
              ),
            ),
          ],
        ),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: staff.isActive
                ? const Color(0xFF1A7A4A)
                : Colors.transparent,
            width: 3,
          ),
        ),
      ),
      child: Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 14),
      child: Row(
        children: [
          // Name
          Expanded(flex: 3, child: _avatarAndName(isSelf)),
          // Email
          Expanded(
            flex: 3,
            child: Text(staff.email,
                style: TextStyle(
                    fontSize: 13, color: Colors.grey[600]),
                overflow: TextOverflow.ellipsis),
          ),
          // Role
          Expanded(
            flex: 2,
            child: _RoleBadge(role: staff.role),
          ),
          // Status
          Expanded(flex: 2, child: _statusPill()),
          // Actions
          SizedBox(
            width: 100,
            child: isSelf
                ? null
                : Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: _actionButtons(isSelf),
                  ),
          ),
        ],
      ),
      ),
    );
  }

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:      return const Color(0xFF1E293B);
      case UserRole.accountant: return const Color(0xFF1A7A4A);
      case UserRole.officer:    return const Color(0xFF7A3A1A);
      default:                  return Colors.grey;
    }
  }

  Future<void> _showChangeRoleDialog(
      BuildContext ctx, StaffModel s, FirestoreService fs) async {
    UserRole? selected = s.role;
    await showDialog(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        title: Text('Change role for ${s.displayName}',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B))),
        content: StatefulBuilder(
          builder: (context, setState) =>
              Column(
            mainAxisSize: MainAxisSize.min,
            children: [UserRole.admin, UserRole.accountant, UserRole.officer]
                .map((r) => RadioListTile<UserRole>(
                      value: r,
                      groupValue: selected,
                      title: Text(r.label),
                      activeColor: const Color(0xFF1E293B),
                      onChanged: (v) =>
                          setState(() => selected = v),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (selected != null) {
                await fs.updateStaffRole(s.uid, selected!);
              }
              Navigator.pop(dialogCtx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleActive(
      BuildContext ctx, StaffModel s, FirestoreService fs) async {
    final action = s.isActive ? 'deactivate' : 'activate';
    final confirm = await showDialog<bool>(
      context: ctx,
      builder: (dialogCtx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        title: Text(
            '${s.isActive ? 'Deactivate' : 'Activate'} ${s.displayName}?',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B))),
        content: Text(
            'Are you sure you want to $action this account?',
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
              backgroundColor: s.isActive
                  ? const Color(0xFFCC2200)
                  : const Color(0xFF1A7A4A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
                s.isActive ? 'Deactivate' : 'Activate'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await fs.setStaffActive(s.uid, !s.isActive);
    }
  }
}

// ── Add staff dialog ──────────────────────────────────────────────────────────
class _AddStaffDialog extends StatefulWidget {
  final FirestoreService fs;
  const _AddStaffDialog({required this.fs});
  @override
  State<_AddStaffDialog> createState() => _AddStaffDialogState();
}

class _AddStaffDialogState extends State<_AddStaffDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name    = TextEditingController();
  final _email   = TextEditingController();
  final _pass    = TextEditingController();
  UserRole _role  = UserRole.officer;
  bool     _loading = false;
  String?  _error;

  static const Color _navy = Color(0xFF1E293B);

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() { _loading = true; _error = null; });
    try {
      // Create Firebase Auth user
      final cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email:    _email.text.trim(),
        password: _pass.text,
      );

      // Save to Firestore
      await widget.fs.addStaff(StaffModel(
        uid:         cred.user!.uid,
        displayName: _name.text.trim(),
        email:       _email.text.trim(),
        role:        _role,
        isActive:    true,
        createdAt:   DateTime.now(),
      ));

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Staff account created successfully.'),
            backgroundColor: Color(0xFF1A7A4A),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _loading = false;
        _error   = _mapAuthError(e.code);
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error   = 'An error occurred. Please try again.';
      });
    }
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

  InputDecoration _dec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(fontSize: 13, color: Colors.grey[400]),
    filled: true,
    fillColor: const Color(0xFFF7F9FC),
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD0DBEE))),
    enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFD0DBEE))),
    focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(
            color: Color(0xFF2563EB), width: 1.5)),
    errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFCC2200))),
  );

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth =
        screenSize.width > 540 ? 480.0 : screenSize.width * 0.92;

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
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Add Staff Account',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _navy)),
                const SizedBox(height: 4),
                Text(
                  'Creates a Firebase Auth account and staff profile.',
                  style: TextStyle(
                      fontSize: 12.5, color: Colors.grey[500]),
                ),
                const SizedBox(height: 20),

                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0EE),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFFCC2200)
                              .withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            size: 15,
                            color: Color(0xFFCC2200)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error!,
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFFCC2200))),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Full name
                _Label('Full Name'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _name,
                  validator: (v) =>
                      v!.isEmpty ? 'Required' : null,
                  style: const TextStyle(fontSize: 13.5),
                  decoration: _dec('HOA Officer'),
                ),
                const SizedBox(height: 14),

                // Email
                _Label('Email Address'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v!.isEmpty) return 'Required';
                    if (!v.contains('@')) return 'Invalid email';
                    return null;
                  },
                  style: const TextStyle(fontSize: 13.5),
                  decoration: _dec('officer@lamhoai.com'),
                ),
                const SizedBox(height: 14),

                // Password
                _Label('Temporary Password'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _pass,
                  obscureText: true,
                  validator: (v) {
                    if (v!.isEmpty) return 'Required';
                    if (v.length < 6) {
                      return 'Minimum 6 characters';
                    }
                    return null;
                  },
                  style: const TextStyle(fontSize: 13.5),
                  decoration: _dec('Min. 6 characters'),
                ),
                const SizedBox(height: 14),

                // Role
                _Label('Role'),
                const SizedBox(height: 6),
                DropdownButtonFormField<UserRole>(
                  value: _role,
                  style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF1A2B4A)),
                  decoration: _dec(''),
                  items: [
                    UserRole.admin,
                    UserRole.accountant,
                    UserRole.officer,
                  ]
                      .map((r) => DropdownMenuItem(
                            value: r,
                            child: Text(r.label),
                          ))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _role = v);
                  },
                ),
                const SizedBox(height: 24),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel',
                          style:
                              TextStyle(color: Colors.grey)),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton(
                      onPressed: _loading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _navy,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                      child: _loading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white))
                          : const Text('Create Account'),
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

// ── Dropdown filter (role / status) ──────────────────────────────────────────
// ── Filter popover button (desktop) ──────────────────────────────────────────
// Anchors a "Filter" button to a floating panel below it via
// CompositedTransformTarget/Follower + an OverlayEntry — a proper
// desktop dropdown panel, rather than reusing the mobile bottom sheet
// on a screen wide enough that a sheet sliding up from the bottom
// edge would look out of place.
class _FilterPopoverButton extends StatefulWidget {
  final int activeFilterCount;
  final List<Widget> Function(
    BuildContext context,
    void Function(void Function()) setPanelState,
    VoidCallback close,
  ) panelBuilder;
  final VoidCallback onReset;

  const _FilterPopoverButton({
    required this.activeFilterCount,
    required this.panelBuilder,
    required this.onReset,
  });

  @override
  State<_FilterPopoverButton> createState() => _FilterPopoverButtonState();
}

class _FilterPopoverButtonState extends State<_FilterPopoverButton> {
  static const Color _navy   = Color(0xFF1E293B);
  static const Color _accent = Color(0xFF2563EB);

  final LayerLink _link = LayerLink();
  OverlayEntry? _entry;

  void _toggle() => _entry == null ? _open() : _close();

  void _open() {
    final overlay = Overlay.of(context);
    _entry = OverlayEntry(
      builder: (overlayContext) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: _close,
            ),
          ),
          CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            offset: const Offset(0, 48),
            child: Align(
              alignment: Alignment.topLeft,
              child: Material(
                color: Colors.transparent,
                child: GestureDetector(
                  onTap: () {},
                  child: StatefulBuilder(
                    builder: (panelContext, setPanelState) => Container(
                      width: 300,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: const Color(0xFFE0E8F4)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.12),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text('Filters',
                                  style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: _navy)),
                              const Spacer(),
                              TextButton(
                                onPressed: () {
                                  widget.onReset();
                                  setPanelState(() {});
                                },
                                style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: const Size(0, 0),
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap),
                                child: const Text('Reset',
                                    style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          ...widget.panelBuilder(
                              panelContext, setPanelState, _close),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _close,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _navy,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 10),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(8)),
                              ),
                              child: const Text('Done',
                                  style: TextStyle(fontSize: 13)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(_entry!);
    setState(() {});
  }

  void _close() {
    _entry?.remove();
    _entry = null;
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _entry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: _toggle,
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: widget.activeFilterCount > 0
                      ? _accent
                      : const Color(0xFFD0DBEE)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.filter_list,
                    size: 18,
                    color: widget.activeFilterCount > 0
                        ? _accent
                        : Colors.grey[600]),
                const SizedBox(width: 6),
                Text(
                    widget.activeFilterCount > 0
                        ? 'Filter (${widget.activeFilterCount})'
                        : 'Filter',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: widget.activeFilterCount > 0
                            ? _accent
                            : const Color(0xFF1A2B4A))),
                const SizedBox(width: 4),
                Icon(Icons.expand_more, size: 16, color: Colors.grey[500]),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// A labeled filter field inside a popover panel.
// A row of tappable chips for picking one filter value — used inside
// popover panels instead of a nested DropdownButton, since a dropdown
// menu opening from inside a custom OverlayEntry panel can end up
// rendering behind the panel itself (both insert into the same
// Overlay, and the dropdown's route doesn't reliably stack above a
// plain OverlayEntry). A flat chip list avoids that entirely and is
// a one-click selection instead of open-menu-then-click.
class _FilterChipGroup<T> extends StatelessWidget {
  final T value;
  final List<MapEntry<T, String>> options;
  final ValueChanged<T> onChanged;

  const _FilterChipGroup({
    required this.value,
    required this.options,
    required this.onChanged,
  });

  static const Color _accent = Color(0xFF2563EB);

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 8,
    runSpacing: 8,
    children: options.map((opt) {
      final selected = opt.key == value;
      return InkWell(
        onTap: () => onChanged(opt.key),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? _accent.withOpacity(0.1)
                : const Color(0xFFF7F9FC),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
                color: selected ? _accent : const Color(0xFFD0DBEE)),
          ),
          child: Text(opt.value,
              style: TextStyle(
                  fontSize: 12.5,
                  color:
                      selected ? _accent : const Color(0xFF1A2B4A),
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.w400)),
        ),
      );
    }).toList(),
  );
}

class _PopoverFilterField extends StatelessWidget {
  final String label;
  final Widget child;
  const _PopoverFilterField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600])),
        const SizedBox(height: 5),
        SizedBox(width: double.infinity, child: child),
      ],
    ),
  );
}

class _DropdownFilter extends StatelessWidget {
  final String?                         value;
  final String                          hint;
  final List<DropdownMenuItem<String?>> items;
  final void Function(String?)          onChanged;

  const _DropdownFilter({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

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
      child: DropdownButton<String?>(
        value: value,
        hint: Text(hint,
            style: TextStyle(fontSize: 13, color: Colors.grey[500])),
        style: const TextStyle(
            fontSize: 13, color: Color(0xFF1A2B4A)),
        icon: const Icon(Icons.expand_more, size: 18),
        items: items,
        onChanged: onChanged,
      ),
    ),
  );
}

// ── Shared small widgets ──────────────────────────────────────────────────────
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

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: Color(0xFF1E293B)));
}

class _RoleBadge extends StatelessWidget {
  final UserRole role;
  const _RoleBadge({required this.role});

  Color get _color {
    switch (role) {
      case UserRole.admin:      return const Color(0xFF1E293B);
      case UserRole.accountant: return const Color(0xFF1A7A4A);
      case UserRole.officer:    return const Color(0xFF7A3A1A);
      default:                  return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding:
        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: _color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _color.withOpacity(0.3)),
    ),
    child: Text(role.label,
        style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: _color)),
  );
}