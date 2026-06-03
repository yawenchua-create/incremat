import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../models/senior.dart';
import 'hardware_provider.dart';
import 'senior_provider.dart';

/// Gapless layered-music engine using isolated instrument stems.
///
/// All [kLayerCount] stems are the *same* long track split per instrument.
/// They play **simultaneously, in sync, from the first rep** — layers 2…N
/// start silent (volume 0). "Adding a layer" simply fades that stem's volume
/// up, so it enters perfectly in time with zero loading/seeking latency.
///
/// A master stem (layer 1) drives the clock; the others are nudged back into
/// alignment periodically to counter any drift between the independent players.
///
/// Rules:
///   * Nothing is audible until rep #1 is detected.
///   * Every `repsPerLayer` reps the next stem fades in (capped at
///     [kLayerCount]). `repsPerLayer` scales with the senior's daily goal so
///     the full mix lands as the goal is met (see [repsPerLayerForGoal]).
///   * The track loops continuously; the session ends only on manual stop.
const int kLayerCount = 5;

/// Stem filenames in build-up order (layer 1 → layer 5). Each song folder
/// under assets/audio/stems/ holds these same five files.
const List<String> kStemFiles = [
  'drums.mp3', // layer 1 — rhythmic foundation
  'bass.mp3', // layer 2
  'guitar.mp3', // layer 3
  'other.mp3', // layer 4 — keys / extras
  'vocals.mp3', // layer 5 — full song
];

String stemAssetPath(String folder, int layer) =>
    'assets/audio/stems/$folder/${kStemFiles[layer]}';

/// A selectable song, mapped to its stem folder. [id] matches the track names
/// shown in the Settings music card so the selection drives playback.
class SongOption {
  final String id;
  final String name;
  final String folder;
  const SongOption({required this.id, required this.name, required this.folder});
}

const List<SongOption> kSongs = [
  SongOption(id: '半斤八两', name: '半斤八两', folder: 'banjinbaliang'),
  SongOption(id: '甜蜜蜜', name: '甜蜜蜜', folder: 'tianmimi'),
];

SongOption songForFolder(String folder) =>
    kSongs.firstWhere((s) => s.folder == folder, orElse: () => kSongs.first);

/// Resolves which song's stems the active senior should hear, from their
/// Settings track selection. Falls back to the first song.
final activeSongFolderProvider = Provider<String>((ref) {
  final senior = ref.watch(selectedSeniorProvider);
  if (senior == null) return kSongs.first.folder;
  final track = ref.watch(selectedTrackProvider(senior.id));
  if (track != null) {
    final match = kSongs.where((s) => s.id == track).firstOrNull;
    if (match != null) return match.folder;
  }
  return kSongs.first.folder;
});

const List<String> kLayerNames = [
  'Drums',
  'Bass',
  'Guitar',
  'Melody',
  'Vocals',
];

const List<String> kLayerHints = [
  'Rhythmic foundation',
  'Bass groove joins',
  'Guitar joins in',
  'Keys & extras fill out',
  'Vocals — full song',
];

/// Fallback cadence when no daily goal is known (matches a 20-rep design:
/// 5 reps × 4 layer transitions).
const int kDefaultRepsPerLayer = 5;

/// Derives how many reps separate each layer from the daily rep goal.
///
/// There are [kLayerCount] layers but only `kLayerCount - 1` transitions
/// (layer 1 is audible from the first rep), so spacing them evenly across the
/// goal means the final, fullest layer lands exactly as the goal is met.
/// e.g. goal 20 → 5 reps/layer, goal 40 → 10 reps/layer, goal 12 → 3.
int repsPerLayerForGoal(int dailyRepGoal) {
  if (dailyRepGoal <= 0) return kDefaultRepsPerLayer;
  final transitions = kLayerCount - 1;
  return (dailyRepGoal / transitions).round().clamp(1, dailyRepGoal);
}

/// Number of stems that should be audible for a cumulative rep count.
int layerForReps(int reps, int repsPerLayer) =>
    (1 + reps ~/ repsPerLayer).clamp(1, kLayerCount);

