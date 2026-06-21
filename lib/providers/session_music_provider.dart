import 'dart:async';

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/senior.dart';
import 'hardware_provider.dart';
import 'locale_provider.dart';
import 'senior_provider.dart';

/// Gapless layered-music engine using isolated instrument stems.
///
/// All [kMaxLayers] stems are the *same* long track split per instrument.
/// They play **simultaneously, in sync, from the first rep** — layers 2…N
/// start silent (volume 0). "Adding a layer" simply fades that stem's volume
/// up, so it enters perfectly in time with zero loading/seeking latency.
///
/// A master stem (layer 1) drives the clock; the others are nudged back into
/// alignment periodically to counter any drift between the independent players.
///
/// Rules:
///   * Nothing is audible until rep #1 is detected.
///   * Every `repsPerLayer` reps the next stem fades in (capped at the active
///     song's layer count). `repsPerLayer` scales with the senior's daily goal
///     so the full mix lands as the goal is met (see [repsPerLayerForGoal]).
///   * The track loops continuously; the session ends only on manual stop.
///
/// [kMaxLayers] is the MAXIMUM number of layers any song can have — we allocate
/// that many players/enhancers once. Each song then uses the first
/// `song.layerCount` of them (see [SongOption.stems]); the rest stay muted.
/// Raised to 6 so songs with a full 6-stem split (drums/bass/guitar/piano/
/// other/vocals) can use them all.
const int kMaxLayers = 6;

/// Master volume range. 0–100% is normal device volume; 100–200% applies an
/// extra gain boost (via AndroidLoudnessEnhancer) so the music can play louder
/// than the phone's usual maximum.
const double kMaxVolume = 2.0;

/// Loudness-enhancer gain (just_audio targetGain units, ≈ tens of dB) applied
/// at full boost (200%). ~1.0 ≈ +10 dB. Below 100% no boost is applied.
const double _kMaxBoostGain = 1.0;

/// A spoken count is read out every this many reps to encourage the senior
/// ("5", "10", "15"…). The music keeps playing underneath.
const int kAnnounceEvery = 5;

/// How far the music is ducked (its volume multiplier) while the count is
/// spoken, so the voice is clearly audible over it. 0.25 = 25% of current
/// volume. Restored to full once the announcement finishes.
const double _kDuckFactor = 0.25;

/// Stem filenames in build-up order (layer 1 → layer 5). Each song folder
/// under assets/audio/stems/ holds these same five files.
const List<String> kStemFiles = [
  'drums.mp3', // layer 1 — rhythmic foundation
  'bass.mp3', // layer 2
  'guitar.mp3', // layer 3
  'other.mp3', // layer 4 — keys / extras
  'vocals.mp3', // layer 5 — full song
];

// Builds the asset path for a given [layer] using that song's own [stems] list,
// so each song decides its own number/order of layers.
String stemAssetPath(String folder, List<String> stems, int layer) =>
    'assets/audio/stems/$folder/${stems[layer]}';

/// A selectable song. [stems] lists its layer files in build-up order (layer 1
/// → N); its length is the song's layer count. Defaults to the standard 5-stem
/// set ([kStemFiles]); a song with fewer stems (e.g. a ballad with no drums)
/// just supplies a shorter list and the engine plays it as a TRUE N-layer
/// build-up — no duplicated/faked stems.
class SongOption {
  final String id;
  final String name;
  final String folder;
  final List<String> stems;
  const SongOption({
    required this.id,
    required this.name,
    required this.folder,
    this.stems = kStemFiles,
  });

  /// How many layers this song actually has.
  int get layerCount => stems.length;
}

