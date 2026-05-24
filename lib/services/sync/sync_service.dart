import 'package:shared_preferences/shared_preferences.dart';
import '../../models/sync_status.dart';

class SyncService {
  static const _lastSyncKey = 'last_sync_timestamp';
  static const _pendingKey = 'pending_sessions_count';

  Future<SyncStatus> loadStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final ts = prefs.getInt(_lastSyncKey);
    final pending = prefs.getInt(_pendingKey) ?? MockSyncStatus.initial.pendingSessions;
    return SyncStatus(
      lastSyncedAt: ts != null ? DateTime.fromMillisecondsSinceEpoch(ts) : null,
      pendingSessions: pending,
    );
  }

  Future<SyncStatus> sync() async {
    // Simulate a network sync
    await Future.delayed(const Duration(seconds: 2));
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setInt(_lastSyncKey, now.millisecondsSinceEpoch);
    await prefs.setInt(_pendingKey, 0);
    return SyncStatus(lastSyncedAt: now, pendingSessions: 0);
  }
}
