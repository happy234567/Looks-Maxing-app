import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LOCK IN NOTIFICATION SERVICE
// Sends 2 automatic daily notifications:
//   1. 7 PM  — "5 hours left" gentle reminder
//   2. 11 PM — "1 hour left" danger alert
// Both are cancelled automatically when user completes the day.
// ─────────────────────────────────────────────────────────────────────────────

class LockInNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // Fixed IDs so we can cancel specific notifications
  static const int _reminderNotifId = 1001; // 7 PM reminder
  static const int _dangerNotifId   = 1002; // 11 PM danger

  // Key to avoid scheduling twice on the same day
  static const String _kScheduledDay = 'notif_scheduled_day';

  // ── Initialize — call once when app starts ───────────────────────────────

  static Future<void> initialize() async {
    // Initialize timezone data
    tzdata.initializeTimeZones();

    // Android setup
    const androidInit = AndroidInitializationSettings('@drawable/ic_stat_notification');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create notification channel (required on Android 8+)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'lock_in_channel_v2',
      'Lock In Reminders',
      description: 'Daily reminders to complete your Lock In tasks',
      importance: Importance.defaultImportance,
      playSound: true,
      enableVibration: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // High-importance channel for challenge results (heads-up display)
    const AndroidNotificationChannel challengeChannel = AndroidNotificationChannel(
      'challenge_result_channel',
      'Challenge Results',
      description: 'Challenge completion and giveaway notifications',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(challengeChannel);

    // Request notification permission (Android 13+)
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }

  // Called when user taps a notification
  static void _onNotificationTap(NotificationResponse response) {
    debugPrint('Lock In notification tapped: id=${response.id}');
  }

  // ── Schedule today's notifications ───────────────────────────────────────
  // Call every time app opens.
  // Skips if already scheduled today.
  // Cancels if day is already complete.

  static Future<void> scheduleTodayNotifications({
    required int dayNumber,
    required double completionRate,
  }) async {
    // Already fully done → cancel everything
    if (completionRate >= 1.0) {
      await cancelAll();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month}-${now.day}';

    // Already scheduled today → skip
    if (prefs.getString(_kScheduledDay) == todayKey) return;

    // Cancel leftovers from yesterday
    await cancelAll();

    // ── 8 PM — gentle reminder ────────────────────────────────────────────
    final eightPM = DateTime(now.year, now.month, now.day, 20, 0, 0);
    if (now.isBefore(eightPM)) {
      await _schedule(
        id: _reminderNotifId,
        title: 'Don\'t break your streak ⚡',
        body: 'You didn\'t complete your Day $dayNumber task. Complete it now to maintain your streak.',
        bigText: 'You didn\'t complete your Day $dayNumber task. Complete it now to maintain your streak.',
        scheduledTime: eightPM,
        isDanger: false,
      );
      debugPrint('Scheduled 8PM reminder for day $dayNumber');
    }

    await prefs.setString(_kScheduledDay, todayKey);
  }

  // ── Cancel all Lock In notifications ─────────────────────────────────────

  static Future<void> cancelAll() async {
    await _plugin.cancel(_reminderNotifId);
    await _plugin.cancel(_dangerNotifId);
    debugPrint('Lock In notifications cancelled');
  }

  // ── Internal: build and schedule one notification ────────────────────────

  static Future<void> _schedule({
    required int id,
    required String title,
    required String body,
    required String bigText,
    required DateTime scheduledTime,
    required bool isDanger,
  }) async {
    final tzScheduled = tz.TZDateTime.from(scheduledTime, tz.local);

    final Int64List vibration = isDanger
        ? Int64List.fromList([0, 400, 200, 400, 200, 400])
        : Int64List.fromList([0, 300, 150, 300]);

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'lock_in_channel_v2',
      'Lock In Reminders',
      channelDescription: 'Daily reminders to complete your Lock In tasks',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
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

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzScheduled,
      NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  // ── Challenge completion result notification ─────────────────────────────

  static Future<void> showChallengeResult({required bool isEligible}) async {
    debugPrint('[ChallengeNotif] Firing notification: isEligible=$isEligible');
    final title = isEligible ? '🎉 You Made It!' : 'Almost There 😔';
    final body = isEligible
        ? 'You completed the challenge and entered the giveaway! We\'ll notify you if you win.'
        : 'You needed 80% accuracy. Don\'t give up — start a new challenge!';

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
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
      largeIcon:
          const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
      enableLights: true,
      ledColor: const Color(0xFFFFD700),
      ledOnMs: 800,
      ledOffMs: 400,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 300, 150, 300, 150, 300]),
    );

    try {
      await _plugin.show(
        isEligible ? 2001 : 2002,
        title,
        body,
        NotificationDetails(android: androidDetails),
      );
      debugPrint('[ChallengeNotif] Notification fired successfully');
    } catch (e) {
      debugPrint('[ChallengeNotif] ERROR firing notification: $e');
    }
  }
}