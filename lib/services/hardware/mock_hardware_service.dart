import 'dart:async';
import 'hardware_service.dart';

class MockHardwareService implements HardwareService {
  static const HardwareStatus _connectedStatus = HardwareStatus(
    isConnected: true,
    batteryPercent: 85,
    rssi: -62,
    isMatOnChair: true,
  );

  final _controller = StreamController<HardwareStatus>.broadcast();
  final _repController = StreamController<int>.broadcast();
  final _speedController = StreamController<double>.broadcast();
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
  }
}
