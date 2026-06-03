import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../providers/auth_provider.dart';
import '../../services/nfc/nfc_service.dart';
import '../../services/nfc/nfc_uid_service.dart';

enum _EnrollState { waiting, scanning, success, error, unavailable }

/// Bottom sheet that enrolls a physical card/fob for a senior by reading its
/// UID and saving it to Firestore. Works with any NFC card — EZ-Link,
/// MIFARE Classic, NTAG, contactless bank cards, etc.
class NfcWriteSheet extends ConsumerStatefulWidget {
  final String seniorId;
  final String seniorName;

  const NfcWriteSheet({
    super.key,
    required this.seniorId,
    required this.seniorName,
  });

  static Future<void> show(
    BuildContext context, {
    required String seniorId,
    required String seniorName,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NfcWriteSheet(
        seniorId: seniorId,
        seniorName: seniorName,
      ),
    );
  }

  @override
  ConsumerState<NfcWriteSheet> createState() => _NfcWriteSheetState();
}

class _NfcWriteSheetState extends ConsumerState<NfcWriteSheet> {
  _EnrollState _state = _EnrollState.waiting;
  String _errorMessage = '';
  String? _enrolledUid;

  @override
  void initState() {
    super.initState();
    _startEnroll();
  }

  @override
  void dispose() {
    NfcService.stopSession().ignore();
    super.dispose();
  }

  Future<void> _startEnroll() async {
    final available = await NfcService.isAvailable();
    if (!available) {
      if (mounted) setState(() => _state = _EnrollState.unavailable);
      return;
    }
    if (mounted) setState(() => _state = _EnrollState.scanning);

    await NfcService.readUid(
      onRead: (uid) async {
        final caregiverId =
            ref.read(authStateProvider).valueOrNull?.uid ?? '';
        try {
          await NfcUidService().enroll(
            uid: uid,
            seniorId: widget.seniorId,
            caregiverId: caregiverId,
          );
          if (mounted) {
            setState(() {
              _state = _EnrollState.success;
              _enrolledUid = uid;
            });
          }
        } catch (e) {
          if (mounted) {
            setState(() {
              _state = _EnrollState.error;
              _errorMessage = 'Failed to save card. Please try again.';
            });
          }
        }
      },
      onError: (msg) {
        if (mounted) {
          setState(() {
            _state = _EnrollState.error;
            _errorMessage = msg;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.warmCream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 40),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.subtleText.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildIcon(),
            const SizedBox(height: 20),
            Text(_title,
                style: AppTextStyles.headlineSmall,
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(_subtitle,
                style: AppTextStyles.bodySmall,
                textAlign: TextAlign.center),
            const SizedBox(height: 28),
            if (_state == _EnrollState.error) ...[
              ElevatedButton(
                onPressed: () {
                  setState(() => _state = _EnrollState.waiting);
                  _startEnroll();
                },
                child: const Text('Try Again'),
              ),
              const SizedBox(height: 12),
            ],
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                _state == _EnrollState.success ? 'Done' : 'Cancel',
                style: AppTextStyles.labelLarge
                    .copyWith(color: AppColors.subtleText),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIcon() {
    final isError = _state == _EnrollState.error ||
        _state == _EnrollState.unavailable;
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        color: isError
            ? AppColors.terracotta.withValues(alpha: 0.1)
            : AppColors.sageGreen.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(
        _state == _EnrollState.success
            ? Icons.check_circle_outline_rounded
            : isError
                ? Icons.error_outline_rounded
                : Icons.nfc,
        size: 44,
        color: isError ? AppColors.terracotta : AppColors.sageGreen,
      ),
    );
  }

  String get _title => switch (_state) {
        _EnrollState.waiting => 'Ready to Enrol',
        _EnrollState.scanning => 'Tap Card to Phone',
        _EnrollState.success => 'Card Enrolled!',
        _EnrollState.error => 'Enrolment Failed',
        _EnrollState.unavailable => 'NFC Not Available',
      };

  String get _subtitle => switch (_state) {
        _EnrollState.waiting =>
          'Hold any NFC card — EZ-Link, access fob, etc. — to the back of the phone.',
        _EnrollState.scanning =>
          "Hold ${widget.seniorName}'s card flat against the back of the phone.",
        _EnrollState.success =>
          "${widget.seniorName}'s card has been enrolled. "
              "They can now tap it on the mat to log in automatically.\n\n"
              "UID: ${_enrolledUid ?? ''}",
        _EnrollState.error => _errorMessage,
        _EnrollState.unavailable =>
          'This device does not have NFC or it is turned off. '
              'Enable NFC in Settings and try again.',
      };
}
