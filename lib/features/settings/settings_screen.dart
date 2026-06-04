import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/auth_errors.dart';
import '../../l10n/app_localizations.dart';
import '../../models/senior.dart';
import '../../providers/auth_provider.dart';
import '../../providers/hardware_provider.dart';
import '../../providers/locale_provider.dart';
import '../../providers/notification_provider.dart';
import '../../providers/senior_provider.dart';
import '../auth/login_screen.dart';
import '../session_music/session_music_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final senior = ref.watch(selectedSeniorProvider);
    final authState = ref.watch(authNotifierProvider);

    ref.listen(authNotifierProvider, (_, next) {
      if (next.hasError && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyAuthError(l, next.error))),
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: const _SettingsHeader()),
            SliverToBoxAdapter(child: const _LanguageCard()),
            SliverToBoxAdapter(child: _SettingsSeniorSwitcher()),
            if (senior != null) ...[
              SliverToBoxAdapter(child: _RepGoalCard(senior: senior)),
              SliverToBoxAdapter(child: _WeeklyRewardDaysCard(senior: senior)),
              SliverToBoxAdapter(child: _MusicCard(senior: senior)),
              SliverToBoxAdapter(child: _NotificationsCard(senior: senior)),
            ],
            SliverToBoxAdapter(
              child: _AccountSection(
                isAuthLoading: authState.isLoading,
                onSignOut: () async {
                  final nav = Navigator.of(context);
                  await ref.read(authNotifierProvider.notifier).signOut();
                  nav.pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
                onDeleteAccount: (password) async {
                  final nav = Navigator.of(context);
                  await ref
                      .read(authNotifierProvider.notifier)
                      .deleteAccount(password: password);
                  if (ref.read(authNotifierProvider).hasError) return;
                  nav.pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                    (route) => false,
                  );
                },
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

class _SettingsSeniorSwitcher extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seniors = ref.watch(seniorsProvider);
    final selected = ref.watch(selectedSeniorProvider);

    if (seniors.length <= 1) return const SizedBox.shrink();

    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        itemCount: seniors.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final senior = seniors[i];
          final isSelected = senior.id == selected?.id;
          return GestureDetector(
            onTap: () => selectSenior(ref, senior.id),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? AppColors.sageGreen : AppColors.cardSurface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.espresso.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                senior.name,
                style: AppTextStyles.labelMedium.copyWith(
                  color: isSelected ? Colors.white : AppColors.espresso,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SettingsHeader extends StatelessWidget {
  const _SettingsHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context).exerciseSettings,
                  style: AppTextStyles.headlineLarge),
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

class _LanguageCard extends ConsumerWidget {
  const _LanguageCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final locale = ref.watch(localeProvider);

    Widget option(String label, String code) {
      final selected = locale.languageCode == code;
      return Expanded(
        child: GestureDetector(
          onTap: () => ref
              .read(localeProvider.notifier)
              .setLocale(Locale(code)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: selected ? AppColors.sageGreen : AppColors.warmCream,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected ? AppColors.sageGreen : AppColors.divider,
              ),
            ),
            child: Center(
              child: Text(
                label,
                style: AppTextStyles.titleMedium.copyWith(
                  color: selected ? Colors.white : AppColors.subtleText,
                ),
              ),
            ),
          ),
        ),
      );
    }

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
                child: const Icon(Icons.language,
                    size: 18, color: AppColors.sageGreen),
              ),
              const SizedBox(width: 12),
              Text(l.language, style: AppTextStyles.titleLarge),
            ],
          ),
          const SizedBox(height: 6),
          Text(l.languageSubtitle, style: AppTextStyles.caption),
          const SizedBox(height: 16),
          Row(
            children: [
              option(l.english, 'en'),
              const SizedBox(width: 12),
              option(l.chinese, 'zh'),
            ],
          ),
        ],
      ),
    );
  }
}

class _RepGoalCard extends ConsumerStatefulWidget {
  final Senior senior;
  const _RepGoalCard({required this.senior});

  @override
  ConsumerState<_RepGoalCard> createState() => _RepGoalCardState();
}

class _RepGoalCardState extends ConsumerState<_RepGoalCard> {
  late int _goal;
  late double _sliderValue;

  @override
  void initState() {
    super.initState();
    _goal = widget.senior.dailyRepGoal;
    _sliderValue = _goal.clamp(5, 50).toDouble();
  }

