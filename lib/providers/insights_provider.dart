import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/session_log.dart';
import 'auth_provider.dart';
import 'live_session_provider.dart';
import 'senior_provider.dart';

class SeniorInsights {
  final List<int> mobilityScores;
  final double avgRepTimeSeconds;
  final double consistencyPercent;
  final double overallImprovementPercent;
  final int todayReps;
  final int yesterdayReps;
  final int daysActiveThisWeek;
  final int daysInWeek;
  final int totalRepsThisMonth;
  final int daysActiveThisMonth;
  final int totalDaysThisMonth;
  final double speedImprovementSeconds;
  final List<int> weeklyReps;
  final DateTime? lastSessionDate;

  const SeniorInsights({
    required this.mobilityScores,
    required this.avgRepTimeSeconds,
    required this.consistencyPercent,
    required this.overallImprovementPercent,
    required this.todayReps,
    required this.yesterdayReps,
    required this.daysActiveThisWeek,
    required this.daysInWeek,
    required this.totalRepsThisMonth,
    required this.daysActiveThisMonth,
    required this.totalDaysThisMonth,
    required this.speedImprovementSeconds,
    required this.weeklyReps,
    required this.lastSessionDate,
  });
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

SeniorInsights _mockInsights() => SeniorInsights(
      mobilityScores: MockSessionData.mobilityScoresW1toW12,
      avgRepTimeSeconds: MockSessionData.avgRepTimeSeconds,
      consistencyPercent: MockSessionData.consistencyPercent,
      overallImprovementPercent: MockSessionData.overallImprovementPercent,
      todayReps: MockSessionData.todayReps,
      yesterdayReps: 6,
      daysActiveThisWeek: MockSessionData.daysActiveThisWeek,
      daysInWeek: MockSessionData.daysInWeek,
      totalRepsThisMonth: MockSessionData.totalRepsThisMonth,
      daysActiveThisMonth: MockSessionData.daysActiveThisMonth,
      totalDaysThisMonth: MockSessionData.totalDaysThisMonth,
      speedImprovementSeconds: MockSessionData.speedImprovementSeconds,
      weeklyReps: MockSessionData.weeklyReps,
      lastSessionDate: DateTime.now(),
    );

final seniorInsightsProvider =
    Provider.family<SeniorInsights, String>((ref, seniorId) {
  final user = ref.watch(authStateProvider).valueOrNull;
  // Unauthenticated = demo mode; show full mock data so Betty looks realistic.
  if (user == null) return _mockInsights();

  final sessions =
      ref.watch(monthlySessionsProvider(seniorId)).valueOrNull ?? [];

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  // Live BLE reps for this session (added on top of committed Firestore sessions).
  final liveSession = ref.watch(liveSessionProvider);
  final liveReps = liveSession?.seniorId == seniorId ? (liveSession?.repCount ?? 0) : 0;

  // Today's and yesterday's reps
  final todayReps = sessions
          .where((s) => _sameDay(s.timestamp, today))
          .fold(0, (sum, s) => sum + s.repCount) +
      liveReps;
  final yesterday = today.subtract(const Duration(days: 1));
  final yesterdayReps = sessions
      .where((s) => _sameDay(s.timestamp, yesterday))
      .fold(0, (sum, s) => sum + s.repCount);

  // Current week daily reps (Mon = index 0, Sun = index 6)
  final monday = today.subtract(Duration(days: today.weekday - 1));
  final weeklyReps = List.generate(7, (i) {
    final day = monday.add(Duration(days: i));
    return sessions
        .where((s) => _sameDay(s.timestamp, day))
        .fold(0, (sum, s) => sum + s.repCount);
  });
  // Include any in-progress live session in today's slot so active-day count is accurate.
  final effectiveWeeklyReps = List<int>.from(weeklyReps);
  if (liveReps > 0) effectiveWeeklyReps[today.weekday - 1] += liveReps;
  final daysActiveThisWeek = effectiveWeeklyReps.where((r) => r > 0).length;

  // Weekly consistency: active days / days elapsed since first session this week.
  // Resets every Monday so old test data from earlier this month cannot distort it.
  // First active day this week: earliest index (0=Mon) with reps > 0.
  final firstActiveIdx = effectiveWeeklyReps.indexWhere((r) => r > 0);
  final consistencyPercent = firstActiveIdx == -1
      ? 0.0
      : (daysActiveThisWeek / (today.weekday - firstActiveIdx) * 100)
          .clamp(0.0, 100.0);

  // Monthly stats
  final startOfMonth = DateTime(now.year, now.month, 1);
  final monthlySessions =
      sessions.where((s) => !s.timestamp.isBefore(startOfMonth)).toList();
  final totalRepsThisMonth =
      monthlySessions.fold(0, (sum, s) => sum + s.repCount);
  final activeDaysSet = monthlySessions
      .map((s) =>
          DateTime(s.timestamp.year, s.timestamp.month, s.timestamp.day))
      .toSet();
  final daysActiveThisMonth = activeDaysSet.length;
  final totalDaysThisMonth = DateTime(now.year, now.month + 1, 0).day;

  // Average rep time across all monthly sessions with valid speed data.
  // Uses the same session set as consistency and total reps so all three update together.
  final sessionsWithSpeed =
      monthlySessions.where((s) => s.avgRepTimeSeconds > 0).toList();
  final avgRepTimeSeconds = sessionsWithSpeed.isEmpty
      ? 0.0
      : sessionsWithSpeed.fold(0.0, (sum, s) => sum + s.avgRepTimeSeconds) /
          sessionsWithSpeed.length;

  // Last session date
  final lastSessionDate = sessions.isEmpty
      ? null
      : sessions
          .map((s) => s.timestamp)
          .reduce((a, b) => a.isAfter(b) ? a : b);

  return SeniorInsights(
    // 12-week chart and trend deltas are mock until historical aggregation lands.
    mobilityScores: MockSessionData.mobilityScoresW1toW12,
    overallImprovementPercent: MockSessionData.overallImprovementPercent,
    speedImprovementSeconds: MockSessionData.speedImprovementSeconds,
    avgRepTimeSeconds: avgRepTimeSeconds,
    consistencyPercent: consistencyPercent,
    todayReps: todayReps,
    yesterdayReps: yesterdayReps,
    daysActiveThisWeek: daysActiveThisWeek,
    daysInWeek: 7,
    totalRepsThisMonth: totalRepsThisMonth,
    daysActiveThisMonth: daysActiveThisMonth,
    totalDaysThisMonth: totalDaysThisMonth,
    // Use effectiveWeeklyReps (includes live session) so the week calendar
    // lights up today's dot while a session is in progress.
    weeklyReps: effectiveWeeklyReps,
    lastSessionDate: lastSessionDate,
  );
});
