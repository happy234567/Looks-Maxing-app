import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_plugin.dart';

class LockInNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = sharedNotificationsPlugin;

  static const int _reminderNotifId = 1001;
  static const int _dangerNotifId   = 1002;
  static const String _kScheduledDay = 'notif_scheduled_day';

  static Future<void> initialize() async {
    tzdata.initializeTimeZones();
    try {
      final locationName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(locationName));
    } catch (e) {
      debugPrint('[LockInNotif] Failed to set timezone: $e');
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
        debugPrint('Lock In notification tapped: id=${response.id}, payload=${response.payload}');
        handleNotificationNavigation(response.payload);
      },
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'lock_in_channel_v2',
      'Lock In Reminders',
      description: 'Daily reminders to complete your Lock In tasks',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    const AndroidNotificationChannel challengeChannel = AndroidNotificationChannel(
      'challenge_result_channel',
      'Challenge Results',
      description: 'Challenge completion and giveaway notifications',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(challengeChannel);

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  static Future<void> scheduleTodayNotifications({
    required int dayNumber,
    required double completionRate,
  }) async {
    if (completionRate >= 1.0) {
      await cancelAll();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month}-${now.day}';
    if (prefs.getString(_kScheduledDay) == todayKey) return;

    await cancelAll();

    final eightPM = DateTime(now.year, now.month, now.day, 20, 0, 0);
    if (now.isBefore(eightPM)) {
      await _schedule(
        id: _reminderNotifId,
        title: 'Don\'t break your streak ⚡',
        body: 'You didn\'t complete your Day $dayNumber task. Complete it now to maintain your streak.',
        bigText: 'You didn\'t complete your Day $dayNumber task. Complete it now to maintain your streak.',
        scheduledTime: eightPM,
        isDanger: false,
        payload: 'lockin',
      );
    }

    final elevenPM = DateTime(now.year, now.month, now.day, 23, 0, 0);
    if (now.isBefore(elevenPM)) {
      await _schedule(
        id: _dangerNotifId,
        title: '🚨 1 HOUR LEFT!',
        body: 'Day $dayNumber is almost over! Complete your tasks NOW or lose your streak.',
        bigText: 'Day $dayNumber is almost over! You only have 1 hour left to complete your tasks. Don\'t let your streak die — open the app and finish strong! 💪',
        scheduledTime: elevenPM,
        isDanger: true,
        payload: 'lockin',
      );
    }

    await prefs.setString(_kScheduledDay, todayKey);
  }

  static Future<void> cancelAll() async {
    try {
      await _plugin.cancel(_reminderNotifId);
    } catch (e) {
      debugPrint('[LockInNotif] cancelReminder failed (safe): $e');
    }
    try {
      await _plugin.cancel(_dangerNotifId);
    } catch (e) {
      debugPrint('[LockInNotif] cancelDanger failed (safe): $e');
    }
    debugPrint('Lock In notifications cancelled');
  }

  static Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required String bigText,
    required DateTime scheduledTime,
    required bool isDanger,
    required String payload,
  }) async {
    final tzScheduled = tz.TZDateTime.from(scheduledTime, tz.local);

    final Int64List vibration = isDanger
        ? Int64List.fromList([0, 400, 200, 400, 200, 400])
        : Int64List.fromList([0, 300, 150, 300]);

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'lock_in_channel_v2',
      'Lock In Reminders',
      channelDescription: 'Daily reminders to complete your Lock In tasks',
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(
        bigText,
        htmlFormatBigText: false,
        contentTitle: title,
        summaryText: 'Task reminder',
      ),
      color: const Color(0xFFFFD700),
      ledColor: const Color(0xFFFFD700),
      ledOnMs: 1000,
      ledOffMs: 500,
      enableLights: true,
      playSound: true,
      enableVibration: true,
      vibrationPattern: vibration,
      category: AndroidNotificationCategory.reminder,
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
      when: scheduledTime.millisecondsSinceEpoch,
      showWhen: true,
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
        tzScheduled,
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
      );
    } catch (e) {
      debugPrint('[LockInNotif] _schedule failed (safe): $e');
    }
  }

  static Future<void> showChallengeResult({required bool isEligible}) async {
    final title = isEligible ? '🎉 You Made It!' : 'Almost There 😔';
    final body = isEligible
        ? 'You completed the challenge and entered the giveaway! We\'ll notify you if you win.'
        : 'You needed 80% accuracy. Don\'t give up — start a new challenge!';

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'challenge_result_channel',
      'Challenge Results',
      channelDescription: 'Challenge completion and giveaway notifications',
      importance: Importance.max,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: '<b>$title</b>',
        htmlFormatContentTitle: true,
        htmlFormatBigText: true,
        summaryText: 'Challenge Result',
      ),
      color: const Color(0xFFFFD700),
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
      enableLights: true,
      ledColor: const Color(0xFFFFD700),
      ledOnMs: 800,
      ledOffMs: 400,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 300, 150, 300, 150, 300]),
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      sound: 'default',
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    try {
      await _plugin.show(
        isEligible ? 2001 : 2002,
        title,
        body,
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        payload: 'lockin',
      );
    } catch (e) {
      debugPrint('[ChallengeNotif] ERROR firing notification: $e');
    }
  }
}