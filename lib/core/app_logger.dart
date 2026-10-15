import 'dart:io';

import 'package:path/path.dart' as p;

import 'app_paths.dart';

class AppLogger {
  AppLogger._();

  static Future<void> write(Object error, StackTrace stack) async {
    try {
      final root = AppPaths.dataRoot;
      if (root == null) return;
      final file = File(p.join(root, 'reports', 'technical.log'));
      await file.parent.create(recursive: true);
      await file.writeAsString(
        '\n[${DateTime.now().toIso8601String()}] $error\n$stack\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {
      // Logging must never cause a second application failure.
    }
  }
}
