import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/senior.dart';
import '../../providers/auth_provider.dart';
import '../../providers/hardware_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/senior_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final senior = ref.watch(selectedSeniorProvider) ?? MockSeniors.betty;
    final authState = ref.watch(authNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _SettingsHeader(senior: senior)),
            SliverToBoxAdapter(child: _RepGoalCard(senior: senior)),
            SliverToBoxAdapter(child: _MusicCard(senior: senior)),
            SliverToBoxAdapter(child: _NotificationsCard(senior: senior)),
            SliverToBoxAdapter(child: _AccountSection(
              isSigningOut: authState.isLoading,
              onSignOut: () async {
                await ref.read(authNotifierProvider.notifier).signOut();
              },
            )),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  final Senior senior;
  const _SettingsHeader({required this.senior});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Exercise Settings', style: AppTextStyles.headlineLarge),
              const SizedBox(height: 4),
              Text(
                senior.name,
                style: AppTextStyles.headlineSmall.copyWith(color: AppColors.sageGreen),
              ),
              Container(
                margin: const EdgeInsets.only(top: 2),
                width: 40,
                height: 2,
                color: AppColors.terracotta.withValues(alpha: 0.6),
              ),
            ],
          ),
          Positioned(
            right: 0,
            top: -8,
            child: Icon(Icons.eco, size: 52, color: AppColors.lightSage),
          ),
        ],
      ),
    );
  }
}

// Uses local state for the slider so Firestore stream ticks don't reset it.
class _RepGoalCard extends ConsumerStatefulWidget {
  final Senior senior;
  const _RepGoalCard({required this.senior});

  @override
  ConsumerState<_RepGoalCard> createState() => _RepGoalCardState();
}

class _RepGoalCardState extends ConsumerState<_RepGoalCard> {
  late int _goal;
  late double _sliderValue; // clamped to slider range; decoupled from _goal

  @override
  void initState() {
    super.initState();
    _goal = widget.senior.dailyRepGoal;
    _sliderValue = _goal.clamp(5, 50).toDouble();
  }

