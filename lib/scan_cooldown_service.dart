import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_plugin.dart';

class ScanCooldownService {
  static const String _kLastScanPrefix = 'last_scan_date';
  static const int _scanReadyNotifId = 3001;
  static const Duration _cooldownDuration = Duration(days: 1);

  static final FlutterLocalNotificationsPlugin _plugin = sharedNotificationsPlugin;

  static String _userKey(String userId) => '${_kLastScanPrefix}_$userId';
  static String? get _currentUserId => FirebaseAuth.instance.currentUser?.uid;

  static Future<void> initialize() async {
    tzdata.initializeTimeZones();
    try {
      final locationName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(locationName));
      debugPrint('[ScanCooldown] Timezone set to: $locationName');
    } catch (e) {
      debugPrint('[ScanCooldown] Failed to set timezone, using UTC: $e');
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
      // ─── FIX: Tapping cooldown notification → opens Face Rating (scan) tab ──
      onDidReceiveNotificationResponse: (NotificationResponse resp) {
        debugPrint('Scan-ready notification tapped: ${resp.id}, payload=${resp.payload}');
        handleNotificationNavigation(resp.payload);
      },
      // ────────────────────────────────────────────────────────────────────────
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'scan_ready_channel',
      'Face Scan Ready',
      description: 'Notifies you when your next face scan is available',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static Future<void> clearLocalCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      for (final key in keys) {
        if (key.startsWith(_kLastScanPrefix)) {
          await prefs.remove(key);
        }
      }
      debugPrint('[ScanCooldown] Cleared all local cooldown cache');
    } catch (e) {
      debugPrint('[ScanCooldown] Failed to clear local cache: $e');
    }
  }

  static Future<void> cancelNotification() async {
    try {
      await _plugin.cancel(_scanReadyNotifId);
      debugPrint('[ScanCooldown] Cancelled scheduled notification');
    } catch (e) {
      debugPrint('[ScanCooldown] Failed to cancel notification: $e');
    }
  }

  static Future<void> syncFromFirestore() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 5));

      if (doc.exists && doc.data()?['lastScanDate'] != null) {
        final lastScanStr = doc.data()!['lastScanDate'] as String;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_userKey(user.uid), lastScanStr);
        debugPrint('[ScanCooldown] Synced from Firestore for ${user.uid}: $lastScanStr');

        // Re-schedule notification if cooldown is still active
        // (handles app restart / Android clearing pending alarms)
        final lastScan = DateTime.parse(lastScanStr);
        final nextScanTime = lastScan.add(_cooldownDuration);
        if (DateTime.now().isBefore(nextScanTime)) {
          await _scheduleReadyNotification(nextScanTime, isPremium: false);
          debugPrint('[ScanCooldown] Re-scheduled notification for $nextScanTime');
        }
      }
    } catch (e) {
      debugPrint('[ScanCooldown] Failed to sync from Firestore: $e');
    }
  }

  static Future<void> recordScan({required bool isPremium}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('[ScanCooldown] recordScan: no user signed in — skipping');
      return;
    }

    final now = DateTime.now();
    final nowStr = now.toIso8601String();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey(user.uid), nowStr);

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'lastScanDate': nowStr,
        'lastScanTimestamp': Timestamp.fromDate(now),
      }, SetOptions(merge: true));
      debugPrint('[ScanCooldown] Saved to Firestore for ${user.uid}');
    } catch (e) {
      debugPrint('[ScanCooldown] Failed to save to Firestore: $e');
    }

    final notifTime = now.add(_cooldownDuration);
    await _scheduleReadyNotification(notifTime, isPremium: isPremium);
  }

  static Future<String?> _getLastScanDate() async {
    final userId = _currentUserId;
    if (userId == null) return null;

    final prefs = await SharedPreferences.getInstance();
    final localStr = prefs.getString(_userKey(userId));

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get(const GetOptions(source: Source.cache))
            .timeout(const Duration(seconds: 2),
                onTimeout: () => throw Exception('timeout'));

        if (doc.exists && doc.data()?['lastScanDate'] != null) {
          final firestoreStr = doc.data()!['lastScanDate'] as String;
          if (localStr == null) {
            await prefs.setString(_userKey(userId), firestoreStr);
            return firestoreStr;
          }
          final localDate = DateTime.parse(localStr);
          final firestoreDate = DateTime.parse(firestoreStr);
          if (firestoreDate.isAfter(localDate)) {
            await prefs.setString(_userKey(userId), firestoreStr);
            return firestoreStr;
          }
        }
      }
    } catch (_) {}

    return localStr;
  }

  static Future<bool> canScan({required bool isPremium}) async {
    final remaining = await getRemainingDuration(isPremium: isPremium);
    return remaining == Duration.zero;
  }

  static Future<Duration> getRemainingDuration({required bool isPremium}) async {
    final lastScanStr = await _getLastScanDate();
    if (lastScanStr == null) return Duration.zero;

    final lastScan = DateTime.parse(lastScanStr);
    final nextScanTime = lastScan.add(_cooldownDuration);
    final now = DateTime.now();
    if (now.isAfter(nextScanTime)) return Duration.zero;
    return nextScanTime.difference(now);
  }

  static Future<DateTime?> getNextScanTime({required bool isPremium}) async {
    final lastScanStr = await _getLastScanDate();
    if (lastScanStr == null) return null;
    final lastScan = DateTime.parse(lastScanStr);
    final nextScanTime = lastScan.add(_cooldownDuration);
    final now = DateTime.now();
    if (now.isAfter(nextScanTime)) return null;
    return nextScanTime;
  }

  static Future<void> _scheduleReadyNotification(
    DateTime scheduledTime, {
    required bool isPremium,
  }) async {
    // Safe cancel with try/catch (same fix as LockInNotificationService)
    try {
      await _plugin.cancel(_scanReadyNotifId);
    } catch (e) {
      debugPrint('[ScanCooldown] cancel failed (safe): $e');
    }

    final tzScheduled = tz.TZDateTime.from(scheduledTime, tz.local);
    final Int64List vibration = Int64List.fromList([0, 300, 150, 300, 150, 300]);

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
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
      styleInformation: const BigTextStyleInformation(
        'Your cooldown is over. Scan your face now to get your latest face score.',
        contentTitle: 'Cooldown Complete ✅',
        summaryText: 'Face Scan',
      ),
      ticker: 'Cooldown Complete ✅',
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
        _scanReadyNotifId,
        'Cooldown Complete ✅',
        'Your cooldown is over. Scan your face now to get your latest face score.',
        tzScheduled,
        NotificationDetails(android: androidDetails, iOS: iosDetails),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'scan', // ← tapping opens Face Rating tab
      );
      debugPrint('Scan-ready notification scheduled for $scheduledTime');
    } catch (e) {
      debugPrint('[ScanCooldown] _scheduleReadyNotification failed (safe): $e');
    }
  }

  static String formatRemaining(Duration d) {
    if (d == Duration.zero) return 'Available Now!';
    final days = d.inDays;
    final hours = d.inHours.remainder(24);
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (days > 0) return '${days}d ${hours}h ${minutes}m left';
    if (hours > 0) return '${hours}h ${minutes}m ${seconds}s left';
    if (minutes > 0) return '${minutes}m ${seconds}s left';
    return '${seconds}s left';
  }

  static Future<double> getCooldownProgress({required bool isPremium}) async {
    final lastScanStr = await _getLastScanDate();
    if (lastScanStr == null) return 1.0;
    final lastScan = DateTime.parse(lastScanStr);
    final totalMs = _cooldownDuration.inMilliseconds;
    final elapsedMs =
        DateTime.now().difference(lastScan).inMilliseconds.clamp(0, totalMs);
    return elapsedMs / totalMs;
  }
}