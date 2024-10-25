import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show Platform;

class Notifikasi {
  static final FlutterLocalNotificationsPlugin _localNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    if (kIsWeb) {
      _initializeForWeb();
    } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      _initializeForDesktop();
    } else if (Platform.isAndroid || Platform.isIOS) {
      _initializeForMobile();
    }
  }

  static Future<void> _initializeForWeb() async {
    print('Web notification initialized');
  }

  static Future<void> _initializeForDesktop() async {
    print('Desktop notification initialized');
  }

  static Future<void> _initializeForMobile() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('bgnotif');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _localNotificationsPlugin.initialize(initializationSettings);
  }

  static Future<void> showNotification(
      int id, String title, String body) async {
    try {
      if (kIsWeb) {
      } else {
        const AndroidNotificationDetails androidPlatformChannelSpecifics =
            AndroidNotificationDetails(
          'Service',
          'Background Service',
          channelDescription: 'Background Service',
          importance: Importance.max,
          priority: Priority.high,
          showWhen: false,
        );

        const NotificationDetails platformChannelSpecifics =
            NotificationDetails(android: androidPlatformChannelSpecifics);

        await _localNotificationsPlugin.show(
          id,
          title,
          body,
          platformChannelSpecifics,
        );
        print('Local notification shown: $title - $body');
      }
    } catch (e) {
      print('Failed to show local notification: $e');
    }
  }
}

// class Notifikasi {
//   static final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
//       FlutterLocalNotificationsPlugin();

//   static Future<void> initialize() async {
//     const AndroidInitializationSettings initializationSettingsAndroid =
//         AndroidInitializationSettings('bgnotif');

//     const InitializationSettings initializationSettings =
//         InitializationSettings(android: initializationSettingsAndroid);

//     await flutterLocalNotificationsPlugin.initialize(initializationSettings);
//   }

//   static Future<void> showNotification(
//       int id, String title, String body) async {
//     const AndroidNotificationDetails androidPlatformChannelSpecifics =
//         AndroidNotificationDetails(
//       'Service',
//       'Background Service',
//       channelDescription: 'Background Service',
//       importance: Importance.max,
//       priority: Priority.high,
//     );

//     const NotificationDetails platformChannelSpecifics =
//         NotificationDetails(android: androidPlatformChannelSpecifics);

//     await flutterLocalNotificationsPlugin.show(
//       id,
//       title,
//       body,
//       platformChannelSpecifics,
//     );
//   }
// }
