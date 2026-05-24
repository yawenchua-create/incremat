class BleConstants {
  // Placeholder service UUID — replace with actual hardware spec
  static const String serviceUuid = 'INCREMAT-SERVICE-UUID-PLACEHOLDER-0001';

  // Placeholder characteristic UUIDs
  static const String repCountCharUuid = 'INCREMAT-CHAR-UUID-REP-COUNT-00001';
  static const String repSpeedCharUuid = 'INCREMAT-CHAR-UUID-REP-SPEED-00001';
  static const String batteryCharUuid = 'INCREMAT-CHAR-UUID-BATTERY-000001';
  static const String matPlacedCharUuid = 'INCREMAT-CHAR-UUID-MAT-PLACED-0001';
  static const String musicTrackCharUuid = 'INCREMAT-CHAR-UUID-MUSIC-TRACK-001';

  static const String deviceNamePrefix = 'IncreMat';
  static const int scanTimeoutSeconds = 15;
  static const int connectionTimeoutSeconds = 10;
}