class SessionMusicState {
  /// True once rep #1 has been detected and playback has begun.
  final bool started;

  /// True once the session has been stopped.
  final bool ended;

  /// Cumulative reps reported by the mat this session.
  final int reps;

  /// Number of stems currently audible (1…[kLayerCount]).
  final int layer;

  /// Whether audio is actively playing right now.
  final bool isPlaying;

  /// Playback position / length of the track.
  final Duration position;
  final Duration duration;

  /// True when one or more stems could not be loaded.
  final bool assetMissing;

  /// Reps between each layer, derived from the senior's daily rep goal.
  final int repsPerLayer;

  /// Display name of the song currently loaded.
  final String songName;

  const SessionMusicState({
    required this.started,
    required this.ended,
    required this.reps,
    required this.layer,
    required this.isPlaying,
    required this.position,
    required this.duration,
    required this.assetMissing,
    required this.repsPerLayer,
    required this.songName,
  });

  factory SessionMusicState.initial({int? repsPerLayer, String? songName}) =>
      SessionMusicState(
        started: false,
        ended: false,
        reps: 0,
        layer: 1,
        isPlaying: false,
        position: Duration.zero,
        duration: Duration.zero,
        assetMissing: false,
        repsPerLayer: repsPerLayer ?? kDefaultRepsPerLayer,
        songName: songName ?? kSongs.first.name,
      );

  /// Progress through the track in the range 0.0–1.0.
  double get trackProgress {
    final ms = duration.inMilliseconds;
    if (ms <= 0) return 0;
    return (position.inMilliseconds / ms).clamp(0.0, 1.0);
  }

  SessionMusicState copyWith({
    bool? started,
    bool? ended,
    int? reps,
    int? layer,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    bool? assetMissing,
    int? repsPerLayer,
    String? songName,
  }) =>
      SessionMusicState(
        started: started ?? this.started,
        ended: ended ?? this.ended,
        reps: reps ?? this.reps,
        layer: layer ?? this.layer,
        isPlaying: isPlaying ?? this.isPlaying,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        assetMissing: assetMissing ?? this.assetMissing,
        repsPerLayer: repsPerLayer ?? this.repsPerLayer,
        songName: songName ?? this.songName,
      );
}

class SessionMusicNotifier extends Notifier<SessionMusicState> {
  /// One player per stem. Index 0 (drums) is the master clock.
  late final List<AudioPlayer> _players;
  AudioPlayer get _master => _players[0];

  StreamSubscription<int>? _repSub;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;
  StreamSubscription<PlayerState>? _playerStateSub;

  Timer? _syncTimer;
  final List<Timer?> _fadeTimers = List.filled(kLayerCount, null);

  bool _ready = false;
  bool _looping = false;
  String _currentFolder = kSongs.first.folder;

  // Drift beyond this between a stem and the master triggers a re-align.
  static const _driftTolerance = Duration(milliseconds: 60);

  @override
  SessionMusicState build() {
    _players = List.generate(kLayerCount, (_) => AudioPlayer());

    // Consume the existing BLE rep-count stream — we never re-implement BLE.
    final service = ref.watch(hardwareServiceProvider);
    _repSub = service.repCountStream.listen(_onRep);

    // The master stem drives the UI clock and the layer fades.
    _posSub = _master.positionStream.listen((p) {
      state = state.copyWith(position: p);
    });
    _durSub = _master.durationStream.listen((d) {
      state = state.copyWith(duration: d ?? Duration.zero);
    });
    _playerStateSub = _master.playerStateStream.listen((ps) {
      // Track end → loop the whole stack from the start, keeping every layer's
      // volume exactly where it is so the progress (layers) carries over.
      if (ps.processingState == ProcessingState.completed) {
        if (state.started && !state.ended) _loopAll();
        return; // swallow the transient "not playing" at the loop seam
      }
      if (state.isPlaying != ps.playing) {
        state = state.copyWith(isPlaying: ps.playing);
      }
    });

    // Scale the layer cadence with the active senior's daily goal. listen (not
    // watch) so a goal change adjusts in place without restarting playback.
    ref.listen<Senior?>(selectedSeniorProvider, (_, next) {
      _onGoalChanged(next?.dailyRepGoal);
    });

    // Swap the loaded song when the selected track changes.
    ref.listen<String>(activeSongFolderProvider, (_, folder) {
      _onSongChanged(folder);
    });

    ref.onDispose(() {
      _repSub?.cancel();
      _posSub?.cancel();
      _durSub?.cancel();
      _playerStateSub?.cancel();
      _syncTimer?.cancel();
      for (final t in _fadeTimers) {
        t?.cancel();
      }
      for (final p in _players) {
        p.dispose();
      }
    });

    final goal = ref.read(selectedSeniorProvider)?.dailyRepGoal;
    _currentFolder = ref.read(activeSongFolderProvider);
    _preloadStems(_currentFolder);
    return SessionMusicState.initial(
      repsPerLayer: repsPerLayerForGoal(goal ?? 0),
      songName: songForFolder(_currentFolder).name,
    );
  }

