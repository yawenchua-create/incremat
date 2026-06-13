import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/session_log.dart';
import 'auth_provider.dart';
import 'live_session_provider.dart';
import 'senior_provider.dart';

class SeniorInsights {
  final double avgRepTimeSeconds;
  final double consistencyPercent;
  final int todayReps;
  final int yesterdayReps;
  final int daysActiveThisWeek;
  final int daysInWeek;
  final int totalRepsThisMonth;
  final int daysActiveThisMonth;
  final int totalDaysThisMonth;
  final List<int> weeklyReps;
  final DateTime? lastSessionDate;
  // Most recent everyday 5-rep sit-to-stand pace in seconds; 0 if never seen.
  final double latestFiveRepSeconds;

  const SeniorInsights({
    required this.avgRepTimeSeconds,
    required this.consistencyPercent,
    required this.todayReps,
    required this.yesterdayReps,
    required this.daysActiveThisWeek,
    required this.daysInWeek,
    required this.totalRepsThisMonth,
    required this.daysActiveThisMonth,
    required this.totalDaysThisMonth,
    required this.weeklyReps,
    required this.lastSessionDate,
    this.latestFiveRepSeconds = 0.0,
  });
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// Stats computed over an explicit date range — used by the exportable report
/// so the date-range picker actually filters the numbers.
class ReportStats {
  final int totalReps;
  final int activeDays;
  final int totalDays;
  final double avgRepTimeSeconds;

  const ReportStats({
    required this.totalReps,
    required this.activeDays,
    required this.totalDays,
    required this.avgRepTimeSeconds,
  });

  static const empty =
      ReportStats(totalReps: 0, activeDays: 0, totalDays: 1, avgRepTimeSeconds: 0);
}

final reportStatsProvider =
    FutureProvider.family<ReportStats, (String, DateTime, DateTime)>(
        (ref, key) async {
  final (seniorId, start, end) = key;
  final repo = ref.watch(sessionRepositoryProvider(seniorId));
  if (repo == null) return ReportStats.empty;
  final startDay = DateTime(start.year, start.month, start.day);
  final endDay = DateTime(end.year, end.month, end.day, 23, 59, 59);
  final sessions = await repo.getInRange(startDay, endDay);

  final totalReps = sessions.fold(0, (s, e) => s + e.repCount);
  final activeDays = sessions
      .map((e) => DateTime(e.timestamp.year, e.timestamp.month, e.timestamp.day))
      .toSet()
      .length;
  final totalDays = endDay.difference(startDay).inDays + 1;
  final withSpeed = sessions.where((e) => e.avgRepTimeSeconds > 0).toList();
  final avg = withSpeed.isEmpty
      ? 0.0
      : withSpeed.fold(0.0, (s, e) => s + e.avgRepTimeSeconds) / withSpeed.length;

  return ReportStats(
    totalReps: totalReps,
    activeDays: activeDays,
    totalDays: totalDays,
    avgRepTimeSeconds: avg,
  );
});

SeniorInsights _mockInsights() => SeniorInsights(
      avgRepTimeSeconds: MockSessionData.avgRepTimeSeconds,
      consistencyPercent: MockSessionData.consistencyPercent,
      todayReps: MockSessionData.todayReps,
      yesterdayReps: 6,
      daysActiveThisWeek: MockSessionData.daysActiveThisWeek,
      daysInWeek: MockSessionData.daysInWeek,
      totalRepsThisMonth: MockSessionData.totalRepsThisMonth,
      daysActiveThisMonth: MockSessionData.daysActiveThisMonth,
      totalDaysThisMonth: MockSessionData.totalDaysThisMonth,
      weeklyReps: MockSessionData.weeklyReps,
      lastSessionDate: DateTime.now(),
      latestFiveRepSeconds: 12.5,
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

  // Latest 5-rep sit-to-stand time: prefer an in-progress session that has
  // already passed 5 reps, otherwise the most recent measured session.
  final liveFiveRep =
      (liveSession?.seniorId == seniorId && (liveSession?.firstFiveRepsSeconds ?? 0) > 0)
          ? liveSession!.firstFiveRepsSeconds
          : 0.0;
  final measured = sessions.where((s) => s.hasFiveRepTime).toList()
    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  final latestFiveRepSeconds =
      liveFiveRep > 0 ? liveFiveRep : (measured.isNotEmpty ? measured.first.firstFiveRepsSeconds : 0.0);

  return SeniorInsights(
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
    latestFiveRepSeconds: latestFiveRepSeconds,
  );
});
