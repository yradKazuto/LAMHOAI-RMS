// lib/features/auth/forgot_password_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/providers/auth_provider.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  String _state    = 'idle'; // idle | loading | sent

  static const _blue800   = Color(0xFF0F2547);
  static const _blue700   = Color(0xFF1A3D6B);
  static const _blue600   = Color(0xFF1E52A0);
  static const _blue200   = Color(0xFFBAD9FD);
  static const _blue50    = Color(0xFFEFF6FF);
  static const _gray50    = Color(0xFFF8FAFC);
  static const _gray200   = Color(0xFFD4DCE8);
  static const _gray400   = Color(0xFF8A9BB0);
  static const _gray600   = Color(0xFF4A5A6E);
  static const _gray800   = Color(0xFF1E2A3A);
  static const _danger    = Color(0xFFDC2626);
  static const _dangerBg  = Color(0xFFFEE2E2);
  static const _success   = Color(0xFF16A34A);
  static const _successBg = Color(0xFFDCFCE7);

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
    } catch (_) {
      if (mounted) setState(() => _state = 'idle');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                child: _state == 'sent' ? _buildSentState(context) : _buildForm(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_blue800, _blue700],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => context.canPop() ? context.pop() : context.go('/login'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.arrow_back_ios_new, size: 12, color: _blue200),
                SizedBox(width: 4),
                Text('Back to Sign In', style: TextStyle(fontSize: 10, color: _blue200)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: const Center(child: Icon(Icons.lock_reset_outlined, size: 22, color: Colors.white)),
          ),
          const SizedBox(height: 12),
          const Text(
            'Reset Password',
            style: TextStyle(fontFamily: 'Georgia', fontSize: 20, color: Colors.white, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          const Text('MEMBER PORTAL', style: TextStyle(fontSize: 10, color: _blue200, letterSpacing: 1)),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final auth      = context.watch<AuthProvider>();
    final isLoading = _state == 'loading';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Info box
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _blue50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _blue200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Icon(Icons.info_outline, size: 16, color: _blue600),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Enter your email address linked to your HOA account. We\'ll send you a reset link.',
                  style: TextStyle(fontSize: 11, color: _gray600, height: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Error banner
        if (auth.status == AuthStatus.error && auth.errorMessage != null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: _dangerBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _danger.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, size: 16, color: _danger),
                const SizedBox(width: 8),
                Expanded(child: Text(auth.errorMessage!, style: const TextStyle(fontSize: 11, color: _danger))),
                GestureDetector(onTap: auth.clearError, child: const Icon(Icons.close, size: 14, color: _danger)),
              ],
            ),
          ),

        const Text(
          'EMAIL ADDRESS',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _gray600, letterSpacing: 0.5),
        ),
        const SizedBox(height: 6),

        Form(
          key: _formKey,
          child: TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            style: const TextStyle(fontSize: 13, color: _gray800),
            decoration: InputDecoration(
              hintText: 'your@email.com',
              hintStyle: const TextStyle(fontSize: 13, color: _gray400),
              prefixIcon: const Icon(Icons.email_outlined, size: 18, color: _gray400),
              filled: true,
              fillColor: _gray50,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _gray200, width: 1.5)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _gray200, width: 1.5)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _blue600, width: 1.5)),
              errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _danger, width: 1.5)),
              focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _danger, width: 1.5)),
              errorStyle: const TextStyle(fontSize: 10, color: _danger),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required';
              if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) return 'Enter a valid email address';
              return null;
            },
          ),
        ),
        const SizedBox(height: 24),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue600,
              disabledBackgroundColor: _blue600.withOpacity(0.6),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: isLoading
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('SEND RESET LINK', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () => context.canPop() ? context.pop() : context.go('/login'),
            child: const Text('Back to Sign In', style: TextStyle(fontSize: 12, color: _blue600, fontWeight: FontWeight.w500)),
          ),
        ),
      ],
    );
  }

  Widget _buildSentState(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        Container(
          width: 72,
          height: 72,
          decoration: const BoxDecoration(color: _successBg, shape: BoxShape.circle),
          child: const Center(child: Icon(Icons.mark_email_read_outlined, size: 32, color: _success)),
        ),
        const SizedBox(height: 20),
        const Text(
          'Check Your Email',
          style: TextStyle(fontFamily: 'Georgia', fontSize: 20, color: _gray800, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          'We sent a reset link to\n${_emailCtrl.text.trim()}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: _gray600, height: 1.6),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _gray50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _gray200),
          ),
          child: const Column(
            children: [
              _TipRow(icon: Icons.schedule_outlined,  text: 'The link expires in 1 hour.'),
              SizedBox(height: 8),
              _TipRow(icon: Icons.folder_outlined,    text: 'Check your spam or junk folder if you don\'t see it.'),
              SizedBox(height: 8),
              _TipRow(icon: Icons.phone_outlined,     text: 'Still no email? Contact the LAMHOAI office.'),
            ],
          ),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => context.go('/login'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _blue600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text('BACK TO SIGN IN', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => setState(() => _state = 'idle'),
          child: const Text('Resend email', style: TextStyle(fontSize: 12, color: _blue600, fontWeight: FontWeight.w500)),
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
        Icon(icon, size: 14, color: const Color(0xFF8A9BB0)),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 11, color: Color(0xFF4A5A6E), height: 1.4))),
      ],
    );
  }
}