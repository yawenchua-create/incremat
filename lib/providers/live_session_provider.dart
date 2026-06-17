import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/senior.dart';
import 'hardware_provider.dart';
import 'senior_provider.dart';
import 'auth_provider.dart';

class LiveSession {
  final String seniorId;
  final DateTime startedAt;
  final int repCount;
  final double avgRepTimeSeconds;

  const LiveSession({
    required this.seniorId,
    required this.startedAt,
    required this.repCount,
    required this.avgRepTimeSeconds,
  });

  LiveSession copyWith({int? repCount, double? avgRepTimeSeconds}) => LiveSession(
        seniorId: seniorId,
        startedAt: startedAt,
        repCount: repCount ?? this.repCount,
        avgRepTimeSeconds: avgRepTimeSeconds ?? this.avgRepTimeSeconds,
      );
}

class LiveSessionNotifier extends Notifier<LiveSession?> {
  StreamSubscription<int>? _repSub;
  StreamSubscription<double>? _speedSub;
  Timer? _flushTimer;

  // The mat's rep counter is a single running total that does NOT reset on an
  // NFC tap — only on disconnect. So we segment it ourselves:
  //   _lastCumulative = the latest raw count from the mat.
  //   _baseline       = the raw count when the current user's session started.
  //   this user's reps = _lastCumulative - _baseline.
  // When the active senior changes (NFC tap / manual switch) we finalize the
  // previous person's session and move the baseline to the current count, so
  // the next reps count from zero for the new user.
  int _lastCumulative = 0;
  int _baseline = 0;

  @override
  LiveSession? build() {
    final service = ref.watch(hardwareServiceProvider);
    _repSub?.cancel();
    _speedSub?.cancel();
    _repSub = service.repCountStream.listen(_onRep);
    _speedSub = service.avgRepTimeStream.listen(_onSpeed);

    // Segment the rep stream whenever the person on the mat changes.
    ref.listen<Senior?>(selectedSeniorProvider, (prev, next) {
      if (prev?.id != next?.id) _onUserSwitch(next?.id);
    });

    ref.onDispose(() {
      _repSub?.cancel();
      _speedSub?.cancel();
      _flushTimer?.cancel();
    });
    return null;
  }

  void _onRep(int cumulativeCount) {
    // Counter went backwards → mat reset (reconnect). Re-baseline from zero.
    if (cumulativeCount < _lastCumulative) _baseline = 0;
    _lastCumulative = cumulativeCount;
    if (cumulativeCount == 0) return;

    final seniorId = ref.read(selectedSeniorProvider)?.id;
    if (seniorId == null) return;

    final reps = cumulativeCount - _baseline;
    if (reps <= 0) return;

    final current = state;
    if (current == null || current.seniorId != seniorId) {
      state = LiveSession(
        seniorId: seniorId,
        startedAt: DateTime.now(),
        repCount: reps,
        avgRepTimeSeconds: 0.0,
      );
    } else {
      state = current.copyWith(repCount: reps);
    }
    _resetFlushTimer();
    _publishLive();
  }

  /// Called the instant the active senior changes. Finalizes the outgoing
  /// person's session and rebaselines so the new person's reps start at zero.
  void _onUserSwitch(String? newSeniorId) {
    final current = state;
    debugPrint('[LIVE] user switch -> $newSeniorId; outgoing session: '
        '${current == null ? "none" : "${current.seniorId} (${current.repCount} reps)"}');
    if (current != null && current.seniorId != newSeniorId) {
      // Clear the live state synchronously so the new user's first rep starts a
      // fresh session; persist the finished one in the background.
      state = null;
      _finalizeSession(current);
    }
    _baseline = _lastCumulative;
  }

  /// Mirrors the live rep count to Firestore so the play app can show it in
  /// real time. Fire-and-forget; reps arrive at human pace so write volume is
  /// low.
  void _publishLive() {
    final s = state;
    if (s == null) return;
    final repo = ref.read(sessionRepositoryProvider(s.seniorId));
    repo
        ?.updateLive(
          repCount: s.repCount,
          avgRepTimeSeconds: s.avgRepTimeSeconds,
          startedAt: s.startedAt,
        )
        .ignore();
  }

  void _onSpeed(double avgTime) {
    final current = state;
    if (current == null) return;
    state = current.copyWith(avgRepTimeSeconds: avgTime);
  }

  void _resetFlushTimer() {
    _flushTimer?.cancel();
    _flushTimer = Timer(const Duration(minutes: 3), _flush);
  }

  Future<void> _flush() async {
    final current = state;
    if (current == null) return;
    // Clear live state now; persist the completed record afterwards.
    state = null;
    // A new session after this idle gap should start counting from zero.
    _baseline = _lastCumulative;
    await _finalizeSession(current);
  }

  /// Writes [session] as a completed session and clears its live doc.
  /// Best-effort — never throws.
  Future<void> _finalizeSession(LiveSession session) async {
    final repo = ref.read(sessionRepositoryProvider(session.seniorId));
    if (repo == null) {
      debugPrint('[LIVE] finalize SKIPPED for ${session.seniorId}: no repo '
          '(not authenticated?) — ${session.repCount} reps NOT saved');
      return;
    }
    final authed = ref.read(authStateProvider).valueOrNull != null;
    if (session.repCount > 0 && authed) {
      // Keep these reps on the senior's home total until the persisted stream
      // catches up, so the card doesn't momentarily drop to 0 on a user switch.
      ref
          .read(recentlyFinalizedProvider.notifier)
          .remember(session.seniorId, session.repCount);
      try {
        await repo
            .add(
              repCount: session.repCount,
              avgRepTimeSeconds: session.avgRepTimeSeconds,
            )
            .timeout(const Duration(seconds: 8));
        debugPrint('[LIVE] saved ${session.repCount} reps to ${session.seniorId}');
      } catch (e) {
        debugPrint('[LIVE] FAILED to save ${session.repCount} reps to '
            '${session.seniorId}: $e');
      }
    } else {
      debugPrint('[LIVE] finalize for ${session.seniorId} wrote nothing '
          '(reps=${session.repCount}, authed=$authed)');
    }
    // No longer in progress — stop publishing it as live to the play app.
    await repo.clearLive().timeout(const Duration(seconds: 5)).catchError((_) {});
  }

  Future<void> flushNow() => _flush();
}

final liveSessionProvider =
    NotifierProvider<LiveSessionNotifier, LiveSession?>(LiveSessionNotifier.new);

/// Reps from a session that just ended (e.g. another user tapped in), recorded
/// the moment it's persisted. [at] matches the saved session's timestamp.
class FinalizedCarry {
  final int reps;
  final DateTime at;
  const FinalizedCarry({required this.reps, required this.at});
}

/// Bridges the gap between a live session ending and Firestore's session stream
/// reflecting the write. Insights keeps counting a carried entry until the saved
/// record shows up in the stream, so a senior's total never blinks back to 0.
class RecentFinalizedNotifier extends Notifier<Map<String, FinalizedCarry>> {
  @override
  Map<String, FinalizedCarry> build() => {};

  void remember(String seniorId, int reps) {
    final carry = FinalizedCarry(reps: reps, at: DateTime.now());
    state = {...state, seniorId: carry};
    // Safety net: drop it even if the write never lands, so it can't linger.
    Future.delayed(const Duration(seconds: 20), () {
      if (identical(state[seniorId], carry)) {
        state = {...state}..remove(seniorId);
      }
    });
  }
}

final recentlyFinalizedProvider =
    NotifierProvider<RecentFinalizedNotifier, Map<String, FinalizedCarry>>(
        RecentFinalizedNotifier.new);
