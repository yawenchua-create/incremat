class HardwareStatus {
  final bool isConnected;
  final int batteryPercent;
  final int rssi;
  final bool isMatOnChair;
  final String signalLabel;

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

  static const HardwareStatus disconnected = HardwareStatus(
    isConnected: false,
    batteryPercent: 0,
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
  HardwareStatus get currentStatus;
  Future<void> connect(String deviceId);
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

  void dispose();
}
