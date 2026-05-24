import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../models/senior.dart';
import '../../models/session_log.dart';
import '../../providers/senior_provider.dart';
import '../seniors/add_loved_one_screen.dart';
import 'senior_detail_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seniorsAsync = ref.watch(seniorsStreamProvider);

    void onAddPerson() => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddLovedOneScreen()),
        );

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.sageGreen,
          onRefresh: () async => ref.invalidate(seniorsStreamProvider),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _Header(onAddPerson: onAddPerson)),
              SliverToBoxAdapter(child: _SitToStandIllustration()),
              seniorsAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: CircularProgressIndicator(color: AppColors.sageGreen),
                    ),
                  ),
                ),
                error: (e, _) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: _ErrorCard(message: e.toString()),
                  ),
                ),
                data: (seniors) {
                  if (seniors.isEmpty) {
                    return SliverToBoxAdapter(
                      child: _EmptyState(onAddPerson: onAddPerson),
                    );
                  }
                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final senior = seniors[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: Dismissible(
                              key: ValueKey(senior.id),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 24),
                                decoration: BoxDecoration(
                                  color: AppColors.terracotta.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: const Icon(
                                  Icons.delete_outline,
                                  color: AppColors.terracotta,
                                  size: 24,
                                ),
                              ),
                              confirmDismiss: (_) async {
                                return await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: Text('Remove ${senior.name}?'),
                                    content: const Text(
                                      'This will remove them from your care circle.',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: Text(
                                          'Remove',
                                          style: TextStyle(color: AppColors.terracotta),
                                        ),
                                      ),
                                    ],
                                  ),
                                ) ?? false;
                              },
                              onDismissed: (_) => ref
                                  .read(seniorsNotifierProvider.notifier)
                                  .deleteSenior(senior.id),
                              child: _SeniorCard(
                                senior: senior,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => SeniorDetailScreen(senior: senior),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                        childCount: seniors.length,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAddPerson;
  const _EmptyState({required this.onAddPerson});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppColors.espresso.withValues(alpha: 0.06),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(Icons.eco, size: 52, color: AppColors.lightSage),
                const SizedBox(height: 16),
                Text(
                  'No loved ones yet',
                  style: AppTextStyles.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Add your first loved one to start\ntracking their sit-to-stand progress.',
                  style: AppTextStyles.bodySmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: onAddPerson,
                  icon: const Icon(Icons.add, size: 18),
                  label: Text('Add a Loved One', style: AppTextStyles.buttonText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.terracotta.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.terracotta, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Could not load seniors: $message',
              style: AppTextStyles.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onAddPerson;
  const _Header({required this.onAddPerson});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Your Loved Ones', style: AppTextStyles.headlineLarge),
          GestureDetector(
            onTap: onAddPerson,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.cardSurface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.espresso.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(Icons.add, color: AppColors.espresso, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

class _SitToStandIllustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: 16,
            left: 40,
            child: _ChairWithMat(),
          ),
          Positioned(
            bottom: 60,
            left: 120,
            child: _PersonSilhouette(),
          ),
          Positioned(
            bottom: 80,
            left: 100,
            child: Icon(
              Icons.arrow_upward,
              color: AppColors.sageGreen.withValues(alpha: 0.7),
              size: 28,
            ),
          ),
          Positioned(
            top: 10,
            left: 20,
            child: Icon(Icons.eco, color: AppColors.lightSage, size: 32),
          ),
        ],
      ),
    );
  }
}

class _ChairWithMat extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          children: [
            Container(
              width: 80,
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFFD4C8B8),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            Positioned(
              top: 1,
              left: 8,
              child: Container(
                width: 64,
                height: 10,
                decoration: BoxDecoration(
                  color: AppColors.espresso.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ChairLeg(),
            const SizedBox(width: 60),
            _ChairLeg(),
          ],
        ),
      ],
    );
  }
}

class _ChairLeg extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFFD4C8B8),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class _PersonSilhouette extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: AppColors.mutedSage.withValues(alpha: 0.5),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 32,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.mutedSage.withValues(alpha: 0.4),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ],
    );
  }
}

class _SeniorCard extends StatelessWidget {
  final Senior senior;
  final VoidCallback onTap;

  const _SeniorCard({required this.senior, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final todayReps = MockSessionData.todayReps;
    final goalReps = senior.dailyRepGoal;
    final progress = (todayReps / goalReps).clamp(0.0, 1.0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: AppColors.espresso.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _Avatar(),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(senior.name, style: AppTextStyles.headlineSmall),
                        Text('Sit-to-Stand Progress', style: AppTextStyles.bodySmall),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.lightSage.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Today', style: AppTextStyles.caption),
                        const SizedBox(width: 4),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: AppColors.sageGreen,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right, color: AppColors.subtleText),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _ProgressCircle(
                    current: todayReps,
                    goal: goalReps,
                    progress: progress,
                  ),
                  const SizedBox(width: 24),
                  Expanded(
                    child: Column(
                      children: [
                        _StatRow(
                          icon: Icons.trending_up,
                          label: 'Improvement',
                          value: '+2 from yesterday',
                        ),
                        const SizedBox(height: 12),
                        _StatRow(
                          icon: Icons.timer_outlined,
                          label: 'Avg. Time',
                          value: '${MockSessionData.avgRepTimeSeconds}s',
                        ),
                        const SizedBox(height: 12),
                        _StatRow(
                          icon: Icons.bar_chart_outlined,
                          label: 'This Week',
                          value:
                              '${MockSessionData.daysActiveThisWeek} of ${MockSessionData.daysInWeek} days',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: const BoxDecoration(
        color: AppColors.lightSage,
        shape: BoxShape.circle,
      ),
      child: const Icon(Icons.person, color: AppColors.sageGreen, size: 28),
    );
  }
}

class _ProgressCircle extends StatelessWidget {
  final int current;
  final int goal;
  final double progress;

  const _ProgressCircle({
    required this.current,
    required this.goal,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90,
      height: 90,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 90,
            height: 90,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 6,
              backgroundColor: AppColors.lightSage,
              valueColor: const AlwaysStoppedAnimation(AppColors.sageGreen),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '$current',
                      style: AppTextStyles.statMedium.copyWith(fontSize: 26),
                    ),
                    TextSpan(
                      text: '/$goal',
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              Text(
                progress >= 1.0
                    ? 'Goal met!'
                    : current == 0
                        ? 'Not started'
                        : 'Keep going!',
                style: AppTextStyles.caption.copyWith(color: AppColors.sageGreen),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: AppColors.lightSage.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 14, color: AppColors.sageGreen),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: AppTextStyles.titleMedium.copyWith(fontSize: 13)),
              Text(label, style: AppTextStyles.caption),
            ],
          ),
        ),
      ],
    );
  }
}
