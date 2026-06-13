import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';
import '../../core/utils/chair_stand.dart';
import '../../models/senior.dart';
import '../../models/session_log.dart';
import '../../providers/insights_provider.dart';
import '../../providers/live_session_provider.dart';
import '../../providers/mobility_alert_provider.dart';
import '../../providers/senior_provider.dart';
import '../seniors/chair_stand_test_screen.dart';
import '../seniors/edit_senior_sheet.dart';
import '../seniors/nfc_write_sheet.dart';

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
            SliverToBoxAdapter(child: _MobilityAlertBanner(senior: senior)),
            SliverToBoxAdapter(child: _TodayCard(senior: senior)),
            SliverToBoxAdapter(child: _ChairStandCard(senior: senior)),
            SliverToBoxAdapter(child: _SitToStandCard(senior: senior)),
            SliverToBoxAdapter(child: _WeekCalendar(seniorId: senior.id)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Text(AppLocalizations.of(context).monthlySummary,
                    style: AppTextStyles.headlineSmall),
              ),
            ),
            SliverToBoxAdapter(child: _MonthlySummary(seniorId: senior.id)),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                child: Text(AppLocalizations.of(context).recentSessions,
                    style: AppTextStyles.headlineSmall),
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
    final l = AppLocalizations.of(context);
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
              Text(l.todaysProgress, style: AppTextStyles.titleLarge),
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
                    Text(l.live, style: AppTextStyles.caption),
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
                              ? l.goalMet
                              : todayReps == 0
                                  ? l.notStarted
                                  : l.keepGoing,
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
                      label: l.avgRepTime,
                      value: l.secondsShort(
                          insights.avgRepTimeSeconds.toStringAsFixed(1)),
                      icon: Icons.timer_outlined,
                    ),
                    const SizedBox(height: 12),
                    _MetricRow(
                      label: l.vsYesterday,
                      value: '$repDiffSign${l.repsLabel(repDiff)}',
                      icon: repDiff >= 0 ? Icons.trending_up : Icons.trending_down,
                      valueColor: repDiff >= 0 ? AppColors.sageGreen : AppColors.terracotta,
                    ),
                    const SizedBox(height: 12),
                    _MetricRow(
                      label: l.dailyGoal,
                      value: l.repsLabel(senior.dailyRepGoal),
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

  const _WeekCalendar({required this.seniorId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
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
          Text(l.thisWeek, style: AppTextStyles.titleLarge),
          const SizedBox(height: 4),
          Text(
            l.daysActiveThisWeek(
                insights.daysActiveThisWeek, insights.daysInWeek),
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
                    l.weekdayShort(i),
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
    final l = AppLocalizations.of(context);
    final insights = ref.watch(seniorInsightsProvider(seniorId));
    // Use the same consistency metric as the Insights/stats page (active days
    // ÷ days elapsed since the first active day this week) so the two screens
    // never disagree.
    final consistencyPct = insights.consistencyPercent.round();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: _SummaryTile(
              icon: Icons.repeat_outlined,
              label: l.totalReps,
              value: '${insights.totalRepsThisMonth}',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryTile(
              icon: Icons.calendar_today_outlined,
              label: l.consistency,
              value: '$consistencyPct%',
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _SummaryTile(
              icon: Icons.speed_outlined,
              label: l.avgSpeed,
              value: l.secondsShort(insights.avgRepTimeSeconds.toStringAsFixed(1)),
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

/// A prominent warning shown when a senior's sit-to-stand speed has dropped.
class _MobilityAlertBanner extends ConsumerWidget {
  final Senior senior;
  const _MobilityAlertBanner({required this.senior});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final alert = ref.watch(mobilityAlertProvider(senior.id));
    if (!alert.isAlerting) return const SizedBox.shrink();

    final body = alert.kind == MobilityAlertKind.dayDrop
        ? l.mobilityDayDrop(senior.name, alert.percentSlower)
        : l.mobilityWeekDrop(senior.name, alert.percentSlower);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.terracotta.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.terracotta.withValues(alpha: 0.45)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppColors.terracotta, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.mobilityAlertHeading,
                    style: AppTextStyles.titleMedium
                        .copyWith(color: AppColors.terracotta)),
                const SizedBox(height: 4),
                Text(body, style: AppTextStyles.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Everyday sit-to-stand pace: the senior's usual time for 5 reps during
/// sessions. A personal day-to-day trend — NOT a clinical test or rating.
class _SitToStandCard extends ConsumerWidget {
  final Senior senior;
  const _SitToStandCard({required this.senior});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final insights = ref.watch(seniorInsightsProvider(senior.id));
    final seconds = insights.latestFiveRepSeconds;
    final measured = seconds > 0;

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
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.lightSage.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.speed_outlined,
                    size: 18, color: AppColors.sageGreen),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.fiveRepTitle, style: AppTextStyles.titleLarge),
                    Text(l.fiveRepSubtitle, style: AppTextStyles.caption),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (measured)
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: seconds.toStringAsFixed(1),
                    style: AppTextStyles.statMedium
                        .copyWith(fontSize: 34, color: AppColors.sageGreen),
                  ),
                  TextSpan(
                    text: ' ${l.secUnit}',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            )
          else
            Text(l.doFiveReps, style: AppTextStyles.titleMedium),
          const SizedBox(height: 8),
          Text(l.fiveRepExplain, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

/// Latest 30-Second Chair Stand Test result + a prompt to (re)test when due.
class _ChairStandCard extends StatelessWidget {
  final Senior senior;
  const _ChairStandCard({required this.senior});

  void _startTest(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChairStandTestScreen(
          seniorId: senior.id,
          isInitial: senior.chairStandReps == null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final reps = senior.chairStandReps;
    final due = ChairStand.isRetestDue(senior.chairStandTestAt);
    final rating =
        reps != null ? ChairStand.rate(reps, senior.age, senior.sex) : null;

    Color ratingColor = AppColors.sageGreen;
    String ratingLabel = '';
    switch (rating) {
      case ChairStandRating.belowAverage:
        ratingColor = AppColors.terracotta;
        ratingLabel = l.belowAverage;
      case ChairStandRating.average:
        ratingColor = const Color(0xFFD9A441);
        ratingLabel = l.average;
      case ChairStandRating.aboveAverage:
        ratingColor = AppColors.sageGreen;
        ratingLabel = l.aboveAverage;
      case null:
        break;
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(24),
        border: due
            ? Border.all(color: AppColors.sageGreen.withValues(alpha: 0.5))
            : null,
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
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.lightSage.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.event_seat_outlined,
                    size: 18, color: AppColors.sageGreen),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(l.chairStandCardTitle,
                    style: AppTextStyles.titleLarge),
              ),
              if (reps != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: ratingColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(ratingLabel,
                      style: AppTextStyles.caption.copyWith(
                          color: ratingColor, fontWeight: FontWeight.w700)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (reps != null) ...[
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$reps',
                    style: AppTextStyles.statMedium
                        .copyWith(fontSize: 34, color: ratingColor),
                  ),
                  TextSpan(
                    text: '  ${l.standsInThirtySeconds}',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              senior.chairStandTestAt != null
                  ? l.chairStandLastTested(
                      DateFormat('MMM d, yyyy').format(senior.chairStandTestAt!))
                  : l.chairStandNeverTested,
              style: AppTextStyles.caption,
            ),
            if (senior.chairStandHistory.length >= 2) ...[
              const SizedBox(height: 12),
              Text(l.chairStandTrend,
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.subtleText)),
              const SizedBox(height: 6),
              SizedBox(
                height: 40,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    borderData: FlBorderData(show: false),
                    titlesData: const FlTitlesData(
                      leftTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles:
                          AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: [
                          for (var i = 0;
                              i < senior.chairStandHistory.length;
                              i++)
                            FlSpot(i.toDouble(),
                                senior.chairStandHistory[i].reps.toDouble())
                        ],
                        isCurved: true,
                        color: AppColors.sageGreen,
                        barWidth: 2,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(show: false),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ] else
            Text(l.chairStandBaselinePrompt(senior.name),
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.subtleText)),
          if (due) ...[
            const SizedBox(height: 14),
            if (reps != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.lightSage.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 16, color: AppColors.sageGreen),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(l.chairStandDuePrompt(senior.name),
                          style: AppTextStyles.caption),
                    ),
                  ],
                ),
              ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _startTest(context),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24)),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 20),
                label: Text(
                    reps == null ? l.chairStandDoTest : l.chairStandRetest,
                    style: AppTextStyles.buttonText),
              ),
            ),
          ] else if (reps != null) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _startTest(context),
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                icon: const Icon(Icons.refresh, size: 18),
                label: Text(l.chairStandRetest),
              ),
            ),
          ],
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
                  AppLocalizations.of(context).noSessionsRecorded,
                  style: AppTextStyles.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  AppLocalizations.of(context).sessionsWillAppear,
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
    final l = AppLocalizations.of(context);
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.key_outlined, size: 18, color: AppColors.sageGreen),
              const SizedBox(width: 10),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: AppTextStyles.bodySmall,
                    children: [
                      TextSpan(text: l.playCodeOf(senior.name)),
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
                    SnackBar(content: Text(l.codeCopied)),
                  );
                },
                child: const Icon(Icons.copy_outlined,
                    size: 18, color: AppColors.subtleText),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Enrol or re-enrol a card for this senior at any time.
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => NfcWriteSheet.show(
                context,
                seniorId: senior.id,
                seniorName: senior.name,
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.sageGreen,
                side: BorderSide(
                    color: AppColors.sageGreen.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.nfc, size: 18),
              label: Text(l.enrolNfcCard),
            ),
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
    final l = AppLocalizations.of(context);
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
                Text(l.today, style: AppTextStyles.titleMedium),
                Text(
                  l.repsSyncing(liveSession.repCount),
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
              l.repsLabel(liveSession.repCount),
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

  String _relativeTime(AppLocalizations l, DateTime ts) {
    final diff = DateTime.now().difference(ts).inDays;
    if (diff == 0) return l.today;
    if (diff == 1) return l.yesterday;
    return l.daysAgo(diff);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
                Text(_relativeTime(l, session.timestamp), style: AppTextStyles.titleMedium),
                Text(
                  l.sessionRepsAvg(session.repCount,
                      session.avgRepTimeSeconds.toStringAsFixed(1)),
                  style: AppTextStyles.bodySmall,
                ),
                if (session.hasFiveRepTime)
                  Text(
                    '${l.fiveRepLabel}: ${l.secondsShort(session.firstFiveRepsSeconds.toStringAsFixed(1))}',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.sageGreen),
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
              l.repsLabel(session.repCount),
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
