// test/design_system_test.dart
//
// Guards the two rules the design system is built on:
//   1. the tokens resolve to the values in docs/brand-guidelines.md
//   2. no screen reaches for a raw hex or Colors.grey[]
// plus one golden of the shared component layer, so a change to the
// card/header/pill look shows up as a diff instead of a surprise.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lamhoai_rms/core/theme/app_theme.dart';
import 'package:lamhoai_rms/core/theme/design_tokens.dart';
import 'package:lamhoai_rms/core/utils/status_colors.dart';
import 'package:lamhoai_rms/core/widgets/app_card.dart';
import 'package:lamhoai_rms/core/widgets/app_header.dart';

void main() {
  group('tokens', () {
    test('resolve to the brand hex values', () {
      expect(AppColors.primary, const Color(0xFF2563EB));
      expect(AppColors.primaryHeader, const Color(0xFF0D2A5C));
      expect(AppColors.textPrimary, const Color(0xFF1E293B));
      expect(AppColors.background, const Color(0xFFF5F7FA));
      expect(AppColors.danger, const Color(0xFFCC2200));
      expect(AppColors.success, const Color(0xFF1A7A4A));
      expect(AppColors.warning, const Color(0xFFB45309));
    });

    test('the app theme is built from the tokens', () {
      final t = AppTheme.lightTheme;
      expect(t.colorScheme.primary, AppColors.primary);
      expect(t.scaffoldBackgroundColor, AppColors.background);
      expect(t.textTheme.titleMedium?.fontFamily, AppTypography.fontFamily);
    });

    test('a status word maps to one hue', () {
      expect(StatusColors.ink('paid'), AppColors.success);
      expect(StatusColors.ink('overdue'), AppColors.danger);
      expect(StatusColors.ink('pending'), AppColors.warning);
      expect(StatusColors.ink('resolved'), AppColors.success);
    });
  });

  group('brand rules', () {
    test('no screen hardcodes a colour', () {
      final offenders = <String>[];
      for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
        if (!f.path.endsWith('.dart')) continue;
        if (f.path.endsWith('theme${Platform.pathSeparator}design_tokens.dart')) continue;
        final src = f.readAsStringSync();
        // black* is allowed: it is the shadow/scrim neutral, not a brand colour.
        final raw = RegExp(r'(?<![\w])Colors\.(?!white\b|black|transparent\b)');
        if (raw.hasMatch(src) || RegExp(r'(?<![\w])Color\(\s*0x').hasMatch(src)) {
          offenders.add(f.path);
        }
      }
      expect(offenders, isEmpty,
          reason: 'use a semantic token, not a raw colour:\n${offenders.join('\n')}');
    });
  });

  testWidgets('member screen fragment', (tester) async {
    await _loadInter();
    tester.view.physicalSize = const Size(1080, 1680);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: const Scaffold(
        backgroundColor: AppColors.background,
        body: _Fragment(),
      ),
    ));

    await expectLater(
      find.byType(_Fragment),
      matchesGoldenFile('goldens/member_fragment.png'),
    );
  });
}

Future<void> _loadInter() async {
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

  // Material's icon font ships with the app, not the test binding — without
  // it every Icon renders as an empty box in the golden.
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
}

/// A representative member screen: header, summary, list rows.
class _Fragment extends StatelessWidget {
  const _Fragment();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const AppHeader(
          title: 'Payment Records',
          subtitle: 'Juan Dela Cruz',
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Total balance due', style: AppTypography.caption),
                          const SizedBox(height: 4),
                          Text('₱3,250.00', style: AppTypography.money),
                        ],
                      ),
                    ),
                    const AppStatusPill(label: 'Overdue', color: AppColors.danger),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppCardHeader(
                      title: 'Monthly dues',
                      subtitle: 'October 2026',
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.receipt_long_outlined,
                            size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text('Reference ID', style: AppTypography.caption),
                        const Spacer(),
                        Text('PAY-2026-0042', style: AppTypography.body),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AppCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppCardHeader(
                      title: 'Annual dues',
                      subtitle: '2026',
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        const Icon(Icons.receipt_long_outlined,
                            size: 14, color: AppColors.primary),
                        const SizedBox(width: 6),
                        Text('Reference ID', style: AppTypography.caption),
                        const Spacer(),
                        Text('PAY-2026-0007', style: AppTypography.body),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
