import 'dart:html' as html;

Future<void> downloadGaitSerialLog(List<String> lines) async {
  final content = lines.isEmpty
      ? 'No serial input captured.'
      : lines.join('\n');
  final blob = html.Blob([content], 'text/plain;charset=utf-8');
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..download = 'insoul-gait-visualizer.txt'
    ..click();
  html.Url.revokeObjectUrl(url);
}
