import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';

enum LogLevel {
  info,
  wsOut,
  wsIn,
  gps,
  camera,
  warn,
  error,
}

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String tag;
  final String message;
  final String? payload;
  final Object? error;
  final StackTrace? stackTrace;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.payload,
    this.error,
    this.stackTrace,
  });

  String get formattedTime => DateFormat('HH:mm:ss.SSS').format(timestamp);

  String get levelPrefix {
    switch (level) {
      case LogLevel.info:
        return 'ℹ️ [INFO]';
      case LogLevel.wsOut:
        return '📤 [WS_OUT]';
      case LogLevel.wsIn:
        return '📥 [WS_IN]';
      case LogLevel.gps:
        return '🛰️ [GPS]';
      case LogLevel.camera:
        return '📷 [CAM]';
      case LogLevel.warn:
        return '⚠️ [WARN]';
      case LogLevel.error:
        return '❌ [EXCEPTION]';
    }
  }

  @override
  String toString() {
    final buffer = StringBuffer('$formattedTime $levelPrefix [$tag] $message');
    if (payload != null && payload!.isNotEmpty) {
      buffer.write('\n   Payload: $payload');
    }
    if (error != null) {
      buffer.write('\n   Error: $error');
    }
    if (stackTrace != null) {
      buffer.write('\n   StackTrace: $stackTrace');
    }
    return buffer.toString();
  }
}

/// Centralized diagnostic logging service for monitoring network payloads,
/// sensor events, AI responses, and exceptions.
class LogService {
  static const int maxLogEntries = 300;
  static final List<LogEntry> _logs = [];

  static final ValueNotifier<List<LogEntry>> logsNotifier =
      ValueNotifier<List<LogEntry>>([]);

  static final StreamController<LogEntry> _streamController =
      StreamController<LogEntry>.broadcast();

  static Stream<LogEntry> get logStream => _streamController.stream;

  static void info(String tag, String message) {
    _add(LogLevel.info, tag, message);
  }

  static void wsOut(String tag, String message, {String? payload}) {
    _add(LogLevel.wsOut, tag, message, payload: payload);
  }

  static void wsIn(String tag, String message, {String? payload}) {
    _add(LogLevel.wsIn, tag, message, payload: payload);
  }

  static void gps(String tag, String message, {String? payload}) {
    _add(LogLevel.gps, tag, message, payload: payload);
  }

  static void camera(String tag, String message, {String? payload}) {
    _add(LogLevel.camera, tag, message, payload: payload);
  }

  static void warn(String tag, String message) {
    _add(LogLevel.warn, tag, message);
  }

  static void error(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) {
    _add(
      LogLevel.error,
      tag,
      message,
      error: error,
      stackTrace: stackTrace,
    );
  }

  static void _add(
    LogLevel level,
    String tag,
    String message, {
    String? payload,
    Object? error,
    StackTrace? stackTrace,
  }) {
    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      tag: tag,
      message: message,
      payload: payload,
      error: error,
      stackTrace: stackTrace,
    );

    _logs.add(entry);
    if (_logs.length > maxLogEntries) {
      _logs.removeAt(0);
    }

    // Print to terminal console immediately.
    debugPrint(entry.toString());

    // Notifying listeners synchronously is unsafe if _add is called while a
    // frame is being built/laid out/painted (e.g. from FlutterError.onError
    // reporting a layout overflow). In that case, defer to after the frame.
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks ||
        phase == SchedulerPhase.transientCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) => _notify(entry));
    } else {
      _notify(entry);
    }
  }

  static void _notify(LogEntry entry) {
    logsNotifier.value = List.unmodifiable(_logs);
    if (!_streamController.isClosed) {
      _streamController.add(entry);
    }
  }

  static void clear() {
    _logs.clear();
    logsNotifier.value = [];
  }

  static String exportLogsAsString() {
    return _logs.map((e) => e.toString()).join('\n');
  }
}
