import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/senior.dart';
import '../../models/session_log.dart';

class SeniorDetailScreen extends StatelessWidget {
  final Senior senior;
  const SeniorDetailScreen({super.key, required this.senior});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(senior.name, style: AppTextStyles.headlineSmall),
        centerTitle: true,
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _TodayCard(senior: senior)),
            SliverToBoxAdapter(child: _WeekCalendar()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Text('Monthly Summary', style: AppTextStyles.headlineSmall),
              ),
            ),
            SliverToBoxAdapter(child: _MonthlySummary()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Text('Recent Sessions', style: AppTextStyles.headlineSmall),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _SessionTile(index: i),
                childCount: 3,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  final Senior senior;
  const _TodayCard({required this.senior});

  @override
  Widget build(BuildContext context) {
    final todayReps = MockSessionData.todayReps;
    final goal = senior.dailyRepGoal;
    final progress = (todayReps / goal).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(24),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text("Today's Progress", style: AppTextStyles.titleLarge),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.lightSage.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Live', style: AppTextStyles.caption),
                    const SizedBox(width: 4),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: AppColors.sageGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Large progress circle
              SizedBox(
                width: 110,
                height: 110,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 110,
                      height: 110,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 7,
                        backgroundColor: AppColors.lightSage,
                        valueColor: const AlwaysStoppedAnimation(AppColors.sageGreen),
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '$todayReps',
                                style: AppTextStyles.statMedium.copyWith(fontSize: 32),
                              ),
                              TextSpan(
                                text: '/$goal',
                                style: AppTextStyles.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Text(
                          progress >= 1.0
                              ? 'Goal met!'
                              : todayReps == 0
                                  ? 'Not started'
                                  : 'Keep going!',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.sageGreen),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _MetricRow(
                      label: 'Avg. Rep Time',
                      value: '${MockSessionData.avgRepTimeSeconds}s',
                      icon: Icons.timer_outlined,
                    ),
                    const SizedBox(height: 12),
                    _MetricRow(
                      label: 'vs. yesterday',
                      value: '+2 reps',
                      icon: Icons.trending_up,
                      valueColor: AppColors.sageGreen,
                    ),
                    const SizedBox(height: 12),
                    _MetricRow(
                      label: 'Daily goal',
                      value: '${senior.dailyRepGoal} reps',
                      icon: Icons.track_changes_outlined,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _MetricRow({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.lightSage.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: AppColors.sageGreen),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: AppTextStyles.titleMedium.copyWith(
                  fontSize: 13,
                  color: valueColor,
                ),
              ),
              Text(label, style: AppTextStyles.caption),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeekCalendar extends StatelessWidget {
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  // Mock: 5 of 7 days active — Mon, Tue, Wed, Fri, Sat
  static const _active = {0, 1, 2, 4, 5};

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.espresso.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('This Week', style: AppTextStyles.titleLarge),
          const SizedBox(height: 4),
          Text(
            '${MockSessionData.daysActiveThisWeek} of ${MockSessionData.daysInWeek} days active',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final isActive = _active.contains(i);
              return Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isActive ? AppColors.sageGreen : AppColors.lightSage,
                      shape: BoxShape.circle,
                    ),
                    child: isActive
                        ? const Icon(Icons.check, size: 16, color: Colors.white)
                        : null,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _days[i],
                    style: AppTextStyles.caption.copyWith(
                      color:
                          isActive ? AppColors.sageGreen : AppColors.subtleText,
                      fontWeight:
                          isActive ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _MonthlySummary extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: _SummaryTile(
              icon: Icons.repeat_outlined,
              label: 'Total Reps',
              value: '${MockSessionData.totalRepsThisMonth}',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryTile(
              icon: Icons.calendar_today_outlined,
              label: 'Consistency',
              value:
                  '${(MockSessionData.daysActiveThisMonth / MockSessionData.totalDaysThisMonth * 100).round()}%',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryTile(
              icon: Icons.speed_outlined,
              label: 'Avg Speed',
              value: '${MockSessionData.avgRepTimeSeconds}s',
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: AppColors.espresso.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: AppColors.sageGreen),
          const SizedBox(height: 8),
          Text(value, style: AppTextStyles.titleLarge),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.caption, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final int index;
  const _SessionTile({required this.index});

  static const _reps = [8, 9, 7];
  static const _times = ['2.6s', '2.4s', '2.9s'];
  static const _labels = ['This morning', 'Yesterday afternoon', '2 days ago'];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.espresso.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
            child: const Icon(
              Icons.fitness_center_outlined,
              size: 18,
              color: AppColors.sageGreen,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_labels[index], style: AppTextStyles.titleMedium),
                Text(
                  '${_reps[index]} reps  •  avg ${_times[index]}',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.lightSage.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${_reps[index]} reps',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.sageGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
