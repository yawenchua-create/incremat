import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/hardware/hardware_service.dart';
import '../services/hardware/ble_hardware_service.dart';
import '../services/hardware/simulator_hardware_service.dart';

// When on, the app talks to a fake mat (SimulatorHardwareService) instead of
// real BLE — so the whole app can be tested without doing reps on the hardware.
// Persisted so it survives restarts during a testing session.
class SimulatorModeNotifier extends Notifier<bool> {
  static const _key = 'simulator_mode';

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

final hardwareServiceProvider = Provider<HardwareService>((ref) {
  final HardwareService service =
      ref.watch(simulatorModeProvider) ? SimulatorHardwareService() : BleHardwareService();
  ref.onDispose(service.dispose);
  return service;
});

final hardwareStatusProvider = StreamProvider<HardwareStatus>((ref) {
  final service = ref.watch(hardwareServiceProvider);
  return service.statusStream;
});

// Tracks ongoing connect/disconnect action for UI feedback.
final hardwareConnectingProvider = StateProvider<bool>((ref) => false);
