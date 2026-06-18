/// Bluetooth Low Energy (BLE) addressing constants for talking to the mat.
///
/// BLE devices expose data through a GATT table: one **service** (a logical
/// group) that contains several **characteristics** (individual values you can
/// read, write, or subscribe to). Every service and characteristic is named by
/// a 128-bit **UUID**. The phone and the ESP32 firmware must agree on the exact
/// same UUIDs — that's the whole point of this file: it's the shared contract.
///
/// "notify" below means the characteristic *pushes* a new value to the phone
/// whenever it changes (event-driven), so we never have to poll the mat.
class BleConstants {
  // Custom UUIDs — program these exact values into your ESP32 S3 firmware.
  // (The first 7 bytes are shared; only the last byte changes per value.)
  static const String serviceUuid       = '4fafc201-1fb5-459e-8fcc-c5c9c3319100';
  static const String repCountCharUuid  = '4fafc201-1fb5-459e-8fcc-c5c9c3319101';
  static const String repSpeedCharUuid  = '4fafc201-1fb5-459e-8fcc-c5c9c3319102';
  static const String batteryCharUuid   = '4fafc201-1fb5-459e-8fcc-c5c9c3319103';
  static const String matPlacedCharUuid = '4fafc201-1fb5-459e-8fcc-c5c9c3319104';
  static const String musicTrackCharUuid= '4fafc201-1fb5-459e-8fcc-c5c9c3319105';
  // NFC_SCAN char → notify, UTF-8 lowercase hex UID string sent on each card tap.
  static const String nfcScanCharUuid   = '4fafc201-1fb5-459e-8fcc-c5c9c3319107';

  // ESP32 firmware protocol
  // repCount char  → notify, 2 bytes little-endian uint16 = cumulative reps this session
  // repSpeed char  → notify, 4 bytes little-endian float32 = avg rep time in seconds
  // battery char   → notify, 1 byte uint8 = battery %
  // matPlaced char → notify, 1 byte: 1 = on chair, 0 = removed
  // musicTrack char→ write (no response), UTF-8 track name string

  // When scanning, we treat any advertised device whose name starts with this
  // prefix as one of our mats.
  static const String deviceNamePrefix = 'IncreMat';
  // Give up scanning after 15s if no mat is found, and fail a connection attempt
  // after 10s — so the UI can show an error instead of hanging forever.
  static const int scanTimeoutSeconds = 15;
  static const int connectionTimeoutSeconds = 10;
}
