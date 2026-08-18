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

class UserManagementScreen extends StatelessWidget {
  const UserManagementScreen({super.key});

  static const Color _navy   = Color(0xFF0D2A5C);
  static const Color _accent = Color(0xFF2E6BE6);
  static const Color _bg     = Color(0xFFF0F4FB);

  @override
  Widget build(BuildContext context) {
    final _fs = FirestoreService();

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
                    const Text('User Management',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: _navy)),
                    const SizedBox(height: 2),
                    Text('Manage admin panel staff accounts',
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600])),
                  ],
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => _showAddStaffDialog(context, _fs),
                  icon: const Icon(Icons.person_add_outlined,
                      size: 18),
                  label: const Text('Add Staff'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _navy,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // ── Role legend ───────────────────────────────────────────────────
            Row(
              children: [
                _RoleBadge(role: UserRole.admin),
                const SizedBox(width: 8),
                _RoleBadge(role: UserRole.accountant),
                const SizedBox(width: 8),
                _RoleBadge(role: UserRole.officer),
              ],
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

                  final staff = snap.data ?? [];

                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFFE0E8F4)),
                    ),
                    child: Column(
                      children: [
                        // Table header
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

                        if (staff.isEmpty)
                          const Expanded(
                            child: Center(
                              child: Text(
                                  'No staff accounts found.',
                                  style: TextStyle(
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

  static const Color _navy = Color(0xFF0D2A5C);

  const _StaffRow({
    required this.staff,
    required this.fs,
    required this.context,
  });

  @override
  Widget build(BuildContext context) {
    final auth       = context.read<AuthProvider>();
    final isSelf     = staff.uid == auth.userModel?.uid;

    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 14),
      child: Row(
        children: [
          // Name
          Expanded(
            flex: 3,
            child: Row(
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
                              color: Color(0xFF0D2A5C)),
                          overflow: TextOverflow.ellipsis),
                      if (isSelf)
                        const Text('(You)',
                            style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF2E6BE6))),
                    ],
                  ),
                ),
              ],
            ),
          ),
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
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: staff.isActive
                    ? const Color(0xFFEAF7F0)
                    : const Color(0xFFF0F4FB),
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
            ),
          ),
          // Actions
          SizedBox(
            width: 100,
            child: isSelf
                ? null
                : Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      // Change role
                      IconButton(
                        icon: const Icon(
                            Icons.manage_accounts_outlined,
                            size: 18,
                            color: Color(0xFF2E6BE6)),
                        tooltip: 'Change role',
                        onPressed: () =>
                            _showChangeRoleDialog(
                                context, staff, fs),
                      ),
                      // Activate / Deactivate
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
                        tooltip: staff.isActive
                            ? 'Deactivate'
                            : 'Activate',
                        onPressed: () =>
                            _toggleActive(context, staff, fs),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Color _roleColor(UserRole role) {
    switch (role) {
      case UserRole.admin:      return const Color(0xFF0D2A5C);
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
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        title: Text('Change role for ${s.displayName}',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0D2A5C))),
        content: StatefulBuilder(
          builder: (context, setState) =>
              Column(
            mainAxisSize: MainAxisSize.min,
            children: [UserRole.admin, UserRole.accountant, UserRole.officer]
                .map((r) => RadioListTile<UserRole>(
                      value: r,
                      groupValue: selected,
                      title: Text(r.label),
                      activeColor: const Color(0xFF0D2A5C),
                      onChanged: (v) =>
                          setState(() => selected = v),
                    ))
                .toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (selected != null) {
                await fs.updateStaffRole(s.uid, selected!);
              }
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0D2A5C),
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
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        title: Text(
            '${s.isActive ? 'Deactivate' : 'Activate'} ${s.displayName}?',
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0D2A5C))),
        content: Text(
            'Are you sure you want to $action this account?',
            style: const TextStyle(fontSize: 13.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
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

  static const Color _navy = Color(0xFF0D2A5C);

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
            color: Color(0xFF2E6BE6), width: 1.5)),
    errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFFCC2200))),
  );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14)),
      child: SizedBox(
        width: 480,
        child: Padding(
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
          color: Color(0xFF0D2A5C)));
}

class _RoleBadge extends StatelessWidget {
  final UserRole role;
  const _RoleBadge({required this.role});

  Color get _color {
    switch (role) {
      case UserRole.admin:      return const Color(0xFF0D2A5C);
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