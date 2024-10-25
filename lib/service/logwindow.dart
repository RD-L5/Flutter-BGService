import 'dart:io' as io; // Import for file handling on non-web platforms
import 'package:intl/intl.dart';

// Variable to store log content in memory
String logContent = '';
String deviceAlert = '';
// Function to save the counter log to a file
void saveLogToFile() {
  var now = DateTime.now();
  var formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
  final newLogEntry = '$deviceAlert : $formattedDate\n';
  try {
    // Append the new log entry to log.txt file
    final file = io.File('log.txt');
    file.writeAsStringSync(newLogEntry, mode: io.FileMode.append);
    logContent += newLogEntry; // Keep track of the log in memory as well
    print('Log saved to log.txt');
  } catch (e) {
    print('Error writing to file: $e');
  }
}

// Function to download the log file (for Windows, just open the log file)
void downloadLogFile() {
  try {
    // In Windows, you can simply open the log file using the default text editor
    final file = io.File('log.txt');
    if (file.existsSync()) {
      io.Process.run(
          'notepad.exe', ['log.txt']); // Open the log file in Notepad
      print('Log file opened in Notepad');
    } else {
      print('No log file found to open.');
    }
  } catch (e) {
    print('Error opening the file: $e');
  }
}
