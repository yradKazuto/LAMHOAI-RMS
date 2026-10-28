// lib/features/profile/profile_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/models/user_model.dart';
import '../../core/providers/auth_provider.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/utils/status_colors.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_header.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          AppHeader(
            title: 'Profile',
            subtitle: user?.displayName,
            onBack: () =>
                context.canPop() ? context.pop() : context.go('/home'),
          ),
          Expanded(
            child: user == null
                ? const Center(child: CircularProgressIndicator())
                : _buildBody(context, user, auth),
          ),
        ],
      ),
    );
  }

  // ── Body ──────────────────────────────────────────────────────────────────

  Widget _buildBody(
      BuildContext context, UserModel user, AuthProvider auth) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          _buildProfileCard(user),
          const SizedBox(height: 12),
          _buildCard(
            icon: Icons.person_outline,
            title: 'ACCOUNT INFORMATION',
            children: [
              _row('Full Name', user.displayName),
              _row('Email Address', user.email),
              _row('Member ID', user.uid, isLast: true),
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
                AppStatusPill(
                  label: _statusLabel(user.status),
                  color: StatusColors.ink(user.status ?? 'active'),
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
            icon: Icons.feedback_outlined,
            title: 'SEND FEEDBACK',
            children: [
              _rowWidget(
                'Help us improve',
                Text(
                  'Send feedback, suggestions, or report issues',
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                trailing:
                    const Icon(Icons.chevron_right, size: 16, color: AppColors.textMuted),
                isLast: true,
              ),
            ],
            onTap: () => context.go('/home/feedback'),
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
                          size: 16, color: AppColors.primary),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text('Change Password',
                            style: AppTypography.bodyMedium),
                      ),
                      Icon(Icons.chevron_right, size: 16, color: AppColors.textMuted),
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
              icon: const Icon(Icons.logout, size: 16, color: AppColors.error),
              label: const Text('Sign Out',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.error)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 13),
                side: const BorderSide(color: AppColors.error, width: 1.5),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.lg)),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── Profile summary ───────────────────────────────────────────────────────

  Widget _buildProfileCard(UserModel user) {
    final initials = _initials(user.displayName);
    final status   = StatusColors.forLabel(user.status ?? 'active');
    final isActive = (user.status ?? 'active').toLowerCase() == 'active';

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: AppComponents.iconBoxDecoration(AppColors.primary),
                child: Center(
                  child: Text(
                    initials,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName.isEmpty ? '—' : user.displayName,
                      style: AppTypography.cardTitle,
                    ),
                    const SizedBox(height: 2),
                    Text(user.email, style: AppTypography.caption),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              AppStatusPill(
                label: user.role == UserRole.admin ? 'Administrator' : 'HOA Member',
                color: AppColors.primary,
              ),
              const SizedBox(width: 6),
              AppStatusPill(
                label: isActive ? 'Active' : 'Inactive',
                color: status.ink,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Card ──────────────────────────────────────────────────────────────────

  Widget _buildCard({
    required IconData icon,
    required String title,
    required List<Widget> children,
    VoidCallback? onTap,
  }) {
    return AppCard(
      padding: EdgeInsets.zero,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            child: Row(
              children: [
                Icon(icon, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(title,
                    style: AppTypography.label.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const Divider(height: 1, color: AppColors.borderSubtle),
          ...children,
        ],
      ),
    );
  }

  // ── Row helpers ───────────────────────────────────────────────────────────

  Widget _row(String label, String value, {bool isLast = false}) {
    return _rowWidget(
      label,
      Text(
        value,
        textAlign: TextAlign.right,
        style: AppTypography.bodyMedium,
      ),
      isLast: isLast,
    );
  }

  Widget _rowWidget(String label, Widget valueWidget,
      {bool isLast = false, Widget? trailing}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : const Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppTypography.caption),
          const SizedBox(width: 16),
          Flexible(child: valueWidget),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing,
          ],
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

  String _statusLabel(String? status) {
    final s = status ?? 'active';
    return s.isEmpty ? 'Active' : s[0].toUpperCase() + s.substring(1);
  }

  Future<bool?> _confirmSignOut(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: AppRadius.dialogBorderRadius),
        title: const Text('Sign Out', style: AppTypography.cardTitle),
        content: const Text('Are you sure you want to sign out?',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child:
                const Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              foregroundColor: AppColors.textInverted,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg)),
            ),
            child: const Text('Sign Out',
                style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
