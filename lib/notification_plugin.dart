import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Single shared instance of FlutterLocalNotificationsPlugin.
/// Both NotificationService and LockInNotificationService must use this.
final FlutterLocalNotificationsPlugin sharedNotificationsPlugin =
    FlutterLocalNotificationsPlugin();