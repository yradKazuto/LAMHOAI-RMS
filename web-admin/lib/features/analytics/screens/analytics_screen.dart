// features/analytics/screens/analytics_screen.dart
// Dashboard analytics — monthly collections bar chart,
// member status pie chart, payment compliance gauge

import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../../../core/routing/app_router.dart';
import '../../../core/services/analytics_service.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  static const Color _navy   = Color(0xFF0D2A5C);
  static const Color _accent = Color(0xFF2E6BE6);
  static const Color _bg     = Color(0xFFF0F4FB);

  @override
  Widget build(BuildContext context) {
    final _svc = AnalyticsService();

    return Scaffold(
      backgroundColor: _bg,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ─────────────────────────────────────────────────────
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: _navy),
                  tooltip: 'Back to Dashboard',
                  onPressed: () => context.go(AppRoutes.dashboard),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Analytics',
                        style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                            color: _navy)),
                    const SizedBox(height: 2),
                    Text('Financial and membership overview',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey[600])),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 28),

            // ── Row 1: Summary tiles ────────────────────────────────────────
            _SummaryTilesRow(svc: _svc),
            const SizedBox(height: 24),

            // ── Row 2: Bar chart + Pie chart ────────────────────────────────
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

            // ── Row 3: Payment compliance gauge ────────────────────────────
            _PaymentComplianceCard(svc: _svc),
          ],
        ),
      ),
    );
  }
}

// ── Summary tiles ─────────────────────────────────────────────────────────────
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

            return Row(
              children: [
                Expanded(
                  child: _SummaryTile(
                    label: 'Collected This Month',
                    value:
                        '₱${thisMonth.toStringAsFixed(0)}',
                    icon:  Icons.payments_outlined,
                    color: const Color(0xFF1A7A4A),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _SummaryTile(
                    label: 'Active Members',
                    value:
                        '${memberBreakdown?.active ?? 0}',
                    icon:  Icons.people_outline,
                    color: const Color(0xFF1A4A9C),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _SummaryTile(
                    label: 'Overdue Payments',
                    value:
                        '${paymentBreakdown?.overdue ?? 0}',
                    icon:  Icons.warning_amber_outlined,
                    color: const Color(0xFFCC2200),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _SummaryTile(
                    label: 'Compliance Rate',
                    value: memberBreakdown != null
                        ? '${memberBreakdown.complianceRate.toStringAsFixed(0)}%'
                        : '—',
                    icon:  Icons.verified_outlined,
                    color: const Color(0xFF7A3A1A),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final String  label, value;
  final IconData icon;
  final Color   color;

  const _SummaryTile({
    required this.label, required this.value,
    required this.icon,  required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE0E8F4)),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 11.5,
                      color: Colors.grey[600])),
              Text(value,
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: color)),
            ],
          ),
        ),
      ],
    ),
  );
}

// ── Monthly bar chart ─────────────────────────────────────────────────────────
class _MonthlyBarChart extends StatelessWidget {
  final AnalyticsService svc;
  const _MonthlyBarChart({required this.svc});

  static const Color _navy = Color(0xFF0D2A5C);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E8F4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Monthly Collections',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _navy)),
          const SizedBox(height: 4),
          Text('Last 6 months',
              style: TextStyle(
                  fontSize: 12, color: Colors.grey[500])),
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
                              color: Colors.grey))),
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
                        color: const Color(0xFFE0E8F4),
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
                                color: Colors.grey[500]),
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
                                          Colors.grey[600])),
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
                                    const Color(0xFF2E6BE6),
                                width: 28,
                                borderRadius:
                                    const BorderRadius.vertical(
                                  top: Radius.circular(6),
                                ),
                                backDrawRodData:
                                    BackgroundBarChartRodData(
                                  show: true,
                                  toY: maxY,
                                  color: const Color(
                                      0xFFF0F4FB),
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
                    barTouchData: BarTouchData(
                      touchTooltipData: BarTouchTooltipData(
                        getTooltipColor: (_) =>
                            const Color(0xFF0D2A5C),
                        getTooltipItem:
                            (group, groupIndex, rod, rodIndex) =>
                                BarTooltipItem(
                          '₱${rod.toY.toStringAsFixed(0)}',
                          const TextStyle(
                              color: Colors.white,
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

// ── Member status pie chart ───────────────────────────────────────────────────
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

  static const Color _navy = Color(0xFF0D2A5C);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E8F4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Member Status',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _navy)),
          const SizedBox(height: 4),
          Text('Breakdown by status',
              style: TextStyle(
                  fontSize: 12, color: Colors.grey[500])),
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
                              color: Colors.grey))),
                );
              }

              final sections = [
                _PieSection(
                    value: data.active.toDouble(),
                    color: const Color(0xFF1A7A4A),
                    label: 'Active'),
                _PieSection(
                    value: data.inactive.toDouble(),
                    color: const Color(0xFFF0B429),
                    label: 'Inactive'),
                _PieSection(
                    value: data.delinquent.toDouble(),
                    color: const Color(0xFFCC2200),
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
                                color: Colors.white),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Legend
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
                                          Colors.grey[600]),
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

// ── Payment compliance gauge ──────────────────────────────────────────────────
class _PaymentComplianceCard extends StatelessWidget {
  final AnalyticsService svc;
  const _PaymentComplianceCard({required this.svc});

  static const Color _navy = Color(0xFF0D2A5C);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE0E8F4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Payment Status Breakdown',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _navy)),
          const SizedBox(height: 4),
          Text('All payment records',
              style: TextStyle(
                  fontSize: 12, color: Colors.grey[500])),
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
                            TextStyle(color: Colors.grey)));
              }

              return Column(
                children: [
                  _ComplianceBar(
                    label: 'Paid',
                    count: data.paid,
                    total: data.total,
                    color: const Color(0xFF1A7A4A),
                  ),
                  const SizedBox(height: 12),
                  _ComplianceBar(
                    label: 'Unpaid',
                    count: data.unpaid,
                    total: data.total,
                    color: const Color(0xFFF0B429),
                  ),
                  const SizedBox(height: 12),
                  _ComplianceBar(
                    label: 'Overdue',
                    count: data.overdue,
                    total: data.total,
                    color: const Color(0xFFCC2200),
                  ),
                  const SizedBox(height: 12),
                  _ComplianceBar(
                    label: 'Waived',
                    count: data.waived,
                    total: data.total,
                    color: const Color(0xFF5A7099),
                  ),
                  const SizedBox(height: 20),
                  // Compliance rate highlight
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F4FB),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified_outlined,
                            color: Color(0xFF1A4A9C),
                            size: 20),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const Text('Payment Compliance Rate',
                                style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0D2A5C))),
                            Text(
                              '${data.paidPercent.toStringAsFixed(1)}% of all payments are paid',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          '${data.paidPercent.toStringAsFixed(0)}%',
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A4A9C)),
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
                  fontSize: 13, color: Color(0xFF1A2B4A))),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: pct,
              backgroundColor: const Color(0xFFEEF2F9),
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
                color: Colors.grey[600]),
          ),
        ),
      ],
    );
  }
}