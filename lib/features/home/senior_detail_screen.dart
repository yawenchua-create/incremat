import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/senior.dart';
import '../../models/session_log.dart';
import '../../providers/insights_provider.dart';
import '../../providers/live_session_provider.dart';
import '../../providers/senior_provider.dart';
import '../seniors/edit_senior_sheet.dart';

class SeniorDetailScreen extends ConsumerWidget {
  final String seniorId;
  const SeniorDetailScreen({super.key, required this.seniorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seniorsAsync = ref.watch(seniorsStreamProvider);

    // Auto-pop when the senior is deleted while this screen is open.
    if (seniorsAsync.hasValue) {
      final seniors = seniorsAsync.value!;
      final idx = seniors.indexWhere((s) => s.id == seniorId);
      if (idx < 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) Navigator.of(context).pop();
        });
        return const Scaffold(
          backgroundColor: AppColors.warmCream,
          body: SizedBox.shrink(),
        );
      }
    }

    if (!seniorsAsync.hasValue) {
      return const Scaffold(
        backgroundColor: AppColors.warmCream,
        body: Center(child: CircularProgressIndicator(color: AppColors.sageGreen)),
      );
    }

    final senior = seniorsAsync.value!.firstWhere((s) => s.id == seniorId);

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(senior.name, style: AppTextStyles.headlineSmall),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            onPressed: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => EditSeniorSheet(senior: senior),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _TodayCard(senior: senior)),
            SliverToBoxAdapter(child: _WeekCalendar(seniorId: senior.id)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Text('Monthly Summary', style: AppTextStyles.headlineSmall),
              ),
            ),
            SliverToBoxAdapter(child: _MonthlySummary(seniorId: senior.id)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Text('Recent Sessions', style: AppTextStyles.headlineSmall),
              ),
            ),
            SliverToBoxAdapter(child: _SessionsList(seniorId: senior.id)),
            if (senior.joinCode != null)
              SliverToBoxAdapter(child: _PlayCodeCard(senior: senior)),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }
}

class _TodayCard extends ConsumerWidget {
  final Senior senior;
  const _TodayCard({required this.senior});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insights = ref.watch(seniorInsightsProvider(senior.id));
    final todayReps = insights.todayReps;
    final goal = senior.dailyRepGoal;
    final progress = (todayReps / goal).clamp(0.0, 1.0);
    final repDiff = todayReps - insights.yesterdayReps;
    final repDiffSign = repDiff >= 0 ? '+' : '';

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
                      value: '${insights.avgRepTimeSeconds.toStringAsFixed(1)}s',
                      icon: Icons.timer_outlined,
                    ),
                    const SizedBox(height: 12),
                    _MetricRow(
                      label: 'vs. yesterday',
                      value: '$repDiffSign$repDiff reps',
                      icon: repDiff >= 0 ? Icons.trending_up : Icons.trending_down,
                      valueColor: repDiff >= 0 ? AppColors.sageGreen : AppColors.terracotta,
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

class _WeekCalendar extends ConsumerWidget {
  final String seniorId;
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  const _WeekCalendar({required this.seniorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insights = ref.watch(seniorInsightsProvider(seniorId));
    final weeklyReps = insights.weeklyReps;
    final activeSet = {
      for (int i = 0; i < weeklyReps.length && i < 7; i++)
        if (weeklyReps[i] > 0) i,
    };

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
            '${insights.daysActiveThisWeek} of ${insights.daysInWeek} days active',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final isActive = activeSet.contains(i);
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
                      color: isActive ? AppColors.sageGreen : AppColors.subtleText,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
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

class _MonthlySummary extends ConsumerWidget {
  final String seniorId;
  const _MonthlySummary({required this.seniorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final insights = ref.watch(seniorInsightsProvider(seniorId));
    final consistencyPct = insights.totalDaysThisMonth > 0
        ? (insights.daysActiveThisMonth / insights.totalDaysThisMonth * 100).round()
        : 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: _SummaryTile(
              icon: Icons.repeat_outlined,
              label: 'Total Reps',
              value: '${insights.totalRepsThisMonth}',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryTile(
              icon: Icons.calendar_today_outlined,
              label: 'Consistency',
              value: '$consistencyPct%',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryTile(
              icon: Icons.speed_outlined,
              label: 'Avg Speed',
              value: '${insights.avgRepTimeSeconds.toStringAsFixed(1)}s',
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

class _SessionsList extends ConsumerWidget {
  final String seniorId;
  const _SessionsList({required this.seniorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(recentSessionsProvider(seniorId));
    final liveSession = ref.watch(liveSessionProvider);
    final pendingSession = (liveSession != null &&
            liveSession.seniorId == seniorId &&
            liveSession.repCount > 0)
        ? liveSession
        : null;

    return sessionsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.sageGreen),
        ),
      ),
      error: (_, _) => const SizedBox.shrink(),
      data: (sessions) {
        if (sessions.isEmpty && pendingSession == null) {
          return Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            padding: const EdgeInsets.all(24),
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
            child: Column(
              children: [
                Icon(Icons.fitness_center_outlined, size: 32, color: AppColors.lightSage),
                const SizedBox(height: 10),
                Text(
                  'No sessions recorded yet',
                  style: AppTextStyles.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Sessions will appear here once the mat syncs.',
                  style: AppTextStyles.caption,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        return Column(
          children: [
            if (pendingSession != null)
              _PendingSessionTile(liveSession: pendingSession),
            ...sessions.take(10).map((s) => _SessionTile(session: s)),
          ],
        );
      },
    );
  }
}

class _PlayCodeCard extends StatelessWidget {
  final Senior senior;
  const _PlayCodeCard({required this.senior});

  @override
  Widget build(BuildContext context) {
    final code = senior.joinCode!;
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      padding: const EdgeInsets.all(20),
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
          const Icon(Icons.key_outlined, size: 18, color: AppColors.sageGreen),
          const SizedBox(width: 10),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: AppTextStyles.bodySmall,
                children: [
                  TextSpan(text: "${senior.name}'s Play Code: "),
                  TextSpan(
                    text: code,
                    style: AppTextStyles.titleMedium.copyWith(
                      color: AppColors.sageGreen,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: code));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Code copied to clipboard')),
              );
            },
            child: const Icon(Icons.copy_outlined, size: 18, color: AppColors.subtleText),
          ),
        ],
      ),
    );
  }
}

class _PendingSessionTile extends StatelessWidget {
  final LiveSession liveSession;
  const _PendingSessionTile({required this.liveSession});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.sageGreen.withValues(alpha: 0.3)),
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
                Text('Today', style: AppTextStyles.titleMedium),
                Text(
                  '${liveSession.repCount} reps  •  syncing…',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.sageGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${liveSession.repCount} reps',
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

class _SessionTile extends StatelessWidget {
  final SessionLog session;
  const _SessionTile({required this.session});

  String _relativeTime(DateTime ts) {
    final diff = DateTime.now().difference(ts).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '$diff days ago';
  }

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
                Text(_relativeTime(session.timestamp), style: AppTextStyles.titleMedium),
                Text(
                  '${session.repCount} reps  •  avg ${session.avgRepTimeSeconds.toStringAsFixed(1)}s',
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
              '${session.repCount} reps',
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