  @override
  void didUpdateWidget(_RepGoalCard old) {
    super.didUpdateWidget(old);
    if (old.senior.id != widget.senior.id) {
      _goal = widget.senior.dailyRepGoal;
      _sliderValue = _goal.clamp(5, 50).toDouble();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.espresso.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.lightSage.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.track_changes_outlined, size: 18, color: AppColors.sageGreen),
              ),
              const SizedBox(width: 12),
              Text('Daily Rep Goal', style: AppTextStyles.titleLarge),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Text('$_goal', style: AppTextStyles.statNumber),
                Text('reps per day', style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderThemeData(
              activeTrackColor: AppColors.sageGreen,
              inactiveTrackColor: AppColors.lightSage,
              thumbColor: AppColors.sageGreen,
              overlayColor: AppColors.sageGreen.withValues(alpha: 0.15),
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
              trackHeight: 4,
            ),
            child: Slider(
              value: _sliderValue,
              min: 5,
              max: 50,
              divisions: 9,
              onChanged: (v) => setState(() {
                _sliderValue = v;
                _goal = v.round();
              }),
              onChangeEnd: (v) {
                final newGoal = v.round();
                ref.read(seniorsNotifierProvider.notifier)
                    .updateGoal(widget.senior.id, newGoal);
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [5, 15, 25, 35, 50]
                  .map((v) => Text('$v', style: AppTextStyles.caption))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _MusicCard extends ConsumerWidget {
  final Senior senior;
  const _MusicCard({required this.senior});

  static const _tracks = ['甜蜜蜜', '半斤八两', 'Morning Zen', 'Afternoon Groove', 'Evening Calm'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTrack = ref.watch(selectedTrackProvider(senior.id));
    final randomize = ref.watch(randomizeTracksProvider(senior.id));

    // Sync explicit track selection to hardware whenever the user picks one.
    ref.listen(selectedTrackProvider(senior.id), (_, track) {
      if (!ref.read(randomizeTracksProvider(senior.id))) {
        ref.read(hardwareServiceProvider).sendMusicTrack(track);
      }
    });

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.espresso.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.lightSage.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.music_note_outlined, size: 18, color: AppColors.sageGreen),
              ),
              const SizedBox(width: 12),
              Text('Session Music', style: AppTextStyles.titleLarge),
            ],
          ),
          const SizedBox(height: 16),
          Text('Select Track', style: AppTextStyles.labelMedium),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.divider),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: _tracks.asMap().entries.map((entry) {
                final track = entry.value;
                final isLast = entry.key == _tracks.length - 1;
                final isSelected = track == selectedTrack;
                return Column(
                  children: [
                    InkWell(
                      onTap: () => ref
                          .read(selectedTrackProvider(senior.id).notifier)
                          .state = track,
                      borderRadius: BorderRadius.vertical(
                        top: entry.key == 0 ? const Radius.circular(15) : Radius.zero,
                        bottom: isLast ? const Radius.circular(15) : Radius.zero,
                      ),
                      child: Container(
                        color: isSelected
                            ? AppColors.lightSage.withValues(alpha: 0.3)
                            : null,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.sageGreen
                                    : AppColors.lightSage.withValues(alpha: 0.5),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.play_arrow,
                                size: 16,
                                color: isSelected ? Colors.white : AppColors.subtleText,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(track, style: AppTextStyles.bodyMedium),
                            ),
                            if (isSelected)
                              const Icon(Icons.check_circle, size: 18, color: AppColors.sageGreen)
                            else
                              const Icon(Icons.more_horiz, size: 18, color: AppColors.subtleText),
                          ],
                        ),
                      ),
                    ),
                    if (!isLast) const Divider(height: 1),
                  ],
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: Divider(color: AppColors.divider)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('OR', style: AppTextStyles.caption),
              ),
              Expanded(child: Divider(color: AppColors.divider)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Randomize Tracks', style: AppTextStyles.titleMedium),
                    Text('Play a different mix each session', style: AppTextStyles.caption),
                  ],
                ),
              ),
              Switch(
                value: randomize,
                onChanged: (v) => ref
                    .read(randomizeTracksProvider(senior.id).notifier)
                    .state = v,
                activeThumbColor: AppColors.sageGreen,
                activeTrackColor: AppColors.sageGreen.withValues(alpha: 0.4),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NotificationsCard extends ConsumerWidget {
  final Senior senior;
  const _NotificationsCard({required this.senior});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifAsync = ref.watch(notificationsProvider);
    final enabled = notifAsync.valueOrNull ?? false;

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.espresso.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.lightSage.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.notifications_outlined, size: 18, color: AppColors.sageGreen),
              ),
              const SizedBox(width: 12),
              Text('Daily Reminders', style: AppTextStyles.titleLarge),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Goal Reminder', style: AppTextStyles.titleMedium),
                    Text(
                      enabled
                          ? 'Reminder set for 8:00 PM daily'
                          : "Notify if daily rep goal isn't met",
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              notifAsync.isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.sageGreen,
                      ),
                    )
                  : Switch(
                      value: enabled,
                      onChanged: (v) => ref
                          .read(notificationsProvider.notifier)
                          .toggle(v, seniorName: senior.name, goalReps: senior.dailyRepGoal),
                      activeThumbColor: AppColors.sageGreen,
                      activeTrackColor: AppColors.sageGreen.withValues(alpha: 0.4),
                    ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AccountSection extends StatelessWidget {
  final VoidCallback onSignOut;
  final bool isSigningOut;
  const _AccountSection({required this.onSignOut, required this.isSigningOut});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.espresso.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _SettingsTile(
            icon: Icons.person_outline,
            label: 'Account',
            onTap: () {},
          ),
          const Divider(height: 1, indent: 20, endIndent: 20),
          _SettingsTile(
            icon: Icons.logout,
            label: isSigningOut ? 'Signing out…' : 'Sign Out',
            labelColor: AppColors.terracotta,
            iconColor: AppColors.terracotta,
            trailing: isSigningOut
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.terracotta,
                    ),
                  )
                : null,
            onTap: isSigningOut ? () {} : onSignOut,
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? labelColor;
  final Color? iconColor;
  final Widget? trailing;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.labelColor,
    this.iconColor,
    this.trailing,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor ?? AppColors.espresso),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(color: labelColor),
              ),
            ),
            trailing ?? const Icon(Icons.chevron_right, size: 18, color: AppColors.subtleText),
          ],
        ),
      ),
    );
  }
}
