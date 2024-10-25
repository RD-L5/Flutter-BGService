import 'dart:html' as html;
import 'package:intl/intl.dart';

String logContent = '';
String deviceAlert = '';
void saveLogToFile() {
  var now = DateTime.now();
  var formattedDate = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
  final newLogEntry = '$deviceAlert : $formattedDate\n';
  logContent += newLogEntry;
}

void downloadLogFile() {
  final blob = html.Blob([logContent], 'text/plain');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', 'log.txt')
    ..style.display = 'none';

  html.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
