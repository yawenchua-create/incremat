import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/utils/chair_stand.dart';
import '../models/senior.dart';
import '../models/session_log.dart';
import '../services/notifications/notification_service.dart';
import 'senior_provider.dart';

/// What kind of decline in the 5-rep sit-to-stand time we detected.
enum MobilityAlertKind { none, dayDrop, weekDrop }

/// Result of analysing a senior's recent 5-rep (5XSST) times.
class MobilityAlert {
  final MobilityAlertKind kind;

  /// The concerning (slower / larger) value, in seconds.
  final double latestSeconds;

  /// What [latestSeconds] is being compared against (prior baseline / last
  /// week's average), in seconds.
  final double baselineSeconds;

  /// The day the latest value is from (for a day-drop), else null.
  final DateTime? day;

  const MobilityAlert({
    required this.kind,
    this.latestSeconds = 0,
    this.baselineSeconds = 0,
    this.day,
  });

  static const none = MobilityAlert(kind: MobilityAlertKind.none);

  bool get isAlerting => kind != MobilityAlertKind.none;

  /// How much slower the latest value is vs the baseline, as a percentage.
  int get percentSlower => baselineSeconds <= 0
      ? 0
      : (((latestSeconds / baselineSeconds) - 1) * 100).round();
}

// ── Tuning thresholds ─────────────────────────────────────────────────────────
// A "dramatic" single-day drop: at least 30% slower AND 3+ seconds slower than
// the recent baseline (both, so trivial day-to-day noise never alerts).
const double _dayRatioThreshold = 1.30;
const double _dayAbsoluteThreshold = 3.0;
// A sustained weekly decline: this week averages 15%+ slower than last week.
const double _weekRatioThreshold = 1.15;

DateTime _dayKey(DateTime t) => DateTime(t.year, t.month, t.day);

double _median(List<double> values) {
  if (values.isEmpty) return 0;
  final sorted = [...values]..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[mid]
      : (sorted[mid - 1] + sorted[mid]) / 2;
}

double _mean(List<double> values) =>
    values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;

/// Best (fastest) 5-rep time per active day, mirroring clinical "best effort"
/// scoring and damping noise from a single slow session.
Map<DateTime, double> _bestPerDay(List<SessionLog> sessions) {
  final map = <DateTime, double>{};
  for (final s in sessions) {
    if (!s.hasFiveRepTime) continue;
    final key = _dayKey(s.timestamp);
    final cur = map[key];
    if (cur == null || s.firstFiveRepsSeconds < cur) {
      map[key] = s.firstFiveRepsSeconds;
    }
  }
  return map;
}

/// Analyses the last 28 days of 5-rep times and flags a decline worth a
/// caregiver check-in. Pure function so it's easy to test/reuse.
MobilityAlert analyseMobility(List<SessionLog> sessions, {DateTime? now}) {
  final today = _dayKey(now ?? DateTime.now());
  final perDay = _bestPerDay(sessions);
  if (perDay.length < 2) return MobilityAlert.none;

  final days = perDay.keys.toList()..sort();

  // ── Day-over-day sudden drop ────────────────────────────────────────────────
  final latestDay = days.last;
  final latest = perDay[latestDay]!;
  final priorDays = days.where((d) => d != latestDay).toList();
  if (priorDays.length >= 3) {
    // Baseline = median of up to the 7 most recent prior active days.
    final recentPrior = priorDays
        .sublist(priorDays.length > 7 ? priorDays.length - 7 : 0)
        .map((d) => perDay[d]!)
        .toList();
    final baseline = _median(recentPrior);
    if (baseline > 0 &&
        latest >= baseline * _dayRatioThreshold &&
        (latest - baseline) >= _dayAbsoluteThreshold) {
      return MobilityAlert(
        kind: MobilityAlertKind.dayDrop,
        latestSeconds: latest,
        baselineSeconds: baseline,
        day: latestDay,
      );
    }
  }

  // ── Week-over-week decline ──────────────────────────────────────────────────
  final weekAgo = today.subtract(const Duration(days: 7));
  final twoWeeksAgo = today.subtract(const Duration(days: 14));
  final thisWeek = <double>[];
  final lastWeek = <double>[];
  perDay.forEach((day, secs) {
    if (!day.isBefore(weekAgo)) {
      thisWeek.add(secs);
    } else if (!day.isBefore(twoWeeksAgo)) {
      lastWeek.add(secs);
    }
  });
  if (thisWeek.length >= 2 && lastWeek.length >= 2) {
    final thisAvg = _mean(thisWeek);
    final lastAvg = _mean(lastWeek);
    if (lastAvg > 0 && thisAvg >= lastAvg * _weekRatioThreshold) {
      return MobilityAlert(
        kind: MobilityAlertKind.weekDrop,
        latestSeconds: thisAvg,
        baselineSeconds: lastAvg,
      );
    }
  }

  return MobilityAlert.none;
}