  @override
  void didUpdateWidget(_RepGoalCard old) {
    super.didUpdateWidget(old);
    final incoming = widget.senior.dailyRepGoal;
    if (_goal != incoming) {
      _goal = incoming;
      _sliderValue = incoming.clamp(5, 50).toDouble();
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
              Text(AppLocalizations.of(context).dailyRepGoal,
                  style: AppTextStyles.titleLarge),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: Column(
              children: [
                Text('$_goal', style: AppTextStyles.statNumber),
                Text(AppLocalizations.of(context).repsPerDay,
                    style: AppTextStyles.bodySmall),
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
              onChangeEnd: (v) async {
                final messenger = ScaffoldMessenger.of(context);
                final msg = AppLocalizations.of(context).couldNotSaveGoal;
                try {
                  await ref.read(seniorsNotifierProvider.notifier)
                      .updateGoal(widget.senior.id, v.round());
                } catch (_) {
                  if (!mounted) return;
                  messenger.showSnackBar(
                    SnackBar(content: Text(msg)),
                  );
                }
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

class _WeeklyRewardDaysCard extends ConsumerStatefulWidget {
  final Senior senior;
  const _WeeklyRewardDaysCard({required this.senior});

  @override
  ConsumerState<_WeeklyRewardDaysCard> createState() => _WeeklyRewardDaysCardState();
}

class _WeeklyRewardDaysCardState extends ConsumerState<_WeeklyRewardDaysCard> {
  late int _threshold;

  @override
  void initState() {
    super.initState();
    _threshold = widget.senior.consistencyThreshold;
  }

  @override
  void didUpdateWidget(_WeeklyRewardDaysCard old) {
    super.didUpdateWidget(old);
    final incoming = widget.senior.consistencyThreshold;
    if (_threshold != incoming) {
      _threshold = incoming;
    }
  }

  @override
  Widget build(BuildContext context) {
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
                child: const Icon(Icons.calendar_today_outlined,
                    size: 18, color: AppColors.sageGreen),
              ),
              const SizedBox(width: 12),
              Text(AppLocalizations.of(context).weeklyRewardDays,
                  style: AppTextStyles.titleLarge),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(7, (i) {
              final value = i + 1;
              final selected = value == _threshold;
              return GestureDetector(
                onTap: () async {
                  setState(() => _threshold = value);
                  final messenger = ScaffoldMessenger.of(context);
                  final msg = AppLocalizations.of(context).couldNotSave;
                  try {
                    await ref
                        .read(seniorsNotifierProvider.notifier)
                        .updateConsistencyThreshold(widget.senior.id, value);
                  } catch (_) {
                    if (!mounted) return;
                    messenger.showSnackBar(
                      SnackBar(content: Text(msg)),
                    );
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: selected ? AppColors.sageGreen : AppColors.warmCream,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected ? AppColors.sageGreen : AppColors.divider,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$value',
                      style: AppTextStyles.titleMedium.copyWith(
                        color: selected ? Colors.white : AppColors.subtleText,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 12),
          Text(
            AppLocalizations.of(context)
                .eggRewardExplain(widget.senior.name, _threshold),
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}

class _MusicCard extends ConsumerWidget {
  final Senior senior;
  const _MusicCard({required this.senior});

  static const _tracks = ['甜蜜蜜', '半斤八两'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final selectedTrack = ref.watch(selectedTrackProvider(senior.id));
    final randomize = ref.watch(randomizeTracksProvider(senior.id));

    ref.listen(selectedTrackProvider(senior.id), (_, track) {
      if (track != null && !ref.read(randomizeTracksProvider(senior.id))) {
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
              Text(l.sessionMusic, style: AppTextStyles.titleLarge),
            ],
          ),
          const SizedBox(height: 16),
          Text(l.selectTrack, style: AppTextStyles.labelMedium),
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
                final isSelected = !randomize && track == selectedTrack;
                return Column(
                  children: [
                    Opacity(
                      opacity: randomize ? 0.45 : 1.0,
                      child: InkWell(
                        onTap: () {
                          if (randomize) {
                            ref.read(randomizeTracksProvider(senior.id).notifier).state = false;
                          }
                          ref.read(selectedTrackProvider(senior.id).notifier).state =
                              isSelected ? null : track;
                        },
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
                child: Text(l.orDivider, style: AppTextStyles.caption),
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
                    Text(l.randomizeTracks, style: AppTextStyles.titleMedium),
                    Text(l.randomizeSubtitle, style: AppTextStyles.caption),
                  ],
                ),
              ),
              Switch(
                value: randomize,
                onChanged: selectedTrack != null
                    ? null
                    : (v) => ref
                        .read(randomizeTracksProvider(senior.id).notifier)
                        .state = v,
                activeThumbColor: AppColors.sageGreen,
                activeTrackColor: AppColors.sageGreen.withValues(alpha: 0.4),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(color: AppColors.divider),
          const SizedBox(height: 4),
          InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SessionMusicScreen()),
            ),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.lightSage.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.graphic_eq_outlined,
                        size: 18, color: AppColors.sageGreen),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.sessionPlayer, style: AppTextStyles.titleMedium),
                        Text(l.sessionPlayerSubtitle,
                            style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right,
                      color: AppColors.subtleText, size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationsCard extends ConsumerWidget {
  final Senior senior;
  const _NotificationsCard({required this.senior});

  String _formatTime(AppLocalizations l, TimeOfDay t) {
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? l.amLabel : l.pmLabel;
    return '$hour:$minute $period';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final notifAsync = ref.watch(notificationsProvider(senior.id));
    final enabled = notifAsync.valueOrNull ?? false;
    final timeAsync = ref.watch(notificationTimeProvider);
    final currentTime = timeAsync.valueOrNull ?? const TimeOfDay(hour: 20, minute: 0);

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
              Text(l.dailyReminders, style: AppTextStyles.titleLarge),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.goalReminder, style: AppTextStyles.titleMedium),
                    Text(
                      enabled
                          ? l.reminderSetFor(_formatTime(l, currentTime))
                          : l.notifyIfGoalNotMet,
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
                          .read(notificationsProvider(senior.id).notifier)
                          .toggle(v, seniorName: senior.name, goalReps: senior.dailyRepGoal),
                      activeThumbColor: AppColors.sageGreen,
                      activeTrackColor: AppColors.sageGreen.withValues(alpha: 0.4),
                    ),
            ],
          ),
          if (enabled) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            InkWell(
              onTap: () async {
                final picked = await showTimePicker(
                  context: context,
                  initialTime: currentTime,
                  builder: (context, child) => Theme(
                    data: Theme.of(context).copyWith(
                      colorScheme: const ColorScheme.light(
                        primary: AppColors.sageGreen,
                      ),
                    ),
                    child: child!,
                  ),
                );
                if (picked != null) {
                  ref.read(notificationTimeProvider.notifier).setTime(
                    picked,
                    seniorId: senior.id,
                    seniorName: senior.name,
                    goalReps: senior.dailyRepGoal,
                  );
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.schedule_outlined, size: 18, color: AppColors.sageGreen),
                    const SizedBox(width: 10),
                    Text(l.reminderTime, style: AppTextStyles.titleMedium),
                    const Spacer(),
                    Text(
                      _formatTime(l, currentTime),
                      style: AppTextStyles.titleMedium.copyWith(color: AppColors.sageGreen),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right, size: 16, color: AppColors.subtleText),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AccountSection extends StatelessWidget {
  final VoidCallback onSignOut;
  final void Function(String password) onDeleteAccount;
  final bool isAuthLoading;

  const _AccountSection({
    required this.onSignOut,
    required this.onDeleteAccount,
    required this.isAuthLoading,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
            label: l.account,
            onTap: () {},
          ),
          const Divider(height: 1, indent: 20, endIndent: 20),
          _SettingsTile(
            icon: Icons.logout,
            label: isAuthLoading ? l.signingOut : l.signOut,
            labelColor: AppColors.terracotta,
            iconColor: AppColors.terracotta,
            trailing: isAuthLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.terracotta,
                    ),
                  )
                : null,
            onTap: isAuthLoading ? () {} : onSignOut,
          ),
          const Divider(height: 1, indent: 20, endIndent: 20),
          _SettingsTile(
            icon: Icons.delete_forever_outlined,
            label: l.deleteAccount,
            labelColor: AppColors.terracotta,
            iconColor: AppColors.terracotta,
            onTap: isAuthLoading
                ? () {}
                : () async {
                    final passwordCtrl = TextEditingController();
                    final password = await showDialog<String?>(
                      context: context,
                      builder: (ctx) => StatefulBuilder(
                        builder: (ctx, setDialogState) => AlertDialog(
                          title: Text(l.deleteAccountQ),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.deleteAccountWarning,
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                controller: passwordCtrl,
                                obscureText: true,
                                autofocus: true,
                                decoration: InputDecoration(
                                  hintText: l.password,
                                  prefixIcon: const Icon(Icons.lock_outline,
                                      size: 18, color: AppColors.subtleText),
                                ),
                                onChanged: (_) => setDialogState(() {}),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, null),
                              child: Text(l.cancel),
                            ),
                            TextButton(
                              onPressed: passwordCtrl.text.isEmpty
                                  ? null
                                  : () => Navigator.pop(ctx, passwordCtrl.text),
                              child: Text(
                                l.delete,
                                style: const TextStyle(color: AppColors.terracotta),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                    passwordCtrl.dispose();
                    if (password != null && password.isNotEmpty) {
                      onDeleteAccount(password);
                    }
                  },
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
