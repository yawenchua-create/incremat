import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/sync_status.dart';
import '../services/sync/sync_service.dart';

final syncServiceProvider = Provider<SyncService>((ref) => SyncService());

class SyncNotifier extends AsyncNotifier<SyncStatus> {
  @override
  Future<SyncStatus> build() async {
    final service = ref.read(syncServiceProvider);
    // Return mock data immediately; load persisted status in background
    service.loadStatus().then((s) {
      if (!state.isLoading) state = AsyncData(s);
    }).catchError((_) {});
    return MockSyncStatus.initial;
  }

  Future<void> sync() async {
    final current = state.valueOrNull ?? MockSyncStatus.initial;
    state = AsyncData(current.copyWith(isSyncing: true));
    state = await AsyncValue.guard(() async {
      final service = ref.read(syncServiceProvider);
      return service.sync();
    });
  }
}

final syncProvider = AsyncNotifierProvider<SyncNotifier, SyncStatus>(
  SyncNotifier.new,
);
