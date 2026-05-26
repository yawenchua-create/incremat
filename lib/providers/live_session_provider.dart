import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

  @override
  LiveSession? build() {
    final service = ref.watch(hardwareServiceProvider);
    _repSub?.cancel();
    _speedSub?.cancel();
    _repSub = service.repCountStream.listen(_onRep);
    _speedSub = service.avgRepTimeStream.listen(_onSpeed);
    ref.onDispose(() {
      _repSub?.cancel();
      _speedSub?.cancel();
      _flushTimer?.cancel();
    });
    return null;
  }

  void _onRep(int cumulativeCount) {
    if (cumulativeCount == 0) return;
    final seniorId = ref.read(selectedSeniorProvider)?.id;
    if (seniorId == null) return;
    final current = state;
    if (current == null) {
      state = LiveSession(
        seniorId: seniorId,
        startedAt: DateTime.now(),
        repCount: cumulativeCount,
        avgRepTimeSeconds: 0.0,
      );
    } else {
      state = current.copyWith(repCount: cumulativeCount);
    }
    _resetFlushTimer();
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
    if (current == null || current.repCount == 0) return;
    if (ref.read(authStateProvider).valueOrNull == null) return;
    final repo = ref.read(sessionRepositoryProvider(current.seniorId));
    if (repo == null) return;
    try {
      await repo
          .add(
            repCount: current.repCount,
            avgRepTimeSeconds: current.avgRepTimeSeconds,
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
    state = null;
  }

  Future<void> flushNow() => _flush();
}

final liveSessionProvider =
    NotifierProvider<LiveSessionNotifier, LiveSession?>(LiveSessionNotifier.new);
