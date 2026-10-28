// lib/features/feedback/feedback_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_header.dart';

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
          SnackBar(content: Text('Failed to submit: $e'), backgroundColor: AppColors.error),
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
            title: 'Send Feedback',
            subtitle: 'Your feedback helps us improve the HOA experience.',
            onBack: () =>
                context.canPop() ? context.pop() : context.go('/home'),
          ),
          Expanded(child: _submitted ? _buildSuccess(context) : _buildForm()),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        child: AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppFieldLabel('Category'),
              _buildCategoryPicker(),
              const SizedBox(height: 16),

              const AppFieldLabel('Title (optional)'),
              TextFormField(
                controller: _titleCtrl,
                textInputAction: TextInputAction.next,
                style: AppTypography.body,
                decoration: AppFieldDecoration(
                  hint: 'Brief summary of your feedback',
                ),
                // No validation required for title (optional)
              ),
              const SizedBox(height: 16),

              const AppFieldLabel('Message'),
              TextFormField(
                controller: _messageCtrl,
                maxLines: 5,
                textInputAction: TextInputAction.done,
                style: AppTypography.body,
                decoration: AppFieldDecoration(
                  hint: 'Please share your feedback, suggestions, or concerns...',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Message is required';
                  if (v.trim().length < 10) return 'Please provide more detail (min 10 characters)';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              const AppFieldLabel('Rating (optional)'),
              _buildRatingPicker(),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
                    foregroundColor: AppColors.textInverted,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                    ),
                    elevation: 0,
                  ),
                  child: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: AppColors.textInverted,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('SEND FEEDBACK', style: AppTypography.button),
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'We review all feedback and respond when needed.',
                  textAlign: TextAlign.center,
                  style: AppTypography.caption,
                ),
              ),
            ],
          ),
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
              color: active ? AppColors.primary : AppColors.surfaceAlt,
              borderRadius: AppRadius.pillBorderRadius,
              border: Border.all(
                color: active ? AppColors.primary : AppColors.border,
                width: 1.5,
              ),
            ),
            child: Text(
              cat.$2,
              style: AppTypography.label.copyWith(
                fontWeight: FontWeight.w500,
                color: active ? AppColors.textInverted : AppColors.textSecondary,
              ),
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
              color: active ? AppColors.primary : AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(
                color: active ? AppColors.primary : AppColors.border,
                width: 1.5,
              ),
            ),
            child: Center(
              child: Text(
                rating.toString(),
                style: AppTypography.label.copyWith(
                  fontWeight: FontWeight.w600,
                  color: active ? AppColors.textInverted : AppColors.textSecondary,
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
            decoration: AppComponents.iconBoxDecoration(AppColors.success),
            child: const Center(
              child: Icon(
                Icons.rate_review_outlined,
                size: 36,
                color: AppColors.success,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Feedback Sent!',
            style: AppTypography.pageTitle,
          ),
          const SizedBox(height: 8),
          Text(
            'Thank you for your feedback.\nThe HOA team will review it and respond if needed.',
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.go('/home'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textInverted,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                elevation: 0,
              ),
              child: const Text('GO TO HOME', style: AppTypography.button),
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
            child: const Text('Send Another Feedback'),
          ),
        ],
      ),
    );
  }
}