const List<SongOption> kSongs = [
  SongOption(id: '半斤八两', name: '半斤八两', folder: 'banjinbaliang'),
  SongOption(id: '甜蜜蜜', name: '甜蜜蜜', folder: 'tianmimi'),
  SongOption(id: '小苹果', name: '小苹果', folder: 'xiaopingguo'),
  // "Over the Rainbow" — a ballad with no percussion. A TRUE 4-layer song built
  // up from its instrumental bed → bass → guitar → vocals (no drums stem).
  SongOption(
    id: 'Over the Rainbow',
    name: 'Over the Rainbow',
    folder: 'overtherainbow',
    stems: ['other.mp3', 'bass.mp3', 'guitar.mp3', 'vocals.mp3'],
  ),
  // "I Want It That Way" — a 4-layer build-up: piano → drums → other → vocals.
  SongOption(
    id: 'I Want It That Way',
    name: 'I Want It That Way',
    folder: 'iwantitthatway',
    stems: ['piano.mp3', 'drums.mp3', 'other.mp3', 'vocals.mp3'],
  ),
  // 中国话 (S.H.E) — a full 6-layer build-up using every stem:
  // drums → bass → guitar → piano → other (keys) → vocals.
  SongOption(
    id: '中国话',
    name: '中国话',
    folder: 'zhongguohua',
    stems: ['drums.mp3', 'bass.mp3', 'guitar.mp3', 'piano.mp3', 'other.mp3', 'vocals.mp3'],
  ),
  // 阿里山 (Teresa Teng) — a 4-layer build-up: drums → bass → other → vocals.
  SongOption(
    id: '阿里山',
    name: '阿里山',
    folder: 'alishan',
    stems: ['drums.mp3', 'bass.mp3', 'other.mp3', 'vocals.mp3'],
  ),
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
/// There are [kMaxLayers] layers but only `kMaxLayers - 1` transitions
/// (layer 1 is audible from the first rep), so spacing them evenly across the
/// goal means the final, fullest layer lands exactly as the goal is met.
/// e.g. goal 20 → 5 reps/layer, goal 40 → 10 reps/layer, goal 12 → 3.
int repsPerLayerForGoal(int dailyRepGoal, int layerCount) {
  if (dailyRepGoal <= 0) return kDefaultRepsPerLayer;
  // A song with N layers has N-1 transitions (layer 1 is audible from rep 1).
  // Guard against 0/1-layer songs so we never divide by zero.
  final transitions = (layerCount - 1).clamp(1, layerCount);
  return (dailyRepGoal / transitions).round().clamp(1, dailyRepGoal);
}

/// Number of stems that should be audible for a cumulative rep count, capped at
/// the active song's [layerCount].
int layerForReps(int reps, int repsPerLayer, int layerCount) =>
    (1 + reps ~/ repsPerLayer).clamp(1, layerCount);

class SessionMusicState {
  /// True once rep #1 has been detected and playback has begun.
  final bool started;

  /// True once the session has been stopped.
  final bool ended;

  /// Cumulative reps reported by the mat this session.
  final int reps;

  /// Number of stems currently audible (1…[kMaxLayers]).
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

  /// The active song's total number of layers (varies per song — e.g. 5 for the
  /// standard set, 4 for a drumless ballad, 3 for a partial set).
  final int layerCount;

  /// The active song's stem filenames in build-up order — used to label each
  /// layer correctly per song (not every song has drums/bass/guitar).
  final List<String> stems;

  /// Master volume, 0.0–[kMaxVolume]. Above 1.0 boosts past the phone's max.
  final double volume;

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
    this.layerCount = kMaxLayers,
    this.stems = kStemFiles,
    this.volume = 1.0,
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

  /// True when boosting above the phone's normal maximum.
  bool get isBoosted => volume > 1.0;

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
    int? layerCount,
    List<String>? stems,
    double? volume,
  }) => SessionMusicState(
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
    layerCount: layerCount ?? this.layerCount,
    stems: stems ?? this.stems,
    volume: volume ?? this.volume,
  );
}

class SessionMusicNotifier extends Notifier<SessionMusicState> {
  /// One player per stem. Index 0 (drums) is the master clock.
  late final List<AudioPlayer> _players;
  AudioPlayer get _master => _players[0];

  /// One loudness enhancer per stem (Android) for the >100% volume boost.
  late final List<AndroidLoudnessEnhancer> _enhancers;

  /// Per-stem layer gain (0–1, the fade target). The actual player volume is
  /// this × the master volume scalar, so the master slider and the per-layer
  /// fades compose cleanly.
  final List<double> _layerGain = List.filled(kMaxLayers, 0.0);

