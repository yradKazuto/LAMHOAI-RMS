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
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, user),
            Expanded(
              child: user == null
                  ? const Center(child: CircularProgressIndicator())
                  : _buildBody(context, user, auth),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context, UserModel? user) {
    final initials = _initials(user?.displayName ?? '');

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_blue800, _blue700],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      child: Column(
        children: [
          Row(
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
            ],
          ),
          const SizedBox(height: 16),
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
                  color: Colors.white,
                ),
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
          const SizedBox(height: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
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
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
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
          _buildAccountInfo(user),
          const SizedBox(height: 12),
          _buildLotInfo(user),
          const SizedBox(height: 12),
          _buildContactInfo(user),
          const SizedBox(height: 12),
          _buildSecuritySection(context),
          const SizedBox(height: 12),
          _buildSignOutButton(context, auth),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Account info card ─────────────────────────────────────────────────────

  Widget _buildAccountInfo(UserModel user) {
    return _card(
      icon: Icons.person_outline,
      title: 'ACCOUNT INFORMATION',
      children: [
        _infoRow('Full Name', user.displayName),
        _infoRow('Email Address', user.email),
        _infoRow('Member ID', user.uid, mono: true, isLast: true),
      ],
    );
  }

  // ── Lot info card ─────────────────────────────────────────────────────────

  Widget _buildLotInfo(UserModel user) {
    final isActive =
        (user.status ?? 'active').toLowerCase() == 'active';

    final memberSince = user.createdAt != null
        ? DateFormat('MMMM d, yyyy').format(user.createdAt!)
        : '—';

    return _card(
      icon: Icons.home_outlined,
      title: 'LOT INFORMATION',
      children: [
        _infoRow('Lot Number', user.lotNumber ?? '—'),
        _infoRow('Phase', user.phase ?? '—'),
        _infoRow('Member Since', memberSince),
        _infoRowWidget(
          'Status',
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: isActive ? _successBg : _dangerBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              (user.status ?? 'Active')[0].toUpperCase() +
                  (user.status ?? 'active').substring(1),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: isActive ? _success : _danger,
              ),
            ),
          ),
          isLast: true,
        ),
      ],
    );
  }

  // ── Contact info card ─────────────────────────────────────────────────────

  Widget _buildContactInfo(UserModel user) {
    return _card(
      icon: Icons.contact_phone_outlined,
      title: 'CONTACT INFORMATION',
      children: [
        _infoRow('Address', user.address ?? '—'),
        _infoRow('Contact No.', user.contactNumber ?? '—',
            isLast: true),
      ],
    );
  }

  // ── Security section ──────────────────────────────────────────────────────

  Widget _buildSecuritySection(BuildContext context) {
    return _card(
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
                  child: Text(
                    'Change Password',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: _gray800),
                  ),
                ),
                Icon(Icons.chevron_right,
                    size: 16, color: _gray400),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Sign out button ───────────────────────────────────────────────────────

  Widget _buildSignOutButton(
      BuildContext context, AuthProvider auth) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          final confirmed = await _confirmSignOut(context);
          if (confirmed == true) await auth.signOut();
        },
        icon: const Icon(Icons.logout, size: 16, color: _danger),
        label: const Text(
          'Sign Out',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: _danger,
          ),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 13),
          side: const BorderSide(color: _danger, width: 1.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  // ── Card wrapper ──────────────────────────────────────────────────────────

  Widget _card({
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
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _blue600,
                    letterSpacing: 0.5,
                  ),
                ),
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

  Widget _infoRow(String label, String value,
      {bool mono = false, bool isLast = false}) {
    return _infoRowWidget(
      label,
      Text(
        value,
        textAlign: TextAlign.right,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: _gray800,
          fontFamily: mono ? 'monospace' : null,
        ),
      ),
      isLast: isLast,
    );
  }

  Widget _infoRowWidget(String label, Widget valueWidget,
      {bool isLast = false}) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(
                bottom: BorderSide(color: _gray100)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 11, color: _gray400)),
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
        title: const Text(
          'Sign Out',
          style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 16,
              color: _gray800),
        ),
        content: const Text(
          'Are you sure you want to sign out?',
          style: TextStyle(fontSize: 12, color: _gray600),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: _gray600)),
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