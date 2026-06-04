import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../core/utils/auth_errors.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../shell/main_shell.dart';
import 'account_creation_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authNotifierProvider.notifier).signIn(
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
  }

  Future<void> _forgotPassword() async {
    final l = AppLocalizations.of(context);
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.enterEmailFirst)),
      );
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.passwordResetSent(email))),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyAuthError(l, e))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final authState = ref.watch(authNotifierProvider);

    ref.listen(authNotifierProvider, (_, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyAuthError(l, next.error))),
        );
      } else if (!next.isLoading && next.value != null) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainShell()),
          (route) => false,
        );
      }
    });

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                const SizedBox(height: 64),
                Column(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.sageGreen, width: 1.5),
                        borderRadius: BorderRadius.circular(26),
                      ),
                      child: const Icon(Icons.spa_outlined, color: AppColors.sageGreen, size: 26),
                    ),
                    const SizedBox(height: 10),
                    Text('IncreMat', style: AppTextStyles.headlineLarge),
                    const SizedBox(height: 2),
                    Text(
                      l.caregiverOverline,
                      style: AppTextStyles.overline.copyWith(letterSpacing: 3),
                    ),
                  ],
                ),
                const SizedBox(height: 48),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(l.welcomeBack, style: AppTextStyles.headlineMedium),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    l.signInToAccount,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.subtleText),
                  ),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  style: AppTextStyles.bodyMedium,
                  decoration: InputDecoration(
                    hintText: l.email,
                    prefixIcon: const Icon(Icons.mail_outline, color: AppColors.subtleText, size: 20),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return l.enterYourEmail;
                    if (!v.contains('@')) return l.enterValidEmail;
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  style: AppTextStyles.bodyMedium,
                  decoration: InputDecoration(
                    hintText: l.password,
                    prefixIcon: const Icon(Icons.lock_outline, color: AppColors.subtleText, size: 20),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                        color: AppColors.subtleText,
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) =>
                      v == null || v.isEmpty ? l.enterYourPassword : null,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: _forgotPassword,
                    child: Text(
                      l.forgotPassword,
                      style: AppTextStyles.caption.copyWith(color: AppColors.sageGreen),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: authState.isLoading ? null : _submit,
                  child: authState.isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(l.signIn, style: AppTextStyles.buttonText),
                ),
                const SizedBox(height: 24),
                TextButton(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const AccountCreationScreen()),
                  ),
                  child: Text(
                    l.noAccountCreate,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.sageGreen),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
