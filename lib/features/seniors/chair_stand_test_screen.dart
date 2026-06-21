import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/chair_stand.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/hardware_provider.dart';
import '../../providers/senior_provider.dart';
import '../../services/hardware/hardware_service.dart';

enum _Phase { intro, running, done }

/// Guides the caregiver through the 30-Second Chair Stand Test: instructions, a
/// timed tap-counter (one tap per completed stand), then the result with an
/// age-adjusted fall-risk rating and a recommended starting daily goal.
class ChairStandTestScreen extends ConsumerStatefulWidget {
  final String seniorId;
  // True when run as the baseline test right after creating a profile — the
  // recommended goal toggle then defaults on.
  final bool isInitial;

  const ChairStandTestScreen({
    super.key,
    required this.seniorId,
    this.isInitial = false,
  });

  @override
  ConsumerState<ChairStandTestScreen> createState() =>
      _ChairStandTestScreenState();
}

class _ChairStandTestScreenState extends ConsumerState<ChairStandTestScreen> {
  static const _durationSeconds = 30;

  _Phase _phase = _Phase.intro;
  int _count = 0;
  int _remaining = _durationSeconds;
  Timer? _timer;
  bool _applyGoal = true;
  bool _saving = false;

  // Mat auto-counting: the mat reports a cumulative rep counter; we capture a
  // baseline when the test starts and count the difference. Falls back to
  // manual tapping when the mat isn't connected (or the caregiver turns it off).
  bool _connected = false;
  bool _autoCount = false;
  int _latestCumulative = 0;
  int _baseline = 0;
  StreamSubscription<int>? _repSub;
  StreamSubscription<HardwareStatus>? _statusSub;

