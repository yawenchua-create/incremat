/// An immutable snapshot of the mat's connection state at one moment.
/// Re-created (never mutated) every time any value changes, then pushed down
/// [HardwareService.statusStream] so the UI rebuilds.
class HardwareStatus {
  final bool isConnected;
  // -1 is a sentinel meaning "battery unknown" — we haven't received a real
  // reading yet (or the firmware doesn't report it). This is deliberately
  // different from a genuine 0%, so the UI can show "—" instead of a misleading
  // "0%". Use [hasBattery] to tell them apart.
  final int batteryPercent;
  final int rssi;          // Received Signal Strength Indicator, in dBm.
                           // It's NEGATIVE: closer to 0 = stronger (−40 great,
                           // −90 barely there).
  final bool isMatOnChair;
  final String signalLabel; // human label derived from rssi (see below)

  // The part after `:` is an INITIALIZER LIST — it runs before the constructor
  // body to set a final field from other inputs. Here it converts the raw rssi
  // number into a "Strong"/"Good"/"Weak" label using a nested ternary
  // (condition ? a : b) so the UI doesn't have to know the dBm thresholds.
  const HardwareStatus({
    required this.isConnected,
    required this.batteryPercent,
    required this.rssi,
    required this.isMatOnChair,
  }) : signalLabel = rssi >= -70
            ? 'Strong'
            : rssi >= -85
                ? 'Good'
                : 'Weak';

  /// True once a real battery reading (0–100) has arrived, so the UI knows
  /// whether to show a percentage or "—".
  bool get hasBattery => batteryPercent >= 0;

  static const HardwareStatus disconnected = HardwareStatus(
    isConnected: false,
    batteryPercent: -1, // unknown until a reading arrives
    rssi: -100,
    isMatOnChair: false,
  );
}

/// One training session the mat tallied while no app was connected, buffered in
/// its flash until sync. [uidHex] is the tapped card's UID in the same
/// lowercase-hex form the phone-side scanner produces, so it can be looked up
/// against the `nfc_uids` collection.
class NfcOfflineSession {
  final String uidHex;
  final int reps;
  final int durationMs;

  const NfcOfflineSession({
    required this.uidHex,
    required this.reps,
    required this.durationMs,
  });
}

/// The CONTRACT for "something that talks to the mat", with no implementation.
///
/// `abstract` means you can't create a HardwareService directly — you create a
/// class that `implements` it. We have three such classes:
///   • [BleHardwareService]      — the real one (actual Bluetooth)
///   • SimulatorHardwareService  — a fake driven from the Developer screen
///   • MockHardwareService       — canned demo data
/// The rest of the app only ever depends on this interface, so it never knows
/// or cares which one is plugged in (this is "dependency inversion" — it makes
/// the app testable and lets us swap in the simulator). A `Stream` is a pipe of
/// values over time that the UI can `listen` to and rebuild on each new value.
abstract class HardwareService {
  Stream<HardwareStatus> get statusStream;
  // Emits cumulative rep count for the current session each time a rep is detected.
  Stream<int> get repCountStream;
  // Emits avg rep time (seconds) updated after each rep.
  Stream<double> get avgRepTimeStream;
  // Emits the lowercase-hex UID each time a card is tapped on the mat (online).
  Stream<String> get nfcUidStream;
  // Emits each buffered offline session as the mat dumps them after a sync request.
  Stream<NfcOfflineSession> get offlineSessionStream;
  HardwareStatus get currentStatus;       // the latest value, read synchronously
  Future<void> connect(String deviceId);  // async: returns a Future you await
  Future<void> disconnect();
  Future<void> sendMusicTrack(String trackName);

  // ── NFC roster + offline sync ──────────────────────────────────────────────
  /// Caches a registered user's card UID on the mat so it can attribute reps
  /// offline. [uidHex] is lowercase hex (the `nfc_uids` doc id).
  Future<void> pushKnownUid(String uidHex);

  /// Wipes the mat's cached roster (sent before re-pushing the full set).
  Future<void> clearRoster();

  /// Asks the mat to stream every buffered offline session over [offlineSessionStream].
  Future<void> requestOfflineDump();

  /// Tells the mat the dumped sessions were stored, so it clears its buffer.
  Future<void> ackOfflineSync();

  void dispose();                          // release resources / close streams
}
