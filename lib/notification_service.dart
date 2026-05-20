import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'notification_plugin.dart';

// ─────────────────────────────────────────────────────────────────────────────
// BACKGROUND HANDLER — must be a top-level function (not inside a class).
// Runs in its own isolate when the app is in the background or terminated.
// ─────────────────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('[FCM] Background notification received: ${message.notification?.title}');
  // Note: notification payload messages are shown automatically by the system
  // tray when the app is in the background — no manual handling needed here.
  // Data-only messages can be processed here if needed in the future.
}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = sharedNotificationsPlugin;

  /// Whether initialize() has already been called this session.
  /// Prevents duplicate listener registration on hot restart / re-init.
  static bool _initialized = false;

  // ── INITIALIZE ──────────────────────────────────────────────────────────────
  /// Sets up local notifications, FCM permissions, token management,
  /// and all foreground/background/terminated message handlers.
  /// Safe to call multiple times — only runs once per session.
  static Future<void> initialize() async {
    if (_initialized) {
      debugPrint('[FCM] Already initialized — skipping');
      return;
    }

    // ── 1. Local notification plugin setup ──────────────────────────────────
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@drawable/ic_stat_notification');

    const DarwinInitializationSettings iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('[FCM] Local notification tapped: payload=${response.payload}');
        handleNotificationNavigation(response.payload);
      },
    );

    // ── 2. Create notification channel ──────────────────────────────────────
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'Used for critical app alerts and scan results.',
      importance: Importance.max,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // ── 3. Register background handler ──────────────────────────────────────
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // ── 4. Request notification permissions ──────────────────────────────────
    // This covers both iOS permission dialog and Android 13+ POST_NOTIFICATIONS.
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );
      debugPrint('[FCM] Permission status: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        debugPrint('[FCM] ⚠️ User denied notification permission');
      }
    } catch (e) {
      debugPrint('[FCM] Permission request failed: $e');
    }

    // Also request via flutter_local_notifications for Android 13+
    try {
      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } catch (e) {
      debugPrint('[FCM] Android notification permission request failed: $e');
    }

    // ── 5. Save FCM token to Firestore ──────────────────────────────────────
    await _saveTokenToFirestore();

    // ── 6. FOREGROUND — show local notification manually ────────────────────
    // When the app is open, FCM does NOT show notifications automatically.
    // We intercept the message and show it via flutter_local_notifications.
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('[FCM] Foreground message: ${message.notification?.title}');
      if (message.notification != null) {
        final screen = message.data['screen'] as String?;
        showPremiumNotification(
          title: message.notification!.title ?? 'Level Max 🚀',
          body: message.notification!.body ?? 'Check your latest update now.',
          payload: screen,
        );
      }
    });

    // ── 7. BACKGROUND TAP — user tapped notification while app was alive ────
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('[FCM] Background notification tapped: ${message.data}');
      final screen = message.data['screen'] as String?;
      handleNotificationNavigation(screen);
    });

    // ── 8. TERMINATED TAP — app was killed, user tapped to open ─────────────
    try {
      final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('[FCM] App opened from terminated state via notification');
        final screen = initialMessage.data['screen'] as String?;
        // Delay so the widget tree is built before attempting navigation
        Future.delayed(const Duration(milliseconds: 800), () {
          handleNotificationNavigation(screen);
        });
      }
    } catch (e) {
      debugPrint('[FCM] getInitialMessage failed: $e');
    }

    // ── 9. TOKEN REFRESH — save new token when FCM rotates it ───────────────
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      debugPrint('[FCM] Token refreshed — saving to Firestore');
      _saveTokenToFirestoreWithToken(newToken);
    });

    _initialized = true;
    debugPrint('[FCM] ✅ NotificationService fully initialized');
  }

  // ── SHOW LOCAL NOTIFICATION ─────────────────────────────────────────────────
  /// Creates a premium-styled local notification visible in the system tray.
  /// Used for foreground FCM messages and can be called from anywhere in the app.
  static Future<void> showPremiumNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'high_importance_channel',
      'High Importance Notifications',
      channelDescription: 'Used for critical app alerts and scan results.',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'Level Max',
      icon: '@drawable/ic_stat_notification',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: '<b>$title</b>',
        htmlFormatContentTitle: true,
        htmlFormatBigText: true,
        summaryText: 'Level Max',
      ),
      color: const Color(0xFFFFD700),
      enableLights: true,
      ledColor: const Color(0xFFFFD700),
      ledOnMs: 800,
      ledOffMs: 400,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 200, 100, 200]),
      channelShowBadge: true,
      autoCancel: true,
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      sound: 'default',
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.hashCode,
      title,
      body,
      details,
      payload: payload,
    );
  }

  // ── TOKEN MANAGEMENT ────────────────────────────────────────────────────────

  /// Gets the current FCM token and saves it to Firestore for the signed-in user.
  static Future<void> _saveTokenToFirestore() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        debugPrint('[FCM] Token obtained: ${token.substring(0, 20)}...');
        await _saveTokenToFirestoreWithToken(token);
      } else {
        debugPrint('[FCM] ⚠️ getToken() returned null');
      }
    } catch (e) {
      debugPrint('[FCM] Error getting token: $e');
    }
  }

  /// Saves a specific FCM token to Firestore under the current user's
  /// `tokens` subcollection. Uses the token itself (with / replaced) as
  /// the document ID to prevent duplicates.
  ///
  /// Schema: users/{uid}/tokens/{safeTokenId}
  ///   - token: String (raw FCM token)
  ///   - platform: String ("android" / "ios")
  ///   - updatedAt: Timestamp (server)
  ///   - createdAt: Timestamp (server, set only on first write)
  static Future<void> _saveTokenToFirestoreWithToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint('[FCM] No user signed in — token NOT saved');
      return;
    }

    try {
      // Clean up legacy flat fcmToken field (migration from old schema)
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'fcmToken': FieldValue.delete(),
          'tokenUpdated': FieldValue.delete(),
        });
      } catch (_) {
        // Field may not exist — safe to ignore
      }

      // Save in subcollection for multi-device support
      final safeTokenId = token.replaceAll('/', '_');
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('tokens')
          .doc(safeTokenId)
          .set({
        'token': token,
        'platform': Platform.operatingSystem,
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      debugPrint('[FCM] ✅ Token saved for user ${user.uid}');
    } catch (e) {
      debugPrint('[FCM] Failed to save token: $e');
    }
  }

  /// Called after successful login to ensure the FCM token is linked to the
  /// newly signed-in user.
  static Future<void> saveTokenAfterLogin() async {
    debugPrint('[FCM] Saving token after login...');
    await _saveTokenToFirestore();
  }

  /// Called on sign-out / account deletion to remove this device's token
  /// from the user's Firestore subcollection, then deletes the local token
  /// so this device stops receiving notifications for the old user.
  static Future<void> removeTokenOnLogout() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await _messaging.getToken();
        if (token != null) {
          final safeTokenId = token.replaceAll('/', '_');
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('tokens')
              .doc(safeTokenId)
              .delete();
          debugPrint('[FCM] Token removed from Firestore for ${user.uid}');
        }
      }
      await _messaging.deleteToken();
      debugPrint('[FCM] Local FCM token deleted');
    } catch (e) {
      debugPrint('[FCM] removeTokenOnLogout failed: $e');
    }
  }
}