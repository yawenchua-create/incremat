import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/utils/rep_segmenter.dart';
import 'hardware_provider.dart';
import 'senior_provider.dart';
import 'auth_provider.dart';

class LiveSession {
  final String seniorId;
  final DateTime startedAt;
  final int repCount;
  final double avgRepTimeSeconds;
  // Seconds elapsed from the 1st to the 5th rep — the on-mat 5XSST proxy.
  // 0 until the 5th rep of this session lands.
  final double firstFiveRepsSeconds;

  const LiveSession({
    required this.seniorId,
    required this.startedAt,
    required this.repCount,
    required this.avgRepTimeSeconds,
    this.firstFiveRepsSeconds = 0.0,
  });

  LiveSession copyWith({
    int? repCount,
    double? avgRepTimeSeconds,
    double? firstFiveRepsSeconds,
  }) => LiveSession(
    seniorId: seniorId,
    startedAt: startedAt,
    repCount: repCount ?? this.repCount,
    avgRepTimeSeconds: avgRepTimeSeconds ?? this.avgRepTimeSeconds,
    firstFiveRepsSeconds: firstFiveRepsSeconds ?? this.firstFiveRepsSeconds,
  );
}

class LiveSessionNotifier extends Notifier<LiveSession?> {
  StreamSubscription<int>? _repSub;
  StreamSubscription<double>? _speedSub;
  Timer? _flushTimer;

  // Turns the mat's single cumulative counter into per-session reps (see
  // RepSegmenter for the edge-case handling). Recreated on every build.
  RepSegmenter _segmenter = RepSegmenter();

  @override
  LiveSession? build() {
    final service = ref.watch(hardwareServiceProvider);
    _repSub?.cancel();
    _speedSub?.cancel();
    _segmenter = RepSegmenter();
    _repSub = service.repCountStream.listen(_onRep);
    _speedSub = service.avgRepTimeStream.listen(_onSpeed);

    // Only an explicit "who's on the mat" signal (an NFC tap) switches the
    // attributed senior — never merely viewing another profile.
    ref.listen<String?>(activeExerciserIdProvider, (prev, next) {
      if (prev != next && next != null) _onUserSwitch(next);
    });

    ref.onDispose(() {
      _repSub?.cancel();
      _speedSub?.cancel();
      _flushTimer?.cancel();
    });
    return null;
  }

  void _onRep(int cumulativeCount) {
    // Don't log reps performed during an in-progress chair-stand test; resume
    // normal counting from here once it finishes.
    if (ref.read(chairStandTestActiveProvider)) {
      _segmenter.establish(cumulativeCount);
      return;
    }

    final reps = _segmenter.onCount(cumulativeCount);
    if (reps <= 0) return;

    // Attribution is locked for the life of a session: keep the current
    // session's senior; only at session start do we pick the active exerciser
    // (NFC) or, failing that, the senior being viewed.
    final current = state;
    final seniorId =
        current?.seniorId ??
        ref.read(activeExerciserIdProvider) ??
        ref.read(selectedSeniorProvider)?.id;
    if (seniorId == null) return;

    if (current == null) {
      // ignore: avoid_print
      print('[SESSION] new session started: senior=$seniorId reps=$reps');
      // startedAt marks the first rep; the 5-rep time is measured against it.
      state = LiveSession(
        seniorId: seniorId,
        startedAt: DateTime.now(),
        repCount: reps,
        avgRepTimeSeconds: 0.0,
      );
    } else {
      var updated = current.copyWith(repCount: reps);
      // Capture the 5XSST proxy the instant the 5th rep of this session lands.
      if (updated.firstFiveRepsSeconds == 0 && reps >= 5) {
        final secs =
            DateTime.now().difference(updated.startedAt).inMilliseconds /
            1000.0;
        if (secs > 0) updated = updated.copyWith(firstFiveRepsSeconds: secs);
      }
      state = updated;
    }
    _resetFlushTimer();
    _publishLive();
  }

  /// Called when the active exerciser changes (an NFC tap on the mat).
  /// Finalizes the outgoing person's session and rebaselines so the new
  /// person's reps start at zero.
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
    _segmenter.establish();
  }

  /// Persists the in-progress session (if any) right now, **awaiting** the
  /// write, then rebaselines so the next person's reps start from zero. Call
  /// this *before* switching the active exerciser (e.g. an NFC tap on the mat)
  /// so the outgoing person's session is logged and never lost. Unlike the
  /// reactive [_onUserSwitch] path, the caller can await this to guarantee the
  /// save commits before attribution changes. Does not change the
  /// active-exerciser selection.
  Future<void> finalizeCurrentSession() async {
    final current = state;
    // ignore: avoid_print
    print('[SESSION] finalizeCurrentSession: current=${current == null ? 'NULL' : 'senior=${current.seniorId} reps=${current.repCount}'}');
    // Clear live state up front so the next rep begins a fresh session.
    state = null;
    _segmenter.establish();
    if (current != null) await _finalizeSession(current);
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
    _segmenter.establish();
    // An NFC tap attributes only the current session; once it ends by idle,
    // defer back to the selected senior for the next one.
    ref.read(activeExerciserIdProvider.notifier).state = null;
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
    final uid = ref.read(authStateProvider).valueOrNull?.uid;
    if (session.repCount > 0 && uid != null) {
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
              firstFiveRepsSeconds: session.firstFiveRepsSeconds,
              source: 'mat',
              recordedBy: uid,
            )
            .timeout(const Duration(seconds: 8));
        debugPrint('[LIVE] saved ${session.repCount} reps to ${session.seniorId}');
      } catch (e) {
        debugPrint('[LIVE] FAILED to save ${session.repCount} reps to '
            '${session.seniorId}: $e');
      }
    } else {
      debugPrint('[LIVE] finalize for ${session.seniorId} wrote nothing '
          '(reps=${session.repCount}, authed=${uid != null})');
    }
    // No longer in progress — stop publishing it as live to the play app.
    await repo
        .clearLive()
        .timeout(const Duration(seconds: 5))
        .catchError((_) {});
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
