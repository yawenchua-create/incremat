import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../providers/senior_provider.dart';

class AddLovedOneScreen extends ConsumerStatefulWidget {
  const AddLovedOneScreen({super.key});

  @override
  ConsumerState<AddLovedOneScreen> createState() => _AddLovedOneScreenState();
}

class _AddLovedOneScreenState extends ConsumerState<AddLovedOneScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _ageCtrl = TextEditingController();
  final _goalCtrl = TextEditingController(text: '25');
  bool _isPairing = false;
  bool _paired = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ageCtrl.dispose();
    _goalCtrl.dispose();
    super.dispose();
  }

  Future<void> _pairDevice() async {
    setState(() => _isPairing = true);
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) setState(() { _isPairing = false; _paired = true; });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await ref.read(seniorsNotifierProvider.notifier).addSenior(
            name: _nameCtrl.text.trim(),
            age: int.parse(_ageCtrl.text.trim()),
            dailyRepGoal: int.parse(_goalCtrl.text.trim()),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('IncreMat Caregiver', style: AppTextStyles.labelLarge),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Expanded(child: Divider()),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Icon(Icons.eco, size: 18, color: AppColors.sageGreen),
                    ),
                    const Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 12),
                Text('Add a Loved One', style: AppTextStyles.displayMedium),
                const SizedBox(height: 28),
                // Avatar picker
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: AppColors.lightSage.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.lightSage, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.espresso.withValues(alpha: 0.05),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.add, size: 36, color: AppColors.sageGreen),
                    ),
                    Positioned(
                      right: -24,
                      top: -8,
                      child: Icon(Icons.eco, size: 48, color: AppColors.lightSage),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                _FormField(
                  controller: _nameCtrl,
                  hint: 'Senior Name',
                  icon: Icons.person_outline,
                  validator: (v) => v == null || v.isEmpty ? 'Enter a name' : null,
                ),
                const SizedBox(height: 12),
                _FormField(
                  controller: _ageCtrl,
                  hint: 'Age',
                  icon: Icons.calendar_today_outlined,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter age';
                    final age = int.tryParse(v);
                    if (age == null || age < 1 || age > 120) return 'Enter a valid age';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _FormField(
                  controller: _goalCtrl,
                  hint: 'Daily Rep Goal',
                  icon: Icons.track_changes_outlined,
                  keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter a goal';
                    final goal = int.tryParse(v);
                    if (goal == null || goal < 5 || goal > 99) {
                      return 'Enter a goal between 5 and 99';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                // Pair IncreMat row
                GestureDetector(
                  onTap: _isPairing ? null : _pairDevice,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                    decoration: BoxDecoration(
                      color: AppColors.cardSurface,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: _paired ? AppColors.lightSage : AppColors.warmCream,
                            shape: BoxShape.circle,
                          ),
                          child: _isPairing
                              ? const Padding(
                                  padding: EdgeInsets.all(8),
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.sageGreen,
                                  ),
                                )
                              : Icon(
                                  _paired
                                      ? Icons.bluetooth_connected
                                      : Icons.bluetooth,
                                  size: 20,
                                  color: _paired
                                      ? AppColors.sageGreen
                                      : AppColors.subtleText,
                                ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _paired ? 'IncreMat Paired' : 'Pair IncreMat',
                                style: AppTextStyles.titleMedium,
                              ),
                              Text(
                                _paired
                                    ? 'Connected successfully'
                                    : 'Connect your IncreMat via Bluetooth',
                                style: AppTextStyles.caption,
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            color: AppColors.subtleText, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.people_outline, size: 20),
                            const SizedBox(width: 8),
                            Text('Add to Care Circle',
                                style: AppTextStyles.buttonText),
                          ],
                        ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _FormField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: AppTextStyles.bodyMedium,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.subtleText, size: 20),
      ),
    );
  }
}
