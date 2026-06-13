import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  static const _channelId = 'daily_goal_reminder';
  static const _mobilityChannelId = 'mobility_alert';
  static const _chairStandChannelId = 'chair_stand_reminder';

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // Derive a stable per-senior notification ID from the senior's Firestore ID.
  static int _notifId(String seniorId) => seniorId.hashCode.abs() % 100000;
  // Offsets so each notification type has its own slot per senior.
  static int _mobilityNotifId(String seniorId) =>
      100000 + (seniorId.hashCode.abs() % 100000);
  static int _chairStandNotifId(String seniorId) =>
      200000 + (seniorId.hashCode.abs() % 100000);

  Future<void> initialize() async {
    if (_initialized) return;
    tz.initializeTimeZones();
    final tzInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: androidInit));
    _initialized = true;
  }

  Future<void> scheduleGoalReminder(
    String seniorId,
    String seniorName,
    int goalReps, [
    int hour = 20,
    int minute = 0,
  ]) async {
    await initialize();

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    final now = tz.TZDateTime.now(tz.local);
    var tzTarget = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute, 0);
    if (tzTarget.isBefore(now)) tzTarget = tzTarget.add(const Duration(days: 1));

    await _plugin.zonedSchedule(
      _notifId(seniorId),
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

  Future<void> cancelGoalReminder(String seniorId) async {
    await initialize();
    await _plugin.cancel(_notifId(seniorId));
  }

  /// Shows an immediate mobility-decline alert prompting the caregiver to check
  /// in. Used when a senior's 5-rep sit-to-stand time worsens sharply.
  Future<void> showMobilityAlert(
    String seniorId,
    String title,
    String body,
  ) async {
    await initialize();
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _plugin.show(
      _mobilityNotifId(seniorId),
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _mobilityChannelId,
          'Mobility Alerts',
          channelDescription:
              'Alerts the caregiver if a senior\'s sit-to-stand speed drops',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }

  /// Shows an immediate reminder that a senior is due for their monthly
  /// 30-Second Chair Stand Test.
  Future<void> showChairStandReminder(
    String seniorId,
    String title,
    String body,
  ) async {
    await initialize();
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    await _plugin.show(
      _chairStandNotifId(seniorId),
      title,
      body,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          _chairStandChannelId,
          'Fitness Test Reminders',
          channelDescription:
              'Monthly reminder to redo the 30-second chair stand test',
          importance: Importance.high,
          priority: Priority.high,
        ),
      ),
    );
  }
}
