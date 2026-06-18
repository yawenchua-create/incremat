import 'dart:async';
import 'dart:typed_data'; // for ByteData/Uint8List — parsing raw bytes
import 'package:flutter_blue_plus/flutter_blue_plus.dart'; // the BLE plugin
import '../../core/constants/ble_constants.dart';
import 'hardware_service.dart';

/// The REAL hardware driver: talks to the physical mat over Bluetooth Low
/// Energy using the `flutter_blue_plus` package. `implements HardwareService`
/// means it must provide every member the interface declares.
///
/// Lifecycle: connect() → scan → connect to device → discover GATT services →
/// subscribe (setNotifyValue) to each characteristic → translate incoming bytes
/// into Dart values → push them onto streams the app listens to.
class BleHardwareService implements HardwareService {
  BluetoothDevice? _device;             // the connected mat (null until connected)
  BluetoothCharacteristic? _musicChar;  // the one characteristic we WRITE to

  // StreamControllers are the "write" end of each stream; `.stream` (below) is
  // the "read" end the app subscribes to. `.broadcast()` allows MORE THAN ONE
  // listener at a time (e.g. several widgets watching reps).
  final _statusController = StreamController<HardwareStatus>.broadcast();
  final _repController = StreamController<int>.broadcast();
  final _speedController = StreamController<double>.broadcast();
  final _nfcController = StreamController<String>.broadcast();

  HardwareStatus _current = HardwareStatus.disconnected; // last status we built

  // Handles to each BLE subscription/timer so we can cancel them on disconnect
  // (otherwise they leak and keep firing). `?` = nullable; null when not active.
  StreamSubscription<BluetoothConnectionState>? _connectionSub;
  StreamSubscription<List<int>>? _batterySub;
  StreamSubscription<List<int>>? _matPlacedSub;
  StreamSubscription<List<int>>? _repCountSub;
  StreamSubscription<List<int>>? _repSpeedSub;
  StreamSubscription<List<int>>? _nfcScanSub;
  Timer? _rssiTimer;

  // Expose the READ end of each controller. `@override` confirms we're
  // fulfilling a member declared in HardwareService.
  @override
  Stream<HardwareStatus> get statusStream => _statusController.stream;

  @override
  Stream<String> get nfcUidStream => _nfcController.stream;

  @override
  Stream<int> get repCountStream => _repController.stream;

  @override
  Stream<double> get avgRepTimeStream => _speedController.stream;

  @override
  HardwareStatus get currentStatus => _current;

  /// Finds and connects to a nearby mat. `async` + `await` let us write the
  /// step-by-step sequence as if it were synchronous; each `await` pauses until
  /// that asynchronous step finishes.
  @override
  Future<void> connect(String deviceId) async {
    try {
      // 1. Make sure the phone's Bluetooth radio is on (Android can prompt to
      //    enable it; this is a no-op on iOS).
      if (await FlutterBluePlus.adapterState.first != BluetoothAdapterState.on) {
        await FlutterBluePlus.turnOn();
      }

      // 2. SCAN. Devices that are advertising appear in `scanResults`. We listen
      //    and grab the first hit. `found ??= x` assigns only if `found` is
      //    still null, so we keep the first match and ignore later ones.
      ScanResult? found;
      final sub = FlutterBluePlus.scanResults.listen((results) {
        found ??= results.firstOrNull;
      });

      // Only surface devices advertising the "IncreMat" name; stop after 15s.
      await FlutterBluePlus.startScan(
        withNames: [BleConstants.deviceNamePrefix],
        timeout: const Duration(seconds: BleConstants.scanTimeoutSeconds),
      );
      // Wait until scanning flips back to false (i.e. the scan finished), then
      // stop listening to scan results.
      await FlutterBluePlus.isScanning.where((s) => !s).first;
      sub.cancel();

      if (found == null) throw Exception('No IncreMat device found nearby');

      // 3. CONNECT to the device we found (fails after 10s if it won't respond).
      _device = found!.device;
      await _device!.connect(
        timeout: const Duration(seconds: BleConstants.connectionTimeoutSeconds),
      );

      // 4. Watch the link so we know if the mat drops out, then discover its
      //    GATT table and subscribe to the data characteristics (next method).
      _connectionSub = _device!.connectionState.listen(_onConnectionState);
      await _discoverAndSubscribe();

      // 5. BLE doesn't push signal strength, so poll it ourselves every 5s.
      _rssiTimer = Timer.periodic(const Duration(seconds: 5), (_) => _updateRssi());
    } catch (e) {
      // Any failure above → report disconnected, then `rethrow` so the caller
      // (the UI) can show an error message.
      _current = HardwareStatus.disconnected;
      _statusController.add(_current);
      rethrow;
    }
  }

