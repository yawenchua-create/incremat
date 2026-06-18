import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/session_log.dart';

/// Data-access layer ("repository") for ONE senior's exercise sessions.
///
/// The repository pattern hides all Firestore details behind plain methods like
/// add()/watchRecent(), so the rest of the app never writes database code — it
/// just calls these. Each instance is scoped to a single senior, passed into the
/// constructor (`this._seniorId` is shorthand for "store the argument in the
/// field"). Sessions live at `seniors/{id}/sessions/{autoId}` — a SUBCOLLECTION
/// under that senior's document.
class SessionRepository {
  SessionRepository(this._seniorId);

  final String _seniorId;

  // The sessions subcollection for this senior (computed each time it's used).
  CollectionReference<Map<String, dynamic>> get _col =>
      FirebaseFirestore.instance.collection('seniors/$_seniorId/sessions');

  // Single doc mirroring the in-progress session so the play app can show
  // live reps in real time: seniors/{id}/live/current
  DocumentReference<Map<String, dynamic>> get _liveDoc =>
      FirebaseFirestore.instance.doc('seniors/$_seniorId/live/current');

  /// Publishes the current in-progress rep count for live display. This single
  /// doc is overwritten on every rep so the Play app (which watches it) can show
  /// the caregiver's count in near-real-time. It's a MIRROR, not the permanent
  /// record — the real session is written once by add() when it finishes.
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

  /// Marks the live session inactive (session ended / flushed). `SetOptions(
  /// merge: true)` updates only these two fields and leaves the rest of the doc
  /// intact, instead of replacing the whole document.
  Future<void> clearLive() async {
    await _liveDoc.set({
      'active': false,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
    }, SetOptions(merge: true));
  }

  /// Permanently records ONE completed session. `_col.doc()` (no id) makes
  /// Firestore mint a new random document id; we build a SessionLog, convert it
  /// with `.toMap()`, and `.set(...)` writes it. This is what the session-save
  /// fix awaits before switching users so reps are never lost.
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

  /// LIVE list of the most recent sessions. The key word is `.snapshots()`:
  /// unlike `.get()` (a one-time read), it returns a Stream that re-emits every
  /// time the data changes in Firestore — so the UI auto-updates. We `.map` each
  /// snapshot's raw docs into typed SessionLog objects. (Returns newest first,
  /// capped at `limit`.)
  Stream<List<SessionLog>> watchRecent({int limit = 10}) {
    return _col
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) =>
            snap.docs.map((d) => SessionLog.fromMap(d.data(), d.id)).toList());
  }

  /// One-shot fetch of sessions whose timestamp falls within [start, end].
  /// Two `.where(...)` clauses chained = an AND query (>= start AND <= end).
  /// `.get()` here (not `.snapshots()`) because reports want a fixed snapshot,
  /// not a live feed.
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
