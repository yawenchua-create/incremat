import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import 'hardware_provider.dart';

/// Mirrors the IncreMat firmware's layered-music engine.
///
/// Audio is organised into [kLayerCount] layers, each containing up to
/// [kMaxChunks] chunks. The same chunk index in different layers is the *same*
/// musical passage rendered with progressively richer instrumentation (stems),
/// so advancing a layer mid-chunk keeps the playback position and just swaps in
/// a fuller arrangement.
///
/// Firmware rules reproduced here exactly:
///   * Nothing plays until rep #1 is detected.
///   * Chunks advance automatically when the current chunk finishes.
///   * Every [kRepsPerLayer] reps the current layer increments (capped at
///     [kLayerCount]); playback immediately jumps to the new layer at the
///     *current* chunk index — the chunk is never reset on a layer change.
///   * The session ends when chunk [kMaxChunks] finishes.
const int kLayerCount = 5;
const int kMaxChunks = 20;
const int kRepsPerLayer = 5;

/// Hardcoded asset manifest. Files are organised one folder per layer
/// (`assets/audio/01` … `assets/audio/05`), each holding 20 chunks named
/// `001.mp3` … `020.mp3`. The engine resolves paths from the live state.
final List<String> kSessionMusicAssets = [
  for (int layer = 1; layer <= kLayerCount; layer++)
    for (int chunk = 1; chunk <= kMaxChunks; chunk++)
      sessionMusicAssetPath(layer, chunk),
];

String sessionMusicAssetPath(int layer, int chunk) {
  final layerDir = layer.toString().padLeft(2, '0');
  final chunkFile = chunk.toString().padLeft(3, '0');
  return 'assets/audio/$layerDir/$chunkFile.mp3';
}

/// Computes the active layer for a cumulative rep count, following the
/// firmware's "increment every [kRepsPerLayer] reps, cap at [kLayerCount]" rule.
/// rep 1-4 → layer 1, rep 5-9 → layer 2, … rep 20+ → layer 5.
int layerForReps(int reps) =>
    (1 + reps ~/ kRepsPerLayer).clamp(1, kLayerCount);

class SessionMusicState {
  /// True once rep #1 has been detected and playback has begun.
  final bool started;

  /// True once chunk [kMaxChunks] has finished — the session is complete.
  final bool ended;

  /// Cumulative reps reported by the mat this session.
  final int reps;

  /// Current layer (1…[kLayerCount]).
  final int layer;

  /// Current chunk (1…[kMaxChunks]).
  final int chunk;

  /// Whether audio is actively playing right now.
  final bool isPlaying;

  /// Playback position / length of the current chunk.
  final Duration position;
  final Duration duration;

  /// True when the resolved mp3 could not be loaded (e.g. files not added yet).
  final bool assetMissing;

  const SessionMusicState({
    required this.started,
    required this.ended,
    required this.reps,
    required this.layer,
    required this.chunk,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.assetMissing,
  });

  factory SessionMusicState.initial() => const SessionMusicState(
        started: false,
        ended: false,
        reps: 0,
        layer: 1,
        chunk: 1,
        isPlaying: false,
        position: Duration.zero,
        duration: Duration.zero,
        assetMissing: false,
      );

  /// Progress through the current chunk in the range 0.0–1.0.
  double get chunkProgress {
    final ms = duration.inMilliseconds;
    if (ms <= 0) return 0;
    return (position.inMilliseconds / ms).clamp(0.0, 1.0);
  }

  SessionMusicState copyWith({
    bool? started,
    bool? ended,
    int? reps,
    int? layer,
    int? chunk,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    bool? assetMissing,
  }) =>
      SessionMusicState(
        started: started ?? this.started,
        ended: ended ?? this.ended,
        reps: reps ?? this.reps,
        layer: layer ?? this.layer,
        chunk: chunk ?? this.chunk,
        isPlaying: isPlaying ?? this.isPlaying,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        assetMissing: assetMissing ?? this.assetMissing,
      );
}

class SessionMusicNotifier extends Notifier<SessionMusicState> {
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<int>? _repSub;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;
  StreamSubscription<PlayerState>? _playerStateSub;

  /// Guards completion events while we are intentionally swapping the source,
  /// so a `setAsset` reset is never mistaken for a chunk finishing.
  bool _transitioning = false;

