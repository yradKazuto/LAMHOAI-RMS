// features/auth/screens/login_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  // ── Brand colours ──────────────────────────────────────────────────────────
  static const Color _navy = Color(0xFF0D2A5C);
  static const Color _blue = Color(0xFF1A4A9C);
  static const Color _accent = Color(0xFF2E6BE6);
  static const Color _lightBg = Color(0xFFF0F4FB);
  static const Color _border = Color(0xFFD0DBEE);
  static const Color _error = Color(0xFFCC2200);

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    ));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // ── Submit ─────────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    await auth.signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth >= 900;

    return Scaffold(
      body: Container(
        // Seamless Fullscreen Background Gradient
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0D2A5C), // _navy
              Color(0xFF1A4A9C), // _blue
              Color(0xFFE2EAF8), // soft tint to blend with light card
            ],
            stops: [0.0, 0.45, 1.0],
          ),
        ),
        child: Row(
          children: [
            // ── Left Hero Panel (Desktop) ────────────────────────────────────
            if (isDesktop)
              const Expanded(
                flex: 5,
                child: _LeftPanel(),
              ),

            // ── Right Form Section ───────────────────────────────────────────
            Expanded(
              flex: 6,
              child: Center(
                child: SingleChildScrollView(
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: SlideTransition(
                      position: _slideAnim,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: _LoginCard(
                          formKey: _formKey,
                          emailController: _emailController,
                          passwordController: _passwordController,
                          obscurePassword: _obscurePassword,
                          onTogglePassword: () => setState(
                              () => _obscurePassword = !_obscurePassword),
                          onSubmit: _submit,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Left decorative panel ─────────────────────────────────────────────────────
class _LeftPanel extends StatelessWidget {
  const _LeftPanel();

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Stack(
        children: [
          // Background Watermark & Geometry
          Positioned.fill(
            child: CustomPaint(painter: _GeoPainter()),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Brand Badge
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.25),
                          width: 1,
                        ),
                      ),
                      child: const Icon(
                        Icons.account_balance,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Text(
                      'LAMHOAI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2.5,
                      ),
                    ),
                  ],
                ),

                const Spacer(),

                // Center Headline Block
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2E6BE6),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'La Milagrosa\nHomeowners\nAssociation',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Record Management System',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Centralized administration dashboard for authorized personnel to manage community operations and records.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.75),
                    fontSize: 13.5,
                    height: 1.5,
                  ),
                ),

                const Spacer(),

                // Footer Version Tag
                Text(
                  '© ${DateTime.now().year} LAMHOAI · RMS v2.0',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Geometric painter ─────────────────────────────────────────────────────────
class _GeoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.05)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    // Background watermark arc design
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.7),
      size.width * 0.6,
      paint,
    );

    canvas.drawCircle(
      Offset(size.width * 0.1, size.height * 0.2),
      size.width * 0.35,
      paint,
    );
  }

  @override
  bool shouldRepaint(_) => false;
}

// ── Login card ────────────────────────────────────────────────────────────────
class _LoginCard extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController passwordController;
  final bool obscurePassword;
  final VoidCallback onTogglePassword;
  final VoidCallback onSubmit;

  static const Color _navy = Color(0xFF0D2A5C);
  static const Color _error = Color(0xFFCC2200);

  const _LoginCard({
    required this.formKey,
    required this.emailController,
    required this.passwordController,
    required this.obscurePassword,
    required this.onTogglePassword,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, auth, _) {
        return Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 44),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D2A5C).withOpacity(0.12),
                blurRadius: 40,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Header ───────────────────────────────────────────────────
                const Text(
                  'Welcome back',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: _navy,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sign in to the LAMHOAI admin portal',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 32),

                // ── Error banner ─────────────────────────────────────────────
                if (auth.errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF0EE),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _error.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            size: 16, color: _error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            auth.errorMessage!,
                            style: const TextStyle(
                              color: _error,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // ── Email ────────────────────────────────────────────────────
                const _FieldLabel(label: 'Email address'),
                const SizedBox(height: 6),
                _AuthField(
                  controller: emailController,
                  hint: 'admin@lamhoai.org',
                  keyboardType: TextInputType.emailAddress,
                  prefixIcon: Icons.email_outlined,
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
                const SizedBox(height: 20),

                // ── Password ─────────────────────────────────────────────────
                const _FieldLabel(label: 'Password'),
                const SizedBox(height: 6),
                _AuthField(
                  controller: passwordController,
                  hint: '••••••••',
                  obscureText: obscurePassword,
                  prefixIcon: Icons.lock_outline,
                  suffixIcon: obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  onSuffixTap: onTogglePassword,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Password is required';
                    if (v.length < 6) return 'Password too short';
                    return null;
                  },
                  onFieldSubmitted: (_) => onSubmit(),
                ),
                const SizedBox(height: 32),

                // ── Submit button ─────────────────────────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: auth.isLoading ? null : onSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _navy,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _navy.withOpacity(0.5),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: auth.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Sign In',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                // ── Footer note ───────────────────────────────────────────────
                Center(
                  child: Text(
                    'Access restricted to authorized HOA personnel.\nMembers use the LAMHOAI mobile app.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey[500],
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Field label ───────────────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String label;
  const _FieldLabel({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF0D2A5C),
        letterSpacing: 0.1,
      ),
    );
  }
}

// ── Reusable auth text field ──────────────────────────────────────────────────
class _AuthField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool obscureText;
  final TextInputType keyboardType;
  final IconData prefixIcon;
  final IconData? suffixIcon;
  final VoidCallback? onSuffixTap;
  final String? Function(String?)? validator;
  final void Function(String)? onFieldSubmitted;

  static const Color _accent = Color(0xFF2E6BE6);
  static const Color _border = Color(0xFFD0DBEE);

  const _AuthField({
    required this.controller,
    required this.hint,
    required this.prefixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.suffixIcon,
    this.onSuffixTap,
    this.validator,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      onFieldSubmitted: onFieldSubmitted,
      style: const TextStyle(
        fontSize: 14,
        color: Color(0xFF1A2B4A),
      ),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(
          color: Colors.grey[400],
          fontSize: 14,
        ),
        prefixIcon: Icon(prefixIcon, size: 18, color: Colors.grey[500]),
        suffixIcon: suffixIcon != null
            ? IconButton(
                icon: Icon(suffixIcon, size: 18, color: Colors.grey[500]),
                onPressed: onSuffixTap,
                splashRadius: 18,
              )
            : null,
        filled: true,
        fillColor: const Color(0xFFF7F9FC),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCC2200)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFCC2200), width: 1.5),
        ),
        errorStyle: const TextStyle(
          fontSize: 11.5,
          color: Color(0xFFCC2200),
        ),
      ),
    );
  }
}