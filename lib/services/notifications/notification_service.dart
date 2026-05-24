import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  static const _channelId = 'daily_goal_reminder';
  static const _notificationId = 1;

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: androidInit));
    _initialized = true;
  }

  Future<void> scheduleGoalReminder(String seniorName, int goalReps) async {
    await initialize();

    // Request Android 13+ notification permission if not yet granted.
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Schedule at 8:00 PM device-local time; convert to UTC TZDateTime.
    final now = DateTime.now();
    var target = DateTime(now.year, now.month, now.day, 20, 0, 0);
    if (target.isBefore(now)) target = target.add(const Duration(days: 1));
    final tzTarget = tz.TZDateTime.from(target.toUtc(), tz.UTC);

    await _plugin.zonedSchedule(
      _notificationId,
      'Daily Goal Reminder',
      "$seniorName hasn't completed their $goalReps reps today. Check in!",
      tzTarget,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Daily Goal Reminders',
          channelDescription: 'Reminds caregivers if the daily rep goal is not met',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> cancelGoalReminder() async {
    await initialize();
    await _plugin.cancel(_notificationId);
  }
}
