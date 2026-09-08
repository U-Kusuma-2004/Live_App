import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/config_screen.dart';
import 'services/log_service.dart';

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

  // Set system UI styling for seamless edge-to-edge dark theme
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0A0E17),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  LogService.info('Bootstrap', '🚀 LiveApp Initialized with Diagnostic Monitoring.');
  runApp(const LiveCameraPocApp());
}

class LiveCameraPocApp extends StatelessWidget {
  const LiveCameraPocApp({super.key});

  @override
  Widget build(BuildContext context) {
    const bgDark = Color(0xFF0A0E17);
    const surfaceDark = Color(0xFF131B2A);
    const primaryCyan = Color(0xFF00E5FF);

    return MaterialApp(
      title: 'Vehicle Camera POC',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: bgDark,
        colorScheme: const ColorScheme.dark(
          primary: primaryCyan,
          secondary: Color(0xFF00F5A0),
          surface: surfaceDark,
          error: Color(0xFFFF3366),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: surfaceDark,
          foregroundColor: Colors.white,
          elevation: 0,
          centerTitle: false,
        ),
        fontFamily: 'Roboto',
      ),
      home: const ConfigScreen(),
    );
  }
}
