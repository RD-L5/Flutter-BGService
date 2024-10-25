import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'service/notif.dart';
import 'login/login.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Notifikasi.initialize();

  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await initializeService();
  }
  runApp(const MyApp());
}

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      isForegroundMode: true,
      autoStart: true,
      foregroundServiceNotificationId: 888,
      initialNotificationTitle: 'Background Service',
      initialNotificationContent: 'Running...',
    ),
    iosConfiguration: IosConfiguration(
      onForeground: onStart,
      onBackground: onIosBackground,
      autoStart: true,
    ),
  );

  await service.startService();
}

@pragma('vm:entry-point')
bool onIosBackground(ServiceInstance service) {
  WidgetsFlutterBinding.ensureInitialized();
  print('iOS background fetch');
  return true;
}

class LogStorage {
  static final LogStorage _instance = LogStorage._internal();
  factory LogStorage() => _instance;
  LogStorage._internal();

  Future<void> writeLog(String message) async {
    try {
      final logFile = await _getLogFile();
      await logFile.writeAsString('$message\n', mode: FileMode.append);
    } catch (e) {
      print('Error writing log: $e');
    }
  }

  Future<String> readLogs() async {
    try {
      final logFile = await _getLogFile();
      return await logFile.exists() ? await logFile.readAsString() : '';
    } catch (e) {
      print('Error reading logs: $e');
      return '';
    }
  }

  Future<void> clearLogs() async {
    try {
      final logFile = await _getLogFile();
      if (await logFile.exists()) {
        await logFile.writeAsString('');
      }
    } catch (e) {
      print('Error clearing logs: $e');
    }
  }

  Future<File> _getLogFile() async {
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/logs.txt');
  }
}

Future<void> ambildataserver(ServiceInstance service) async {
  const String url = 'http://192.168.0.8:80/data';
  final client = http.Client();

  try {
    final response = await client
        .get(
          Uri.parse(url),
        )
        .timeout(const Duration(seconds: 1));

    if (response.statusCode == 200) {
      await _handleResponse(response.body, service);
    }
  } on TimeoutException {
    print('Request timed out');
  } catch (e) {
    print('Error fetching data: $e');
  } finally {
    client.close();
  }
}

Future<void> _processItem(
    Map<String, dynamic> item, ServiceInstance service) async {
  final endDeviceIds = item['end_device_ids'];

  if (endDeviceIds == null) {
    print('Invalid item format: missing end_device_ids');
    return;
  }

  String deviceID = endDeviceIds['device_id']?.toString() ?? 'No device ID';
  if (deviceID.startsWith('id-')) {
    deviceID = deviceID.substring(3);
  }

  if (deviceID.isNotEmpty && deviceID != 'No device ID') {
    final prefs = await SharedPreferences.getInstance();
    final lastDeviceAlert = prefs.getString('lastDeviceAlert');
    if (lastDeviceAlert != deviceID) {
      await Future.wait([
        _saveDeviceAlert(deviceID),
        _logDeviceAlert(deviceID),
      ]);
      _sendNotification(deviceID);
      service.invoke('Device', {"ID": deviceID});
      await prefs.setString('lastDeviceAlert', deviceID);
    }
  }
}

Future<void> _handleResponse(
    String responseBody, ServiceInstance service) async {
  try {
    final List<dynamic> jsonData =
        json.decode(responseBody);

    for (var item in jsonData) {
      await _processItem(item, service);
    }
  } catch (e) {
    print('Error processing response: $e');
  }
}

Future<void> _saveDeviceAlert(String deviceID) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('deviceAlert', deviceID);
  } catch (e) {
    print('Error saving device alert: $e');
  }
}

Future<void> _logDeviceAlert(String deviceID) async {
  try {
    final logStorage = LogStorage();
    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
    await logStorage.writeLog('$deviceID : $formattedDate');
  } catch (e) {
    print('Error logging device alert: $e');
  }
}

Future<void> _sendNotification(String deviceID) async {
  try {
    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
    await Notifikasi.showNotification(
      0,
      'Device',
      '$deviceID : $formattedDate',
    );
  } catch (e) {
    print('Error sending notification: $e');
  }
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  Timer? periodicTimer;
  periodicTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
    try {
      await ambildataserver(service);
    } catch (e) {
      print('Error in periodic task: $e');
    }
  });
  service.on('stop').listen((event) {
    periodicTimer?.cancel();
    print('Background service stopped');
  });
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}
