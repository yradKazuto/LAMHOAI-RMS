// features/analytics/screens/analytics_screen.dart
// Dashboard analytics — monthly collections bar chart,
// member status pie chart, payment compliance gauge

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/theme/design_tokens.dart';


class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  
  
  

  @override
  Widget build(BuildContext context) {
    final _svc = AnalyticsService();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
                  tooltip: 'Back to Dashboard',
                  onPressed: () => context.go(AppRoutes.dashboard),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Analytics',
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                      const SizedBox(height: 2),
                      Text('Financial and membership overview',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            _SummaryTilesRow(svc: _svc),
            const SizedBox(height: 24),

            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 700;
                return isWide
                    ? Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              flex: 3,
                              child: _MonthlyBarChart(svc: _svc)),
                          const SizedBox(width: 20),
                          Expanded(
                              flex: 2,
                              child:
                                  _MemberStatusPieChart(svc: _svc)),
                        ],
                      )
                    : Column(
                        children: [
                          _MonthlyBarChart(svc: _svc),
                          const SizedBox(height: 20),
                          _MemberStatusPieChart(svc: _svc),
                        ],
                      );
              },
            ),
            const SizedBox(height: 24),

            _PaymentComplianceCard(svc: _svc),
          ],
        ),
      ),
    );
  }
}

class _SummaryTilesRow extends StatelessWidget {
  final AnalyticsService svc;
  const _SummaryTilesRow({required this.svc});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<double>(
      future: svc.getCollectedThisMonth(),
      builder: (context, snap) {
        final thisMonth = snap.data ?? 0.0;
        return FutureBuilder(
          future: Future.wait([
            svc.getMemberStatusBreakdown(),
            svc.getPaymentStatusBreakdown(),
          ]),
          builder: (context, AsyncSnapshot<List<dynamic>> snap2) {
            final memberBreakdown = snap2.data?[0]
                as MemberStatusBreakdown?;
            final paymentBreakdown = snap2.data?[1]
                as PaymentStatusBreakdown?;

            return LayoutBuilder(
              builder: (context, constraints) {
                final tiles = [
                  _SummaryTile(
                    label: 'Collected This Month',
                    value: '₱${thisMonth.toStringAsFixed(0)}',
                  ),
                  _SummaryTile(
                    label: 'Active Members',
                    value: '${memberBreakdown?.active ?? 0}',
                  ),
                  _SummaryTile(
                    label: 'Overdue Payments',
                    value: '${paymentBreakdown?.overdue ?? 0}',
                    valueColor: AppColors.danger,
                  ),
                  _SummaryTile(
                    label: 'Compliance Rate',
                    value: memberBreakdown != null
                        ? '${memberBreakdown.complianceRate.toStringAsFixed(0)}%'
                        : '—',
                  ),
                ];

                // Four tiles side-by-side leaves each one too narrow
                // to hold its label below this width — fall back to a
                // 2x2 grid instead.
                if (constraints.maxWidth < 640) {
                  return Column(
                    children: [
                      Row(children: [
                        Expanded(child: tiles[0]),
                        const SizedBox(width: 14),
                        Expanded(child: tiles[1]),
                      ]),
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(child: tiles[2]),
                        const SizedBox(width: 14),
                        Expanded(child: tiles[3]),
                      ]),
                    ],
                  );
                }

                return Row(
                  children: [
                    for (int i = 0; i < tiles.length; i++) ...[
                      if (i > 0) const SizedBox(width: 14),
                      Expanded(child: tiles[i]),
                    ],
                  ],
                );
              },
            );
          },
        );
      },
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String label, value;
  final Color? valueColor;

  const _SummaryTile({
    required this.label,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: AppRadius.cardBorderRadius,
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.label),
        const SizedBox(height: 4),
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.greeting.copyWith(
              fontSize: 20,
              color: valueColor ?? AppColors.textPrimary,
            )),
      ],
    ),
  );
}