  @override
  void initState() {
    super.initState();
    _applyGoal = widget.isInitial;
    final hw = ref.read(hardwareServiceProvider);
    _connected = hw.currentStatus.isConnected;
    _autoCount = _connected;
    _repSub = hw.repCountStream.listen((value) {
      _latestCumulative = value;
      if (_phase == _Phase.running && _autoCount) {
        final c = value - _baseline;
        setState(() => _count = c < 0 ? 0 : c);
      }
    });
    _statusSub = hw.statusStream.listen((s) {
      if (!mounted) return;
      setState(() {
        _connected = s.isConnected;
        // Losing the mat mid-test falls back to manual tapping.
        if (!s.isConnected) _autoCount = false;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _repSub?.cancel();
    _statusSub?.cancel();
    // Make sure we never leave the live pipeline suppressed if the caregiver
    // backs out mid-test.
    ref.read(chairStandTestActiveProvider.notifier).state = false;
    super.dispose();
  }

  void _start() {
    _baseline = _latestCumulative; // count reps from now
    // Tell the live-session pipeline to ignore reps during the test so they
    // aren't double-logged as everyday exercise.
    ref.read(chairStandTestActiveProvider.notifier).state = true;
    setState(() {
      _phase = _Phase.running;
      _count = 0;
      _remaining = _durationSeconds;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_remaining <= 1) {
        _timer?.cancel();
        ref.read(chairStandTestActiveProvider.notifier).state = false;
        setState(() {
          _remaining = 0;
          _phase = _Phase.done;
        });
      } else {
        setState(() => _remaining--);
      }
    });
  }

  // Manual tap only counts when not auto-counting from the mat.
  void _tap() {
    if (_phase == _Phase.running && !_autoCount) setState(() => _count++);
  }

  void _reset() {
    _timer?.cancel();
    ref.read(chairStandTestActiveProvider.notifier).state = false;
    setState(() {
      _phase = _Phase.intro;
      _count = 0;
      _remaining = _durationSeconds;
    });
  }

  Future<void> _save(int recommendedGoal) async {
    setState(() => _saving = true);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final l = AppLocalizations.of(context);
    try {
      await ref.read(seniorsNotifierProvider.notifier).recordChairStandTest(
            widget.seniorId,
            _count,
            newGoal: _applyGoal ? recommendedGoal : null,
          );
      messenger.showSnackBar(SnackBar(content: Text(l.testSaved)));
      nav.pop();
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        messenger.showSnackBar(SnackBar(content: Text(l.couldNotSaveTest)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final senior =
        ref.watch(seniorsProvider).where((s) => s.id == widget.seniorId).firstOrNull;

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        backgroundColor: AppColors.warmCream,
        elevation: 0,
        foregroundColor: AppColors.espresso,
        leading: IconButton(
          icon: const Icon(Icons.close, size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(l.chairStandTitle, style: AppTextStyles.titleLarge),
        centerTitle: true,
      ),
      body: SafeArea(
        child: senior == null
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.sageGreen))
            : switch (_phase) {
                _Phase.intro => _IntroView(
                    onStart: _start,
                    connected: _connected,
                    autoCount: _autoCount,
                    onAutoCountChanged: (v) => setState(() => _autoCount = v),
                  ),
                _Phase.running => _RunningView(
                    count: _count,
                    remaining: _remaining,
                    total: _durationSeconds,
                    autoCount: _autoCount,
                    onTap: _tap,
                  ),
                _Phase.done => _ResultView(
                    reps: _count,
                    age: senior.age,
                    sex: senior.sex,
                    applyGoal: _applyGoal,
                    saving: _saving,
                    onApplyGoalChanged: (v) => setState(() => _applyGoal = v),
                    onSave: _save,
                    onRedo: _reset,
                  ),
              },
      ),
    );
  }
}

class _IntroView extends StatelessWidget {
  final VoidCallback onStart;
  final bool connected;
  final bool autoCount;
  final ValueChanged<bool> onAutoCountChanged;
  const _IntroView({
    required this.onStart,
    required this.connected,
    required this.autoCount,
    required this.onAutoCountChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: AppColors.lightSage.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.event_seat_outlined,
                  size: 48, color: AppColors.sageGreen),
            ),
          ),
          const SizedBox(height: 20),
          Text(l.chairStandIntroTitle,
              style: AppTextStyles.headlineMedium, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(l.chairStandIntroSubtitle,
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.subtleText),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Step(number: 1, text: l.chairStandStep1),
                _Step(number: 2, text: l.chairStandStep2),
                _Step(number: 3, text: l.chairStandStep3),
                _Step(number: 4, text: l.chairStandStep4),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.lightSage.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline,
                    size: 18, color: AppColors.sageGreen),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(l.chairStandSafety,
                      style: AppTextStyles.caption),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Counting mode: auto from the mat (if connected) or manual taps.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(
                  connected ? Icons.bluetooth_connected : Icons.bluetooth_disabled,
                  size: 20,
                  color: connected ? AppColors.sageGreen : AppColors.subtleText,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.countFromMat, style: AppTextStyles.titleMedium),
                      Text(
                        connected
                            ? (autoCount ? l.countFromMatOn : l.countManually)
                            : l.matNotConnectedCount,
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: autoCount,
                  onChanged: connected ? onAutoCountChanged : null,
                  activeThumbColor: AppColors.sageGreen,
                  activeTrackColor: AppColors.sageGreen.withValues(alpha: 0.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: onStart,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28)),
            ),
            icon: const Icon(Icons.play_arrow_rounded, size: 22),
            label: Text(l.startTest, style: AppTextStyles.buttonText),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final int number;
  final String text;
  const _Step({required this.number, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              color: AppColors.sageGreen,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text('$number',
                style: AppTextStyles.caption
                    .copyWith(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: AppTextStyles.bodyMedium)),
        ],
      ),
    );
  }
}

class _RunningView extends StatelessWidget {
  final int count;
  final int remaining;
  final int total;
  final bool autoCount;
  final VoidCallback onTap;

