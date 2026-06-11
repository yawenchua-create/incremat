import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/hardware_provider.dart';
import '../../providers/live_session_provider.dart';
import '../../providers/senior_provider.dart';
import '../../services/hardware/hardware_service.dart';
import '../../services/nfc/nfc_service.dart';
import '../../services/nfc/nfc_uid_service.dart';

class HardwareScreen extends ConsumerWidget {
  const HardwareScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(hardwareStatusProvider);
    final current = ref.watch(hardwareServiceProvider).currentStatus;
    final status = statusAsync.valueOrNull ?? current;
    final liveSession = ref.watch(liveSessionProvider);

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _HardwareHeader()),
            SliverToBoxAdapter(
              child: _ConnectionBadge(status: status),
            ),
            if (liveSession != null)
              SliverToBoxAdapter(
                child: _LiveSessionCard(liveSession: liveSession),
              ),
            // NFC tap-to-identify so sessions are credited to the right user.
            SliverToBoxAdapter(child: _NfcIdentifyCard()),
            const SliverToBoxAdapter(
              child: _ChairIllustration(),
            ),
            SliverToBoxAdapter(
              child: _StatusCards(status: status),
            ),
            SliverToBoxAdapter(
              child: _ConnectButton(status: status),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        ),
      ),
    );
  }
}

