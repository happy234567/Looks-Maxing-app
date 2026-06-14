import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'notification_plugin.dart';

class FoodLogNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = sharedNotificationsPlugin;

  static const int _breakfastId = 3001;
  static const int _lunchId = 3002;
  static const int _dinnerId = 3003;

  /// Initialize and schedule daily food log reminders
  static Future<void> initialize() async {
    tzdata.initializeTimeZones();
    try {
      final locationName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(locationName));
    } catch (e) {
      debugPrint('[FoodLogNotif] Failed to set timezone: $e');
    }

    const androidInit = AndroidInitializationSettings('@drawable/ic_stat_notification');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Food Log notification tapped: id=${response.id}, payload=${response.payload}');
        handleNotificationNavigation(response.payload);
      },
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'food_log_channel',
      'Food Log Reminders',
      description: 'Daily reminders to log your breakfast, lunch, and dinner',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Schedule the daily reminders
    await scheduleDailyReminders();
  }

  /// Calculates the next instance of a specific time
  static tz.TZDateTime _nextInstanceOfTime(int hour, int minute) {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }

  /// Schedules daily recurring breakfast, lunch, and dinner logging reminders
  static Future<void> scheduleDailyReminders() async {
    // 1. Breakfast at 9:00 AM
    await _scheduleDaily(
      id: _breakfastId,
      hour: 9,
      minute: 0,
      title: 'Did you eat breakfast? 🍳',
      body: 'Keep your caloric and macro logs up to date. Scan or log your breakfast now!',
      summaryText: 'Breakfast Reminder',
    );

    // 2. Lunch at 1:30 PM
    await _scheduleDaily(
      id: _lunchId,
      hour: 13,
      minute: 30,
      title: 'Lunch time check! 🥗',
      body: 'Time to track your mid-day meal. Open the app to log your lunch.',
      summaryText: 'Lunch Reminder',
    );

    // 3. Dinner at 8:30 PM
    await _scheduleDaily(
      id: _dinnerId,
      hour: 20,
      minute: 30,
      title: 'Dinner time! 🍗',
      body: 'Finish strong today. Track your dinner to complete your daily logs.',
      summaryText: 'Dinner Reminder',
    );

    debugPrint('[FoodLogNotif] All daily reminders scheduled successfully.');
  }

  /// Low-level zoned daily scheduler
  static Future<void> _scheduleDaily({
    required int id,
    required int hour,
    required int minute,
    required String title,
    required String body,
    required String summaryText,
  }) async {
    final scheduledTime = _nextInstanceOfTime(hour, minute);

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'food_log_channel',
      'Food Log Reminders',
      channelDescription: 'Daily reminders to log your breakfast, lunch, and dinner',
      importance: Importance.high,
      priority: Priority.high,
      color: const Color(0xFFFFD700),
      ledColor: const Color(0xFFFFD700),
      ledOnMs: 1000,
      ledOffMs: 500,
      enableLights: true,
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.reminder,
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: summaryText,
      ),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      sound: 'default',
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduledTime,
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time, // Recurring daily
        payload: 'food_log',
      );
      debugPrint('[FoodLogNotif] Scheduled "$title" at $scheduledTime (daily)');
    } catch (e) {
      debugPrint('[FoodLogNotif] Failed to schedule daily reminder ID $id: $e');
    }
  }

  /// Cancels all scheduled food log reminders (e.g. on logout)
  static Future<void> cancelAll() async {
    try {
      await _plugin.cancel(_breakfastId);
      await _plugin.cancel(_lunchId);
      await _plugin.cancel(_dinnerId);
      debugPrint('[FoodLogNotif] All daily food log reminders cancelled');
    } catch (e) {
      debugPrint('[FoodLogNotif] Failed to cancel notifications: $e');
    }
  }
}
