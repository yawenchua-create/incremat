import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/hardware_provider.dart';
import '../../providers/senior_provider.dart';
import '../../services/hardware/simulator_hardware_service.dart';
import '../../services/notifications/notification_service.dart';

/// Developer tools: drive a fake mat so the whole app can be tested without
/// doing real reps on the hardware.
class DebugScreen extends ConsumerStatefulWidget {
  const DebugScreen({super.key});

  @override
  ConsumerState<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends ConsumerState<DebugScreen> {
  final _nfcCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _nfcCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final simMode = ref.watch(simulatorModeProvider);
    // Only touch the hardware service when the simulator is actually on. Reading
    // it unconditionally would construct the real BLE service just to render
    // this screen, which can throw on devices with no Bluetooth / denied
    // permission and blank the whole screen.
    final service = simMode ? ref.watch(hardwareServiceProvider) : null;
    final sim = service is SimulatorHardwareService ? service : null;
    // Extra bottom padding so the NFC field at the end can scroll clear of the
    // on-screen keyboard.
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.warmCream,
      appBar: AppBar(
        backgroundColor: AppColors.warmCream,
        elevation: 0,
        foregroundColor: AppColors.espresso,
        title: Text(l.devSimulator),
      ),
      body: SafeArea(
        child: ListView(
          controller: _scrollCtrl,
          padding: EdgeInsets.fromLTRB(20, 8, 20, 32 + keyboardInset),
          children: [
            _card(
              child: SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: simMode,
                activeThumbColor: AppColors.sageGreen,
                title: Text(l.devSimulatorMode),
                subtitle: Text(l.devSimulatorModeHint),
                onChanged: (v) =>
                    ref.read(simulatorModeProvider.notifier).set(v),
              ),
            ),
            // Notification preview — independent of the simulator, so it works
            // whether or not a fake mat is running.
            const _MobilityAlertCard(),
            // Gate on the persisted simMode (not the live service instance) so
            // the controls don't collapse during a service swap; show a stable
            // placeholder for the brief moment before the simulator is ready.
            if (!simMode)
              _card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    l.devSimulatorTurnOnHint,
                    style: const TextStyle(color: AppColors.subtleText),
                  ),
                ),
              )
            else if (sim == null)
              _card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(
                    l.devStartingSimulator,
                    style: const TextStyle(color: AppColors.subtleText),
                  ),
                ),
              )
            else ...[
              _RepsCard(sim: sim),
              _ConnectionCard(sim: sim),
              _SpeedCard(sim: sim),
              _NfcCard(sim: sim, controller: _nfcCtrl),
            ],
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) => _debugCard(child: child);
}

/// Card surface backed by a [Material] — required so the ListTiles /
/// SwitchListTiles inside can paint their background and ink. Without a Material
/// ancestor between them and the coloured box, Flutter asserts ("ListTile
/// wrapped in a DecoratedBox…") and the whole screen renders blank in debug.
Widget _debugCard({required Widget child}) => Padding(
  padding: const EdgeInsets.only(top: 12),
  child: Material(
    color: AppColors.cardSurface,
    borderRadius: BorderRadius.circular(18),
    clipBehavior: Clip.antiAlias,
    child: Padding(padding: const EdgeInsets.all(16), child: child),
  ),
);

Widget _sectionTitle(String text) => Padding(
  padding: const EdgeInsets.only(bottom: 12),
  child: Text(text, style: AppTextStyles.titleMedium),
);

class _RepsCard extends StatefulWidget {
  const _RepsCard({required this.sim});

  final SimulatorHardwareService sim;

  @override
  State<_RepsCard> createState() => _RepsCardState();
}

class _RepsCardState extends State<_RepsCard> {
  // Kept local so dragging the slider rebuilds only this card, not the whole
  // Developer screen (which previously caused flicker / lost scroll position).
  double _autoSeconds = 2.0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final sim = widget.sim;
    return _debugCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(l.devReps),
          Center(
            child: StreamBuilder<int>(
              stream: sim.repCountStream,
              initialData: sim.reps,
              builder: (context, snap) => Text(
                '${snap.data ?? 0}',
                style: AppTextStyles.statNumber.copyWith(
                  fontSize: 56,
                  color: AppColors.sageGreen,
                ),
              ),
            ),
          ),
          Center(
            child: Text(l.devRepsCumulative, style: AppTextStyles.caption),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _btn('+1', () => setState(() => sim.addReps(1))),
              const SizedBox(width: 8),
              _btn('+5', () => setState(() => sim.addReps(5))),
              const SizedBox(width: 8),
              _btn('+10', () => setState(() => sim.addReps(10))),
              const SizedBox(width: 8),
              _btn(
                l.devReset,
                () => setState(() => sim.resetReps()),
                outlined: true,
              ),
            ],
          ),
          const Divider(height: 28),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: sim.isAutoRunning,
            activeThumbColor: AppColors.sageGreen,
            title: Text(l.devAutoReps),
            subtitle: Text(l.devAutoRepsEvery(_autoSeconds.toStringAsFixed(1))),
            onChanged: (on) => setState(() {
              if (on) {
                sim.startAuto(
                  Duration(milliseconds: (_autoSeconds * 1000).round()),
                );
              } else {
                sim.stopAuto();
              }
            }),
          ),
          Slider(
            min: 0.5,
            max: 5.0,
            divisions: 9,
            value: _autoSeconds,
            activeColor: AppColors.sageGreen,
            label: '${_autoSeconds.toStringAsFixed(1)}s',
            onChanged: (v) {
              setState(() => _autoSeconds = v);
              if (sim.isAutoRunning) {
                sim.startAuto(Duration(milliseconds: (v * 1000).round()));
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _btn(String label, VoidCallback onTap, {bool outlined = false}) {
    return Expanded(
      child: outlined
          ? OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.terracotta,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(label),
            )
          : ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(label),
            ),
    );
  }
}