  /// Loads every stem of [folder], sets it to loop, and mutes it. They sit
  /// pre-buffered so the first rep can start all of them with no load latency.
  Future<void> _preloadStems(String folder) async {
    _ready = false;
    try {
      for (var i = 0; i < kLayerCount; i++) {
        await _players[i].setAsset(stemAssetPath(folder, i));
        // Loop is driven as a group from the master's completion (see
        // _loopAll), so individual players must NOT auto-loop.
        await _players[i].setLoopMode(LoopMode.off);
        await _players[i].setVolume(0);
      }
      _ready = true;
      state = state.copyWith(
        assetMissing: false,
        duration: _master.duration ?? Duration.zero,
        songName: songForFolder(folder).name,
      );
    } catch (_) {
      state = state.copyWith(assetMissing: true);
    }
  }

  /// Switches to a different song. Reloads its stems and, if a session was
  /// already running, resumes playback from the start at the current layer.
  Future<void> _onSongChanged(String folder) async {
    if (folder == _currentFolder) return;
    _currentFolder = folder;
    _syncTimer?.cancel();
    for (final t in _fadeTimers) {
      t?.cancel();
    }
    final resume = state.started && !state.ended;
    for (final p in _players) {
      await p.stop();
    }
    await _preloadStems(folder);
    if (resume && _ready) {
      await _startPlayback(state.layer);
    }
  }

  // ---- BLE rep handling -----------------------------------------------------

  void _onRep(int cumulativeReps) {
    if (state.ended) return;
    final targetLayer = layerForReps(cumulativeReps, state.repsPerLayer);

    if (!state.started) {
      if (cumulativeReps < 1) {
        state = state.copyWith(reps: cumulativeReps);
        return;
      }
      state = state.copyWith(started: true, reps: cumulativeReps, layer: targetLayer);
      _startPlayback(targetLayer);
      return;
    }

    final previousLayer = state.layer;
    state = state.copyWith(reps: cumulativeReps);
    if (targetLayer > previousLayer) {
      state = state.copyWith(layer: targetLayer);
      // Fade in every stem between the old and new layer.
      for (var i = previousLayer; i < targetLayer; i++) {
        _fadeTo(i, 1.0);
      }
    }
  }

  void _onGoalChanged(int? goal) {
    final newRepsPerLayer = repsPerLayerForGoal(goal ?? 0);
    if (newRepsPerLayer == state.repsPerLayer) return;
    state = state.copyWith(repsPerLayer: newRepsPerLayer);

    if (!state.started || state.ended) return;
    final targetLayer = layerForReps(state.reps, newRepsPerLayer);
    if (targetLayer > state.layer) {
      for (var i = state.layer; i < targetLayer; i++) {
        _fadeTo(i, 1.0);
      }
      state = state.copyWith(layer: targetLayer);
    } else if (targetLayer < state.layer) {
      // Goal raised → some layers shouldn't be in yet; fade them back out.
      for (var i = targetLayer; i < state.layer; i++) {
        _fadeTo(i, 0.0);
      }
      state = state.copyWith(layer: targetLayer);
    }
  }

