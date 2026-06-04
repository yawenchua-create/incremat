import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../l10n/app_localizations.dart';
import 'nfc_write_sheet.dart';

class SeniorAddedScreen extends StatelessWidget {
  final String seniorId;
  final String seniorName;
  final String joinCode;

  const SeniorAddedScreen({
    super.key,
    required this.seniorId,
    required this.seniorName,
    required this.joinCode,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.warmCream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            children: [
              const Spacer(),
              Icon(Icons.check_circle_outline, size: 72, color: AppColors.sageGreen),
              const SizedBox(height: 24),
              Text(
                l.seniorAddedToCircle(seniorName),
                style: AppTextStyles.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
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
                    Text(
                      l.theirPlayCode,
                      style: AppTextStyles.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          joinCode,
                          style: AppTextStyles.statMedium.copyWith(
                            color: AppColors.sageGreen,
                            letterSpacing: 2,
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: joinCode));
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l.codeCopied)),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.lightSage.withValues(alpha: 0.4),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.copy_outlined,
                              size: 18,
                              color: AppColors.sageGreen,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l.shareCodeWith(seniorName),
                      style: AppTextStyles.caption,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              // Program their NFC tag right after creation.
              OutlinedButton.icon(
                onPressed: () => NfcWriteSheet.show(
                  context,
                  seniorId: seniorId,
                  seniorName: seniorName,
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                  side: const BorderSide(color: AppColors.sageGreen),
                ),
                icon: const Icon(Icons.nfc, size: 20, color: AppColors.sageGreen),
                label: Text(
                  l.enrolNfcCard,
                  style: AppTextStyles.buttonText
                      .copyWith(color: AppColors.sageGreen),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: Text(l.done, style: AppTextStyles.buttonText),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
