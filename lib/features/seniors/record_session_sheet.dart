import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../l10n/app_localizations.dart';
import '../../models/senior.dart';
import '../../providers/senior_provider.dart';

class RecordSessionSheet extends ConsumerStatefulWidget {
  final Senior senior;
  const RecordSessionSheet({super.key, required this.senior});

  @override
  ConsumerState<RecordSessionSheet> createState() => _RecordSessionSheetState();
}

class _RecordSessionSheetState extends ConsumerState<RecordSessionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _repsCtrl = TextEditingController();
  final _timeCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _repsCtrl.dispose();
    _timeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      final repo = ref.read(sessionRepositoryProvider(widget.senior.id));
      if (repo == null) return;
      await repo.add(
        repCount: int.parse(_repsCtrl.text.trim()),
        avgRepTimeSeconds: double.parse(_timeCtrl.text.trim()),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
              AppLocalizations.of(context).failedToSaveSession('$e'))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(l.recordSession, style: AppTextStyles.headlineSmall),
              const SizedBox(height: 4),
              Text(
                l.logSessionFor(widget.senior.name),
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _repsCtrl,
                keyboardType: TextInputType.number,
                style: AppTextStyles.bodyMedium,
                decoration: InputDecoration(
                  hintText: l.numberOfReps,
                  prefixIcon: const Icon(Icons.repeat_outlined, color: AppColors.subtleText, size: 20),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return l.enterRepCount;
                  final n = int.tryParse(v);
                  if (n == null || n < 1) return l.enterValidNumber;
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _timeCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: AppTextStyles.bodyMedium,
                decoration: InputDecoration(
                  hintText: l.avgTimePerRep,
                  prefixIcon: const Icon(Icons.timer_outlined, color: AppColors.subtleText, size: 20),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return l.enterAverageTime;
                  final n = double.tryParse(v);
                  if (n == null || n <= 0) return l.enterValidTime;
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _save,
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.save_outlined, size: 18),
                            const SizedBox(width: 8),
                            Text(l.saveSession, style: AppTextStyles.buttonText),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
