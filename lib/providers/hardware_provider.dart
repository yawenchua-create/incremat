import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/hardware/hardware_service.dart';
import '../services/hardware/ble_hardware_service.dart';
import '../services/hardware/simulator_hardware_service.dart';

// When on, the app talks to a fake mat (SimulatorHardwareService) instead of
// real BLE — so the whole app can be tested without doing reps on the hardware.
// Persisted so it survives restarts during a testing session.
class SimulatorModeNotifier extends Notifier<bool> {
  static const _key = 'simulator_mode'; // SharedPreferences storage key

  // build() must return synchronously, so we kick off the async _load() in the
  // background and start from `false`; when the saved value arrives _load()
  // updates `state`, rebuilding watchers.
  @override
  bool build() {
    _load();
    return false;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(_key) ?? false;
  }

  Future<void> set(bool value) async {
    state = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }
}

final simulatorModeProvider =
    NotifierProvider<SimulatorModeNotifier, bool>(SimulatorModeNotifier.new);

/// THE key wiring of the hardware layer: hands the app a HardwareService without
/// it knowing which concrete one. Because this `ref.watch`es simulatorMode, the
/// moment that toggle flips Riverpod REBUILDS this provider — disposing the old
/// service (`ref.onDispose`) and constructing the other. Everything downstream
/// that watches this provider then re-subscribes to the new service's streams.
final hardwareServiceProvider = Provider<HardwareService>((ref) {
  final HardwareService service =
      ref.watch(simulatorModeProvider) ? SimulatorHardwareService() : BleHardwareService();
  ref.onDispose(service.dispose); // clean up when swapped/torn down
  return service;
});

/// Convenience stream of the current mat status. It depends on
/// hardwareServiceProvider, so it too re-subscribes automatically on a swap.
final hardwareStatusProvider = StreamProvider<HardwareStatus>((ref) {
  final service = ref.watch(hardwareServiceProvider);
  return service.statusStream;
});

// A simple boolean flag the UI flips while a connect/disconnect is in progress
// (StateProvider = one mutable value, read/written via `.notifier.state`).
final hardwareConnectingProvider = StateProvider<bool>((ref) => false);
