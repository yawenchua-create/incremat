import 'dart:async';
import 'hardware_service.dart';

/// A fake mat for testing the app without doing real reps on the hardware.
///
/// It implements the same [HardwareService] interface the rest of the app
/// consumes, so live sessions, session music, insights and alerts all react
/// exactly as they would to a real mat — driven instead by the debug screen.
class SimulatorHardwareService implements HardwareService {
  final _statusController = StreamController<HardwareStatus>.broadcast();
  final _repController = StreamController<int>.broadcast();
  final _speedController = StreamController<double>.broadcast();
  final _nfcController = StreamController<String>.broadcast();
  final _offlineController = StreamController<NfcOfflineSession>.broadcast();

  // Backing state for the synthesised status. Starts disconnected so enabling
  // simulator mode never fakes a live mat — flip "Connected" in the debug
  // screen to simulate one. _battery/_rssi are the values reported *once
  // connected*; while disconnected the status reads as no-data, like real BLE.
  bool _connected = false;
  bool _matPlaced = false;
  int _battery = 85;
  final int _rssi = -62;

  // The mat's cumulative rep counter (what real firmware reports).
  int _reps = 0;
  Timer? _autoTimer;
  Timer? _initTimer;

  SimulatorHardwareService() {
    // Emit an initial "connected" status shortly after creation, like the mat.
    // Held in a cancellable timer so disposal never leaves it pending.
    _initTimer = Timer(const Duration(milliseconds: 200), _emitStatus);
  }

  // Synthesises a status from the backing fields — the simulator's equivalent of
  // the real service folding together battery/rssi/mat bytes. When not
  // "connected" it returns the same all-zero disconnected status real BLE would.
  HardwareStatus _build() => _connected
      ? HardwareStatus(
          isConnected: true,
          batteryPercent: _battery,
          rssi: _rssi,
          isMatOnChair: _matPlaced,
        )
      : HardwareStatus.disconnected;

  void _emitStatus() {
    if (!_statusController.isClosed) _statusController.add(_build());
  }

  void _emitReps() {
    if (!_repController.isClosed) _repController.add(_reps);
  }

  // ── Interface ───────────────────────────────────────────────────────────────
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
  HardwareStatus get currentStatus => _build();

  @override
  Future<void> connect(String deviceId) async {
    // Simulating a connection presents a ready mat sitting on the chair.
    _matPlaced = true;
    setConnected(true);
  }

  @override
  Future<void> disconnect() async => setConnected(false);
  @override
  Future<void> sendMusicTrack(String trackName) async {}

  // ── NFC roster + offline sync ────────────────────────────────────────────────
  // The simulator has no firmware buffer, so roster pushes are no-ops and an
  // offline dump emits whatever was queued via [emitOfflineSession] (if any).
  @override
  Future<void> pushKnownUid(String uidHex) async {}
  @override
  Future<void> clearRoster() async {}
  @override
  Future<void> requestOfflineDump() async {}
  @override
  Future<void> ackOfflineSync() async {}

  @override
  void dispose() {
    _autoTimer?.cancel();
    _initTimer?.cancel();
    _statusController.close();
    _repController.close();
    _speedController.close();
    _nfcController.close();
    _offlineController.close();
  }

  // ── Debug controls ──────────────────────────────────────────────────────────
  // These extra methods/getters DON'T exist on HardwareService — they're only
  // for the Developer screen, which holds a SimulatorHardwareService directly and
  // calls them to fake reps, taps, battery, etc. The rest of the app, talking
  // only to the interface, never sees them.

  int get reps => _reps;
  bool get isConnected => _connected;
  bool get isMatPlaced => _matPlaced;
  int get battery => _battery;
  bool get isAutoRunning => _autoTimer != null;

  /// Adds [n] reps to the cumulative counter and emits the new total.
  void addReps([int n = 1]) {
    _reps += n;
    _emitReps();
  }

  /// Resets the mat's counter to zero (like a real disconnect/reset).
  void resetReps() {
    _reps = 0;
    _emitReps();
  }

  /// Emits an average rep time (seconds) — feeds session speed stats.
  void emitAvgRepTime(double seconds) {
    if (!_speedController.isClosed) _speedController.add(seconds);
  }

  /// Emits an NFC card tap (lowercase-hex UID) as if scanned on the mat.
  void tapNfc(String uid) {
    if (uid.trim().isNotEmpty && !_nfcController.isClosed) {
      _nfcController.add(uid.trim().toLowerCase());
    }
  }

  /// Emits a buffered offline session as if the mat dumped it during a sync.
  void emitOfflineSession(NfcOfflineSession session) {
    if (!_offlineController.isClosed) _offlineController.add(session);
  }

  void setConnected(bool value) {
    _connected = value;
    _emitStatus();
  }

  void setMatPlaced(bool value) {
    _matPlaced = value;
    _emitStatus();
  }

  void setBattery(int percent) {
    _battery = percent.clamp(0, 100);
    _emitStatus();
  }

  /// Starts auto-adding 1 rep every [interval] (a hands-free workout).
  void startAuto(Duration interval) {
    _autoTimer?.cancel();
    _autoTimer = Timer.periodic(interval, (_) => addReps(1));
  }

  void stopAuto() {
    _autoTimer?.cancel();
    _autoTimer = null;
  }
}