class _HardwareHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppLocalizations.of(context).hardwareTitle,
                  style: AppTextStyles.headlineLarge),
              const SizedBox(height: 4),
              Text(
                AppLocalizations.of(context).hardwareSubtitle,
                style: AppTextStyles.bodySmall,
              ),
            ],
          ),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: AppColors.espresso.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Text('?',
                  style: TextStyle(
                      color: AppColors.subtleText,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionBadge extends StatelessWidget {
  final HardwareStatus status;
  const _ConnectionBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.espresso.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: status.isConnected
                  ? AppColors.sageGreen
                  : AppColors.subtleText,
              shape: BoxShape.circle,
              boxShadow: status.isConnected
                  ? [
                      BoxShadow(
                        color: AppColors.sageGreen.withValues(alpha: 0.4),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Text(l.statusLabel, style: AppTextStyles.titleMedium),
          Text(
            status.isConnected ? l.connected : l.disconnected,
            style: AppTextStyles.titleMedium.copyWith(
              color: status.isConnected
                  ? AppColors.sageGreen
                  : AppColors.subtleText,
            ),
          ),
          if (status.isConnected) ...[
            const Spacer(),
            Text(
              status.isMatOnChair ? l.matOnChair : l.matRemoved,
              style: AppTextStyles.bodySmall.copyWith(
                color: status.isMatOnChair
                    ? AppColors.sageGreen
                    : AppColors.terracotta,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LiveSessionCard extends StatelessWidget {
  final LiveSession liveSession;
  const _LiveSessionCard({required this.liveSession});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppColors.sageGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.sageGreen.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.fitness_center_outlined,
              size: 20, color: AppColors.sageGreen),
          const SizedBox(width: 12),
          Text(l.liveSessionLabel, style: AppTextStyles.titleMedium),
          Text(
            l.repsLabel(liveSession.repCount),
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.sageGreen,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (liveSession.avgRepTimeSeconds > 0) ...[
            const Spacer(),
            Text(
              l.avgSeconds(liveSession.avgRepTimeSeconds.toStringAsFixed(1)),
              style: AppTextStyles.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _ChairIllustration extends StatelessWidget {
  const _ChairIllustration();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Image.asset(
        'assets/images/chair_mat.png',
        height: 320,
        width: double.infinity,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _StatusCards extends StatelessWidget {
  final HardwareStatus status;
  const _StatusCards({required this.status});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final signal = switch (status.signalLabel) {
      'Strong' => l.signalStrong,
      'Good' => l.signalGood,
      _ => l.signalWeak,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          Expanded(
            child: _InfoCard(
              icon: Icons.battery_charging_full_outlined,
              label: l.batteryLabel(status.batteryPercent),
              iconColor: _batteryColor(status.batteryPercent),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _InfoCard(
              icon: Icons.signal_cellular_alt_outlined,
              label: l.signalLabelText(signal),
              iconColor: AppColors.sageGreen,
            ),
          ),
        ],
      ),
    );
  }

  Color _batteryColor(int pct) {
    if (pct > 50) return AppColors.sageGreen;
    if (pct > 20) return AppColors.terracotta;
    return Colors.red;
  }
}

class _ConnectButton extends ConsumerWidget {
  final HardwareStatus status;
  const _ConnectButton({required this.status});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final isConnecting = ref.watch(hardwareConnectingProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: isConnecting
              ? null
              : () => _onTap(context, ref, status.isConnected),
          style: FilledButton.styleFrom(
            backgroundColor: status.isConnected
                ? AppColors.terracotta
                : AppColors.sageGreen,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: isConnecting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  status.isConnected ? l.disconnect : l.connectToIncreMat,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
        ),
      ),
    );
  }

  Future<void> _onTap(
      BuildContext context, WidgetRef ref, bool isConnected) async {
    final l = AppLocalizations.of(context);
    final service = ref.read(hardwareServiceProvider);
    ref.read(hardwareConnectingProvider.notifier).state = true;
    try {
      if (isConnected) {
        await service.disconnect();
      } else {
        await service.connect('');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l.connectionFailed('$e'))),
        );
      }
    } finally {
      ref.read(hardwareConnectingProvider.notifier).state = false;
    }
  }
}

// ── NFC Identify Card ─────────────────────────────────────────────────────────

class _NfcIdentifyCard extends ConsumerStatefulWidget {
  const _NfcIdentifyCard();

  @override
  ConsumerState<_NfcIdentifyCard> createState() => _NfcIdentifyCardState();
}

class _NfcIdentifyCardState extends ConsumerState<_NfcIdentifyCard> {
  bool _scanning = false;
  String? _statusMsg;
  bool _isError = false;
  StreamSubscription<String>? _matNfcSub;

  @override
  void initState() {
    super.initState();
    // Subscribe to UIDs from the mat's NFC reader so a card tap there
    // auto-identifies the user, identical to tapping the phone manually.
    final service = ref.read(hardwareServiceProvider);
    _matNfcSub = service.nfcUidStream.listen(_onMatUid);
  }

  Future<void> _onMatUid(String uid) async {
    if (!mounted) return;
    setState(() { _statusMsg = null; _isError = false; });
    await _resolveUid(uid);
  }

  /// Shared lookup used by both the phone's NFC reader and the mat's reader.
  Future<void> _resolveUid(String uid) async {
    // Capture localizations before the await so we don't use context across
    // an async gap.
    final l = AppLocalizations.of(context);
    final seniorId = await NfcUidService().lookup(uid);
    if (!mounted) return;
    if (seniorId == null) {
      setState(() {
        _scanning = false;
        _statusMsg = l.cardNotRecognised;
        _isError = true;
      });
      return;
    }
    final seniors = ref.read(seniorsProvider);
    final match = seniors.where((s) => s.id == seniorId).firstOrNull;
    if (match == null) {
      setState(() {
        _scanning = false;
        _statusMsg = l.userNotInCircle;
        _isError = true;
      });
      return;
    }
    selectSenior(ref, seniorId);
    setState(() {
      _scanning = false;
      _statusMsg = l.nowTracking(match.name);
      _isError = false;
    });
  }

  Future<void> _identify() async {
    final l = AppLocalizations.of(context);
    final available = await NfcService.isAvailable();
    if (!available) {
      setState(() {
        _statusMsg = l.nfcUnavailable;
        _isError = true;
      });
      return;
    }
    setState(() { _scanning = true; _statusMsg = null; _isError = false; });
    await NfcService.readUid(
      onRead: (uid) => _resolveUid(uid),
      onError: (msg) {
        if (mounted) {
          setState(() { _scanning = false; _statusMsg = msg; _isError = true; });
        }
      },
    );
  }

  @override
  void dispose() {
    _matNfcSub?.cancel();
    NfcService.stopSession().ignore();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.espresso.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.nfc, size: 20, color: AppColors.sageGreen),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.identifyUser, style: AppTextStyles.titleMedium),
                    Text(
                      l.identifyUserSubtitle,
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_statusMsg != null) ...[
            const SizedBox(height: 10),
            Text(
              _statusMsg!,
              style: AppTextStyles.caption.copyWith(
                color: _isError ? AppColors.terracotta : AppColors.sageGreen,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _scanning ? null : _identify,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.sageGreen,
                side: BorderSide(
                    color: AppColors.sageGreen.withValues(alpha: 0.5)),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              icon: _scanning
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.sageGreen),
                    )
                  : const Icon(Icons.sensors, size: 18),
              label: Text(_scanning ? l.holdTagToPhone : l.scanNfcTag),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;

  const _InfoCard({
    required this.icon,
    required this.label,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.espresso.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label,
                style: AppTextStyles.titleMedium.copyWith(fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