class _MonthlyBarChart extends StatelessWidget {
  final AnalyticsService svc;
  const _MonthlyBarChart({required this.svc});

  

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.textInverted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Monthly Collections',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text('Last 6 months',
              style: TextStyle(
                  fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 24),
          FutureBuilder<List<MonthlyCollection>>(
            future: svc.getMonthlyCollections(months: 6),
            builder: (context, snap) {
              if (snap.connectionState ==
                  ConnectionState.waiting) {
                return const SizedBox(
                  height: 200,
                  child: Center(
                      child: CircularProgressIndicator()),
                );
              }

              final data = snap.data ?? [];
              if (data.isEmpty) {
                return const SizedBox(
                  height: 200,
                  child: Center(
                      child: Text('No data available.',
                          style: TextStyle(
                              color: AppColors.textMuted))),
                );
              }

              final maxVal = data
                  .map((d) => d.total)
                  .reduce((a, b) => a > b ? a : b);
              final maxY = maxVal == 0
                  ? 1000.0
                  : (maxVal * 1.3).ceilToDouble();

              return SizedBox(
                height: 220,
                child: BarChart(
                  BarChartData(
                    maxY: maxY,
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      horizontalInterval: maxY / 4,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: AppColors.border,
                        strokeWidth: 1,
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 52,
                          getTitlesWidget: (val, meta) =>
                              Text(
                            '₱${(val / 1000).toStringAsFixed(0)}k',
                            style: TextStyle(
                                fontSize: 10,
                                color: AppColors.textMuted),
                          ),
                        ),
                      ),
                      rightTitles: const AxisTitles(
                          sideTitles:
                              SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(
                          sideTitles:
                              SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (val, meta) {
                            final i = val.toInt();
                            if (i < 0 || i >= data.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding:
                                  const EdgeInsets.only(top: 6),
                              child: Text(data[i].month,
                                  style: TextStyle(
                                      fontSize: 11,
                                      color:
                                          AppColors.textSecondary)),
                            );
                          },
                        ),
                      ),
                    ),
                    barGroups: data
                        .asMap()
                        .entries
                        .map(
                          (e) => BarChartGroupData(
                            x: e.key,
                            barRods: [
                              BarChartRodData(
                                toY: e.value.total,
                                color:
                                    AppColors.primary,
                                width: 28,
                                borderRadius:
                                    const BorderRadius.vertical(
                                  top: Radius.circular(6),
                                ),
                                backDrawRodData:
                                    BackgroundBarChartRodData(
                                  show: true,
                                  toY: maxY,
                                  color: AppColors.background,
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) =>
                            AppColors.textPrimary,
                        getTooltipItem:
                            (group, groupIndex, rod, rodIndex) =>
                                BarTooltipItem(
                          '₱${rod.toY.toStringAsFixed(0)}',
                          const TextStyle(
                              color: AppColors.textInverted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MemberStatusPieChart extends StatefulWidget {
  final AnalyticsService svc;
  const _MemberStatusPieChart({required this.svc});

  @override
  State<_MemberStatusPieChart> createState() =>
      _MemberStatusPieChartState();
}

class _MemberStatusPieChartState
    extends State<_MemberStatusPieChart> {
  int _touched = -1;

  

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.textInverted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Member Status',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text('Breakdown by status',
              style: TextStyle(
                  fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 24),
          FutureBuilder<MemberStatusBreakdown>(
            future: widget.svc.getMemberStatusBreakdown(),
            builder: (context, snap) {
              if (snap.connectionState ==
                  ConnectionState.waiting) {
                return const SizedBox(
                  height: 200,
                  child: Center(
                      child: CircularProgressIndicator()),
                );
              }

              final data = snap.data;
              if (data == null || data.total == 0) {
                return const SizedBox(
                  height: 200,
                  child: Center(
                      child: Text('No member data.',
                          style: TextStyle(
                              color: AppColors.textMuted))),
                );
              }

              final sections = [
                _PieSection(
                    value: data.active.toDouble(),
                    color: AppColors.success,
                    label: 'Active'),
                _PieSection(
                    value: data.inactive.toDouble(),
                    color: AppColors.warning,
                    label: 'Inactive'),
                _PieSection(
                    value: data.delinquent.toDouble(),
                    color: AppColors.danger,
                    label: 'Delinquent'),
              ]
                  .where((s) => s.value > 0)
                  .toList();

              return Column(
                children: [
                  SizedBox(
                    height: 180,
                    child: PieChart(
                      PieChartData(
                        pieTouchData: PieTouchData(
                          touchCallback: (event, response) {
                            setState(() {
                              if (!event
                                      .isInterestedForInteractions ||
                                  response == null ||
                                  response.touchedSection ==
                                      null) {
                                _touched = -1;
                                return;
                              }
                              _touched = response
                                  .touchedSection!
                                  .touchedSectionIndex;
                            });
                          },
                        ),
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        sections: sections
                            .asMap()
                            .entries
                            .map((e) {
                          final isTouched =
                              e.key == _touched;
                          return PieChartSectionData(
                            value: e.value.value,
                            color: e.value.color,
                            radius: isTouched ? 60 : 50,
                            title: isTouched
                                ? '${e.value.value.toInt()}'
                                : '',
                            titleStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textInverted),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 16,
                    runSpacing: 8,
                    children: sections
                        .map((s) => Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: s.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  '${s.label} (${s.value.toInt()})',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          AppColors.textSecondary),
                                ),
                              ],
                            ))
                        .toList(),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PieSection {
  final double value;
  final Color  color;
  final String label;
  const _PieSection(
      {required this.value,
      required this.color,
      required this.label});
}

class _PaymentComplianceCard extends StatelessWidget {
  final AnalyticsService svc;
  const _PaymentComplianceCard({required this.svc});

  

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.textInverted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Payment Status Breakdown',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text('All payment records',
              style: TextStyle(
                  fontSize: 12, color: AppColors.textMuted)),
          const SizedBox(height: 20),
          FutureBuilder<PaymentStatusBreakdown>(
            future: svc.getPaymentStatusBreakdown(),
            builder: (context, snap) {
              if (snap.connectionState ==
                  ConnectionState.waiting) {
                return const Center(
                    child: CircularProgressIndicator());
              }

              final data = snap.data;
              if (data == null || data.total == 0) {
                return const Center(
                    child: Text('No payment data.',
                        style:
                            TextStyle(color: AppColors.textMuted)));
              }

              return Column(
                children: [
                  _ComplianceBar(
                    label: 'Paid',
                    count: data.paid,
                    total: data.total,
                    color: AppColors.success,
                  ),
                  const SizedBox(height: 12),
                  _ComplianceBar(
                    label: 'Unpaid',
                    count: data.unpaid,
                    total: data.total,
                    color: AppColors.warning,
                  ),
                  const SizedBox(height: 12),
                  _ComplianceBar(
                    label: 'Overdue',
                    count: data.overdue,
                    total: data.total,
                    color: AppColors.danger,
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_outlined,
                            color: AppColors.dataInk,
                            size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Text('Payment Compliance Rate',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary)),
                              Text(
                                '${data.paidPercent.toStringAsFixed(1)}% of all payments are paid',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${data.paidPercent.toStringAsFixed(0)}%',
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppColors.dataInk),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ComplianceBar extends StatelessWidget {
  final String label;
  final int    count, total;
  final Color  color;

  const _ComplianceBar({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pct = total == 0 ? 0.0 : count / total;
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textPrimary)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: AppColors.borderSubtle,
              color: color,
              minHeight: 10,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 60,
          child: Text(
            '$count (${(pct * 100).toStringAsFixed(0)}%)',
            textAlign: TextAlign.right,
            style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}