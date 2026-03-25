import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;

// ─────────────────────────────────────────────────────────────────────────────
// SCAN COOLDOWN SERVICE
// Free users  → 1 scan per 30 days
// Premium     → 1 scan per 5 days
// When cooldown ends → local notification fires
// ─────────────────────────────────────────────────────────────────────────────

class ScanCooldownService {
  static const String _kLastScanDate = 'last_scan_date';
  static const int _scanReadyNotifId = 2001;

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  // ── Initialize (call once in main) ───────────────────────────────────────

  static Future<void> initialize() async {
    tzdata.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (resp) {
        debugPrint('Scan-ready notification tapped: ${resp.id}');
      },
    );

    // Create the notification channel
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'scan_ready_channel',
      'Face Scan Ready',
      description: 'Notifies you when your next face scan is available',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // ── Save the date+time of the latest scan ────────────────────────────────

  static Future<void> recordScan({required bool isPremium}) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    await prefs.setString(_kLastScanDate, now.toIso8601String());

    // Schedule "scan ready" notification
    final cooldownDays = isPremium ? 5 : 30;
    final notifTime = now.add(Duration(days: cooldownDays));
    await _scheduleReadyNotification(notifTime, isPremium: isPremium);
  }

  // ── Check if user can scan right now ────────────────────────────────────

  static Future<bool> canScan({required bool isPremium}) async {
    final remaining = await getRemainingDuration(isPremium: isPremium);
    return remaining == Duration.zero;
  }

  // ── Get how much time is left (Duration.zero = can scan now) ─────────────

  static Future<Duration> getRemainingDuration({required bool isPremium}) async {
    final prefs = await SharedPreferences.getInstance();
    final lastScanStr = prefs.getString(_kLastScanDate);

    if (lastScanStr == null) return Duration.zero; // Never scanned before

    final lastScan = DateTime.parse(lastScanStr);
    final cooldownDays = isPremium ? 5 : 30;
    final nextScanTime = lastScan.add(Duration(days: cooldownDays));
    final now = DateTime.now();

    if (now.isAfter(nextScanTime)) return Duration.zero;

    return nextScanTime.difference(now);
  }

  // ── Get next scan DateTime (null if can scan now) ────────────────────────

  static Future<DateTime?> getNextScanTime({required bool isPremium}) async {
    final prefs = await SharedPreferences.getInstance();
    final lastScanStr = prefs.getString(_kLastScanDate);
    if (lastScanStr == null) return null;

    final lastScan = DateTime.parse(lastScanStr);
    final cooldownDays = isPremium ? 5 : 30;
    final nextScanTime = lastScan.add(Duration(days: cooldownDays));
    final now = DateTime.now();

    if (now.isAfter(nextScanTime)) return null;
    return nextScanTime;
  }

  // ── Schedule the "Scan Ready" notification ───────────────────────────────

  static Future<void> _scheduleReadyNotification(
    DateTime scheduledTime, {
    required bool isPremium,
  }) async {
    // Cancel any previous scan-ready notification
    await _plugin.cancel(_scanReadyNotifId);

    final tzScheduled = tz.TZDateTime.from(scheduledTime, tz.local);

    final Int64List vibration =
        Int64List.fromList([0, 300, 150, 300, 150, 300]);

    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'scan_ready_channel',
      'Face Scan Ready',
      channelDescription: 'Notifies you when your next face scan is available',
      importance: Importance.high,
      priority: Priority.high,
      color: const Color(0xFFFFD700),
      ledColor: const Color(0xFFFFD700),
      ledOnMs: 1000,
      ledOffMs: 500,
      enableLights: true,
      playSound: true,
      enableVibration: true,
      vibrationPattern: vibration,
      styleInformation: BigTextStyleInformation(
        isPremium
            ? 'Your 5-day cooldown is over! Open the app, scan your face and check your latest results. 🏆'
            : 'Your 30-day cooldown is over! Open the app, scan your face and check your latest results. 📸',
        contentTitle: '📸 Face Scan Available!',
        summaryText: 'Level Maxing',
      ),
      ticker: 'Face scan available!',
      when: scheduledTime.millisecondsSinceEpoch,
      showWhen: true,
    );

    await _plugin.zonedSchedule(
      _scanReadyNotifId,
      '📸 Face Scan Available!',
      isPremium
          ? 'Your 5-day cooldown is over — scan your face now!'
          : 'Your 30-day cooldown is over — scan your face now!',
      tzScheduled,
      NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    debugPrint('Scan-ready notification scheduled for $scheduledTime');
  }

  // ── Format remaining time nicely for the countdown bar ──────────────────

  static String formatRemaining(Duration d) {
    if (d == Duration.zero) return 'Available Now!';
    final days = d.inDays;
    final hours = d.inHours.remainder(24);
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);

    if (days > 0) {
      return '${days}d ${hours}h ${minutes}m left';
    } else if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s left';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s left';
    } else {
      return '${seconds}s left';
    }
  }

  // ── Progress 0.0→1.0 for the countdown bar (1.0 = fully ready) ──────────

  static Future<double> getCooldownProgress({required bool isPremium}) async {
    final prefs = await SharedPreferences.getInstance();
    final lastScanStr = prefs.getString(_kLastScanDate);
    if (lastScanStr == null) return 1.0; // Never scanned = fully ready

    final lastScan = DateTime.parse(lastScanStr);
    final cooldownDays = isPremium ? 5 : 30;
    final totalMs = Duration(days: cooldownDays).inMilliseconds;
    final elapsedMs =
        DateTime.now().difference(lastScan).inMilliseconds.clamp(0, totalMs);

    return elapsedMs / totalMs; // 0.0 = just scanned, 1.0 = cooldown done
  }
}