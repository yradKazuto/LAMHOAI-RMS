// core/widgets/app_header.dart
//
// The branded screen header shared by every member screen: a flat
// primaryHeader band with a back affordance, the screen's title, an
// optional subtitle and an optional trailing action.
//
// Taste-skill: no gradient, no emoji, one typeface. The face is Inter
// (the brand face) and the type scale is fixed by AppTypography.

import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

class AppHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;

  const AppHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.primaryHeader,
      // SafeArea only on top so the band fills edge to edge.
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (onBack != null) ...[
                    _BackButton(onBack: onBack!),
                    const SizedBox(width: 12),
                  ],
                  const Spacer(),
                  ?trailing,
                ],
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: const TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 20,
                  color: AppColors.textInverted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitle!,
                  style: const TextStyle(
                    fontFamily: AppTypography.fontFamily,
                    fontSize: 11,
                    color: AppPrimitiveColors.blue200,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final VoidCallback onBack;
  const _BackButton({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      child: InkWell(
        onTap: onBack,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_back_ios_new, size: 13, color: AppPrimitiveColors.blue200),
              SizedBox(width: 5),
              Text(
                'Back',
                style: TextStyle(
                  fontFamily: AppTypography.fontFamily,
                  fontSize: 11,
                  color: AppPrimitiveColors.blue200,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
