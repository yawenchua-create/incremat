import 'dart:async';
import 'hardware_service.dart';

/// The simplest fake mat: always reports a healthy, connected device and never
/// emits reps/NFC. Used for demo mode and widget tests where we just need a mat
/// that "exists" without the interactive controls the SimulatorHardwareService
/// offers. Like the other two, it `implements HardwareService` so it drops into
/// the same provider slot interchangeably.
class MockHardwareService implements HardwareService {
  // A fixed, pre-built "everything's fine" status reused throughout.
  static const HardwareStatus _connectedStatus = HardwareStatus(
    isConnected: true,
    batteryPercent: 85,
    rssi: -62,
    isMatOnChair: true,
  );

  final _controller = StreamController<HardwareStatus>.broadcast();
  final _repController = StreamController<int>.broadcast();
  final _speedController = StreamController<double>.broadcast();
  // No NFC reader in mock — stream never emits.
  final _nfcController = StreamController<String>.broadcast();
  HardwareStatus _current = _connectedStatus;

  MockHardwareService() {
    // Emit connected status after a brief "connecting" delay
    Future.delayed(const Duration(milliseconds: 500), () {
      _current = _connectedStatus;
      if (!_controller.isClosed) {
        _controller.add(_current);
      }
    });
  }

  @override
  Stream<HardwareStatus> get statusStream => _controller.stream;

  @override
  Stream<int> get repCountStream => _repController.stream;

  @override
  Stream<double> get avgRepTimeStream => _speedController.stream;

  @override
  Stream<String> get nfcUidStream => _nfcController.stream;

  @override
  HardwareStatus get currentStatus => _current;

  @override
  Future<void> connect(String deviceId) async {
    await Future.delayed(const Duration(seconds: 1));
    _current = _connectedStatus;
    _controller.add(_current);
  }

  @override
  Future<void> disconnect() async {
    _current = HardwareStatus.disconnected;
    _controller.add(_current);
  }

  @override
  Future<void> sendMusicTrack(String trackName) async {
    // No-op in mock
  }

  @override
  void dispose() {
    _controller.close();
    _repController.close();
    _speedController.close();
    _nfcController.close();
  }
}
