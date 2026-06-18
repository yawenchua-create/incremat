import 'package:shared_preferences/shared_preferences.dart';
import '../../models/sync_status.dart';

/// Tracks "last synced / pending" status for the sync indicator.
///
/// NOTE: real data sync to the cloud is handled automatically by Firestore's
/// offline persistence (writes queue locally and replay when online). This
/// service only persists/loads the small status numbers shown in the UI, using
/// `SharedPreferences` — a tiny key/value store for simple settings that
/// survives app restarts (the phone equivalent of localStorage).
class SyncService {
  // String keys under which the two values are stored on disk.
  static const _lastSyncKey = 'last_sync_timestamp';
  static const _pendingKey = 'pending_sessions_count';

  /// Reads the saved status back on app start. `?? ...` supplies a default when
  /// nothing has been stored yet.
  Future<SyncStatus> loadStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_lastSyncKey);
    final pending = prefs.getInt(_pendingKey) ?? MockSyncStatus.initial.pendingSessions;
    return SyncStatus(
      lastSyncedAt: ts != null ? DateTime.fromMillisecondsSinceEpoch(ts) : null,
      pendingSessions: pending,
    );
  }

  /// Marks everything synced "now" and clears the pending count.
  Future<SyncStatus> sync() async {
    // The 2-second delay just simulates network work so the spinner is visible.
    await Future.delayed(const Duration(seconds: 2));
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setInt(_lastSyncKey, now.millisecondsSinceEpoch);
    await prefs.setInt(_pendingKey, 0);
    return SyncStatus(lastSyncedAt: now, pendingSessions: 0);
  }
}
