import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'notification_plugin.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BACKGROUND TASK — runs every day even when the app is closed.
// WorkManager calls this function in an isolate (separate process).
// It reads the saved day number + completion rate from SharedPreferences
// and schedules the 8 PM / 11 PM notifications for that day.
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    if (taskName != LockInNotificationService.kDailyTaskName) return true;

    try {
      // Re-initialise timezone in this isolate (no Flutter engine here)
      tzdata.initializeTimeZones();
      try {
        final locationName = await FlutterTimezone.getLocalTimezone();
        tz.setLocalLocation(tz.getLocation(locationName));
      } catch (_) {}

      // Initialise the local-notifications plugin in this isolate
      const androidInit = AndroidInitializationSettings('@drawable/ic_stat_notification');
      const initSettings = InitializationSettings(android: androidInit);
      await sharedNotificationsPlugin.initialize(initSettings);

      // Create the notification channels (safe to call even if they exist)
      await sharedNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(const AndroidNotificationChannel(
            'lock_in_channel_v2',
            'Lock In Reminders',
            description: 'Daily reminders to complete your Lock In tasks',
            importance: Importance.high,
            playSound: true,
            enableVibration: true,
          ));

      // Read saved state from SharedPreferences
      final prefs = await SharedPreferences.getInstance();

      // Compute dayNumber dynamically from startDate so it's always
      // correct even if the user hasn't opened the app in several days.
      final startDateStr = prefs.getString(LockInNotificationService.kPrefStartDate);
      int dayNumber;
      if (startDateStr != null) {
        final startDate = DateTime.parse(startDateStr);
        final today = DateTime.now();
        dayNumber = DateTime(today.year, today.month, today.day)
            .difference(DateTime(startDate.year, startDate.month, startDate.day))
            .inDays + 1;
      } else {
        dayNumber = prefs.getInt(LockInNotificationService.kPrefDayNumber) ?? 1;
      }

      // IMPORTANT: Always assume 0% completion in the background task.
      // The user hasn't opened the app today, so no tasks have been
      // checked off. Reading the stored value would use *yesterday's*
      // rate — if it was 1.0 we'd call cancelAll() and never notify.
      const double completionRate = 0.0;

      // Schedule the 8 PM / 11 PM notifications for today
      await LockInNotificationService._scheduleInternal(
        dayNumber: dayNumber,
        completionRate: completionRate,
        forceReschedule: true, // Background task always reschedules for today
      );
    } catch (e) {
      debugPrint('[WorkManager] LockIn background task failed: $e');
    }

    return true; // Always return true so WorkManager doesn't retry forever
  });
}

class LockInNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin = sharedNotificationsPlugin;

  static const int _reminderNotifId = 1001;
  static const int _dangerNotifId   = 1002;
  static const String _kScheduledDay = 'notif_scheduled_day';

  // Keys used to share state with the background isolate
  static const String kPrefDayNumber      = 'lockin_notif_day_number';
  static const String kPrefCompletionRate = 'lockin_notif_completion_rate';
  static const String kPrefStartDate     = 'lockin_notif_start_date';
  static const String kDailyTaskName      = 'lockin_daily_notif_task';

  // ── Initialize ─────────────────────────────────────────────────────────────
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

    // ── Register WorkManager background task ─────────────────────────────────
    // This runs once a day at ~6 AM and reschedules the 8 PM / 11 PM
    // notifications WITHOUT the user needing to open the app.
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false,
    );

    await Workmanager().registerPeriodicTask(
      kDailyTaskName,        // unique task name
      kDailyTaskName,        // task tag (same name is fine)
      frequency: const Duration(hours: 24),
      initialDelay: _delayUntil6AM(),
      constraints: Constraints(
        networkType: NetworkType.not_required, // no internet needed
      ),
      existingWorkPolicy: ExistingWorkPolicy.keep,
    );

    debugPrint('[LockInNotif] WorkManager daily task registered');
  }

  // ── How long until 6 AM tomorrow? ──────────────────────────────────────────
  static Duration _delayUntil6AM() {
    final now = DateTime.now();
    var next6AM = DateTime(now.year, now.month, now.day, 6, 0, 0);
    if (now.isAfter(next6AM)) {
      next6AM = next6AM.add(const Duration(days: 1));
    }
    return next6AM.difference(now);
  }

  // ── Public entry point called from LockInPage ───────────────────────────────
  static Future<void> scheduleTodayNotifications({
    required int dayNumber,
    required double completionRate,
    required DateTime startDate,
  }) async {
    // Save state so the background isolate can read it later
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(kPrefDayNumber, dayNumber);
    await prefs.setDouble(kPrefCompletionRate, completionRate);
    await prefs.setString(kPrefStartDate, startDate.toIso8601String());

    await _scheduleInternal(
      dayNumber: dayNumber,
      completionRate: completionRate,
      forceReschedule: false,
    );
  }

  // ── Internal scheduling logic (used by both foreground and background) ──────
  static Future<void> _scheduleInternal({
    required int dayNumber,
    required double completionRate,
    required bool forceReschedule,
  }) async {
    // If tasks are all done, cancel and exit
    if (completionRate >= 1.0) {
      await cancelAll();
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayKey = '${now.year}-${now.month}-${now.day}';

    // Skip if already scheduled today — UNLESS we're forcing a reschedule
    // (the background task always forces, so it stays correct even if the
    // user already opened the app once today)
    if (!forceReschedule && prefs.getString(_kScheduledDay) == todayKey) return;

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
    debugPrint('[LockInNotif] Notifications scheduled for $todayKey (day $dayNumber)');
  }

  // ── Cancel both notifications ───────────────────────────────────────────────
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

  // ── Low-level scheduler ─────────────────────────────────────────────────────
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
      debugPrint('[LockInNotif] Scheduled "$title" at $scheduledTime');
    } catch (e) {
      debugPrint('[LockInNotif] _schedule failed (safe): $e');
    }
  }

  // ── Challenge result notification (unchanged) ───────────────────────────────
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