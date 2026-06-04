import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/session_music_provider.dart';

/// Session Music — a calming, rep-driven layered player that mirrors the
/// IncreMat firmware. Audio is silent until the first rep is detected; chunks
/// advance on their own as they finish, and every five reps a richer layer
/// fades in over the same passage. The whole screen reflects the firmware state
/// live (reps, current layer, current chunk).
class SessionMusicScreen extends ConsumerWidget {
  const SessionMusicScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(sessionMusicProvider);

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            const _Header(),
            const SizedBox(height: 18),
            _NowPlayingCard(state: s),
            const SizedBox(height: 24),
            _LayersHeader(activeLayer: s.started ? s.layer : 0),
            const SizedBox(height: 12),
            for (int layer = 1; layer <= kLayerCount; layer++)
              _LayerRow(
                layer: layer,
                state: s,
              ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context).sessionMusic,
                  style: AppTextStyles.headlineLarge),
              const SizedBox(height: 6),
              Consumer(
                builder: (context, ref, _) {
                  final song = ref.watch(
                      sessionMusicProvider.select((s) => s.songName));
                  return Text(
                    AppLocalizations.of(context).musicNowLoaded(song),
                    style: AppTextStyles.bodySmall,
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF78695A).withValues(alpha: 0.10),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(Icons.spa_outlined,
              size: 22, color: AppColors.sageGreen),
        ),
      ],
    );
  }
}

class _NowPlayingCard extends ConsumerWidget {
  const _NowPlayingCard({required this.state});

  final SessionMusicState state;

  String _label(AppLocalizations l) {
    if (state.ended) return l.musicSessionCompleteLabel;
    if (!state.started) return l.musicWaitingFirstRep;
    return state.isPlaying ? l.musicNowPlaying : l.musicPaused;
  }

  String _titleText(AppLocalizations l) {
    if (state.ended) return l.musicSessionComplete;
    if (!state.started) return l.musicReadyWhenStarts;
    return l.musicLayerTitle(state.layer, l.layerName(state.layer - 1));
  }

  String _subtitle(AppLocalizations l) {
    if (state.assetMissing) {
      return l.musicStemsMissing;
    }
    if (state.ended) {
      return l.musicSessionEnded(state.reps);
    }
    if (!state.started) {
      return l.musicBeginsAutomatically;
    }
    return l.musicStemsPlaying(state.layer, kLayerCount, state.reps);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final notifier = ref.read(sessionMusicProvider.notifier);
    final active = state.started && state.isPlaying && !state.ended;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF78695A).withValues(alpha: 0.10),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Equalizer(animating: active, color: AppColors.sageGreen),
              const SizedBox(width: 10),
              Text(
                _label(l).toUpperCase(),
                style: AppTextStyles.overline
                    .copyWith(color: AppColors.positiveGreen),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(_titleText(l), style: AppTextStyles.displayMedium),
          const SizedBox(height: 5),
          Text(_subtitle(l), style: AppTextStyles.bodySmall),
          const SizedBox(height: 18),
          _StatRow(state: state),
          const SizedBox(height: 18),
          _SeekBar(progress: state.trackProgress),
          const SizedBox(height: 9),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(state.position), style: AppTextStyles.caption),
              Text('-${_fmt(_remaining(state))}',
                  style: AppTextStyles.caption),
            ],
          ),
          const SizedBox(height: 18),
          _Controls(
            state: state,
            onPlayPause: notifier.togglePlayPause,
            onRestart: notifier.restart,
            onStop: notifier.stop,
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  const _StatRow({required this.state});

  final SessionMusicState state;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Row(
      children: [
        _Stat(label: l.musicReps, value: '${state.reps}'),
        _divider(),
        _Stat(
            label: l.musicLayers,
            value: state.started ? '${state.layer}/$kLayerCount' : '—'),
        _divider(),
        _Stat(
            label: l.musicNextLayer,
            value: state.started && state.layer < kLayerCount
                ? l.musicRepN(state.layer * state.repsPerLayer)
                : (state.started ? l.musicFull : '—')),
      ],
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 30,
        color: AppColors.divider,
      );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: AppTextStyles.statMedium.copyWith(fontSize: 24)),
          const SizedBox(height: 2),
          Text(label.toUpperCase(), style: AppTextStyles.overline),
        ],
      ),
    );
  }
}

