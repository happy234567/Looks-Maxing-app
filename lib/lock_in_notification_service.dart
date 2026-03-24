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
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create notification channel (required on Android 8+)
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'lock_in_channel',
      'Lock In Reminders',
      description: 'Daily reminders to complete your Lock In tasks',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
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

    // ── 7 PM — gentle reminder ────────────────────────────────────────────
    final sevenPM = DateTime(now.year, now.month, now.day, 19, 0, 0);
    if (now.isBefore(sevenPM)) {
      await _schedule(
        id: _reminderNotifId,
        title: '⚡  Day $dayNumber — Tasks Pending',
        body: 'Complete your tasks to maintain your streak!',
        bigText: 'You still have tasks left for Day $dayNumber.\n\nComplete them before midnight to keep your streak alive! 🔥',
        scheduledTime: sevenPM,
        isDanger: false,
      );
      debugPrint('Scheduled 7PM reminder for day $dayNumber');
    }

    // ── 11 PM — danger alert ──────────────────────────────────────────────
    final elevenPM = DateTime(now.year, now.month, now.day, 23, 0, 0);
    if (now.isBefore(elevenPM)) {
      await _schedule(
        id: _dangerNotifId,
        title: '🚨  Streak in Danger!',
        body: 'Only 1 hour left — complete Day $dayNumber now!',
        bigText: 'Day $dayNumber tasks are still incomplete.\n\nOnly 1 hour left before midnight. Don\'t break your streak now! ⏰',
        scheduledTime: elevenPM,
        isDanger: true,
      );
      debugPrint('Scheduled 11PM danger alert for day $dayNumber');
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
      'lock_in_channel',
      'Lock In Reminders',
      channelDescription: 'Daily reminders to complete your Lock In tasks',
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(
        bigText,
        htmlFormatBigText: false,
        contentTitle: title,
        summaryText: isDanger ? '🚨 Streak at risk' : '⚡ Task reminder',
      ),
      color: isDanger ? const Color(0xFFFF4444) : const Color(0xFFFFD700),
      ledColor: isDanger ? const Color(0xFFFF4444) : const Color(0xFFFFD700),
      ledOnMs: 1000,
      ledOffMs: 500,
      enableLights: true,
      playSound: true,
      enableVibration: true,
      vibrationPattern: vibration,
      category: AndroidNotificationCategory.reminder,
      fullScreenIntent: isDanger,
      ticker: isDanger ? 'Streak in danger!' : 'Task reminder',
      when: scheduledTime.millisecondsSinceEpoch,
      showWhen: true,
    );

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      tzScheduled,
      NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}