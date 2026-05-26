import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../providers/insights_provider.dart';
import '../../providers/senior_provider.dart';
import '../reports/export_report_screen.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seniors = ref.watch(seniorsProvider);
    final hasSenior = ref.watch(selectedSeniorProvider) != null;

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _InsightsHeader()),
            if (seniors.isEmpty) ...[
              SliverToBoxAdapter(child: _InsightsEmptyState()),
            ] else ...[
              SliverToBoxAdapter(child: _SeniorSwitcher()),
              SliverToBoxAdapter(child: _MobilityChart()),
              if (hasSenior) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                    child: Text('Rep Statistics', style: AppTextStyles.headlineSmall),
                  ),
                ),
                SliverToBoxAdapter(child: _RepStats()),
              ],
            ],
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

class _InsightsEmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.espresso.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(Icons.bar_chart_outlined, size: 48, color: AppColors.lightSage),
          const SizedBox(height: 16),
          Text(
            'No data yet',
            style: AppTextStyles.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Add a loved one on the Home tab to start\ntracking their sit-to-stand progress.',
            style: AppTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Performance Trends', style: AppTextStyles.headlineLarge),
                const SizedBox(height: 2),
                Text(
                  'Daily rep activity for the current week',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
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
            child: Text('This Week', style: AppTextStyles.labelMedium),
          ),
        ],
      ),
    );
  }
}

class _MobilityChart extends ConsumerWidget {
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final senior = ref.watch(selectedSeniorProvider);
    if (senior == null) return const SizedBox.shrink();
    final insights = ref.watch(seniorInsightsProvider(senior.id));
    final weeklyReps = insights.weeklyReps;
    final consistencyPct = insights.consistencyPercent.toInt();

    final maxReps = weeklyReps.isEmpty ? 10 : weeklyReps.reduce((a, b) => a > b ? a : b);
    final maxY = (maxReps + 5).toDouble().clamp(10.0, double.infinity);
    final interval = (maxY / 4).ceilToDouble();

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
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColors.sageGreen,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('Daily Reps', style: AppTextStyles.caption),
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
                    const Icon(Icons.check_circle_outline, size: 12, color: AppColors.sageGreen),
                    const SizedBox(width: 3),
                    Text(
                      '$consistencyPct%',
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
          Text('Weekly Consistency', style: AppTextStyles.caption),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: interval,
                  getDrawingHorizontalLine: (_) => const FlLine(
                    color: AppColors.divider,
                    strokeWidth: 0.8,
                  ),
                ),
                borderData: FlBorderData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      interval: interval,
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
                      getTitlesWidget: (v, _) {
                        final i = v.toInt();
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            i < _days.length ? _days[i] : '',
                            style: AppTextStyles.caption,
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                barGroups: List.generate(7, (i) {
                  final reps = i < weeklyReps.length ? weeklyReps[i] : 0;
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: reps.toDouble(),
                        color: AppColors.sageGreen,
                        width: 22,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                      ),
                    ],
                  );
                }),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => AppColors.espresso,
                    getTooltipItem: (group, groupIdx, rod, rodIdx) => BarTooltipItem(
                      '${rod.toY.toInt()}',
                      AppTextStyles.caption.copyWith(color: Colors.white),
                    ),
                  ),
                ),
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

class _RepStats extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final senior = ref.watch(selectedSeniorProvider);
    if (senior == null) return const SizedBox.shrink();
    final insights = ref.watch(seniorInsightsProvider(senior.id));

    final weeklyReps = insights.weeklyReps;
    // Sparkline from real daily rep counts.
    final repSpots = List.generate(
      weeklyReps.length,
      (i) => FlSpot(i.toDouble(), weeklyReps[i].toDouble()),
    );
    // Consistency sparkline: 1.0 for active days, 0.0 for rest days.
    final consistencySpots = List.generate(
      weeklyReps.length,
      (i) => FlSpot(i.toDouble(), weeklyReps[i] > 0 ? 1.0 : 0.0),
    );
    final fallbackSpots = [const FlSpot(0, 0), const FlSpot(1, 0)];

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: _StatCard(
              icon: Icons.speed_outlined,
              title: 'Speed',
              subtitle: 'Average Rep Time',
              value: insights.avgRepTimeSeconds.toStringAsFixed(1),
              unit: 'sec',
              label: 'per repetition this month',
              spots: repSpots.length >= 2 ? repSpots : fallbackSpots,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _StatCard(
              icon: Icons.track_changes_outlined,
              title: 'Consistency',
              subtitle: 'Rep Completion Rate',
              value: '${insights.consistencyPercent.toInt()}',
              unit: '%',
              label: '${insights.daysActiveThisMonth}/${insights.totalDaysThisMonth} days active',
              spots: consistencySpots.length >= 2 ? consistencySpots : fallbackSpots,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final String unit;
  final String label;
  final List<FlSpot> spots;

  const _StatCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.unit,
    required this.label,
    required this.spots,
  });

  @override
  Widget build(BuildContext context) {
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
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.caption),
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
