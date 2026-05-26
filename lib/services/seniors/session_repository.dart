import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/session_log.dart';

class SessionRepository {
  SessionRepository(this._uid, this._seniorId);

  final String _uid;
  final String _seniorId;

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance
          .collection('users/$_uid/seniors/$_seniorId/sessions');

  Future<void> add({
    required int repCount,
    required double avgRepTimeSeconds,
  }) async {
    final doc = _col.doc();
    await doc.set(SessionLog(
      id: doc.id,
      seniorId: _seniorId,
      timestamp: DateTime.now(),
      repCount: repCount,
      avgRepTimeSeconds: avgRepTimeSeconds,
      synced: false,
    ).toMap());
  }

  Stream<List<SessionLog>> watchRecent({int limit = 10}) {
    return _col
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => SessionLog.fromMap(d.data(), d.id))
            .toList());
  }

  // Returns all sessions at or after [since], ordered newest-first.
  // timestamp is stored as millisecondsSinceEpoch (int), not Firestore Timestamp.
  Stream<List<SessionLog>> watchSince(DateTime since) {
    return _col
        .orderBy('timestamp', descending: true)
        .where('timestamp', isGreaterThanOrEqualTo: since.millisecondsSinceEpoch)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => SessionLog.fromMap(d.data(), d.id))
            .toList());
  }
}
