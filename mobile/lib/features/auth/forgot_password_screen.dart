// lib/features/auth/forgot_password_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_header.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  String _state    = 'idle'; // idle | loading | sent

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _state = 'loading');
    try {
      await context.read<AuthProvider>().resetPassword(_emailCtrl.text.trim());
      if (mounted) setState(() => _state = 'sent');
    } catch (e) {
      if (mounted) {
        setState(() => _state = 'idle');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), duration: const Duration(seconds: 5)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          AppHeader(
            title: 'Reset Password',
            subtitle: 'MEMBER PORTAL',
            onBack: () =>
                context.canPop() ? context.pop() : context.go('/login'),
            trailing: Container(
              width: 40,
              height: 40,
              decoration: AppComponents.iconBoxDecoration(AppColors.primary),
              child: const Icon(Icons.lock_reset_outlined,
                  size: 20, color: AppColors.textInverted),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              child: AppCard(
                child: _state == 'sent'
                    ? _buildSentState(context)
                    : _buildForm(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Form ──────────────────────────────────────────────────────────────────

  Widget _buildForm(BuildContext context) {
    final auth      = context.watch<AuthProvider>();
    final isLoading = _state == 'loading';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppPrimitiveColors.blue50,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppPrimitiveColors.blue200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Icon(Icons.info_outline, size: 16, color: AppColors.primary),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Enter your email address linked to your HOA account. We\'ll send you a reset link.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        if (auth.status == AuthStatus.error && auth.errorMessage != null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.errorBg,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 16, color: AppColors.error),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(auth.errorMessage!,
                      style: AppTypography.caption
                          .copyWith(color: AppColors.error)),
                ),
                GestureDetector(
                  onTap: auth.clearError,
                  child: const Icon(Icons.close, size: 14, color: AppColors.error),
                ),
              ],
            ),
          ),

        const AppFieldLabel('Email address'),

        Form(
          key: _formKey,
          child: TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            style: AppTypography.body.copyWith(color: AppColors.textPrimary),
            decoration: AppFieldDecoration(hint: 'your@email.com').copyWith(
              prefixIcon: const Icon(Icons.email_outlined,
                  size: 18, color: AppColors.textMuted),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return 'Email is required';
              }
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) {
                return 'Enter a valid email address';
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
              foregroundColor: AppColors.textInverted,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg)),
              elevation: 0,
            ),
            child: isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: AppColors.textInverted, strokeWidth: 2))
                : const Text('SEND RESET LINK', style: AppTypography.button),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: TextButton(
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/login'),
            child: const Text('Back to Sign In',
                style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500)),
          ),
        ),
      ],
    );
  }

  // ── Sent state ────────────────────────────────────────────────────────────

  Widget _buildSentState(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          width: 72,
          height: 72,
          decoration:
              const BoxDecoration(color: AppColors.successBg, shape: BoxShape.circle),
          child: const Center(
            child: Icon(Icons.mark_email_read_outlined,
                size: 32, color: AppColors.success),
          ),
        ),
        const SizedBox(height: 20),
        const Text('Check Your Email', style: AppTypography.pageTitle),
        const SizedBox(height: 8),
        Text(
          'We sent a reset link to\n${_emailCtrl.text.trim()}',
          textAlign: TextAlign.center,
          style: AppTypography.body.copyWith(
            color: AppColors.textSecondary,
            height: 1.6,
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surfaceAlt,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(color: AppColors.border),
          ),
          child: const Column(
            children: [
              _TipRow(
                  icon: Icons.schedule_outlined,
                  text: 'The link expires in 1 hour.'),
              SizedBox(height: 8),
              _TipRow(
                  icon: Icons.folder_outlined,
                  text:
                      'Check your spam or junk folder if you don\'t see it.'),
              SizedBox(height: 8),
              _TipRow(
                  icon: Icons.phone_outlined,
                  text: 'Still no email? Contact the LAMHOAI office.'),
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => context.go('/login'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textInverted,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg)),
              elevation: 0,
            ),
            child: const Text('BACK TO SIGN IN', style: AppTypography.button),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => setState(() => _state = 'idle'),
          child: const Text('Resend email',
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}

class _TipRow extends StatelessWidget {
  final IconData icon;
  final String   text;
  const _TipRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text,
              style: AppTypography.caption.copyWith(
                  color: AppColors.textSecondary, height: 1.4)),
        ),
      ],
    );
  }
}
