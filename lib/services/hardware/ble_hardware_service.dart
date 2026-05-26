import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../core/constants/ble_constants.dart';
import 'hardware_service.dart';

class BleHardwareService implements HardwareService {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _musicChar;

  final _statusController = StreamController<HardwareStatus>.broadcast();
  final _repController = StreamController<int>.broadcast();
  final _speedController = StreamController<double>.broadcast();

  HardwareStatus _current = HardwareStatus.disconnected;

  StreamSubscription<BluetoothConnectionState>? _connectionSub;
  StreamSubscription<List<int>>? _batterySub;
  StreamSubscription<List<int>>? _matPlacedSub;
  StreamSubscription<List<int>>? _repCountSub;
  StreamSubscription<List<int>>? _repSpeedSub;
  Timer? _rssiTimer;

  @override
  Stream<HardwareStatus> get statusStream => _statusController.stream;

  @override
  Stream<int> get repCountStream => _repController.stream;

  @override
  Stream<double> get avgRepTimeStream => _speedController.stream;

  @override
  HardwareStatus get currentStatus => _current;

  @override
  Future<void> connect(String deviceId) async {
    try {
      // Request BLE on if needed (Android only — no-op on others).
      if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
        await FlutterBluePlus.turnOn();
      }

      ScanResult? found;
      final sub = FlutterBluePlus.scanResults.listen((results) {
        found ??= results.firstOrNull;
      });

      await FlutterBluePlus.startScan(
        withNames: [BleConstants.deviceNamePrefix],
        timeout: const Duration(seconds: BleConstants.scanTimeoutSeconds),
      );
      await FlutterBluePlus.isScanning.where((s) => !s).first;
      sub.cancel();

      if (found == null) throw Exception('No IncreMat device found nearby');

      _device = found!.device;
      await _device!.connect(
        timeout: const Duration(seconds: BleConstants.connectionTimeoutSeconds),
      );

      _connectionSub = _device!.connectionState.listen(_onConnectionState);
      await _discoverAndSubscribe();

      // Poll RSSI every 5 s while connected.
      _rssiTimer = Timer.periodic(const Duration(seconds: 5), (_) => _updateRssi());
    } catch (e) {
      _current = HardwareStatus.disconnected;
      _statusController.add(_current);
      rethrow;
    }
  }

  void _onConnectionState(BluetoothConnectionState state) {
    if (state == BluetoothConnectionState.disconnected) {
      _rssiTimer?.cancel();
      _current = HardwareStatus.disconnected;
      _statusController.add(_current);
    }
  }

  Future<void> _discoverAndSubscribe() async {
    if (_device == null) return;
    final services = await _device!.discoverServices();
    for (final service in services) {
      if (service.uuid.toString().toLowerCase() ==
          BleConstants.serviceUuid.toLowerCase()) {
        for (final char in service.characteristics) {
          final uuid = char.uuid.toString().toLowerCase();
          if (uuid == BleConstants.repCountCharUuid.toLowerCase()) {
            await char.setNotifyValue(true);
            _repCountSub = char.onValueReceived.listen(_onRepCountData);
          } else if (uuid == BleConstants.repSpeedCharUuid.toLowerCase()) {
            await char.setNotifyValue(true);
            _repSpeedSub = char.onValueReceived.listen(_onRepSpeedData);
          } else if (uuid == BleConstants.batteryCharUuid.toLowerCase()) {
            await char.setNotifyValue(true);
            _batterySub = char.onValueReceived.listen(_onBatteryData);
          } else if (uuid == BleConstants.matPlacedCharUuid.toLowerCase()) {
            await char.setNotifyValue(true);
            _matPlacedSub = char.onValueReceived.listen(_onMatPlacedData);
          } else if (uuid == BleConstants.musicTrackCharUuid.toLowerCase()) {
            _musicChar = char;
          }
        }
      }
    }
    // Emit an initial connected status.
    _current = HardwareStatus(
      isConnected: true,
      batteryPercent: _current.batteryPercent,
      rssi: _current.rssi,
      isMatOnChair: _current.isMatOnChair,
    );
    _statusController.add(_current);
  }

  // 2-byte little-endian uint16 = cumulative rep count this session.
  void _onRepCountData(List<int> data) {
    if (data.length < 2) return;
    final count = data[0] | (data[1] << 8);
    _repController.add(count);
  }

  // 4-byte little-endian float32 = avg rep time in seconds.
  void _onRepSpeedData(List<int> data) {
    if (data.length < 4) return;
    final bytes = ByteData.sublistView(Uint8List.fromList(data.sublist(0, 4)));
    final avgTime = bytes.getFloat32(0, Endian.little);
    if (avgTime > 0 && avgTime < 60) _speedController.add(avgTime.toDouble());
  }

  void _onBatteryData(List<int> data) {
    if (data.isEmpty) return;
    _current = HardwareStatus(
      isConnected: true,
      batteryPercent: data[0].clamp(0, 100),
      rssi: _current.rssi,
      isMatOnChair: _current.isMatOnChair,
    );
    _statusController.add(_current);
  }

  void _onMatPlacedData(List<int> data) {
    if (data.isEmpty) return;
    _current = HardwareStatus(
      isConnected: _current.isConnected,
      batteryPercent: _current.batteryPercent,
      rssi: _current.rssi,
      isMatOnChair: data[0] == 1,
    );
    _statusController.add(_current);
  }

  Future<void> _updateRssi() async {
    if (_device == null || !_current.isConnected) return;
    try {
      final rssi = await _device!.readRssi();
      _current = HardwareStatus(
        isConnected: _current.isConnected,
        batteryPercent: _current.batteryPercent,
        rssi: rssi,
        isMatOnChair: _current.isMatOnChair,
      );
      _statusController.add(_current);
    } catch (_) {}
  }

  @override
  Future<void> disconnect() async {
    _rssiTimer?.cancel();
    await _device?.disconnect();
    _musicChar = null;
    _current = HardwareStatus.disconnected;
    _statusController.add(_current);
  }

  @override
  Future<void> sendMusicTrack(String trackName) async {
    if (_musicChar == null) return;
    await _musicChar!.write(trackName.codeUnits, withoutResponse: true);
  }

  @override
  void dispose() {
    _rssiTimer?.cancel();
    _connectionSub?.cancel();
    _batterySub?.cancel();
    _matPlacedSub?.cancel();
    _repCountSub?.cancel();
    _repSpeedSub?.cancel();
    _statusController.close();
    _repController.close();
    _speedController.close();
    _device?.disconnect();
  }
}
