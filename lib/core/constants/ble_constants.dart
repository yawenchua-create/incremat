class BleConstants {
  // Custom UUIDs — program these exact values into your ESP32 S3 firmware.
  static const String serviceUuid       = '4fafc201-1fb5-459e-8fcc-c5c9c3319100';
  static const String repCountCharUuid  = '4fafc201-1fb5-459e-8fcc-c5c9c3319101';
  static const String repSpeedCharUuid  = '4fafc201-1fb5-459e-8fcc-c5c9c3319102';
  static const String batteryCharUuid   = '4fafc201-1fb5-459e-8fcc-c5c9c3319103';
  static const String matPlacedCharUuid = '4fafc201-1fb5-459e-8fcc-c5c9c3319104';
  static const String musicTrackCharUuid= '4fafc201-1fb5-459e-8fcc-c5c9c3319105';

  // ESP32 firmware protocol
  // repCount char  → notify, 2 bytes little-endian uint16 = cumulative reps this session
  // repSpeed char  → notify, 4 bytes little-endian float32 = avg rep time in seconds
  // battery char   → notify, 1 byte uint8 = battery %
  // matPlaced char → notify, 1 byte: 1 = on chair, 0 = removed
  // musicTrack char→ write (no response), UTF-8 track name string

  static const String deviceNamePrefix = 'IncreMat';
  static const int scanTimeoutSeconds = 15;
  static const int connectionTimeoutSeconds = 10;
}
