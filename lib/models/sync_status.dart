class SyncStatus {
  final DateTime? lastSyncedAt;
  final int pendingSessions;
  final bool isSyncing;

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
