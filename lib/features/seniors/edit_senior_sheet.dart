import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../l10n/app_localizations.dart';
import '../../models/senior.dart';
import '../../providers/senior_provider.dart';

class EditSeniorSheet extends ConsumerStatefulWidget {
  final Senior senior;
  const EditSeniorSheet({super.key, required this.senior});

  @override
  ConsumerState<EditSeniorSheet> createState() => _EditSeniorSheetState();
}

class _EditSeniorSheetState extends ConsumerState<EditSeniorSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _ageCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.senior.name);
    _ageCtrl = TextEditingController(text: '${widget.senior.age}');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(seniorsNotifierProvider.notifier).updateSenior(
            widget.senior.id,
            name: _nameCtrl.text.trim(),
            age: int.parse(_ageCtrl.text.trim()),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
              AppLocalizations.of(context).failedToSaveChanges('$e'))),
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
              Text(l.editSenior(widget.senior.name), style: AppTextStyles.headlineSmall),
              const SizedBox(height: 24),
              TextFormField(
                controller: _nameCtrl,
                style: AppTextStyles.bodyMedium,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  hintText: l.name,
                  prefixIcon: const Icon(Icons.person_outline, color: AppColors.subtleText, size: 20),
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? l.enterAName : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ageCtrl,
                keyboardType: TextInputType.number,
                style: AppTextStyles.bodyMedium,
                decoration: InputDecoration(
                  hintText: l.age,
                  prefixIcon: const Icon(Icons.calendar_today_outlined,
                      color: AppColors.subtleText, size: 20),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return l.enterAge;
                  final age = int.tryParse(v);
                  if (age == null || age < 1 || age > 120) return l.enterValidAge;
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
                      : Text(l.saveChanges, style: AppTextStyles.buttonText),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
