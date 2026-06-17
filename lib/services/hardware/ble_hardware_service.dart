import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../core/constants/ble_constants.dart';
import 'hardware_service.dart';

class BleHardwareService implements HardwareService {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _musicChar;
  BluetoothCharacteristic? _nfcRosterChar;
  BluetoothCharacteristic? _nfcOfflineChar;

  final _statusController = StreamController<HardwareStatus>.broadcast();
  final _repController = StreamController<int>.broadcast();
  final _speedController = StreamController<double>.broadcast();
  final _nfcController = StreamController<String>.broadcast();
  final _offlineController = StreamController<NfcOfflineSession>.broadcast();

  HardwareStatus _current = HardwareStatus.disconnected;

  StreamSubscription<BluetoothConnectionState>? _connectionSub;
  StreamSubscription<List<int>>? _batterySub;
  StreamSubscription<List<int>>? _matPlacedSub;
  StreamSubscription<List<int>>? _repCountSub;
  StreamSubscription<List<int>>? _repSpeedSub;
  StreamSubscription<List<int>>? _nfcScanSub;
  StreamSubscription<List<int>>? _nfcOfflineSub;
  Timer? _rssiTimer;

  @override
  Stream<HardwareStatus> get statusStream => _statusController.stream;

  @override
  Stream<int> get repCountStream => _repController.stream;

  @override
  Stream<double> get avgRepTimeStream => _speedController.stream;

  @override
  Stream<String> get nfcUidStream => _nfcController.stream;

  @override
  Stream<NfcOfflineSession> get offlineSessionStream => _offlineController.stream;

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
        debugPrint('[NFC] found IncreMat service; characteristics: '
            '${service.characteristics.map((c) => c.uuid.toString()).join(", ")}');
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
          } else if (uuid == BleConstants.nfcScanCharUuid.toLowerCase()) {
            await char.setNotifyValue(true);
            _nfcScanSub = char.onValueReceived.listen(_onNfcScanData);
            debugPrint('[NFC] subscribed to NFC-scan characteristic');
          } else if (uuid == BleConstants.nfcRosterCharUuid.toLowerCase()) {
            _nfcRosterChar = char;
          } else if (uuid == BleConstants.nfcOfflineCharUuid.toLowerCase()) {
            await char.setNotifyValue(true);
            _nfcOfflineChar = char;
            _nfcOfflineSub = char.onValueReceived.listen(_onOfflineData);
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

  // [uidLen][uid bytes] — a card tapped on the mat while we're connected.
  void _onNfcScanData(List<int> data) {
    debugPrint('[NFC] scan notify received: $data');
    if (data.isEmpty) return;
    final len = data[0];
    if (len == 0 || data.length < 1 + len) return;
    _nfcController.add(_bytesToHex(data.sublist(1, 1 + len)));
  }

  // [uidLen][uid bytes][reps u16 LE][durationMs u32 LE] — one buffered session.
  void _onOfflineData(List<int> data) {
    if (data.isEmpty) return;
    final len = data[0];
    if (len == 0 || data.length < 1 + len + 2 + 4) return;
    var i = 1;
    final uid = data.sublist(i, i + len);
    i += len;
    final reps = data[i] | (data[i + 1] << 8);
    i += 2;
    final durationMs = data[i] |
        (data[i + 1] << 8) |
        (data[i + 2] << 16) |
        (data[i + 3] << 24);
    _offlineController.add(NfcOfflineSession(
      uidHex: _bytesToHex(uid),
      reps: reps,
      durationMs: durationMs,
    ));
  }

  // Lowercase hex, matching NfcService.bytesToHex so UIDs line up with `nfc_uids`.
  static String _bytesToHex(List<int> bytes) =>
      bytes.map((b) => (b & 0xFF).toRadixString(16).padLeft(2, '0')).join();

  static List<int> _hexToBytes(String hex) {
    final out = <int>[];
    for (var i = 0; i + 1 < hex.length; i += 2) {
      out.add(int.parse(hex.substring(i, i + 2), radix: 16));
    }
    return out;
  }

  @override
  Future<void> pushKnownUid(String uidHex) async {
    final bytes = _hexToBytes(uidHex);
    if (_nfcRosterChar == null || bytes.isEmpty || bytes.length > 7) return;
    await _nfcRosterChar!.write([0x01, bytes.length, ...bytes]);
  }

  @override
  Future<void> clearRoster() async {
    if (_nfcRosterChar == null) return;
    await _nfcRosterChar!.write([0x02]);
  }

  @override
  Future<void> requestOfflineDump() async {
    if (_nfcOfflineChar == null) return;
    await _nfcOfflineChar!.write([0x20]);
  }

  @override
  Future<void> ackOfflineSync() async {
    if (_nfcOfflineChar == null) return;
    await _nfcOfflineChar!.write([0x10]);
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
    _connectionSub?.cancel();
    _batterySub?.cancel();
    _matPlacedSub?.cancel();
    _repCountSub?.cancel();
    _repSpeedSub?.cancel();
    _nfcScanSub?.cancel();
    _nfcOfflineSub?.cancel();
    _connectionSub = null;
    _batterySub = null;
    _matPlacedSub = null;
    _repCountSub = null;
    _repSpeedSub = null;
    _nfcScanSub = null;
    _nfcOfflineSub = null;
    await _device?.disconnect();
    _musicChar = null;
    _nfcRosterChar = null;
    _nfcOfflineChar = null;
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
    _nfcScanSub?.cancel();
    _nfcOfflineSub?.cancel();
    _statusController.close();
    _repController.close();
    _speedController.close();
    _nfcController.close();
    _offlineController.close();
    _device?.disconnect();
  }
}
