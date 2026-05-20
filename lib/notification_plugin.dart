import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Single shared instance of FlutterLocalNotificationsPlugin.
/// Both NotificationService and LockInNotificationService must use this.
final FlutterLocalNotificationsPlugin sharedNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

/// Global navigator key — used by all notification tap handlers
/// to navigate without needing a BuildContext.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Routes every notification tap to the right screen.
/// [screen] comes from the notification payload or FCM data.
void handleNotificationNavigation(String? screen) {
  if (screen == null) return;
  final nav = navigatorKey.currentState;
  if (nav == null) return;

  switch (screen) {
    case 'scan':
      nav.pushNamedAndRemoveUntil('/main', (r) => false, arguments: 0);
      break;
    case 'progress':
      nav.pushNamedAndRemoveUntil('/main', (r) => false, arguments: 1);
      break;
    case 'lockin':
      nav.pushNamedAndRemoveUntil('/main', (r) => false, arguments: 2);
      break;
    case 'guide':
      nav.pushNamedAndRemoveUntil('/main', (r) => false, arguments: 3);
      break;
    case 'shop':
      nav.pushNamedAndRemoveUntil('/main', (r) => false, arguments: 4);
      break;
    default:
      // Unknown screen — just open app to home
      break;
  }
}
