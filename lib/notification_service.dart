import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:typed_data';

// This runs in the background even when app is closed
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Use plugin to show the notification if needed, or let OS handle it
  debugPrint('Background notification received: ${message.notification?.title}');
}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();

  // Call this once when the app starts
  static Future<void> initialize() async {
    // 1. Android/iOS local notification settings
    // Small icon MUST be monochrome (Android enforces this on API 21+)
    const AndroidInitializationSettings androidSettings = AndroidInitializationSettings('@drawable/ic_stat_notification');
    
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
        // Handle tapping on notification
        debugPrint('Notification clicked: ${response.payload}');
      },
    );

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'high_importance_channel',
      'High Importance Notifications',
      description: 'Used for critical app alerts and scan results.',
      importance: Importance.max,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // 2. Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 3. Ask the user for permission
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('Notification permission: ${settings.authorizationStatus}');

    // 4. Get and save token
    await _saveTokenToFirestore();

    // 5. Handle foreground notifications
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Foreground notification: ${message.notification?.title}');
      if (message.notification != null) {
        showPremiumNotification(
          title: message.notification!.title ?? 'Level Max Up! 🚀',
          body: message.notification!.body ?? 'Check your latest scan results now.',
        );
      }
    });

    // 6. Refresh token listener
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      _saveTokenToFirestoreWithToken(newToken);
    });
  }

  /// Shows a premium notification with the app logo
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
      // Small icon: monochrome silhouette (Android REQUIRES alpha-only for status bar)
      icon: '@drawable/ic_stat_notification',
      // Large icon: full-color app logo (circular on modern Android, high visibility)
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/launcher_icon'),
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: '<b>$title</b>',
        htmlFormatContentTitle: true,
        htmlFormatBigText: true,
        summaryText: 'Level Max',
      ),
      // Gold tint applied to the small monochrome icon in the status bar
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

    final NotificationDetails details = NotificationDetails(android: androidDetails);

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch.hashCode,
      title,
      body,
      details,
      payload: payload,
    );
  }

  // Gets the FCM token for this device and saves it to the user's Firestore doc
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