import 'package:flutter/material.dart';
import '../../../core/theme/design_tokens.dart';

/// Help / Onboarding screen for new admin/accountant users.
/// Provides guidance on key features, FAQs, and overview of the portal.
class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('Help & Onboarding'),
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.textInverted,
    ),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section: Getting Started ──────────────────────────────────────
          _SectionTitle(
            icon: Icons.help_outline,
            title: 'Getting Started',
          ),
          const SizedBox(height: 8),
          Text(
            'Welcome to the HOA Management Portal! This guide will help you '
            'get oriented with the key features and workflows.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 20),

          // ── Section: Dashboard Overview ───────────────────────────────────
          _SectionTitle(
            icon: Icons.dashboard,
            title: 'Dashboard',
          ),
          const SizedBox(height: 4),
          const Text(
            'The dashboard provides a quick overview of your HOA\'s status, '
            'including recent payments, member activity, and important announcements. '
            'Use the sidebar to navigate to deeper sections.',
          ),
          const SizedBox(height: 20),

          // ── Section: Member Management ────────────────────────────────────
          _SectionTitle(
            icon: Icons.people,
            title: 'Member Management',
          ),
          const SizedBox(height: 4),
          const Text(
            'Manage homeowners and staff via the "Users" and "Homeowners" sections. '
            'You can view member details, update roles, and manage statuses. '
            'Filter options are available to narrow down large lists.',
          ),
          const SizedBox(height: 20),

          // ── Section: Payment Processing ───────────────────────────────────
          _SectionTitle(
            icon: Icons.money,
            title: 'Payment Processing',
          ),
          const SizedBox(height: 4),
          const Text(
            'Record and track member payments, overdue statuses, and penalty applications. '
            'Payments can be marked as paid, and overdue records are automatically '
            'flagged when their due date passes. Penalties are applied based on '
            'configurable grace periods.',
          ),
          const SizedBox(height: 20),

          // ── Section: Reports & Export ─────────────────────────────────────
          _SectionTitle(
            icon: Icons.bar_chart,
            title: 'Reports & Export',
          ),
          const SizedBox(height: 4),
          const Text(
            'Generate reports on payments, members, and other HOA data. '
            'Export options include CSV and PDF formats for external use or record-keeping.',
          ),
          const SizedBox(height: 20),

          // ── Section: Location Mapping ─────────────────────────────────────
          _SectionTitle(
            icon: Icons.map,
            title: 'Location Mapping',
          ),
          const SizedBox(height: 4),
          const Text(
            'Map lot boundaries, import polygon data, and visualize phase layouts. '
            'Use the polygon import tool to upload lot definitions and associate '
            'them with members.',
          ),
          const SizedBox(height: 20),

          // ── Section: FAQ ──────────────────────────────────────────────────
          _SectionTitle(
            icon: Icons.quiz_outlined,
            title: 'Frequently Asked Questions',
          ),
          const SizedBox(height: 4),
          _FaqItem(
            question: 'How do I mark a payment as overdue?',
            answer:
                'The system automatically flags payments as overdue when their due date '
                'passes. You can also manually run "Sync Overdue Statuses" from the Payments '
                'screen to update records that are past due.',
          ),
          _FaqItem(
            question: 'What do the color-coded statuses mean?',
            answer:
                'Status colors indicate payment state: green = paid, yellow/orange = overdue '
                ' (grace period), red = danger/high-contrast overdue. These colors come from '
                'the app\'s design token system for consistency.',
          ),
          _FaqItem(
            question: 'How do I apply overdue penalties?',
            answer:
                'Overdue penalties are applied alongside the "Sync Overdue Statuses" function '
                'from the Payments screen. Configure the penalty amount and grace days in the '
                'Settings section.',
          ),
          const SizedBox(height: 30),

          // ── Section: Need More Help? ──────────────────────────────────────
          _SectionTitle(
            icon: Icons.contact_mail,
            title: 'Need More Help?',
          ),
          const SizedBox(height: 4),
          Text(
            'If you cannot find the answer to your question here, please contact '
            'your system administrator or refer to the official documentation.',
          ),
          const SizedBox(height: 16),
          Text(
            'Contact: admin@lamhoai.example.com',
            style: TextStyle(fontStyle: FontStyle.italic, color: AppColors.textMuted),
          ),
        ],
      ),
    ),
  );
}

/// A reusable section header with an icon and title.
class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({
    required this.icon,
    required this.title,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    ),
  );
}

/// A reusable FAQ item (question + answer).
class _FaqItem extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqItem({
    required this.question,
    required this.answer,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text(
          question,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      Text(
        answer,
        style: const TextStyle(fontSize: 13, height: 1.5, color: AppColors.textPrimary),
      ),
    ],
  );
}