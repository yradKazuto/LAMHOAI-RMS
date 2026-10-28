// core/widgets/app_card.dart
//
// The shared surface for a card on a member screen, plus the small
// pieces that every screen was rebuilding by hand: a title row, a
// status pill, an empty state and a label.

import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? borderColor;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final card = Container(
      margin: margin,
      padding: padding ?? const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: AppComponents.cardDecoration(border: borderColor ?? AppColors.border),
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.cardBorderRadius,
        child: card,
      ),
    );
  }
}

/// A card header: title on the left, an optional action on the right.
class AppCardHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const AppCardHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.cardTitle),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: AppTypography.caption),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// A status word in a pale tint of its own hue, with the dark of that
/// hue as the ink. One mark per row — never a tag beside a badge.
class AppStatusPill extends StatelessWidget {
  final String label;
  final Color color;

  const AppStatusPill({
    super.key,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// The empty state: a plain icon in ink-muted, one sentence of copy.
/// No emoji, no illustration.
class AppEmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? hint;

  const AppEmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.body.copyWith(color: AppColors.textMuted),
          ),
          if (hint != null) ...[
            const SizedBox(height: 4),
            Text(
              hint!,
              textAlign: TextAlign.center,
              style: AppTypography.caption,
            ),
          ],
        ],
      ),
    );
  }
}

/// A form label. Sentence case at a readable size — the taste-skill
/// house rule bans tiny tracked uppercase labels.
class AppFieldLabel extends StatelessWidget {
  final String text;

  const AppFieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: AppTypography.label.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// The input decoration every mobile form field was rebuilding.
class AppFieldDecoration extends InputDecoration {
  AppFieldDecoration({
    String? hint,
    String? label,
    super.suffixIcon,
    bool obscure = false,
  }) : super(
          hintText: hint,
          labelText: label,
          isDense: true,
          filled: true,
          fillColor: AppColors.surfaceAlt,
          hintStyle: AppTypography.body.copyWith(color: AppColors.textMuted),
          labelStyle: AppTypography.label.copyWith(color: AppColors.textSecondary),
          floatingLabelStyle:
              AppTypography.label.copyWith(color: AppColors.primary),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.space3_5,
            vertical: AppSpacing.space3,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: const BorderSide(color: AppColors.border, width: 1.5),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: const BorderSide(color: AppColors.border, width: 1.5),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: const BorderSide(color: AppColors.error, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            borderSide: const BorderSide(color: AppColors.error, width: 1.5),
          ),
        );
}