class _ConnectionCard extends StatefulWidget {
  const _ConnectionCard({required this.sim});
  final SimulatorHardwareService sim;

  @override
  State<_ConnectionCard> createState() => _ConnectionCardState();
}

class _ConnectionCardState extends State<_ConnectionCard> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final sim = widget.sim;
    return _debugCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(l.devConnection),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: sim.isConnected,
            activeThumbColor: AppColors.sageGreen,
            title: Text(l.devConnected),
            onChanged: (v) => setState(() => sim.setConnected(v)),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: sim.isMatPlaced,
            activeThumbColor: AppColors.sageGreen,
            title: Text(l.devMatOnChair),
            onChanged: (v) => setState(() => sim.setMatPlaced(v)),
          ),
          Row(
            children: [
              Text(l.devBattery, style: AppTextStyles.bodyMedium),
              Expanded(
                child: Slider(
                  min: 0,
                  max: 100,
                  divisions: 20,
                  value: sim.battery.toDouble(),
                  activeColor: AppColors.sageGreen,
                  label: '${sim.battery}%',
                  onChanged: (v) => setState(() => sim.setBattery(v.round())),
                ),
              ),
              SizedBox(
                width: 40,
                child: Text(
                  '${sim.battery}%',
                  textAlign: TextAlign.right,
                  style: AppTextStyles.caption,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpeedCard extends StatelessWidget {
  const _SpeedCard({required this.sim});
  final SimulatorHardwareService sim;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _debugCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(l.devAvgRepTime),
          Text(l.devAvgRepTimeHint, style: AppTextStyles.caption),
          const SizedBox(height: 12),
          Row(
            children: [
              _chip(l.devSpeedFast('1.5'), () => sim.emitAvgRepTime(1.5)),
              const SizedBox(width: 8),
              _chip(l.devSpeedNormal('2.5'), () => sim.emitAvgRepTime(2.5)),
              const SizedBox(width: 8),
              _chip(l.devSpeedSlow('4.0'), () => sim.emitAvgRepTime(4.0)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, VoidCallback onTap) => Expanded(
    child: OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.sageGreen,
        padding: const EdgeInsets.symmetric(vertical: 10),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 12),
        textAlign: TextAlign.center,
      ),
    ),
  );
}

/// Fires a sample mobility-decline notification so the caregiver warning can be
/// previewed on demand, without waiting for a real decline in the data.
class _MobilityAlertCard extends ConsumerWidget {
  const _MobilityAlertCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return _debugCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(l.devMobilityAlert),
          Text(l.devMobilityAlertHint, style: AppTextStyles.caption),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.notifications_active_outlined, size: 18),
              onPressed: () => _fire(context, ref),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              label: Text(l.devSendSampleAlert),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _fire(BuildContext context, WidgetRef ref) async {
    // Attribute to the senior in view if there is one, else a placeholder so the
    // preview works even before any senior is added.
    final senior = ref.read(selectedSeniorProvider);
    final id = senior?.id ?? 'sample-senior';
    final name = senior?.name ?? 'Betty';
    // Mirrors the real day-drop wording in MobilityAlertWatcher.
    await NotificationService().showMobilityAlert(
      id,
      'Mobility check-in',
      "$name's sit-to-stand was 32% slower than usual today. "
          'Consider checking in.',
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).devSendSampleAlert)),
      );
    }
  }
}

class _NfcCard extends StatelessWidget {
  const _NfcCard({required this.sim, required this.controller});
  final SimulatorHardwareService sim;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _debugCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(l.devNfcTapOnMat),
          Text(l.devNfcHint, style: AppTextStyles.caption),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: l.devCardUidHint,
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => sim.tapNfc(controller.text),
                child: Text(l.devEmit),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
