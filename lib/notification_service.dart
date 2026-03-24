import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// This runs in the background even when app is closed
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Firebase is already initialized in main, so we just handle the message
  debugPrint('Background notification received: ${message.notification?.title}');
}

class NotificationService {
  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // Call this once when the app starts
  static Future<void> initialize() async {
    // 1. Register background handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // 2. Ask the user for permission to send notifications
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    debugPrint('Notification permission: ${settings.authorizationStatus}');

    // 3. Get this device's unique token and save it to Firebase
    await _saveTokenToFirestore();

    // 4. If the token refreshes (rare), save the new one
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      _saveTokenToFirestoreWithToken(newToken);
    });

    // 5. Handle notification tapped when app is in foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('Foreground notification: ${message.notification?.title}');
      // You can show a snackbar or dialog here if you want
    });
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
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'fcmToken': token,
        'tokenUpdated': FieldValue.serverTimestamp(),
        'platform': 'android',
      }, SetOptions(merge: true));
      debugPrint('FCM token saved to Firestore');
    }
  }

  // Call this after login so the token gets linked to the logged-in user
  static Future<void> saveTokenAfterLogin() async {
    await _saveTokenToFirestore();
  }

  // Call this on logout to remove the token so they stop getting notifications
  static Future<void> removeTokenOnLogout() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set({
        'fcmToken': FieldValue.delete(),
      }, SetOptions(merge: true));
    }
    await _messaging.deleteToken();
  }
}
