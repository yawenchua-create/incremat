import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Schedules and shows LOCAL notifications (fired by the phone itself, no
/// server) for daily-goal reminders, mobility alerts, and chair-stand re-tests.
///
/// This is a SINGLETON — only one instance ever exists. The pattern:
///   • `_instance` is the single stored copy,
///   • the private `_()` constructor stops anyone else creating one,
///   • the `factory` constructor returns that same `_instance` every time.
/// So `NotificationService()` anywhere in the app hands back the same object.
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  // Android groups notifications into "channels" the user can mute individually.
  static const _channelId = 'daily_goal_reminder';
  static const _mobilityChannelId = 'mobility_alert';
  static const _chairStandChannelId = 'chair_stand_reminder';

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false; // guard so initialize() only runs its setup once

  // Each notification needs a unique integer id. We derive a STABLE one from the
  // seniorId's hashCode (mod 100000 to keep it small) so re-scheduling for the
  // same senior replaces their old notification instead of stacking duplicates.
  static int _notifId(String seniorId) => seniorId.hashCode.abs() % 100000;
  // Offsets so each notification type has its own slot per senior.
  static int _mobilityNotifId(String seniorId) =>
      100000 + (seniorId.hashCode.abs() % 100000);
  static int _chairStandNotifId(String seniorId) =>
      200000 + (seniorId.hashCode.abs() % 100000);

  /// One-time setup: load the timezone database and point it at the phone's
  /// local zone (needed so `zonedSchedule` fires at the right wall-clock time),
  /// then initialise the plugin with the app icon.
  Future<void> initialize() async {
    if (_initialized) return; // already set up — do nothing
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

    // Build today's target time (default 20:00). If that moment already passed
    // today, push it to tomorrow so we never schedule in the past.
    final now = tz.TZDateTime.now(tz.local);
    var tzTarget = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute, 0);
    if (tzTarget.isBefore(now)) tzTarget = tzTarget.add(const Duration(days: 1));

    // matchDateTimeComponents: DateTimeComponents.time (below) makes this REPEAT
    // daily at the same time, rather than firing only once.
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
