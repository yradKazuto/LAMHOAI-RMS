// core/utils/status_colors.dart
//
// The one place a status word becomes a colour. Every list screen was
// re-deriving this from a lowercased label string, which meant a new
// status needed editing in four files.
//
// Taste-skill: status colour is for status, never decoration, and the
// same status never wears two hues on two screens.

import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

class StatusColors {
  const StatusColors._();

  /// The ink colour for a status word, and the tint behind it.
  static ({Color ink, Color bg}) forLabel(String label) {
    switch (label.toLowerCase()) {
      case 'paid':
      case 'resolved':
      case 'approved':
      case 'active':
        return (ink: AppColors.success, bg: AppColors.successBg);
      case 'overdue':
      case 'rejected':
      case 'inactive':
        return (ink: AppColors.danger, bg: AppColors.dangerBg);
      case 'unpaid':
      case 'pending':
      case 'reviewing':
      case 'waived':
        return (ink: AppColors.warning, bg: AppColors.warningBg);
      default:
        return (ink: AppColors.textSecondary, bg: AppColors.borderSubtle);
    }
  }

  /// The plain ink colour for a status word.
  static Color ink(String label) => forLabel(label).ink;

  /// The pale tint behind a status word.
  static Color bg(String label) => forLabel(label).bg;
}
