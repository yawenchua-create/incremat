import 'dart:async';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../core/constants/ble_constants.dart';
import 'hardware_service.dart';

// BLE hardware service skeleton — placeholder UUIDs, not yet functional.
// Replace BleConstants UUID values with actual hardware spec before enabling.
class BleHardwareService implements HardwareService {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _musicChar;
  final _controller = StreamController<HardwareStatus>.broadcast();
  HardwareStatus _current = HardwareStatus.disconnected;

  StreamSubscription<BluetoothConnectionState>? _connectionSub;
  StreamSubscription<List<int>>? _batterySub;
  StreamSubscription<List<int>>? _matPlacedSub;

  @override
  Stream<HardwareStatus> get statusStream => _controller.stream;

  @override
  HardwareStatus get currentStatus => _current;

  @override
  Future<void> connect(String deviceId) async {
    try {
      ScanResult? found;
      final sub = FlutterBluePlus.scanResults.listen((results) {
        if (found == null && results.isNotEmpty) {
          found = results.first;
        }
      });

      await FlutterBluePlus.startScan(
        withNames: [BleConstants.deviceNamePrefix],
        timeout: const Duration(seconds: BleConstants.scanTimeoutSeconds),
      );
      await FlutterBluePlus.isScanning.where((s) => !s).first;
      sub.cancel();

      if (found == null) {
        throw Exception('No IncreMat device found');
      }

      _device = found!.device;
      await _device!.connect(
        timeout: const Duration(seconds: BleConstants.connectionTimeoutSeconds),
      );

      _connectionSub = _device!.connectionState.listen(_onConnectionState);
      await _discoverAndSubscribe();
    } catch (e) {
      _current = HardwareStatus.disconnected;
      _controller.add(_current);
      rethrow;
    }
  }

  void _onConnectionState(BluetoothConnectionState state) {
    if (state == BluetoothConnectionState.disconnected) {
      _current = HardwareStatus.disconnected;
      _controller.add(_current);
    }
  }

  Future<void> _discoverAndSubscribe() async {
    if (_device == null) return;

    final services = await _device!.discoverServices();
    for (final service in services) {
      if (service.uuid.toString() == BleConstants.serviceUuid) {
        for (final char in service.characteristics) {
          final uuid = char.uuid.toString();
          if (uuid == BleConstants.batteryCharUuid) {
            await char.setNotifyValue(true);
            _batterySub = char.onValueReceived.listen(_onBatteryData);
          } else if (uuid == BleConstants.matPlacedCharUuid) {
            await char.setNotifyValue(true);
            _matPlacedSub = char.onValueReceived.listen(_onMatPlacedData);
          } else if (uuid == BleConstants.musicTrackCharUuid) {
            _musicChar = char;
          }
        }
      }
    }
  }

  void _onBatteryData(List<int> data) {
    if (data.isEmpty) return;
    final battery = data[0].clamp(0, 100);
    final rssi = _current.rssi;
    _current = HardwareStatus(
      isConnected: true,
      batteryPercent: battery,
      rssi: rssi,
      isMatOnChair: _current.isMatOnChair,
    );
    _controller.add(_current);
  }

  void _onMatPlacedData(List<int> data) {
    if (data.isEmpty) return;
    final placed = data[0] == 1;
    _current = HardwareStatus(
      isConnected: _current.isConnected,
      batteryPercent: _current.batteryPercent,
      rssi: _current.rssi,
      isMatOnChair: placed,
    );
    _controller.add(_current);
  }

  @override
  Future<void> disconnect() async {
    await _device?.disconnect();
    _musicChar = null;
    _current = HardwareStatus.disconnected;
    _controller.add(_current);
  }

  @override
  Future<void> sendMusicTrack(String trackName) async {
    if (_musicChar == null) return;
    await _musicChar!.write(trackName.codeUnits);
  }

  @override
  void dispose() {
    _connectionSub?.cancel();
    _batterySub?.cancel();
    _matPlacedSub?.cancel();
    _controller.close();
    _device?.disconnect();
  }
}
