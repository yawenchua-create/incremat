import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/session_log.dart';

class SessionRepository {
  SessionRepository(this._seniorId);

  final String _seniorId;

  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('seniors/$_seniorId/sessions');

  // Single doc mirroring the in-progress session so the play app can show
  // live reps in real time: seniors/{id}/live/current
  DocumentReference<Map<String, dynamic>> get _liveDoc =>
      FirebaseFirestore.instance.doc('seniors/$_seniorId/live/current');

  /// Publishes the current in-progress rep count for live display.
  Future<void> updateLive({
    required int repCount,
    required double avgRepTimeSeconds,
    required DateTime startedAt,
  }) async {
    await _liveDoc.set({
      'active': true,
      'repCount': repCount,
      'avgRepTimeSeconds': avgRepTimeSeconds,
      'startedAt': startedAt.millisecondsSinceEpoch,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Marks the live session inactive (session ended / flushed).
  Future<void> clearLive() async {
    await _liveDoc.set({
      'active': false,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    }, SetOptions(merge: true));
  }

  Future<void> add({
    required int repCount,
    required double avgRepTimeSeconds,
    double firstFiveRepsSeconds = 0.0,
    String source = 'mat',
    String? recordedBy,
  }) async {
    final doc = _col.doc();
    await doc.set(SessionLog(
      id: doc.id,
      seniorId: _seniorId,
      timestamp: DateTime.now(),
      repCount: repCount,
      avgRepTimeSeconds: avgRepTimeSeconds,
      firstFiveRepsSeconds: firstFiveRepsSeconds,
      source: source,
      recordedBy: recordedBy,
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

  /// One-shot fetch of sessions whose timestamp falls within [start, end].
  Future<List<SessionLog>> getInRange(DateTime start, DateTime end) async {
    final snap = await _col
        .where('timestamp',
            isGreaterThanOrEqualTo: start.millisecondsSinceEpoch)
        .where('timestamp', isLessThanOrEqualTo: end.millisecondsSinceEpoch)
        .get();
    return snap.docs
        .map((d) => SessionLog.fromMap(d.data(), d.id))
        .toList();
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
