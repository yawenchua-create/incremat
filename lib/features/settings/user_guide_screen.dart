import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../l10n/app_localizations.dart';

/// A simple, scrollable how-to for caregivers. Walks through setup (adding a
/// loved one, sharing the play code safely, pairing the mat, NFC cards) and the
/// day-to-day features (goals, exercising together, reports).
class UserGuideScreen extends StatelessWidget {
  const UserGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final sections = <({IconData icon, String title, String body})>[
      (icon: Icons.person_add_alt_1_outlined, title: l.guideAddTitle, body: l.guideAddBody),
      (icon: Icons.vpn_key_outlined, title: l.guidePlayCodeTitle, body: l.guidePlayCodeBody),
      (icon: Icons.bluetooth_outlined, title: l.guideMatTitle, body: l.guideMatBody),
      (icon: Icons.nfc_outlined, title: l.guideNfcTitle, body: l.guideNfcBody),
      (icon: Icons.track_changes_outlined, title: l.guideGoalsTitle, body: l.guideGoalsBody),
      (icon: Icons.groups_outlined, title: l.guideTogetherTitle, body: l.guideTogetherBody),
      (icon: Icons.insights_outlined, title: l.guideReportsTitle, body: l.guideReportsBody),
    ];

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        backgroundColor: AppColors.warmCream,
        elevation: 0,
        foregroundColor: AppColors.espresso,
        title: Text(l.userGuide, style: AppTextStyles.titleLarge),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            // Intro hero
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.sageGreen.withValues(alpha: 0.18),
                    AppColors.lightSage.withValues(alpha: 0.25),
                  ],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.guideHeader, style: AppTextStyles.headlineSmall),
                  const SizedBox(height: 8),
                  Text(
                    l.guideIntro,
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.subtleText),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            for (final s in sections)
              _GuideCard(icon: s.icon, title: s.title, body: s.body),
            // Help footer
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.lightSage.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: AppColors.sageGreen.withValues(alpha: 0.3)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.help_outline,
                      size: 22, color: AppColors.sageGreen),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l.guideHelpTitle, style: AppTextStyles.titleMedium),
                        const SizedBox(height: 4),
                        Text(l.guideHelpBody,
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.subtleText)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _GuideCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.espresso.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.lightSage.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: AppColors.sageGreen),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.titleMedium),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: AppTextStyles.bodyMedium
                      .copyWith(color: AppColors.subtleText, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
