// lib/features/feedback/feedback_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/providers/auth_provider.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _messageCtrl = TextEditingController();
  String _category = 'general';
  int? _rating;
  bool _submitting = false;
  bool _submitted = false;

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
  static const _success   = Color(0xFF16A34A);
  static const _successBg = Color(0xFFDCFCE7);
  static const _danger    = Color(0xFFDC2626);

  static const _categories = [
    ('general',     'General'),
    ('bug',         'Bug Report'),
    ('feature',     'Feature Request'),
    ('compliment',  'Compliment'),
    ('other',       'Other'),
  ];

  @override
  void dispose() {
    _titleCtrl.dispose();
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _submitting = true);

    final user = context.read<AuthProvider>().user!;
    try {
      await FirebaseFirestore.instance.collection('feedback').add({
        'uid':         user.uid,
        'memberName':  user.displayName,
        'email':       user.email,
        'title':       _titleCtrl.text.trim(),
        'message':     _messageCtrl.text.trim(),
        'category':    _category,
        'rating':      _rating,
        'status':      'pending',
        'platform':    'mobile',
        'createdAt':   FieldValue.serverTimestamp(),
        'updatedAt':   null,
      });
      if (mounted) setState(() { _submitting = false; _submitted = true; });
    } catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit: $e'), backgroundColor: _danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(child: _submitted ? _buildSuccess(context) : _buildForm()),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      color: _blue700,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => context.canPop() ? context.pop() : context.go('/home'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.arrow_back_ios_new, size: 12, color: _blue200),
                    SizedBox(width: 4),
                    Text('Back', style: TextStyle(fontSize: 10, color: _blue200)),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Send Feedback',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  fontSize: 20,
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              const Text('Your feedback helps us improve the HOA experience.',
                  style: TextStyle(fontSize: 10, color: _blue200)),
            ],
          ),
        ),
      ),
    );
  }

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

            _fieldLabel('TITLE (OPTIONAL)'),
            TextFormField(
              controller: _titleCtrl,
              textInputAction: TextInputAction.next,
              style: const TextStyle(fontSize: 13, color: _gray800),
              decoration: _inputDeco('Brief summary of your feedback'),
              // No validation required for title (optional)
            ),
            const SizedBox(height: 16),

            _fieldLabel('MESSAGE'),
            TextFormField(
              controller: _messageCtrl,
              maxLines: 5,
              textInputAction: TextInputAction.done,
              style: const TextStyle(fontSize: 13, color: _gray800),
              decoration: _inputDeco('Please share your feedback, suggestions, or concerns...'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Message is required';
                if (v.trim().length < 10) return 'Please provide more detail (min 10 characters)';
                return null;
              },
            ),
            const SizedBox(height: 16),

            _fieldLabel('RATING (OPTIONAL)'),
            _buildRatingPicker(),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  elevation: 0,
                ),
                child: _submitting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('SEND FEEDBACK', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text(
                'We review all feedback and respond when needed.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 10, color: _gray400),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPicker() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: _categories.map((cat) {
        final active = _category == cat.$1;
        return GestureDetector(
          onTap: () => setState(() => _category = cat.$1),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: active ? _blue600 : _gray50,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: active ? _blue600 : _gray200, width: 1.5),
            ),
            child: Text(
              cat.$2,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: active ? Colors.white : _gray600),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildRatingPicker() {
    return Wrap(
      spacing: 4,
      children: List.generate(5, (index) {
        final rating = index + 1;
        final active = _rating == rating;
        return GestureDetector(
          onTap: () => setState(() => _rating = rating),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: active ? _blue600 : _gray50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: active ? _blue600 : _gray200, width: 1.5),
            ),
            child: Center(
              child: Text(
                rating.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: active ? Colors.white : _gray600,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildSuccess(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(color: _successBg, shape: BoxShape.circle),
            child: const Center(child: Icon(Icons.feedback, size: 36, color: _success)),
          ),
          const SizedBox(height: 20),
          const Text(
            'Feedback Sent!',
            style: TextStyle(fontFamily: 'Georgia', fontSize: 20, color: _gray800, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Thank you for your feedback.\nThe HOA team will review it and respond if needed.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: _gray600, height: 1.6),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.go('/home'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue600,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                elevation: 0,
              ),
              child: const Text('GO TO HOME', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5)),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => setState(() {
              _submitted = false;
              _titleCtrl.clear();
              _messageCtrl.clear();
              _category = 'general';
              _rating = null;
            }),
            child: const Text('Send Another Feedback', style: TextStyle(fontSize: 12, color: _blue600)),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _gray600, letterSpacing: 0.5)),
    );
  }

  InputDecoration _inputDeco(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(fontSize: 12, color: _gray400),
      filled: true,
      fillColor: _gray50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _gray200, width: 1.5)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _gray200, width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _blue600, width: 1.5)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _danger, width: 1.5)),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: _danger, width: 1.5)),
      errorStyle: const TextStyle(fontSize: 10, color: _danger),
    );
  }
}