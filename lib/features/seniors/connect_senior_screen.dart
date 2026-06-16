import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/senior_provider.dart';
import '../../services/nfc/nfc_service.dart';

class ConnectSeniorScreen extends ConsumerStatefulWidget {
  const ConnectSeniorScreen({super.key});

  @override
  ConsumerState<ConnectSeniorScreen> createState() => _ConnectSeniorScreenState();
}

class _ConnectSeniorScreenState extends ConsumerState<ConnectSeniorScreen> {
  final _ctrl = TextEditingController();
  bool _isConnecting = false;
  bool _isScanning = false;

  @override
  void dispose() {
    NfcService.stopSession().ignore();
    _ctrl.dispose();
    super.dispose();
  }

  /// Connects an existing senior by reading a card that's already enrolled to
  /// them — no Play code needed.
  Future<void> _scanCard() async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    if (!await NfcService.isAvailable()) {
      messenger.showSnackBar(SnackBar(content: Text(l.nfcNotAvailable)));
      return;
    }
    if (!mounted) return;
    setState(() => _isScanning = true);
    await NfcService.readUid(
      onRead: (uid) async {
        final error = await ref
            .read(seniorsNotifierProvider.notifier)
            .connectSeniorByNfcUid(uid, l);
        if (!mounted) return;
        setState(() => _isScanning = false);
        if (error != null) {
          messenger.showSnackBar(SnackBar(content: Text(error)));
        } else {
          nav.popUntil((r) => r.isFirst);
        }
      },
      onError: (msg) {
        if (!mounted) return;
        setState(() => _isScanning = false);
        messenger.showSnackBar(SnackBar(content: Text(msg)));
      },
    );
  }

  Future<void> _connect() async {
    final code = _ctrl.text.trim().toUpperCase();
    if (code.isEmpty) return;
    final l = AppLocalizations.of(context);
    setState(() => _isConnecting = true);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final error = await ref
        .read(seniorsNotifierProvider.notifier)
        .connectSenior(code, l);
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
    final l = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(l.appTitle, style: AppTextStyles.labelLarge),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              Text(l.connectToSenior, style: AppTextStyles.displayMedium),
              const SizedBox(height: 8),
              Text(
                l.connectSeniorSubtitle,
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
                decoration: InputDecoration(
                  hintText: l.connectCodeHint,
                  hintStyle: const TextStyle(letterSpacing: 2),
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
                    : Text(l.connect, style: AppTextStyles.buttonText),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(l.orConnectWord,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.subtleText)),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: (_isConnecting || _isScanning) ? null : _scanCard,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.sageGreen,
                  minimumSize: const Size(double.infinity, 56),
                  side: BorderSide(
                      color: AppColors.sageGreen.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                icon: _isScanning
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: AppColors.sageGreen),
                      )
                    : const Icon(Icons.nfc, size: 22),
                label: Text(
                  _isScanning ? l.holdCardToPhone : l.scanTheirCard,
                  style: AppTextStyles.buttonText
                      .copyWith(color: AppColors.sageGreen),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