  // Called by the connectionState subscription whenever the link changes. If the
  // mat disconnects (walked out of range, powered off), tear down and tell the UI.
  void _onConnectionState(BluetoothConnectionState state) {
    if (state == BluetoothConnectionState.disconnected) {
      _rssiTimer?.cancel();
      _current = HardwareStatus.disconnected;
      _statusController.add(_current);
    }
  }

  /// GATT discovery: ask the connected device for its services/characteristics,
  /// find OUR service by UUID, then wire up each characteristic we recognise.
  /// `setNotifyValue(true)` tells the mat "push me new values for this one";
  /// `onValueReceived.listen(...)` then handles each pushed packet of bytes.
  Future<void> _discoverAndSubscribe() async {
    if (_device == null) return;
    final services = await _device!.discoverServices();
    for (final service in services) {
      // Match our custom service UUID (case-insensitive — vendors vary on case).
      if (service.uuid.toString().toLowerCase() ==
          BleConstants.serviceUuid.toLowerCase()) {
        for (final char in service.characteristics) {
          final uuid = char.uuid.toString().toLowerCase();
          // Route each characteristic to its handler by matching its UUID
          // against the constants. Reps/speed/battery/mat/NFC = notify (read);
          // music = the one we keep a handle to so we can WRITE to it later.
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

  // BLE delivers raw BYTES (List<int>), so each handler must decode them per the
  // firmware's agreed format (documented in ble_constants.dart).
  //
  // Rep count: 2 bytes, little-endian uint16. "Little-endian" = the low byte
  // comes first. To rebuild the number we keep data[0] as-is and shift data[1]
  // left by 8 bits (×256), then OR them together:  count = low | (high << 8).
  // e.g. bytes [44, 1] → 44 | (1<<8) → 44 | 256 → 300 reps.
  void _onRepCountData(List<int> data) {
    if (data.length < 2) return; // ignore malformed/short packets
    final count = data[0] | (data[1] << 8);
    _repController.add(count); // push onto repCountStream
  }

  // Avg rep time: 4 bytes, little-endian float32. Bit-twiddling won't decode a
  // float, so we wrap the 4 bytes in a ByteData view and ask for a Float32.
  void _onRepSpeedData(List<int> data) {
    if (data.length < 4) return;
    final bytes = ByteData.sublistView(Uint8List.fromList(data.sublist(0, 4)));
    final avgTime = bytes.getFloat32(0, Endian.little);
    // Sanity gate: a rep between 0 and 60s is plausible; reject garbage values.
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

  // NFC_SCAN char — the mat's own NFC reader sends the tapped card's UID as
  // text bytes. String.fromCharCodes turns the byte list back into a string;
  // we normalise (trim whitespace, lowercase) and emit it for the app to look up.
  void _onNfcScanData(List<int> data) {
    if (data.isEmpty) return;
    final uid = String.fromCharCodes(data).trim().toLowerCase();
    if (uid.isNotEmpty) _nfcController.add(uid);
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

  // Reads the live signal strength on demand (called by the 5s timer) and folds
  // it into a fresh status. Wrapped in try/empty-catch because a read can fail
  // transiently and we don't want that to crash the timer.
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

  // Cleanly drop the connection: cancel every timer/subscription, null them out,
  // disconnect the radio, and emit a disconnected status. (Cancelling matters —
  // leftover subscriptions keep firing and leak memory/battery.)
  @override
  Future<void> disconnect() async {
    _rssiTimer?.cancel();
    _connectionSub?.cancel();
    _batterySub?.cancel();
    _matPlacedSub?.cancel();
    _repCountSub?.cancel();
    _repSpeedSub?.cancel();
    _nfcScanSub?.cancel();
    _connectionSub = null;
    _batterySub = null;
    _matPlacedSub = null;
    _repCountSub = null;
    _repSpeedSub = null;
    _nfcScanSub = null;
    await _device?.disconnect();
    _musicChar = null;
    _current = HardwareStatus.disconnected;
    _statusController.add(_current);
  }

  // The only WRITE path: send a track name to the mat so it can sync music.
  // `.codeUnits` turns the string into bytes; `withoutResponse: true` is a
  // fire-and-forget write (faster, no acknowledgement) suited to non-critical data.
  @override
  Future<void> sendMusicTrack(String trackName) async {
    if (_musicChar == null) return;
    await _musicChar!.write(trackName.codeUnits, withoutResponse: true);
  }

  // Final teardown when the service itself is thrown away: cancel subscriptions
  // AND close the StreamControllers (a closed stream can never be reopened).
  @override
  void dispose() {
    _rssiTimer?.cancel();
    _connectionSub?.cancel();
    _batterySub?.cancel();
    _matPlacedSub?.cancel();
    _repCountSub?.cancel();
    _repSpeedSub?.cancel();
    _nfcScanSub?.cancel();
    _statusController.close();
    _repController.close();
    _speedController.close();
    _nfcController.close();
    _device?.disconnect();
  }
}
