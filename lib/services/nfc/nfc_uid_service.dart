import 'package:cloud_firestore/cloud_firestore.dart';

/// Maps NFC card UIDs to senior accounts, stored in Cloud Firestore.
/// Documents live at /nfc_uids/{uid_hex}.
///
/// Firestore is a cloud NoSQL database of "collections" (folders) containing
/// "documents" (JSON-like records). Here the collection is `nfc_uids` and each
/// document's id is a card's UID, so looking up "who owns this card" is a single
/// direct read. The phone's NFC reader (nfc_service) gives us the UID string;
/// THIS service turns that UID into a seniorId. Keeping them separate means the
/// raw card scanning has no idea about seniors, and vice-versa.
class NfcUidService {
  // `FirebaseFirestore.instance` is the app-wide handle to the database.
  final _db = FirebaseFirestore.instance;
  // A getter returning the typed `nfc_uids` collection reference (reused below).
  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('nfc_uids');

  /// Saves (or overwrites) the UID → senior mapping. `.doc(uid).set({...})`
  /// creates/replaces the document keyed by the card UID. serverTimestamp()
  /// asks Firestore to stamp the time on its end (trustworthy, clock-independent).
  Future<void> enroll({
    required String uid,
    required String seniorId,
    required String caregiverId,
  }) async {
    await _col.doc(uid).set({
      'seniorId': seniorId,
      'caregiverId': caregiverId,
      'enrolledAt': FieldValue.serverTimestamp(),
    });
  }

  /// Returns the seniorId linked to this UID, or null if not enrolled.
  /// `.get()` reads the single document; `doc.exists` is false for an unknown
  /// card, in which case we return null and the caller shows "card not recognised".
  Future<String?> lookup(String uid) async {
    final doc = await _col.doc(uid).get();
    if (!doc.exists) return null;
    return doc.data()?['seniorId'] as String?;
  }

  /// Streams the UIDs (hex doc ids) this caregiver has enrolled, so the mat's
  /// offline roster can be kept in sync as cards are added/removed.
  Stream<List<String>> watchUidsForCaregiver(String caregiverId) {
    return _col
        .where('caregiverId', isEqualTo: caregiverId)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.id).toList());
  }

  /// Removes the mapping for a specific UID (e.g. when replacing a card).
  Future<void> removeByUid(String uid) => _col.doc(uid).delete();

  /// Removes all UIDs enrolled for a senior (used when deleting a senior).
  /// `.where(...)` runs a query — Firestore returns a "snapshot" of all matching
  /// documents (`snap.docs`); we loop and delete each so no orphan card mappings
  /// remain pointing at a senior who no longer exists.
  Future<void> removeBySenior(String seniorId) async {
    final snap = await _col
        .where('seniorId', isEqualTo: seniorId)
        .get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }
}