  @override
  SessionMusicState build() {
    // Subscribe to the EXISTING BLE rep-count stream — we never re-implement
    // BLE here, we only consume the cumulative counts the firmware notifies.
    final service = ref.watch(hardwareServiceProvider);
    _repSub = service.repCountStream.listen(_onRep);

    _posSub = _player.positionStream.listen((p) {
      state = state.copyWith(position: p);
    });
    _durSub = _player.durationStream.listen((d) {
      state = state.copyWith(duration: d ?? Duration.zero);
    });
    _playerStateSub = _player.playerStateStream.listen(_onPlayerState);

    ref.onDispose(() {
      _repSub?.cancel();
      _posSub?.cancel();
      _durSub?.cancel();
      _playerStateSub?.cancel();
      _player.dispose();
    });

    return SessionMusicState.initial();
  }

  // ---- BLE rep handling -----------------------------------------------------

  void _onRep(int cumulativeReps) {
    if (state.ended) return;

    final targetLayer = layerForReps(cumulativeReps);

    if (!state.started) {
      // Nothing plays until rep #1.
      if (cumulativeReps < 1) {
        state = state.copyWith(reps: cumulativeReps);
        return;
      }
      state = state.copyWith(
        started: true,
        reps: cumulativeReps,
        layer: targetLayer,
        chunk: 1,
      );
      _loadCurrentChunk(fromStart: true);
      return;
    }

    final previousLayer = state.layer;
    state = state.copyWith(reps: cumulativeReps);

    if (targetLayer != previousLayer) {
      state = state.copyWith(layer: targetLayer);
      _swapLayerKeepingPosition();
    }
  }

  // ---- audio transitions ----------------------------------------------------

  /// Loads the chunk for the current layer/chunk and plays it from the start.
  Future<void> _loadCurrentChunk({required bool fromStart}) async {
    _transitioning = true;
    try {
      await _player.setAsset(sessionMusicAssetPath(state.layer, state.chunk));
      if (fromStart) await _player.seek(Duration.zero);
      state = state.copyWith(
        assetMissing: false,
        duration: _player.duration ?? Duration.zero,
      );
      await _player.play();
    } catch (_) {
      state = state.copyWith(assetMissing: true, isPlaying: false);
    } finally {
      _transitioning = false;
    }
  }

  /// Layer change: swap to the same chunk in the new layer but keep the current
  /// playback position, so the arrangement thickens without restarting the bar.
  Future<void> _swapLayerKeepingPosition() async {
    _transitioning = true;
    final position = _player.position;
    final wasPlaying = _player.playing;
    try {
      await _player.setAsset(sessionMusicAssetPath(state.layer, state.chunk));
      final duration = _player.duration ?? Duration.zero;
      final seekTo = position <= duration ? position : duration;
      await _player.seek(seekTo);
      state = state.copyWith(assetMissing: false, duration: duration);
      if (wasPlaying) await _player.play();
    } catch (_) {
      state = state.copyWith(assetMissing: true);
    } finally {
      _transitioning = false;
    }
  }

  void _onPlayerState(PlayerState playerState) {
    if (state.isPlaying != playerState.playing) {
      state = state.copyWith(isPlaying: playerState.playing);
    }

    final finished = playerState.processingState == ProcessingState.completed;
    if (finished && !_transitioning && state.started && !state.ended) {
      _onChunkFinished();
    }
  }

  Future<void> _onChunkFinished() async {
    if (state.chunk >= kMaxChunks) {
      // Session ends when the final chunk finishes.
      state = state.copyWith(ended: true, isPlaying: false);
      await _player.stop();
      return;
    }
    // Chunks advance automatically; the layer carries over unchanged.
    state = state.copyWith(chunk: state.chunk + 1);
    await _loadCurrentChunk(fromStart: true);
  }

  // ---- manual controls (do not alter the rep-driven layer/chunk logic) ------

  void togglePlayPause() {
    if (!state.started || state.ended) return;
    if (_player.playing) {
      _player.pause();
    } else {
      _player.play();
    }
  }

  /// Replays the session from chunk 1 at the layer implied by the current rep
  /// count, without waiting for another rep.
  Future<void> restart() async {
    if (!state.started) return;
    await _player.stop();
    state = state.copyWith(
      ended: false,
      chunk: 1,
      layer: layerForReps(state.reps),
      position: Duration.zero,
    );
    await _loadCurrentChunk(fromStart: true);
  }

  /// Ends the session immediately.
  Future<void> stop() async {
    await _player.stop();
    state = state.copyWith(ended: true, isPlaying: false);
  }
}

final sessionMusicProvider =
    NotifierProvider<SessionMusicNotifier, SessionMusicState>(
        SessionMusicNotifier.new);
