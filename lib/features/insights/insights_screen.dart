import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/session_log.dart';
import '../../providers/senior_provider.dart';
import '../reports/export_report_screen.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.warmCream,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _InsightsHeader()),
            SliverToBoxAdapter(child: _SeniorSwitcher()),
            SliverToBoxAdapter(child: _MobilityChart()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                child: Text('Rep Statistics', style: AppTextStyles.headlineSmall),
              ),
            ),
            SliverToBoxAdapter(child: _RepStats()),
            SliverToBoxAdapter(
              child: _InsightsCta(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ExportReportScreen()),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class _SeniorSwitcher extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seniors = ref.watch(seniorsProvider);
    final selected = ref.watch(selectedSeniorProvider);

    if (seniors.length <= 1) return const SizedBox.shrink();

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        itemCount: seniors.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final senior = seniors[i];
          final isSelected = senior.id == selected?.id;
          return GestureDetector(
            onTap: () => selectSenior(ref, senior.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.sageGreen : AppColors.cardSurface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.espresso.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                senior.name,
                style: AppTextStyles.labelMedium.copyWith(
                  color: isSelected ? Colors.white : AppColors.espresso,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _InsightsHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Performance Trends', style: AppTextStyles.headlineLarge),
              const SizedBox(height: 2),
              Text(
                'Mobility Improvement Over 12 Weeks',
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.espresso.withValues(alpha: 0.05),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text('Last 12 Weeks', style: AppTextStyles.labelMedium),
          ),
        ],
      ),
    );
  }
}

class _MobilityChart extends StatelessWidget {
  static final _spots = List.generate(
    MockSessionData.mobilityScoresW1toW12.length,
    (i) => FlSpot(i.toDouble(), MockSessionData.mobilityScoresW1toW12[i].toDouble()),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.espresso.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 20,
                    height: 2,
                    color: AppColors.chartLine,
                  ),
                  const SizedBox(width: 6),
                  Text('Mobility Score', style: AppTextStyles.caption),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.lightSage.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_upward, size: 12, color: AppColors.sageGreen),
                    const SizedBox(width: 3),
                    Text(
                      '${MockSessionData.overallImprovementPercent.toInt()}%',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: AppColors.sageGreen,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Overall Improvement',
            style: AppTextStyles.caption,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: 100,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: 25,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: AppColors.divider,
                    strokeWidth: 0.8,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 25,
                      reservedSize: 30,
                      getTitlesWidget: (v, _) => Text(
                        v.toInt().toString(),
                        style: AppTextStyles.caption,
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: 1,
                      getTitlesWidget: (v, _) {
                        final week = v.toInt() + 1;
                        if (week % 2 == 0 || week == 1 || week == 12) {
                          return Text('W$week', style: AppTextStyles.caption);
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: _spots,
                    isCurved: true,
                    color: AppColors.chartLine,
                    barWidth: 2,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
                        radius: 3,
                        color: AppColors.chartLine,
                        strokeWidth: 0,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.chartFill,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.eco, size: 14, color: AppColors.sageGreen),
              const SizedBox(width: 6),
              Text(
                'Consistent progress. Keep up the great work!',
                style: AppTextStyles.caption.copyWith(color: AppColors.sageGreen),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RepStats extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              icon: Icons.speed_outlined,
              title: 'Speed',
              subtitle: 'Average Rep Time',
              value: '${MockSessionData.avgRepTimeSeconds}',
              unit: 'sec',
              delta: '-8%',
              deltaPositive: true,
              deltaLabel: 'vs last 12 weeks',
              trend: _TrendDirection.down,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              icon: Icons.track_changes_outlined,
              title: 'Consistency',
              subtitle: 'Rep Completion Rate',
              value: '${MockSessionData.consistencyPercent.toInt()}',
              unit: '%',
              delta: '+6%',
              deltaPositive: true,
              deltaLabel: 'vs last 12 weeks',
              trend: _TrendDirection.up,
            ),
          ),
        ],
      ),
    );
  }
}

enum _TrendDirection { up, down }

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final String unit;
  final String delta;
  final bool deltaPositive;
  final String deltaLabel;
  final _TrendDirection trend;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.unit,
    required this.delta,
    required this.deltaPositive,
    required this.deltaLabel,
    required this.trend,
  });

  static final _upSpots = [
    const FlSpot(0, 1), const FlSpot(1, 1.2), const FlSpot(2, 1.5),
    const FlSpot(3, 1.8), const FlSpot(4, 2), const FlSpot(5, 2.4),
  ];
  static final _downSpots = [
    const FlSpot(0, 3), const FlSpot(1, 2.8), const FlSpot(2, 2.5),
    const FlSpot(3, 2.3), const FlSpot(4, 2.1), const FlSpot(5, 1.9),
  ];

  @override
  Widget build(BuildContext context) {
    final spots = trend == _TrendDirection.up ? _upSpots : _downSpots;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.espresso.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppColors.lightSage.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: AppColors.sageGreen),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.titleMedium.copyWith(fontSize: 12)),
                    Text(subtitle, style: AppTextStyles.caption),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value,
                  style: AppTextStyles.statMedium.copyWith(fontSize: 30),
                ),
                TextSpan(
                  text: ' $unit',
                  style: AppTextStyles.bodySmall.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.lightSage.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  deltaPositive ? Icons.arrow_downward : Icons.arrow_upward,
                  size: 10,
                  color: AppColors.sageGreen,
                ),
                const SizedBox(width: 2),
                Text(delta, style: AppTextStyles.caption.copyWith(color: AppColors.sageGreen, fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(deltaLabel, style: AppTextStyles.caption),
          const SizedBox(height: 10),
          SizedBox(
            height: 32,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                titlesData: const FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppColors.chartLine,
                    barWidth: 1.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, pct, bar, idx) => FlDotCirclePainter(
                        radius: 2,
                        color: AppColors.chartLine,
                        strokeWidth: 0,
                      ),
                    ),
                    belowBarData: BarAreaData(show: false),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightsCta extends StatelessWidget {
  final VoidCallback onTap;
  const _InsightsCta({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.espresso.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.lightSage.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.local_florist_outlined, size: 20, color: AppColors.sageGreen),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Small, consistent efforts\nlead to meaningful progress.',
                style: AppTextStyles.bodyMedium,
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.subtleText),
          ],
        ),
      ),
    );
  }
}
