import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/notifications/notification_service.dart';

// Persists and vends the global reminder time (same time for all seniors).
class NotificationTimeNotifier extends AsyncNotifier<TimeOfDay> {
  static const _hourKey = 'notification_hour';
  static const _minKey = 'notification_minute';

  @override
  Future<TimeOfDay> build() async {
    final prefs = await SharedPreferences.getInstance();
    return TimeOfDay(
      hour: prefs.getInt(_hourKey) ?? 20,
      minute: prefs.getInt(_minKey) ?? 0,
    );
  }

  Future<void> setTime(
    TimeOfDay time, {
    String? seniorId,
    String seniorName = 'your loved one',
    int goalReps = 25,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_hourKey, time.hour);
    await prefs.setInt(_minKey, time.minute);
    state = AsyncData(time);
    // Reschedule the given senior's notification if enabled.
    if (seniorId != null) {
      final enabled =
          ref.read(notificationsProvider(seniorId)).valueOrNull ?? false;
      if (enabled) {
        await NotificationService().scheduleGoalReminder(
            seniorId, seniorName, goalReps, time.hour, time.minute);
      }
    }
  }
}

final notificationTimeProvider =
    AsyncNotifierProvider<NotificationTimeNotifier, TimeOfDay>(
  NotificationTimeNotifier.new,
);

// Per-senior enabled state, keyed by seniorId.
class NotificationsNotifier extends FamilyAsyncNotifier<bool, String> {
  static String _key(String seniorId) => 'notifications_enabled_$seniorId';

  @override
  Future<bool> build(String seniorId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key(seniorId)) ?? false;
  }

  Future<void> toggle(
    bool enabled, {
    required String seniorName,
    required int goalReps,
  }) async {
    final seniorId = arg;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key(seniorId), enabled);
    state = AsyncData(enabled);

    final service = NotificationService();
    if (enabled) {
      final time = ref.read(notificationTimeProvider).valueOrNull ??
          const TimeOfDay(hour: 20, minute: 0);
      await service.scheduleGoalReminder(
          seniorId, seniorName, goalReps, time.hour, time.minute);
    } else {
      await service.cancelGoalReminder(seniorId);
    }
  }
}

final notificationsProvider =
    AsyncNotifierProvider.family<NotificationsNotifier, bool, String>(
  NotificationsNotifier.new,
);