  const _RunningView({
    required this.count,
    required this.remaining,
    required this.total,
    required this.autoCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final progress = (total - remaining) / total;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(
        children: [
          // Countdown
          SizedBox(
            height: 64,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text('$remaining',
                    style: AppTextStyles.statMedium
                        .copyWith(fontSize: 44, color: AppColors.sageGreen)),
                const SizedBox(width: 6),
                Text(l.secondsLeftUnit, style: AppTextStyles.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AppColors.lightSage,
              valueColor: const AlwaysStoppedAnimation(AppColors.sageGreen),
            ),
          ),
          const SizedBox(height: 24),
          // Big tap target
          Expanded(
            child: GestureDetector(
              onTap: onTap,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.sageGreen,
                      AppColors.sageGreen.withValues(alpha: 0.82),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('$count',
                        style: AppTextStyles.statNumber
                            .copyWith(fontSize: 96, color: Colors.white)),
                    Text(l.standsCounted,
                        style: AppTextStyles.titleMedium
                            .copyWith(color: Colors.white)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                              autoCount
                                  ? Icons.bluetooth_connected
                                  : Icons.touch_app_outlined,
                              size: 18,
                              color: Colors.white),
                          const SizedBox(width: 8),
                          Text(autoCount ? l.matIsCounting : l.tapEachStand,
                              style: AppTextStyles.bodyMedium
                                  .copyWith(color: Colors.white)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultView extends StatelessWidget {
  final int reps;
  final int age;
  final Sex sex;
  final bool applyGoal;
  final bool saving;
  final ValueChanged<bool> onApplyGoalChanged;
  final void Function(int recommendedGoal) onSave;
  final VoidCallback onRedo;

  const _ResultView({
    required this.reps,
    required this.age,
    required this.sex,
    required this.applyGoal,
    required this.saving,
    required this.onApplyGoalChanged,
    required this.onSave,
    required this.onRedo,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final rating = ChairStand.rate(reps, age, sex);
    final goal = ChairStand.recommendedDailyGoal(reps);

    final Color color;
    final String label;
    final String description;
    switch (rating) {
      case ChairStandRating.belowAverage:
        color = AppColors.terracotta;
        label = l.belowAverage;
        description = l.chairStandBelowDesc;
      case ChairStandRating.average:
        color = const Color(0xFFD9A441);
        label = l.average;
        description = l.chairStandAverageDesc;
      case ChairStandRating.aboveAverage:
        color = AppColors.sageGreen;
        label = l.aboveAverage;
        description = l.chairStandAboveDesc;
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.testComplete,
              style: AppTextStyles.headlineMedium, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          // Result number
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              children: [
                Text('$reps',
                    style: AppTextStyles.statNumber
                        .copyWith(fontSize: 72, color: color)),
                Text(l.standsInThirtySeconds, style: AppTextStyles.bodyMedium),
                const SizedBox(height: 14),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(label,
                      style: AppTextStyles.labelMedium
                          .copyWith(color: color, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withValues(alpha: 0.35)),
            ),
            child: Text(description, style: AppTextStyles.bodySmall),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline,
                  size: 16, color: AppColors.subtleText),
              const SizedBox(width: 8),
              Expanded(
                child: Text(l.chairStandDisclaimer,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.subtleText)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Recommended goal
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.lightSage.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.track_changes_outlined,
                      color: AppColors.sageGreen),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.recommendedDailyGoal,
                          style: AppTextStyles.titleMedium),
                      Text(l.repsPerDayValue(goal),
                          style: AppTextStyles.bodySmall
                              .copyWith(color: AppColors.sageGreen)),
                      const SizedBox(height: 2),
                      Text(l.recommendedGoalNote,
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.subtleText)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: applyGoal,
            onChanged: onApplyGoalChanged,
            activeThumbColor: AppColors.sageGreen,
            title: Text(l.setDailyGoalTo(goal), style: AppTextStyles.bodyMedium),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: saving ? null : () => onSave(goal),
            style: ElevatedButton.styleFrom(
              minimumSize: const Size.fromHeight(56),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28)),
            ),
            child: saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(l.saveResult, style: AppTextStyles.buttonText),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: saving ? null : onRedo,
            icon: const Icon(Icons.refresh, size: 18),
            label: Text(l.redoTest),
          ),
        ],
      ),
    );
  }
}