  static const _volKey = 'session_music_volume';
  double _volume = 1.0;
  // Once the user touches the slider, don't let the async restore clobber it.
  bool _volumeTouched = false;

  /// Text-to-speech engine for the spoken rep-count encouragements.
  FlutterTts? _tts;

  /// Temporary music-volume multiplier (1.0 = normal). Dropped to [_kDuckFactor]
  /// while a count is being spoken, then restored. Composes with the master
  /// volume and the per-layer gain in [_pushStemVolume].
  double _duckFactor = 1.0;

  /// Highest rep milestone already announced this session, so each "5/10/15…"
  /// is spoken exactly once even though the mat reports a cumulative count.
  int _lastAnnounced = 0;
  bool _announcing = false;

  // 0–100% maps to the player's own volume; above 100% pins it at 1.0 and the
  // extra is applied as loudness-enhancer gain.
  double get _volScalar => _volume < 1.0 ? _volume : 1.0;
  double get _boostGain => _volume <= 1.0
      ? 0.0
      : ((_volume - 1.0) * _kMaxBoostGain).clamp(0.0, _kMaxBoostGain);

  void _pushStemVolume(int i) => _players[i].setVolume(
    (_layerGain[i] * _volScalar * _duckFactor).clamp(0.0, 1.0),
  );

  void _applyBoost() {
    for (final e in _enhancers) {
      e.setTargetGain(_boostGain);
    }
  }

  StreamSubscription<int>? _repSub;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<Duration?>? _durSub;
  StreamSubscription<PlayerState>? _playerStateSub;

  Timer? _syncTimer;
  final List<Timer?> _fadeTimers = List.filled(kMaxLayers, null);

  bool _ready = false;
  bool _looping = false;
  String _currentFolder = kSongs.first.folder;
  // How many layers the CURRENTLY LOADED song uses (≤ kMaxLayers). All active
  // playback loops iterate this, not kMaxLayers, so unused players stay idle.
  int _activeLayerCount = kStemFiles.length;

  // Drift beyond this between a stem and the master triggers a re-align.
  static const _driftTolerance = Duration(milliseconds: 60);

  @override
  SessionMusicState build() {
    _enhancers = List.generate(kMaxLayers, (_) => AndroidLoudnessEnhancer());
    _players = List.generate(
      kMaxLayers,
      (i) => AudioPlayer(
        audioPipeline: AudioPipeline(androidAudioEffects: [_enhancers[i]]),
      ),
    );
    for (final e in _enhancers) {
      e.setEnabled(true);
    }

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

    // Keep the spoken-count voice in the app's current language.
    ref.listen<Locale>(localeProvider, (_, locale) {
      _applyTtsLanguage(locale);
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
      _tts?.stop();
    });

    final goal = ref.read(selectedSeniorProvider)?.dailyRepGoal;
    _currentFolder = ref.read(activeSongFolderProvider);
    _preloadStems(_currentFolder); // sets _activeLayerCount synchronously
    _loadVolume();
    _initTts(ref.read(localeProvider));
    final song = songForFolder(_currentFolder);
    return SessionMusicState.initial(
      repsPerLayer: repsPerLayerForGoal(goal ?? 0, _activeLayerCount),
      songName: song.name,
    ).copyWith(layerCount: _activeLayerCount, stems: song.stems);
  }

  /// Restores the saved master volume and applies it.
  Future<void> _loadVolume() async {
    final prefs = await SharedPreferences.getInstance();
    if (_volumeTouched) return; // user already adjusted it — don't override
    _volume = (prefs.getDouble(_volKey) ?? 1.0).clamp(0.0, kMaxVolume);
    state = state.copyWith(volume: _volume);
    _applyBoost();
    for (var i = 0; i < kMaxLayers; i++) {
      _pushStemVolume(i);
    }
  }

