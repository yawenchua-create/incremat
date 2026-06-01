import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../providers/senior_provider.dart';

class ConnectSeniorScreen extends ConsumerStatefulWidget {
  const ConnectSeniorScreen({super.key});

  @override
  ConsumerState<ConnectSeniorScreen> createState() => _ConnectSeniorScreenState();
}

class _ConnectSeniorScreenState extends ConsumerState<ConnectSeniorScreen> {
  final _ctrl = TextEditingController();
  bool _isConnecting = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final code = _ctrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    setState(() => _isConnecting = true);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final error = await ref
        .read(seniorsNotifierProvider.notifier)
        .connectSenior(code);
    if (!mounted) return;
    setState(() => _isConnecting = false);
    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    } else {
      nav.popUntil((r) => r.isFirst);
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              Text('Connect to a Senior', style: AppTextStyles.displayMedium),
              const SizedBox(height: 8),
              Text(
                'Enter the Play code for the person you\'d like to monitor.',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _ctrl,
                textCapitalization: TextCapitalization.characters,
                style: AppTextStyles.titleLarge.copyWith(
                  letterSpacing: 3,
                  fontSize: 22,
                ),
                textAlign: TextAlign.center,
                decoration: const InputDecoration(
                  hintText: 'e.g. WORD-1234',
                  hintStyle: TextStyle(letterSpacing: 2),
                ),
                onSubmitted: (_) => _connect(),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isConnecting ? null : _connect,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: _isConnecting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text('Connect', style: AppTextStyles.buttonText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
