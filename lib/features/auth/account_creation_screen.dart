import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../providers/auth_provider.dart';
import 'login_screen.dart';

class AccountCreationScreen extends ConsumerStatefulWidget {
  const AccountCreationScreen({super.key});

  @override
  ConsumerState<AccountCreationScreen> createState() => _AccountCreationScreenState();
}

class _AccountCreationScreenState extends ConsumerState<AccountCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  String _parseError(Object? error) {
    final raw = error.toString();
    final idx = raw.lastIndexOf('] ');
    return idx == -1 ? raw : raw.substring(idx + 2);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    await ref.read(authNotifierProvider.notifier).createAccount(
          name: _nameCtrl.text.trim(),
          email: _emailCtrl.text.trim(),
          password: _passwordCtrl.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    ref.listen(authNotifierProvider, (_, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_parseError(next.error))),
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
                const SizedBox(height: 40),
                _Logo(),
                const SizedBox(height: 32),
                _Illustration(),
                const SizedBox(height: 28),
                Text(
                  'Care begins with ',
                  style: AppTextStyles.displayMedium,
                  textAlign: TextAlign.center,
                ),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: 'you',
                        style: AppTextStyles.displayMedium.copyWith(
                          fontStyle: FontStyle.italic,
                          color: AppColors.sageGreen,
                        ),
                      ),
                      TextSpan(
                        text: '.',
                        style: AppTextStyles.displayMedium,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Create your account to support,\nnurture, and make a difference.',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.subtleText),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                _InputField(
                  controller: _nameCtrl,
                  hint: 'Name',
                  icon: Icons.person_outline,
                  validator: (v) => v == null || v.isEmpty ? 'Enter your name' : null,
                ),
                const SizedBox(height: 12),
                _InputField(
                  controller: _emailCtrl,
                  hint: 'Email',
                  icon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter your email';
                    if (!v.contains('@')) return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _InputField(
                  controller: _passwordCtrl,
                  hint: 'Password',
                  icon: Icons.lock_outline,
                  obscureText: _obscurePassword,
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: AppColors.subtleText,
                      size: 20,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (v) {
                    if (v == null || v.length < 6) return 'Minimum 6 characters';
                    return null;
                  },
                ),
                const SizedBox(height: 24),
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
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Create Account', style: AppTextStyles.buttonText),
                            const SizedBox(width: 8),
                            const Icon(Icons.eco_outlined, size: 18),
                          ],
                        ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.shield_outlined, size: 14, color: AppColors.subtleText),
                    const SizedBox(width: 6),
                    Text(
                      'Your information is safe with us.',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  ),
                  child: Text(
                    'Already have an account? Sign in',
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.sageGreen),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
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
        Text(
          'IncreMat',
          style: AppTextStyles.headlineLarge.copyWith(letterSpacing: 0.5),
        ),
        const SizedBox(height: 2),
        Text(
          'C A R E G I V E R',
          style: AppTextStyles.overline.copyWith(letterSpacing: 3),
        ),
      ],
    );
  }
}

class _Illustration extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 160,
            height: 140,
            decoration: BoxDecoration(
              color: AppColors.lightSage.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(80),
            ),
          ),
          const Icon(
            Icons.spa,
            size: 72,
            color: AppColors.sageGreen,
          ),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.obscureText = false,
    this.suffixIcon,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      style: AppTextStyles.bodyMedium,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: AppColors.subtleText, size: 20),
        suffixIcon: suffixIcon,
      ),
    );
  }
}
