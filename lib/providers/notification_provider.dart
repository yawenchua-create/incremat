import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notifications/notification_service.dart';

class NotificationsNotifier extends AsyncNotifier<bool> {
  static const _key = 'notifications_enabled';

  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }

  Future<void> toggle(
    bool enabled, {
    String seniorName = 'your loved one',
    int goalReps = 25,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, enabled);
    state = AsyncData(enabled);

    final service = NotificationService();
    if (enabled) {
      await service.scheduleGoalReminder(seniorName, goalReps);
    } else {
      await service.cancelGoalReminder();
    }
  }
}

final notificationsProvider =
    AsyncNotifierProvider<NotificationsNotifier, bool>(NotificationsNotifier.new);
