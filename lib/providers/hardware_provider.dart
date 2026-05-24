import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/hardware/hardware_service.dart';
import '../services/hardware/mock_hardware_service.dart';

final hardwareServiceProvider = Provider<HardwareService>((ref) {
  final service = MockHardwareService();
  ref.onDispose(service.dispose);
  return service;
});

final hardwareStatusProvider = StreamProvider<HardwareStatus>((ref) {
  final service = ref.watch(hardwareServiceProvider);
  return service.statusStream;
});
