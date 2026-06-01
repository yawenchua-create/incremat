import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/session_log.dart';

class SessionRepository {
  SessionRepository(this._seniorId);

  final String _seniorId;

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('seniors/$_seniorId/sessions');

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
        .map((snap) =>
            snap.docs.map((d) => SessionLog.fromMap(d.data(), d.id)).toList());
  }

  Stream<List<SessionLog>> watchSince(DateTime since) {
    return _col
        .orderBy('timestamp', descending: true)
        .where('timestamp',
            isGreaterThanOrEqualTo: since.millisecondsSinceEpoch)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => SessionLog.fromMap(d.data(), d.id)).toList());
  }
}
