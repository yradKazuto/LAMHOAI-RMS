// lib/features/complaints/submit_complaint_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/providers/auth_provider.dart';

class SubmitComplaintScreen extends StatefulWidget {
  const SubmitComplaintScreen({super.key});

  @override
  State<SubmitComplaintScreen> createState() => _SubmitComplaintScreenState();
}

class _SubmitComplaintScreenState extends State<SubmitComplaintScreen> {
  final _formKey     = GlobalKey<FormState>();
  final _titleCtrl   = TextEditingController();
  final _descCtrl    = TextEditingController();
  String _category   = 'general';
  bool   _submitting = false;
  bool   _submitted  = false;

  static const _blue800   = Color(0xFF0F2547);
  static const _blue700   = Color(0xFF1A3D6B);
  static const _blue600   = Color(0xFF1E52A0);
  static const _blue200   = Color(0xFFBAD9FD);
  static const _gray50    = Color(0xFFF8FAFC);
  static const _gray100   = Color(0xFFEEF2F7);
  static const _gray200   = Color(0xFFD4DCE8);
  static const _gray400   = Color(0xFF8A9BB0);
  static const _gray600   = Color(0xFF4A5A6E);
  static const _gray800   = Color(0xFF1E2A3A);
  static const _danger    = Color(0xFFDC2626);
  static const _success   = Color(0xFF16A34A);
  static const _successBg = Color(0xFFDCFCE7);

  static const _categories = [
    ('general',     'General'),
    ('maintenance', 'Maintenance'),
    ('noise',       'Noise'),
    ('security',    'Security'),
    ('cleanliness', 'Cleanliness'),
    ('billing',     'Billing'),
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final auth = context.read<AuthProvider>();
    final user = auth.user!;

    try {
      await FirebaseFirestore.instance.collection('complaints').add({
        'uid':         user.uid,
        'memberName':  user.displayName,
        'title':       _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'category':    _category,
        'status':      'pending',
        'createdAt':   FieldValue.serverTimestamp(),
        'resolvedAt':  null,
      });
      if (mounted) setState(() { _submitting = false; _submitted = true; });
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit: $e'),
            backgroundColor: _danger,
          ),
        );
      }
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
              child: _submitted
                  ? _buildSuccessState(context)
                  : _buildForm(),
            ),
          ],
        ),
      ),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

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
            onTap: () => context.canPop()
                ? context.pop()
                : context.go('/home/complaints'),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.arrow_back_ios_new, size: 12, color: _blue200),
                SizedBox(width: 4),
                Text('Back',
                    style: TextStyle(fontSize: 10, color: _blue200)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: const Center(
              child: Icon(Icons.feedback_outlined,
                  size: 20, color: Colors.white),
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Submit a Complaint',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'We will review and respond to your concern.',
            style: TextStyle(fontSize: 10, color: _blue200),
          ),
        ],
      ),
    );
  }

  // ── Form ──────────────────────────────────────────────────────────────────

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _fieldLabel('CATEGORY'),
            _buildCategoryPicker(),
            const SizedBox(height: 16),

            _fieldLabel('COMPLAINT TITLE'),
            TextFormField(
              controller: _titleCtrl,
              textInputAction: TextInputAction.next,
              style: const TextStyle(fontSize: 13, color: _gray800),
              decoration: _inputDeco('Brief description of your concern'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Title is required';
                if (v.trim().length < 5) return 'Title too short';
                return null;
              },
            ),
            const SizedBox(height: 16),

            _fieldLabel('DETAILS'),
            TextFormField(
              controller: _descCtrl,
              maxLines: 5,
              textInputAction: TextInputAction.done,
              style: const TextStyle(fontSize: 13, color: _gray800),
              decoration: _inputDeco(
                  'Describe the issue in detail — location, date/time, people involved...'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Details are required';
                if (v.trim().length < 20) return 'Please provide more detail (min 20 characters)';
                return null;
              },
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue600,
                  disabledBackgroundColor: _blue600.withOpacity(0.6),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text(
                        'SUBMIT COMPLAINT',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'Complaints are reviewed within 3–5 business days.',
                style: TextStyle(fontSize: 10, color: _gray400),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Category picker ───────────────────────────────────────────────────────

  Widget _buildCategoryPicker() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _categories.map((cat) {
        final active = _category == cat.$1;
        return GestureDetector(
          onTap: () => setState(() => _category = cat.$1),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: active ? _blue600 : _gray50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: active ? _blue600 : _gray200,
                width: 1.5,
              ),
            ),
            child: Text(
              cat.$2,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: active ? Colors.white : _gray600,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Success state ─────────────────────────────────────────────────────────

  Widget _buildSuccessState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: _successBg,
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Icon(Icons.check_circle_outline,
                  size: 36, color: _success),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Complaint Submitted',
            style: TextStyle(
              fontFamily: 'Georgia',
              fontSize: 20,
              color: _gray800,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your complaint has been received.\nThe HOA team will review it within 3–5 business days.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: _gray600, height: 1.6),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.go('/home/complaints'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: const Text('VIEW MY COMPLAINTS',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5)),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => setState(() {
              _submitted = false;
              _titleCtrl.clear();
              _descCtrl.clear();
              _category = 'general';
            }),
            child: const Text('Submit Another',
                style: TextStyle(fontSize: 12, color: _blue600)),
          ),
        ],
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: _gray600,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, color: _gray400),
      filled: true,
      fillColor: _gray50,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _gray200, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _gray200, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _blue600, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _danger, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: _danger, width: 1.5),
      ),
      errorStyle: const TextStyle(fontSize: 10, color: _danger),
    );
  }
}