import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/hardware/hardware_service.dart';
import '../services/hardware/ble_hardware_service.dart';

final hardwareServiceProvider = Provider<HardwareService>((ref) {
  final service = BleHardwareService();
  ref.onDispose(service.dispose);
  return service;
});

final hardwareStatusProvider = StreamProvider<HardwareStatus>((ref) {
  final service = ref.watch(hardwareServiceProvider);
  return service.statusStream;
});

// Tracks ongoing connect/disconnect action for UI feedback.
final hardwareConnectingProvider = StateProvider<bool>((ref) => false);
