// lib/features/profile/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/models/user_model.dart';
import '../../core/providers/auth_provider.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const _blue800   = Color(0xFF0F2547);
  static const _blue700   = Color(0xFF1A3D6B);
  static const _blue600   = Color(0xFF1E52A0);
  static const _blue500   = Color(0xFF2563EB);
  static const _blue200   = Color(0xFFBAD9FD);
  static const _gray50    = Color(0xFFF8FAFC);
  static const _gray100   = Color(0xFFEEF2F7);
  static const _gray400   = Color(0xFF8A9BB0);
  static const _gray600   = Color(0xFF4A5A6E);
  static const _gray800   = Color(0xFF1E2A3A);
  static const _success   = Color(0xFF16A34A);
  static const _successBg = Color(0xFFDCFCE7);
  static const _danger    = Color(0xFFDC2626);
  static const _dangerBg  = Color(0xFFFEE2E2);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      backgroundColor: _gray50,
      body: Column(
        children: [
          _buildHeader(context, user),
          Expanded(
            child: user == null
                ? const Center(child: CircularProgressIndicator())
                : _buildBody(context, user, auth),
          ),
        ],
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, UserModel? user) {
    final initials = _initials(user?.displayName ?? '');
    final isActive = (user?.status ?? 'active').toLowerCase() == 'active';

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_blue800, _blue700],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Back button — left aligned
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
              const SizedBox(height: 20),

              // Avatar + info centered
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: _blue500,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.2), width: 2),
                      ),
                      child: Center(
                        child: Text(
                          initials,
                          style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user?.displayName ?? '—',
                      style: const TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 18,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? '',
                      style: const TextStyle(fontSize: 11, color: _blue200),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            user?.role == UserRole.admin
                                ? 'Administrator'
                                : 'HOA Member',
                            style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isActive
                                ? _success.withOpacity(0.25)
                                : _danger.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? const Color(0xFF4ADE80)
                                      : const Color(0xFFFCA5A5),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isActive ? 'Active' : 'Inactive',
                                style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Body ──────────────────────────────────────────────────────────────────

  Widget _buildBody(
      BuildContext context, UserModel user, AuthProvider auth) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _buildCard(
            icon: Icons.person_outline,
            title: 'ACCOUNT INFORMATION',
            children: [
              _row('Full Name', user.displayName),
              _row('Email Address', user.email),
              _row('Member ID', user.uid, mono: true, isLast: true),
            ],
          ),
          const SizedBox(height: 12),
          _buildCard(
            icon: Icons.home_outlined,
            title: 'LOT INFORMATION',
            children: [
              _row('Lot Number', user.lotNumber ?? '—'),
              _row('Phase', user.phase ?? '—'),
              _row(
                'Member Since',
                user.createdAt != null
                    ? DateFormat('MMMM d, yyyy').format(user.createdAt!)
                    : '—',
              ),
              _rowWidget(
                'Status',
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: (user.status ?? 'active').toLowerCase() == 'active'
                        ? _successBg
                        : _dangerBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    (user.status ?? 'Active')[0].toUpperCase() +
                        (user.status ?? 'active').substring(1),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color:
                          (user.status ?? 'active').toLowerCase() == 'active'
                              ? _success
                              : _danger,
                    ),
                  ),
                ),
                isLast: true,
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildCard(
            icon: Icons.contact_phone_outlined,
            title: 'CONTACT INFORMATION',
            children: [
              _row('Address', user.address ?? '—'),
              _row('Contact No.', user.contactNumber ?? '—', isLast: true),
            ],
          ),
          const SizedBox(height: 12),
          _buildCard(
            icon: Icons.lock_outline,
            title: 'SECURITY',
            children: [
              GestureDetector(
                onTap: () => context.go('/forgot-password'),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 13),
                  child: Row(
                    children: const [
                      Icon(Icons.lock_reset_outlined,
                          size: 16, color: _blue600),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text('Change Password',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: _gray800)),
                      ),
                      Icon(Icons.chevron_right, size: 16, color: _gray400),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final confirmed = await _confirmSignOut(context);
                if (confirmed == true && context.mounted) {
                  await auth.signOut();
                }
              },
              icon: const Icon(Icons.logout, size: 16, color: _danger),
              label: const Text('Sign Out',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: _danger)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                side: const BorderSide(color: _danger, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Card ──────────────────────────────────────────────────────────────────

  Widget _buildCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gray100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(icon, size: 14, color: _blue600),
                const SizedBox(width: 6),
                Text(title,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _blue600,
                        letterSpacing: 0.5)),
              ],
            ),
          ),
          const Divider(height: 1, color: _gray100),
          ...children,
        ],
      ),
    );
  }

  // ── Row helpers ───────────────────────────────────────────────────────────

  Widget _row(String label, String value,
      {bool mono = false, bool isLast = false}) {
    return _rowWidget(
      label,
      Text(
        value,
        textAlign: TextAlign.right,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: _gray800,
            fontFamily: mono ? 'monospace' : null),
      ),
      isLast: isLast,
    );
  }

  Widget _rowWidget(String label, Widget valueWidget,
      {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: _gray100)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 11, color: _gray400)),
          const SizedBox(width: 16),
          Flexible(child: valueWidget),
        ],
      ),
    );
  }

  // ── Utilities ─────────────────────────────────────────────────────────────

  String _initials(String name) {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  Future<bool?> _confirmSignOut(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
        title: const Text('Sign Out',
            style: TextStyle(
                fontFamily: 'Georgia', fontSize: 16, color: _gray800)),
        content: const Text('Are you sure you want to sign out?',
            style: TextStyle(fontSize: 12, color: _gray600)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Cancel', style: TextStyle(color: _gray600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _danger,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Sign Out',
                style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}