  /// Sets the master volume (0.0–[kMaxVolume]); above 1.0 boosts past the
  /// phone's normal maximum. Persists the choice for next time.
  Future<void> setMasterVolume(double v) async {
    _volumeTouched = true;
    _volume = v.clamp(0.0, kMaxVolume);
    state = state.copyWith(volume: _volume);
    for (var i = 0; i < kMaxLayers; i++) {
      _pushStemVolume(i);
    }
    _applyBoost();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_volKey, _volume);
  }

  // ---- spoken rep-count encouragements --------------------------------------

  /// Prepares the text-to-speech engine: a slower, clear voice suited to
  /// elderly listeners, set to wait for each utterance to finish.
  Future<void> _initTts(Locale locale) async {
    try {
      final tts = FlutterTts();
      await tts.awaitSpeakCompletion(true);
      await tts.setSpeechRate(0.45); // slower & clearer than the default
      await tts.setVolume(1.0);
      await tts.setPitch(1.0);
      _tts = tts;
      await _applyTtsLanguage(locale);
    } catch (_) {
      _tts = null; // TTS unavailable on this device — feature just stays silent
    }
  }

  Future<void> _applyTtsLanguage(Locale locale) async {
    final tts = _tts;
    if (tts == null) return;
    final lang = locale.languageCode == 'zh' ? 'zh-CN' : 'en-US';
    try {
      await tts.setLanguage(lang);
    } catch (_) {}
  }

  /// If [cumulativeReps] has reached a new multiple of [kAnnounceEvery], speak
  /// that count out loud once, ducking the music underneath it.
  void _maybeAnnounce(int cumulativeReps) {
    if (_tts == null) return;
    final milestone = (cumulativeReps ~/ kAnnounceEvery) * kAnnounceEvery;
    if (milestone < kAnnounceEvery || milestone <= _lastAnnounced) return;
    _lastAnnounced = milestone;
    _announce(milestone);
  }

  /// Ducks the music, speaks [count], then restores the music volume.
  Future<void> _announce(int count) async {
    final tts = _tts;
    if (tts == null || _announcing) return; // don't overlap ducking
    _announcing = true;
    _duckFactor = _kDuckFactor;
    for (var i = 0; i < kMaxLayers; i++) {
      _pushStemVolume(i);
    }
    try {
      await tts.stop();
      await tts.speak('$count');
    } catch (_) {
      // ignore — restore volume regardless below
    }
    _duckFactor = 1.0;
    for (var i = 0; i < kMaxLayers; i++) {
      _pushStemVolume(i);
    }
    _announcing = false;
  }

  /// Loads this song's stems, sets each to loop, and mutes it. They sit
  /// pre-buffered so the first rep can start all of them with no load latency.
  /// Only `song.layerCount` players are loaded; any spare players (for songs
  /// with fewer layers than [kMaxLayers]) are stopped and muted so they never
  /// play. Sets `_activeLayerCount` up front so the rest of the engine and the
  /// UI know how many layers this song has.
  Future<void> _preloadStems(String folder) async {
    _ready = false;
    final song = songForFolder(folder);
    final stems = song.stems;
    _activeLayerCount = stems.length; // sync — read immediately by callers
    try {
      for (var i = 0; i < kMaxLayers; i++) {
        if (i < stems.length) {
          await _players[i].setAsset(stemAssetPath(folder, stems, i));
          // Loop is driven as a group from the master's completion (see
          // _loopAll), so individual players must NOT auto-loop.
          await _players[i].setLoopMode(LoopMode.off);
        } else {
          // Spare player not used by this (shorter) song — keep it idle.
          try {
            await _players[i].stop();
          } catch (_) {}
        }
        _layerGain[i] = 0.0;
        await _players[i].setVolume(0);
      }
      _ready = true;
      state = state.copyWith(
        assetMissing: false,
        duration: _master.duration ?? Duration.zero,
        songName: song.name,
        layerCount: _activeLayerCount,
        stems: stems,
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
    // The new song may have a different number of layers → recompute the
    // per-layer cadence and clamp the current layer into the new song's range.
    final goal = ref.read(selectedSeniorProvider)?.dailyRepGoal ?? 0;
    final rpl = repsPerLayerForGoal(goal, _activeLayerCount);
    final layer = layerForReps(state.reps, rpl, _activeLayerCount);
    state = state.copyWith(repsPerLayer: rpl, layer: layer);
    if (resume && _ready) {
      await _startPlayback(layer);
    }
  }

  // ---- BLE rep handling -----------------------------------------------------

  void _onRep(int cumulativeReps) {
    if (state.ended) return;
    // The mat reset its counter (new session) — start announcing from zero again.
    if (cumulativeReps < state.reps) _lastAnnounced = 0;
    final targetLayer =
        layerForReps(cumulativeReps, state.repsPerLayer, _activeLayerCount);

    if (!state.started) {
      if (cumulativeReps < 1) {
        state = state.copyWith(reps: cumulativeReps);
        return;
      }
      _lastAnnounced = 0;
      state = state.copyWith(
        started: true,
        reps: cumulativeReps,
        layer: targetLayer,
      );
      _startPlayback(targetLayer);
      _maybeAnnounce(cumulativeReps);
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
    _maybeAnnounce(cumulativeReps);
  }

  void _onGoalChanged(int? goal) {
    final newRepsPerLayer = repsPerLayerForGoal(goal ?? 0, _activeLayerCount);
    if (newRepsPerLayer == state.repsPerLayer) return;
    state = state.copyWith(repsPerLayer: newRepsPerLayer);

    if (!state.started || state.ended) return;
    final targetLayer =
        layerForReps(state.reps, newRepsPerLayer, _activeLayerCount);
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
      // Only this song's active layers; spare players stay idle/muted.
      for (var i = 0; i < _activeLayerCount; i++) {
        await _players[i].seek(Duration.zero);
        _layerGain[i] = i < audibleLayers ? 1.0 : 0.0;
        _pushStemVolume(i);
      }
      // Start them as close together as possible.
      await Future.wait(_players.take(_activeLayerCount).map((p) => p.play()));
      // One alignment pass after start jitter settles, then keep correcting.
      Future.delayed(const Duration(milliseconds: 400), _syncStems);
      _syncTimer?.cancel();
      _syncTimer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => _syncStems(),
      );
    } catch (_) {
      state = state.copyWith(assetMissing: true);
    }
  }

  /// Pulls every non-master stem back to the master's position if it has
  /// drifted beyond [_driftTolerance].
  Future<void> _syncStems() async {
    if (_looping || !_master.playing) return;
    final ref0 = _master.position;
    for (var i = 1; i < _activeLayerCount; i++) {
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
      for (var i = 0; i < _activeLayerCount; i++) {
        await _players[i].seek(Duration.zero);
      }
      await Future.wait(_players.take(_activeLayerCount).map((p) => p.play()));
    } catch (_) {
      // ignore — next completion will retry
    } finally {
      _looping = false;
    }
  }

  /// Smoothly ramps stem [i]'s layer gain to [target] over ~700 ms. The actual
  /// player volume is the gain scaled by the master volume.
  void _fadeTo(int i, double target) {
    _fadeTimers[i]?.cancel();
    const steps = 14;
    const stepDur = Duration(milliseconds: 50);
    final start = _layerGain[i];
    final delta = target - start;
    if (delta == 0) return;
    var step = 0;
    _fadeTimers[i] = Timer.periodic(stepDur, (t) {
      step++;
      _layerGain[i] = (start + delta * (step / steps)).clamp(0.0, 1.0);
      _pushStemVolume(i);
      if (step >= steps) {
        _layerGain[i] = target;
        _pushStemVolume(i);
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
      for (var i = 0; i < _activeLayerCount; i++) {
        _players[i].play();
      }
      _syncStems();
    }
  }

  /// Restarts the track from the beginning at the layer implied by current reps.
  Future<void> restart() async {
    if (!state.started) return;
    final layer = layerForReps(state.reps, state.repsPerLayer, _activeLayerCount);
    for (var i = 0; i < _activeLayerCount; i++) {
      _fadeTimers[i]?.cancel();
      await _players[i].seek(Duration.zero);
      _layerGain[i] = i < layer ? 1.0 : 0.0;
      _pushStemVolume(i);
    }
    state = state.copyWith(ended: false, layer: layer, position: Duration.zero);
    await Future.wait(_players.take(_activeLayerCount).map((p) => p.play()));
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
      SessionMusicNotifier.new,
    );