  // ---- playback -------------------------------------------------------------

  /// Starts all stems together, with the first [audibleLayers] at full volume
  /// and the rest silent but playing, then begins drift correction.
  Future<void> _startPlayback(int audibleLayers) async {
    if (!_ready) {
      // Stems still loading — try again shortly.
      Future.delayed(const Duration(milliseconds: 300), () {
        if (state.started && !state.ended) _startPlayback(state.layer);
      });
      return;
    }
    try {
      for (var i = 0; i < kLayerCount; i++) {
        await _players[i].seek(Duration.zero);
        await _players[i].setVolume(i < audibleLayers ? 1.0 : 0.0);
      }
      // Start them as close together as possible.
      await Future.wait(_players.map((p) => p.play()));
      // One alignment pass after start jitter settles, then keep correcting.
      Future.delayed(const Duration(milliseconds: 400), _syncStems);
      _syncTimer?.cancel();
      _syncTimer =
          Timer.periodic(const Duration(seconds: 2), (_) => _syncStems());
    } catch (_) {
      state = state.copyWith(assetMissing: true);
    }
  }

  /// Pulls every non-master stem back to the master's position if it has
  /// drifted beyond [_driftTolerance].
  Future<void> _syncStems() async {
    if (_looping || !_master.playing) return;
    final ref0 = _master.position;
    for (var i = 1; i < kLayerCount; i++) {
      final diff = (_players[i].position - ref0).abs();
      if (diff > _driftTolerance) {
        await _players[i].seek(ref0);
      }
    }
  }

  /// Restarts every stem from the top together when the track finishes, leaving
  /// the per-layer volumes untouched so the layering progress is preserved.
  /// The elderly keeps exercising; the music just rolls over seamlessly.
  Future<void> _loopAll() async {
    if (_looping) return; // guard against duplicate completion events
    _looping = true;
    try {
      for (final p in _players) {
        await p.seek(Duration.zero);
      }
      await Future.wait(_players.map((p) => p.play()));
    } catch (_) {
      // ignore — next completion will retry
    } finally {
      _looping = false;
    }
  }

  /// Smoothly ramps stem [i]'s volume to [target] over ~700 ms.
  void _fadeTo(int i, double target) {
    _fadeTimers[i]?.cancel();
    const steps = 14;
    const stepDur = Duration(milliseconds: 50);
    final start = _players[i].volume;
    final delta = target - start;
    if (delta == 0) return;
    var step = 0;
    _fadeTimers[i] = Timer.periodic(stepDur, (t) {
      step++;
      final v = (start + delta * (step / steps)).clamp(0.0, 1.0);
      _players[i].setVolume(v);
      if (step >= steps) {
        _players[i].setVolume(target);
        t.cancel();
      }
    });
  }

  // ---- manual controls ------------------------------------------------------

  void togglePlayPause() {
    if (!state.started || state.ended) return;
    if (_master.playing) {
      for (final p in _players) {
        p.pause();
      }
    } else {
      for (final p in _players) {
        p.play();
      }
      _syncStems();
    }
  }

  /// Restarts the track from the beginning at the layer implied by current reps.
  Future<void> restart() async {
    if (!state.started) return;
    final layer = layerForReps(state.reps, state.repsPerLayer);
    for (var i = 0; i < kLayerCount; i++) {
      _fadeTimers[i]?.cancel();
      await _players[i].seek(Duration.zero);
      await _players[i].setVolume(i < layer ? 1.0 : 0.0);
    }
    state = state.copyWith(ended: false, layer: layer, position: Duration.zero);
    await Future.wait(_players.map((p) => p.play()));
    _syncStems();
  }

  /// Ends the session immediately.
  Future<void> stop() async {
    _syncTimer?.cancel();
    for (final t in _fadeTimers) {
      t?.cancel();
    }
    await Future.wait(_players.map((p) => p.stop()));
    state = state.copyWith(ended: true, isPlaying: false);
  }
}

final sessionMusicProvider =
    NotifierProvider<SessionMusicNotifier, SessionMusicState>(
        SessionMusicNotifier.new);
