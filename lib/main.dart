import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/config_screen.dart';
import 'services/log_service.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Top-level Flutter error handler for exception monitoring
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    LogService.error(
      'FlutterFramework',
      details.exceptionAsString(),
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  // Top-level Platform & Async error handler
  PlatformDispatcher.instance.onError = (error, stack) {
    LogService.error('Platform', 'Unhandled async platform exception', error: error, stackTrace: stack);
    return true;
  };

  // Edge-to-edge, dark icons on the light instrument-panel surface.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  LogService.info('Bootstrap', '🚀 LiveApp Initialized with Diagnostic Monitoring.');
  runApp(const LiveCameraPocApp());
}

class LiveCameraPocApp extends StatelessWidget {
  const LiveCameraPocApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fleet Live Console',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const ConfigScreen(),
    );
  }
}
