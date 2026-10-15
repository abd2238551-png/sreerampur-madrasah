import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui';

import 'core/app_logger.dart';
import 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(AppLogger.write(details.exception, details.stack ?? StackTrace.current));
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(AppLogger.write(error, stack));
    return true;
  };
  runApp(const MadrasaApp());
}
