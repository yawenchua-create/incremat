/// A small immutable snapshot of the data-sync state, shown in the UI (e.g. a
/// "Last synced 5m ago • 3 pending" banner). Produced by the sync provider.
class SyncStatus {
  final DateTime? lastSyncedAt;  // null = has never synced
  final int pendingSessions;     // writes still waiting to reach the server
  final bool isSyncing;          // a sync is in progress right now

  const SyncStatus({
    this.lastSyncedAt,
    this.pendingSessions = 0,
    this.isSyncing = false,
  });

  SyncStatus copyWith({
    DateTime? lastSyncedAt,
    int? pendingSessions,
    bool? isSyncing,
  }) =>
      SyncStatus(
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
        pendingSessions: pendingSessions ?? this.pendingSessions,
        isSyncing: isSyncing ?? this.isSyncing,
      );

  // Turns the raw timestamp into a friendly relative label like "Just now",
  // "5m ago", "3h ago", "2d ago" by bucketing the elapsed Duration.
  String get lastSyncedLabel {
    if (lastSyncedAt == null) return 'Never synced';
    final diff = DateTime.now().difference(lastSyncedAt!);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class MockSyncStatus {
  static SyncStatus get initial => SyncStatus(
        lastSyncedAt: DateTime.now().subtract(const Duration(hours: 2)),
        pendingSessions: 3,
        isSyncing: false,
      );
}
