import 'dart:html' as html;

void downloadDashboardReport(String content) {
  final blob = html.Blob([content], 'text/html');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..download = 'insoul-gait-report.html'
    ..click();
  html.Url.revokeObjectUrl(url);
}