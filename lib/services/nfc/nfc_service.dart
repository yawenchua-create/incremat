import 'dart:typed_data';

import 'package:nfc_manager/nfc_manager.dart';
import 'package:nfc_manager/platform_tags.dart';

/// Shared NFC helpers for reading the UID of any presented tag/card.
///
/// Works with any card that has an NFC chip — MIFARE Classic, NTAG,
/// EZ-Link (CEPAS/ISO-B), contactless bank cards, building-access fobs, etc.
/// The UID is the card's permanent hardware identifier; no data is written.
class NfcService {
  // Not every phone has NFC hardware / it can be switched off, so always check
  // this before starting a scan.
  static Future<bool> isAvailable() => NfcManager.instance.isAvailable();

  // ── UID helpers ───────────────────────────────────────────────────────────

  /// Converts a raw UID byte-array to a lowercase hex string.
  /// For each byte: `toRadixString(16)` formats it as hex, `padLeft(2,'0')`
  /// keeps it two digits (so 0x0A stays "0a"), and `.join('')` concatenates
  /// them, e.g. [4, 171, 16] → "04ab10". This string is the card's unique id.
  static String bytesToHex(Uint8List bytes) =>
      bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join('');

  /// Extracts the UID from a tag by trying each RF technology in turn.
  ///
  /// NFC isn't one protocol — different cards speak different radio standards
  /// (NfcA = most MIFARE/NTAG, NfcB/IsoDep = bank & ID cards, NfcF = FeliCa,
  /// NfcV = vicinity tags). We try each "technology view" until one matches and
  /// gives us its identifier bytes. Returns null only if NONE recognise the tag.
  static String? extractUid(NfcTag tag) {
    final nfcA = NfcA.from(tag);
    if (nfcA != null) return bytesToHex(nfcA.identifier);

    final nfcB = NfcB.from(tag);
    if (nfcB != null) return bytesToHex(nfcB.identifier);

    final isoDep = IsoDep.from(tag);
    if (isoDep != null) return bytesToHex(isoDep.identifier);

    final nfcF = NfcF.from(tag);
    if (nfcF != null) return bytesToHex(nfcF.identifier);

    final nfcV = NfcV.from(tag);
    if (nfcV != null) return bytesToHex(nfcV.identifier);

    return null;
  }

  // ── Session helpers ───────────────────────────────────────────────────────

  /// Starts an NFC session that reads the UID of the first tag presented.
  /// Calls [onRead] with the hex UID string, or [onError] on failure.
  // Takes two CALLBACKS (functions passed as arguments): onRead fires with the
  // UID on success, onError with a message on failure. `startSession` powers up
  // the NFC radio and calls `onDiscovered` the moment a tag enters the field.
  static Future<void> readUid({
    required void Function(String uid) onRead,
    required void Function(String) onError,
  }) async {
    await NfcManager.instance.startSession(
      onDiscovered: (tag) async {
        final uid = extractUid(tag);
        if (uid == null || uid.isEmpty) {
          await NfcManager.instance
              .stopSession(errorMessage: 'Unrecognised card.');
          onError('Could not read this card. Try a different one.');
          return;
        }
        await NfcManager.instance.stopSession();
        onRead(uid);
      },
    );
  }

  static Future<void> stopSession() => NfcManager.instance.stopSession();
}
