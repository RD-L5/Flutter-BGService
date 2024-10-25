import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'service/logweb.dart' if (dart.library.io) 'service/logwindow.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'dart:convert';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  static const int inactivityThreshold = 5; // seconds
  static const String apiUrl = 'http://192.168.0.8:80/data'; //http://202.157.187.108:3000/data http://192.168.0.8:80/data
  static const Duration timeoutDuration = Duration(seconds: 10);
  static const Duration fetchInterval = Duration(seconds: 1);

  Timer? _dataFetchTimer;
  Timer? _inactivityTimer;
  List<String> _logs = [];
  String? _deviceAlert;
  String? _lastSavedAlert;
  DateTime? _lastReceivedTime;
  bool _isLoading = false;

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      await _loadLogs();
      _startTimers();
    } catch (e) {
      _handleError('Initialization error: $e');
    }
  }

  void _startTimers() {
    _dataFetchTimer?.cancel();
    _inactivityTimer?.cancel();

    _dataFetchTimer =
        Timer.periodic(fetchInterval, (_) => _fetchDataFromServer());
    _inactivityTimer = Timer.periodic(fetchInterval, (_) => _checkInactivity());
  }

  Future<void> _fetchDataFromServer() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
     // _errorMessage = null;
    });

    try {
      final response =
          await http.get(Uri.parse(apiUrl)).timeout(timeoutDuration);

      if (!mounted) return;

      if (response.statusCode == 200) {
        await _processServerResponse(response.body);
      } else {
        throw HttpException('Server error: ${response.statusCode}');
      }
    } on TimeoutException {
      _handleError('Connection timeout');
    } on HttpException catch (e) {
      _handleError(e.message);
    } on FormatException {
      _handleError('Invalid data format');
    } catch (e) {
      _handleError('Unexpected error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _processServerResponse(String responseBody) async {
    try {
      final dynamic jsonData = json.decode(responseBody);

      // Handle both List and Map response types
      final data = jsonData is List ? jsonData.first : jsonData;
      final endDeviceIds = data['end_device_ids'];
      String deviceId = endDeviceIds['device_id']?.toString() ?? 'No device ID';

      deviceId = deviceId.replaceFirst(RegExp(r'^id-'), '');

      if (mounted) {
        setState(() {
          _deviceAlert = deviceId;
          _lastReceivedTime = DateTime.now();
          //_errorMessage = null;
        });
      }

      await _saveDeviceAlert();
    } catch (e) {
      throw FormatException('Invalid data structure: $e');
    }
  }

  void _handleError(String message) {
    debugPrint('Error: $message');
    if (mounted) {
      //setState(() =>  = message);
    }
  }

  void _checkInactivity() {
    if (_lastReceivedTime == null) return;

    final inactiveSeconds =
        DateTime.now().difference(_lastReceivedTime!).inSeconds;

    if (inactiveSeconds > inactivityThreshold) {
      _logInactiveStatus();
    }
  }

  Future<void> _logInactiveStatus() async {
    if (_deviceAlert == null || _deviceAlert == _lastSavedAlert) return;

    final formattedDate =
        DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final logEntry = 'Nonaktif $_deviceAlert : $formattedDate';

    await _addLogEntry(logEntry);
    _lastSavedAlert = _deviceAlert;
  }

  Future<void> _saveDeviceAlert() async {
    if (_deviceAlert == null || _deviceAlert == _lastSavedAlert) return;

    final formattedDate =
        DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    final logEntry = '$_deviceAlert : $formattedDate';

    await _addLogEntry(logEntry);
    _lastSavedAlert = _deviceAlert;
  }

  Future<void> _addLogEntry(String logEntry) async {
    if (!mounted) return;

    setState(() {
      _logs.add(logEntry);
    });

    await _saveLogs();

    // Auto-scroll to the latest log
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _loadLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedLogs = prefs.getStringList('logs');

      if (mounted) {
        setState(() {
          _logs = savedLogs ?? [];
          _lastSavedAlert =
              _logs.isNotEmpty ? _logs.last.split(' : ')[0] : null;
        });
      }
    } catch (e) {
      _handleError('Error loading logs: $e');
    }
  }

  Future<void> _saveLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('logs', _logs);
    } catch (e) {
      _handleError('Error saving logs: $e');
    }
  }

  Future<void> _saveLogsToFile() async {
    try {
      final selectedPath = await FilePicker.platform.getDirectoryPath();
      if (selectedPath == null) {
        _showSnackBar('No directory selected');
        return;
      }

      final now = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final file = File('$selectedPath/logs_$now.txt');
      await file.writeAsString(_logs.join('\n'));
      _showSnackBar('Logs saved to ${file.path}');
    } catch (e) {
      _showSnackBar('Error saving logs: $e');
    }
  }

  Future<void> _clearLogs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('logs');

      if (mounted) {
        setState(() {
          _logs.clear();
          _lastSavedAlert = null;
        });
      }
      _showSnackBar('Logs cleared successfully');
    } catch (e) {
      _handleError('Error clearing logs: $e');
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _dataFetchTimer?.cancel();
    _inactivityTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Background Service'),
        backgroundColor: Colors.blue.shade700,
      ),
      drawer: _buildDrawer(),
      body: _buildBody(),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const UserAccountsDrawerHeader(
            currentAccountPicture: CircleAvatar(
              backgroundImage: AssetImage('assets/images/preson.png'),
            ),
            accountEmail: Text('email@example.com'),
            accountName: Text('Name', style: TextStyle(fontSize: 24.0)),
            decoration: BoxDecoration(color: Colors.black87),
          ),
          _buildLogsExpansionTile(),
          _buildDownloadButton(),
          _buildClearLogsButton(),
        ],
      ),
    );
  }

  Widget _buildLogsExpansionTile() {
    return ExpansionTile(
      leading: const Icon(Icons.article),
      title: const Text('Logs', style: TextStyle(fontSize: 20.0)),
      children: _logs.map((log) => ListTile(title: Text(log))).toList(),
    );
  }

  Widget _buildDownloadButton() {
    return ListTile(
      leading: const Icon(Icons.download),
      title: const Text('Download Logs'),
      onTap: () {
        Navigator.pop(context);
        if (kIsWeb || Platform.isWindows) {
          downloadLogFile();
        } else if (Platform.isAndroid) {
          _saveLogsToFile();
        }
      },
    );
  }

  Widget _buildClearLogsButton() {
    return ListTile(
      leading: const Icon(Icons.delete),
      title: const Text('Clear Logs'),
      onTap: () => _showClearLogsDialog(),
    );
  }

  void _showClearLogsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text('Are you sure you want to clear all logs?'),
        actions: [
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
          TextButton(
            child: const Text('Clear'),
            onPressed: () {
              _clearLogs();
              Navigator.pop(context);
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text(
            'Device',
            style: TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            _deviceAlert ?? 'No Data',
            style: const TextStyle(
              color: Colors.blue,
              fontSize: 36,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
