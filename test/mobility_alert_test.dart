import 'package:flutter_test/flutter_test.dart';
import 'package:incremat/models/session_log.dart';
import 'package:incremat/providers/mobility_alert_provider.dart';

void main() {
  final now = DateTime(2026, 6, 11, 12);

  SessionLog s(int daysAgo, double fiveRep) => SessionLog(
        id: '$daysAgo-$fiveRep',
        seniorId: 'x',
        timestamp: now.subtract(Duration(days: daysAgo)),
        repCount: 10,
        avgRepTimeSeconds: 2.5,
        firstFiveRepsSeconds: fiveRep,
      );

  test('stable times → no alert', () {
    final sessions = [s(4, 10), s(3, 10.5), s(2, 9.8), s(1, 10.2), s(0, 10.1)];
    expect(analyseMobility(sessions, now: now).kind, MobilityAlertKind.none);
  });

  test('sudden single-day slowdown → day drop', () {
    // Four steady days ~10s, then today jumps to 14s (40% slower, +4s).
    final sessions = [s(4, 10), s(3, 10), s(2, 10), s(1, 10), s(0, 14)];
    final a = analyseMobility(sessions, now: now);
    expect(a.kind, MobilityAlertKind.dayDrop);
    expect(a.percentSlower, 40);
  });

  test('small daily wobble does not alert', () {
    // +2s / 20% is below the 30% AND +3s thresholds.
    final sessions = [s(4, 10), s(3, 10), s(2, 10), s(1, 10), s(0, 12)];
    expect(analyseMobility(sessions, now: now).kind, MobilityAlertKind.none);
  });

  test('week-over-week decline → week drop', () {
    // Last week ~10s, this week ~12s (20% slower), but no single-day spike.
    final sessions = [
      s(12, 10), s(11, 10), s(9, 10.2), // last week
      s(5, 12), s(3, 12), s(1, 12), // this week
    ];
    final a = analyseMobility(sessions, now: now);
    expect(a.kind, MobilityAlertKind.weekDrop);
  });

  test('too little data → no alert', () {
    expect(analyseMobility([s(0, 14)], now: now).kind, MobilityAlertKind.none);
  });

  test('sessions without a 5-rep time are ignored', () {
    final sessions = [s(2, 0), s(1, 0), s(0, 0)];
    expect(analyseMobility(sessions, now: now).kind, MobilityAlertKind.none);
  });
}
