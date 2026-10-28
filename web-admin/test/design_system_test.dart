// test/design_system_test.dart
//
// Guards the two rules the admin design system is built on:
//   1. the tokens resolve to the values in docs/brand-guidelines.md
//   2. no screen reaches for a raw hex or Colors.grey[]
// plus one golden of the admin surface, so a change to the token layer
// shows up as a diff instead of a surprise.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lamhoai_admin/core/theme/app_theme.dart';
import 'package:lamhoai_admin/core/theme/design_tokens.dart';

void main() {
  group('tokens', () {
    test('resolve to the brand hex values', () {
      expect(AppColors.primary, const Color(0xFF2563EB));
      expect(AppColors.primaryHeader, const Color(0xFF0D2A5C));
      expect(AppColors.textPrimary, const Color(0xFF1E293B));
      expect(AppColors.background, const Color(0xFFF5F7FA));
      expect(AppColors.sidebarBg, const Color(0xFF1E293B));
      expect(AppColors.danger, const Color(0xFFCC2200));
      expect(AppColors.success, const Color(0xFF1A7A4A));
      expect(AppColors.warning, const Color(0xFF7A6A1A));
    });

    test('the app theme is built from the tokens', () {
      final t = AppTheme.lightTheme;
      expect(t.colorScheme.primary, AppColors.primary);
      expect(t.scaffoldBackgroundColor, AppColors.background);
      expect(t.textTheme.titleMedium?.fontFamily, AppTypography.fontFamily);
    });
  });

  group('brand rules', () {
    test('no screen hardcodes a colour', () {
      final offenders = <String>[];
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        if (f.path.endsWith('theme${Platform.pathSeparator}design_tokens.dart')) continue;
        final src = f.readAsStringSync();
        // `(?<![\w])` so the pdf package's own PdfColors.grey600 palette
        // is not mistaken for Flutter's Colors.grey. black* is allowed:
        // it is the shadow/scrim neutral, not a brand colour.
        final raw = RegExp(r'(?<![\w])Colors\.(?!white\b|black|transparent\b)');
        if (raw.hasMatch(src) || RegExp(r'(?<![\w])Color\(\s*0x').hasMatch(src)) {
          offenders.add(f.path);
        }
      }
      expect(offenders, isEmpty,
          reason: 'use a semantic token, not a raw colour:\n${offenders.join('\n')}');
    });
  });

  testWidgets('admin surface', (tester) async {
    await _loadFonts();
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const Scaffold(
        backgroundColor: AppColors.background,
        body: _Surface(),
      ),
    ));

    await expectLater(
      find.byType(_Surface),
      matchesGoldenFile('goldens/admin_surface.png'),
    );
  });
}

Future<void> _loadFonts() async {
  final loader = FontLoader(AppTypography.fontFamily);
  for (final f in const [
    'assets/fonts/Inter-Regular.ttf',
    'assets/fonts/Inter-Medium.ttf',
    'assets/fonts/Inter-SemiBold.ttf',
    'assets/fonts/Inter-Bold.ttf',
  ]) {
    loader.addFont(rootBundle.load(f));
  }
  await loader.load();

  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
}

/// The admin chrome: navy sidebar, type-based KPIs, a data table.
class _Surface extends StatelessWidget {
  const _Surface();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 232,
          color: AppColors.sidebarBg,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('LAMHOAI',
                  style: AppTypography.greeting
                      .copyWith(color: AppColors.sidebarTextActive, fontSize: 18)),
              const SizedBox(height: 4),
              Text('Residents Manager', style: AppTypography.caption),
              const SizedBox(height: 24),
              const _Nav('Dashboard', active: true),
              const _Nav('Members'),
              const _Nav('Payments'),
              const _Nav('Complaints'),
              const _Nav('Audit Log'),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Dashboard', style: AppTypography.greeting),
                const SizedBox(height: 4),
                Text('Overview of the residents association',
                    style: AppTypography.caption),
                const SizedBox(height: 24),
                const Row(
                  children: [
                    Expanded(child: _Kpi('Total members', '248', '12 new this month')),
                    SizedBox(width: 14),
                    Expanded(child: _Kpi('Collected this month', '₱186,400', '82% of billed')),
                    SizedBox(width: 14),
                    Expanded(
                        child: _Kpi('Overdue payments', '₱42,150', '9 members',
                            isStatus: true)),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: AppRadius.cardBorderRadius,
                      border: Border.all(color: AppColors.border),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Recent payments', style: AppTypography.sectionHeader),
                        const SizedBox(height: 14),
                        const _Row('Maria Santos', 'Monthly dues', '₱1,200.00', 'Paid'),
                        const _Row('Jose Rizal', 'Annual dues', '₱5,000.00', 'Pending'),
                        const _Row('Ana Reyes', 'Water bill', '₱480.00', 'Overdue'),
                        const _Row('Pedro Lim', 'Maintenance', '₱2,300.00', 'Paid'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Nav extends StatelessWidget {
  final String label;
  final bool active;
  const _Nav(this.label, {this.active = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: active ? AppColors.sidebarSelectedBg : Colors.transparent,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Text(
        label,
        style: AppTypography.bodyMedium.copyWith(
          color: active ? AppColors.sidebarTextActive : AppColors.sidebarText,
        ),
      ),
    );
  }
}

/// A KPI: muted label, big figure, muted sub-line. No icon tile.
class _Kpi extends StatelessWidget {
  final String label, value, sub;
  final bool isStatus;
  const _Kpi(this.label, this.value, this.sub, {this.isStatus = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: AppRadius.cardBorderRadius,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.label),
          const SizedBox(height: 4),
          Text(value,
              style: AppTypography.greeting.copyWith(
                fontSize: 20,
                color: isStatus ? AppColors.danger : AppColors.textPrimary,
              )),
          const SizedBox(height: 2),
          Text(sub, style: AppTypography.caption),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final String name, type, amount, status;
  const _Row(this.name, this.type, this.amount, this.status);

  @override
  Widget build(BuildContext context) {
    final danger = status == 'Overdue';
    final ok = status == 'Paid';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.borderSubtle)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(name, style: AppTypography.bodyMedium),
          ),
          Expanded(
            child: Text(type, style: AppTypography.caption),
          ),
          Expanded(
            child: Text(amount, style: AppTypography.body),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: (danger ? AppColors.danger : ok ? AppColors.success : AppColors.warning)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              status,
              style: AppTypography.bodyMedium.copyWith(
                fontSize: 11,
                color: danger
                    ? AppColors.danger
                    : ok
                        ? AppColors.success
                        : AppColors.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
