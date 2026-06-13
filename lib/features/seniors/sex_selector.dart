import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/chair_stand.dart';
import '../../l10n/app_localizations.dart';

/// A two-option Male / Female picker used when creating or editing a senior.
/// The selected sex sharpens the 30-Second Chair Stand norm ranges. Leaving it
/// unset falls back to gender-neutral norms.
class SexSelector extends StatelessWidget {
  final Sex value;
  final ValueChanged<Sex> onChanged;

  const SexSelector({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(l.sexLabel,
              style: AppTextStyles.caption.copyWith(color: AppColors.subtleText)),
        ),
        Row(
          children: [
            _option(l.male, Icons.male, Sex.male),
            const SizedBox(width: 12),
            _option(l.female, Icons.female, Sex.female),
          ],
        ),
      ],
    );
  }

  Widget _option(String label, IconData icon, Sex sex) {
    final selected = value == sex;
    return Expanded(
      child: GestureDetector(
        onTap: () => onChanged(sex),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected ? AppColors.sageGreen : AppColors.cardSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.sageGreen : AppColors.divider,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: selected ? Colors.white : AppColors.subtleText),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTextStyles.titleMedium.copyWith(
                  color: selected ? Colors.white : AppColors.subtleText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
