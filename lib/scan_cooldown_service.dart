import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


// ─────────────────────────────────────────────────────────────────────────────
// SCAN COOLDOWN SERVICE
// Free users  → 1 scan per 30 days
// Premium     → 1 scan per 3 days
// When cooldown ends → local notification fires
//
// Cooldown is stored in FIRESTORE (server-side, survives sign-out/app data
// clear/reinstall). SharedPreferences is only used as a fast local cache,
// and ALL local keys are scoped to the current userId to prevent
// cross-account leakage.
// ─────────────────────────────────────────────────────────────────────────────

class ScanCooldownService {
  // Local cache key prefix — actual key is '${_kLastScanPrefix}_{userId}'
  static const String _kLastScanPrefix = 'last_scan_date';
  static const int _scanReadyNotifId = 3001; // Changed from 2001 to avoid collision with challenge result notif

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Returns the user-scoped SharedPreferences key for the last scan date.
  static String _userKey(String userId) => '${_kLastScanPrefix}_$userId';

  /// Returns the current Firebase userId, or null if not signed in.
  static String? get _currentUserId =>
      FirebaseAuth.instance.currentUser?.uid;

  // ── Initialize (call once in main) ───────────────────────────────────────

  static Future<void> initialize() async {
    tzdata.initializeTimeZones();
    // Set local timezone so scheduled notifications fire at the correct local time
    try {
      final locationName = await _getNativeTimezone();
      tz.setLocalLocation(tz.getLocation(locationName));
      debugPrint('[ScanCooldown] Timezone set to: $locationName');
    } catch (e) {
      debugPrint('[ScanCooldown] Failed to set timezone, using UTC: $e');
    }

    const androidInit = AndroidInitializationSettings('@drawable/ic_stat_notification');
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

  // ── Clear local cooldown cache for previous user ─────────────────────────
  // Call on sign-out or account switch to prevent cross-account leakage.

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

  // ── Sync cooldown from Firestore into local cache ────────────────────────
  // Call this after sign-in so the cooldown survives sign-out/reinstall.

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
        // Store under user-scoped key
        await prefs.setString(_userKey(user.uid), lastScanStr);
        debugPrint('[ScanCooldown] Synced from Firestore for ${user.uid}: $lastScanStr');
      }
    } catch (e) {
      debugPrint('[ScanCooldown] Failed to sync from Firestore: $e');
    }
  }

  // ── Save the date+time of the latest scan ────────────────────────────────

  static Future<void> recordScan({required bool isPremium}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('[ScanCooldown] recordScan: no user signed in — skipping');
      return;
    }

    final now = DateTime.now();
    final nowStr = now.toIso8601String();

    // 1. Save to local cache (fast reads) — user-scoped key
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userKey(user.uid), nowStr);

    // 2. Save to Firestore (survives sign-out, app data clear, reinstall)
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

    // 3. Schedule "scan ready" notification
    final cooldownDays = isPremium ? 3 : 30;
    final notifTime = now.add(Duration(days: cooldownDays));
    await _scheduleReadyNotification(notifTime, isPremium: isPremium);
  }

  // ── Get the last scan date (Firestore first, local cache fallback) ──────

  static Future<String?> _getLastScanDate() async {
    final userId = _currentUserId;
    if (userId == null) return null;

    final prefs = await SharedPreferences.getInstance();
    final localStr = prefs.getString(_userKey(userId));

    // Try Firestore for the authoritative value
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get(const GetOptions(source: Source.cache))
            .timeout(const Duration(seconds: 2), onTimeout: () => throw Exception('timeout'));

        if (doc.exists && doc.data()?['lastScanDate'] != null) {
          final firestoreStr = doc.data()!['lastScanDate'] as String;

          // If Firestore has a NEWER scan date than local, use Firestore
          // (handles case where local was cleared)
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
    } catch (_) {
      // If Firestore cache fails, fall through to local
    }

    return localStr;
  }

  // ── Check if user can scan right now ────────────────────────────────────

  static Future<bool> canScan({required bool isPremium}) async {
    final remaining = await getRemainingDuration(isPremium: isPremium);
    return remaining == Duration.zero;
  }

  // ── Get how much time is left (Duration.zero = can scan now) ─────────────

  static Future<Duration> getRemainingDuration({required bool isPremium}) async {
    final lastScanStr = await _getLastScanDate();

    if (lastScanStr == null) return Duration.zero; // Never scanned before

    final lastScan = DateTime.parse(lastScanStr);
    final cooldownDays = isPremium ? 3 : 30;
    final nextScanTime = lastScan.add(Duration(days: cooldownDays));
    final now = DateTime.now();

    if (now.isAfter(nextScanTime)) return Duration.zero;

    return nextScanTime.difference(now);
  }

  // ── Get next scan DateTime (null if can scan now) ────────────────────────

  static Future<DateTime?> getNextScanTime({required bool isPremium}) async {
    final lastScanStr = await _getLastScanDate();
    if (lastScanStr == null) return null;

    final lastScan = DateTime.parse(lastScanStr);
    final cooldownDays = isPremium ? 3 : 30;
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

    await _plugin.zonedSchedule(
      _scanReadyNotifId,
      'Cooldown Complete ✅',
      'Your cooldown is over. Scan your face now to get your latest face score.',
      tzScheduled,
      NotificationDetails(android: androidDetails),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
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
    final lastScanStr = await _getLastScanDate();
    if (lastScanStr == null) return 1.0; // Never scanned = fully ready

    final lastScan = DateTime.parse(lastScanStr);
    final cooldownDays = isPremium ? 3 : 30;
    final totalMs = Duration(days: cooldownDays).inMilliseconds;
    final elapsedMs =
        DateTime.now().difference(lastScan).inMilliseconds.clamp(0, totalMs);

    return elapsedMs / totalMs; // 0.0 = just scanned, 1.0 = cooldown done
  }

  /// Resolve the device's IANA timezone name from the OS.
  static Future<String> _getNativeTimezone() async {
    try {
      final now = DateTime.now();
      final offset = now.timeZoneOffset;
      for (final loc in tz.timeZoneDatabase.locations.values) {
        final tzNow = tz.TZDateTime.now(loc);
        if (tzNow.timeZoneOffset == offset) {
          return loc.name;
        }
      }
    } catch (_) {}
    return DateTime.now().timeZoneName;
  }
}