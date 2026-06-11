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

abstract class HardwareService {
  Stream<HardwareStatus> get statusStream;
  // Emits cumulative rep count for the current session each time a rep is detected.
  Stream<int> get repCountStream;
  // Emits avg rep time (seconds) updated after each rep.
  Stream<double> get avgRepTimeStream;
  // Emits lowercase-hex UID strings whenever the mat's NFC reader scans a card.
  Stream<String> get nfcUidStream;
  HardwareStatus get currentStatus;
  Future<void> connect(String deviceId);
  Future<void> disconnect();
  Future<void> sendMusicTrack(String trackName);
  void dispose();
}