class _SeekBar extends StatelessWidget {
  const _SeekBar({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final fill = (width * progress).clamp(0.0, width);
        return SizedBox(
          height: 17,
          child: Stack(
            alignment: Alignment.centerLeft,
            clipBehavior: Clip.none,
            children: [
              Container(
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Container(
                height: 5,
                width: fill,
                decoration: BoxDecoration(
                  color: AppColors.sageGreen,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              Positioned(
                left: (fill - 8.5).clamp(0.0, width - 17),
                child: Container(
                  width: 17,
                  height: 17,
                  decoration: BoxDecoration(
                    color: AppColors.positiveGreen,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF62765C).withValues(alpha: 0.4),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({
    required this.state,
    required this.onPlayPause,
    required this.onRestart,
    required this.onStop,
  });

  final SessionMusicState state;
  final VoidCallback onPlayPause;
  final VoidCallback onRestart;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final enabled = state.started;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _SideButton(
          icon: Icons.stop_rounded,
          onTap: enabled && !state.ended ? onStop : null,
          tooltip: l.musicEndSession,
        ),
        const SizedBox(width: 22),
        _PlayButton(
          isPlaying: state.isPlaying,
          onTap: enabled && !state.ended ? onPlayPause : null,
        ),
        const SizedBox(width: 22),
        _SideButton(
          icon: Icons.replay_rounded,
          onTap: enabled ? onRestart : null,
          tooltip: l.musicRestart,
        ),
      ],
    );
  }
}

class _SideButton extends StatelessWidget {
  const _SideButton({required this.icon, required this.onTap, this.tooltip});

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final color =
        onTap == null ? AppColors.mutedSage : AppColors.espresso;
    final button = InkResponse(
      onTap: onTap,
      radius: 26,
      child: SizedBox(
        width: 42,
        height: 42,
        child: Icon(icon, size: 24, color: color),
      ),
    );
    return tooltip == null
        ? button
        : Tooltip(message: tooltip!, child: button);
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.isPlaying, required this.onTap});

  final bool isPlaying;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: enabled ? AppColors.sageGreen : AppColors.mutedSage,
          shape: BoxShape.circle,
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: const Color(0xFF7C8F75).withValues(alpha: 0.45),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Icon(
          isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
          size: 30,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _LayersHeader extends StatelessWidget {
  const _LayersHeader({required this.activeLayer});

  final int activeLayer;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(l.musicSessionLayers, style: AppTextStyles.headlineMedium),
        Text(
          activeLayer == 0
              ? l.musicLayersCount(kLayerCount)
              : l.musicLayerActive(activeLayer),
          style: AppTextStyles.bodySmall,
        ),
      ],
    );
  }
}

class _LayerRow extends StatelessWidget {
  const _LayerRow({required this.layer, required this.state});

  final int layer;
  final SessionMusicState state;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final unlocked = state.started && layer <= state.layer;
    final isCurrent = state.started && layer == state.layer && !state.ended;
    final animating = isCurrent && state.isPlaying;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: isCurrent ? AppColors.lightSage : AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent ? AppColors.mutedSage : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: isCurrent
            ? null
            : [
                BoxShadow(
                  color: const Color(0xFF78695A).withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isCurrent
                  ? AppColors.sageGreen
                  : unlocked
                      ? AppColors.lightSage
                      : const Color(0xFFEAE7E0),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: isCurrent
                  ? _Equalizer(animating: animating, color: Colors.white)
                  : unlocked
                      ? const Icon(Icons.check_rounded,
                          size: 20, color: AppColors.positiveGreen)
                      : Icon(Icons.lock_outline_rounded,
                          size: 18, color: AppColors.subtleText),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.musicLayerTitle(layer, l.layerName(layer - 1)),
                  style: AppTextStyles.titleMedium,
                ),
                const SizedBox(height: 1),
                Text(l.layerHint(layer - 1), style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isCurrent
                ? (state.isPlaying ? l.musicPlaying : l.musicPaused)
                : unlocked
                    ? l.musicUnlocked
                    : l.musicRepN(layer == 1 ? 1 : (layer - 1) * state.repsPerLayer),
            style: AppTextStyles.caption.copyWith(
              color: isCurrent ? AppColors.positiveGreen : AppColors.subtleText,
              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}


/// Three little bars that bounce while audio is playing — the design's signature
/// "now playing" motif.
class _Equalizer extends StatefulWidget {
  const _Equalizer({required this.animating, required this.color});

  final bool animating;
  final Color color;

  @override
  State<_Equalizer> createState() => _EqualizerState();
}

class _EqualizerState extends State<_Equalizer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animating) _controller.repeat();
  }

  @override
  void didUpdateWidget(_Equalizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animating && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animating && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const delays = [0.0, 0.2, 0.4, 0.13];
    return SizedBox(
      height: 14,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (int i = 0; i < 4; i++) ...[
            AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = (_controller.value + delays[i]) % 1.0;
                // ease in/out between 25% and 100% height.
                final wave = (0.5 - (t - 0.5).abs()) * 2; // 0→1→0 triangle
                final h = widget.animating ? 3.5 + wave * 10.5 : 4.0;
                return Container(
                  width: 3,
                  height: h,
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              },
            ),
            if (i != 3) const SizedBox(width: 2.5),
          ],
        ],
      ),
    );
  }
}

String _fmt(Duration d) {
  final total = d.inSeconds < 0 ? 0 : d.inSeconds;
  final m = total ~/ 60;
  final s = total % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

Duration _remaining(SessionMusicState state) {
  final remaining = state.duration - state.position;
  return remaining.isNegative ? Duration.zero : remaining;
}
