import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';
import 'notification_plugin.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  debugPrint('Background notification received: ${message.notification?.title}');
}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = sharedNotificationsPlugin;

  static Future<void> initialize() async {
    // Android local notification settings
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
      // ─── FIX: Local notification tap → navigate to correct screen ──────────
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification tapped: payload=${response.payload}');
        // payload contains the screen name e.g. "scan", "lockin", "progress"
        handleNotificationNavigation(response.payload);
      },
      // ────────────────────────────────────────────────────────────────────────
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'Used for critical app alerts and scan results.',
      importance: Importance.max,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('Notification permission: ${settings.authorizationStatus}');

    await _saveTokenToFirestore();

    // ─── FIX: FCM foreground message tap → navigate to correct screen ────────
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Foreground notification: ${message.notification?.title}');
      if (message.notification != null) {
        // Read screen from FCM data payload (what you set in Firebase Console)
        final screen = message.data['screen'] as String?;
        showPremiumNotification(
          title: message.notification!.title ?? 'Level Max Up! 🚀',
          body: message.notification!.body ?? 'Check your latest scan results now.',
          payload: screen, // passed through to onDidReceiveNotificationResponse
        );
      }
    });

    // App was in BACKGROUND and user tapped notification
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('Notification opened app from background: ${message.data}');
      final screen = message.data['screen'] as String?;
      handleNotificationNavigation(screen);
    });

    // App was TERMINATED (killed) and user tapped notification to open app
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('App opened from terminated state via notification');
      final screen = initialMessage.data['screen'] as String?;
      // Small delay to let the app finish building before navigating
      Future.delayed(const Duration(milliseconds: 500), () {
        handleNotificationNavigation(screen);
      });
    }
    // ─────────────────────────────────────────────────────────────────────────

    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      _saveTokenToFirestoreWithToken(newToken);
    });
  }

  static Future<void> showPremiumNotification({
    required String title,
    required String body,
    String? payload, // ← screen name e.g. "scan", "lockin"
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
      payload: payload, // ← this is what gets passed to onDidReceiveNotificationResponse
    );
  }

  static Future<void> _saveTokenToFirestore() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _saveTokenToFirestoreWithToken(token);
      }
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
    }
  }

  static Future<void> _saveTokenToFirestoreWithToken(String token) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'fcmToken': FieldValue.delete(),
          'tokenUpdated': FieldValue.delete(),
        });
      } catch (_) {}

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
      }, SetOptions(merge: true));
      debugPrint('FCM token safely stored in tokens subcollection');
    }
  }

  static Future<void> saveTokenAfterLogin() async {
    await _saveTokenToFirestore();
  }

  static Future<void> removeTokenOnLogout() async {
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
      }
    }
    await _messaging.deleteToken();
  }
}