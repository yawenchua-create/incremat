import 'package:cloud_firestore/cloud_firestore.dart';

/// Maps NFC card UIDs to senior accounts.
/// Documents live at /nfc_uids/{uid_hex}.
class NfcUidService {
  final _db = FirebaseFirestore.instance;
  CollectionReference<Map<String, dynamic>> get _col =>
      _db.collection('nfc_uids');

  /// Saves (or overwrites) the UID → senior mapping.
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
  Future<String?> lookup(String uid) async {
    final doc = await _col.doc(uid).get();
    if (!doc.exists) return null;
    return doc.data()?['seniorId'] as String?;
  }

  /// Removes the mapping for a specific UID (e.g. when replacing a card).
  Future<void> removeByUid(String uid) => _col.doc(uid).delete();

  /// Removes all UIDs enrolled for a senior (used when deleting a senior).
  Future<void> removeBySenior(String seniorId) async {
    final snap = await _col
        .where('seniorId', isEqualTo: seniorId)
        .get();
    for (final doc in snap.docs) {
      await doc.reference.delete();
    }
  }
}
