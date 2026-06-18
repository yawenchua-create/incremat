/// An immutable snapshot of the mat's connection state at one moment.
/// Re-created (never mutated) every time any value changes, then pushed down
/// [HardwareService.statusStream] so the UI rebuilds.
class HardwareStatus {
  final bool isConnected;
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

  static const HardwareStatus disconnected = HardwareStatus(
    isConnected: false,
    batteryPercent: 0,
    rssi: -100,
    isMatOnChair: false,
  );
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
  // Emits lowercase-hex UID strings whenever the mat's NFC reader scans a card.
  Stream<String> get nfcUidStream;
  HardwareStatus get currentStatus;       // the latest value, read synchronously
  Future<void> connect(String deviceId);  // async: returns a Future you await
  Future<void> disconnect();
  Future<void> sendMusicTrack(String trackName);
  void dispose();                          // release resources / close streams
}
