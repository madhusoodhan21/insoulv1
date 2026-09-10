import 'dart:convert';

import 'package:share_plus/share_plus.dart';

Future<void> downloadGaitSerialLog(List<String> lines) async {
  final content = lines.isEmpty
      ? 'No serial input captured.'
      : lines.join('\n');
  await SharePlus.instance.share(
    ShareParams(
      files: [
        XFile.fromData(
          utf8.encode(content),
          name: 'insoul-gait-visualizer.txt',
          mimeType: 'text/plain',
        ),
      ],
    ),
  );
}