/// Live mobility-alert state for a senior, derived from their recent sessions.
final mobilityAlertProvider =
    Provider.family<MobilityAlert, String>((ref, seniorId) {
  final sessions =
      ref.watch(mobilityWindowSessionsProvider(seniorId)).valueOrNull ?? [];
  return analyseMobility(sessions);
});

/// A unique signature for an alert occurrence, so the same day/week event only
/// notifies the caregiver once (even across rebuilds and app launches).
String _signature(MobilityAlert a, DateTime now) {
  switch (a.kind) {
    case MobilityAlertKind.dayDrop:
      final d = a.day!;
      return 'day|${d.year}-${d.month}-${d.day}';
    case MobilityAlertKind.weekDrop:
      final monday = _dayKey(now).subtract(Duration(days: now.weekday - 1));
      return 'week|${monday.year}-${monday.month}-${monday.day}';
    case MobilityAlertKind.none:
      return 'none';
  }
}

/// Watches every senior's mobility alert and pushes a local notification the
/// first time a distinct decline appears. Keep this alive (watch it from the
/// app shell) so alerts fire even when the caregiver isn't on that senior's
/// screen. Notification text is English to match the existing reminders.
class MobilityAlertWatcher extends Notifier<void> {
  @override
  void build() {
    final seniors = ref.watch(seniorsProvider);
    for (final senior in seniors) {
      final alert = ref.watch(mobilityAlertProvider(senior.id));
      if (alert.isAlerting) _maybeNotify(senior, alert);
      _maybeRemindChairStand(senior);
    }
  }

  /// Pushes a reminder when a senior is due for their monthly chair-stand
  /// retest. Only for re-tests — the never-tested case is covered by the
  /// profile-creation prompt and the in-app card. Deduped on the last test
  /// date so each monthly due fires once.
  Future<void> _maybeRemindChairStand(Senior senior) async {
    final lastAt = senior.chairStandTestAt;
    if (lastAt == null || !ChairStand.isRetestDue(lastAt)) return;
    final sig = 'cs|${lastAt.millisecondsSinceEpoch}';
    final prefs = await SharedPreferences.getInstance();
    final key = 'chair_stand_reminder_${senior.id}';
    if (prefs.getString(key) == sig) return;
    await prefs.setString(key, sig);
    await NotificationService().showChairStandReminder(
      senior.id,
      'Fitness check due',
      "It's time for ${senior.name}'s monthly chair stand test.",
    );
  }

  Future<void> _maybeNotify(Senior senior, MobilityAlert alert) async {
    final sig = _signature(alert, DateTime.now());
    final prefs = await SharedPreferences.getInstance();
    final key = 'mobility_alert_last_${senior.id}';
    if (prefs.getString(key) == sig) return; // already alerted for this event
    await prefs.setString(key, sig);

    final body = alert.kind == MobilityAlertKind.dayDrop
        ? "${senior.name}'s sit-to-stand was ${alert.percentSlower}% slower than usual today. Consider checking in."
        : "${senior.name}'s sit-to-stand has slowed ${alert.percentSlower}% this week. Consider checking in.";
    await NotificationService()
        .showMobilityAlert(senior.id, 'Mobility check-in', body);
  }
}

final mobilityAlertWatcherProvider =
    NotifierProvider<MobilityAlertWatcher, void>(MobilityAlertWatcher.new);
