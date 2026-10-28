// lib/features/complaints/submit_complaint_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/providers/auth_provider.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_header.dart';

class SubmitComplaintScreen extends StatefulWidget {
  const SubmitComplaintScreen({super.key});

  @override
  State<SubmitComplaintScreen> createState() => _SubmitComplaintScreenState();
}

class _SubmitComplaintScreenState extends State<SubmitComplaintScreen> {
  final _formKey   = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl  = TextEditingController();
  String _category  = 'general';
  bool   _submitting = false;
  bool   _submitted  = false;

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

    final user = context.read<AuthProvider>().user!;
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
            title: 'Submit a Complaint',
            subtitle: 'We will review and respond within 3–5 business days.',
            onBack: () =>
                context.canPop() ? context.pop() : context.go('/home/complaints'),
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

              const AppFieldLabel('Complaint title'),
              TextFormField(
                controller: _titleCtrl,
                textInputAction: TextInputAction.next,
                style: AppTypography.body,
                decoration: AppFieldDecoration(
                  hint: 'Brief summary of your concern',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Title is required';
                  if (v.trim().length < 5) return 'Title is too short';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              const AppFieldLabel('Details'),
              TextFormField(
                controller: _descCtrl,
                maxLines: 5,
                textInputAction: TextInputAction.done,
                style: AppTypography.body,
                decoration: AppFieldDecoration(
                  hint: 'Describe the issue — location, date/time, people involved...',
                ),
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
                      : const Text('SUBMIT COMPLAINT', style: AppTypography.button),
                ),
              ),
              const SizedBox(height: 12),
              const Center(
                child: Text(
                  'Complaints are reviewed within 3–5 business days.',
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
                Icons.check_circle_outline,
                size: 36,
                color: AppColors.success,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Complaint Submitted!',
            style: AppTypography.pageTitle,
          ),
          const SizedBox(height: 8),
          Text(
            'Your complaint has been received.\nThe HOA team will review it within 3–5 business days.',
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
              onPressed: () => context.go('/home/complaints'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textInverted,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                elevation: 0,
              ),
              child: const Text('VIEW MY COMPLAINTS', style: AppTypography.button),
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
            child: const Text('Submit Another'),
          ),
        ],
      ),
    );
  }
}
