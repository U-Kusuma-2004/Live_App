import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/ai_event.dart';
import 'log_service.dart';

enum WebSocketConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// Talks to the drowsiness-detection backend on `/video`.
///
/// Protocol (from the server):
///   1. Client -> `{"type":"START_STREAM","user_id","user_name","camera_id"}` (JSON text).
///   2. Server -> `{"type":"STREAM_STARTED",...}` on success, or `{"type":"ERROR",...}` + close.
///   3. Client -> raw JPEG bytes, one binary frame per image (NOT JSON, NOT base64).
///   4. Server -> `DETECTION_STATUS` / `DROWSINESS_ALERT` JSON as it analyses frames.
/// There is no GPS channel — sending anything but bytes after the handshake
/// breaks the server's `receive_bytes()` loop.
class WebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;

  String? _currentUrl;
  String _userId = '';
  String _userName = '';
  String _cameraId = '';

  bool _shouldBeConnected = false;
  bool _streamStarted = false;
  bool _fatalError = false;
  int _reconnectAttempts = 0;
  int _inboundCount = 0;
  DateTime _lastNormalLoggedAt = DateTime.fromMillisecondsSinceEpoch(0);
  static const int _maxReconnectDelaySec = 10;

  final ValueNotifier<WebSocketConnectionStatus> statusNotifier =
      ValueNotifier<WebSocketConnectionStatus>(WebSocketConnectionStatus.disconnected);

  final ValueNotifier<String?> errorNotifier = ValueNotifier<String?>(null);

  final StreamController<AiEvent> _aiEventController = StreamController<AiEvent>.broadcast();
  Stream<AiEvent> get aiEventStream => _aiEventController.stream;

  final ValueNotifier<int> framesSentNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> alertsNotifier = ValueNotifier<int>(0);
  final ValueNotifier<AiEvent?> latestAiEventNotifier = ValueNotifier<AiEvent?>(null);

  WebSocketConnectionStatus get status => statusNotifier.value;

  /// True only once the server has acknowledged the stream with STREAM_STARTED.
  /// Frames must not be sent before this.
  bool get isConnected =>
      statusNotifier.value == WebSocketConnectionStatus.connected && _streamStarted;

  /// Connects and performs the START_STREAM handshake, then waits for the
  /// server's STREAM_STARTED acknowledgement before [isConnected] flips true.
  Future<void> connect(
    String url, {
    required String userId,
    required String userName,
    required String cameraId,
  }) async {
    _currentUrl = url.trim();
    _userId = userId.trim();
    _userName = userName.trim();
    _cameraId = cameraId.trim();
    _shouldBeConnected = true;
    _fatalError = false;
    _reconnectAttempts = 0;
    LogService.info('WebSocket', 'Initiating connection to $_currentUrl');
    await _doConnect();
  }

  /// The required first message. All three identity fields must be non-empty or
  /// the server replies {"type":"ERROR"} and closes. Adjust here if the backend
  /// contract changes.
  String _startStreamMessage() => json.encode({
        'type': 'START_STREAM',
        'user_id': _userId,
        'user_name': _userName,
        'camera_id': _cameraId,
      });

  Future<void> _doConnect() async {
    if (!_shouldBeConnected || _fatalError) return;
    if (_currentUrl == null || _currentUrl!.isEmpty) return;

    _cleanupSocket();
    _streamStarted = false;

    if (_reconnectAttempts > 0) {
      statusNotifier.value = WebSocketConnectionStatus.reconnecting;
      LogService.warn('WebSocket', 'Reconnecting to $_currentUrl (attempt $_reconnectAttempts)...');
    } else {
      statusNotifier.value = WebSocketConnectionStatus.connecting;
      LogService.info('WebSocket', 'Connecting to $_currentUrl...');
    }
    errorNotifier.value = null;

    try {
      final channel = WebSocketChannel.connect(Uri.parse(_currentUrl!));
      _channel = channel;

      _subscription = channel.stream.listen(
        _handleInboundMessage,
        onDone: () {
          LogService.warn(
            'WebSocket',
            'Connection closed by remote server (code: ${channel.closeCode ?? 'n/a'}).',
          );
          _handleDisconnect();
        },
        onError: (error, stackTrace) {
          LogService.error('WebSocket', 'Socket stream error', error: error, stackTrace: stackTrace);
          errorNotifier.value = error.toString();
          _handleDisconnect();
        },
        cancelOnError: true,
      );

      // Wait for the real WebSocket upgrade before sending anything.
      await channel.ready;
      if (_channel != channel || !_shouldBeConnected) return; // superseded

      channel.sink.add(_startStreamMessage());
      statusNotifier.value = WebSocketConnectionStatus.connecting;
      LogService.wsOut(
        'WebSocket',
        'START_STREAM sent — waiting for server acknowledgement',
        payload: _startStreamMessage(),
      );
    } catch (e, stackTrace) {
      LogService.error('WebSocket', 'Exception during connection setup', error: e, stackTrace: stackTrace);
      errorNotifier.value = e.toString();
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
    _streamStarted = false;
    if (_fatalError) {
      statusNotifier.value = WebSocketConnectionStatus.error;
      return;
    }
    statusNotifier.value = WebSocketConnectionStatus.disconnected;
    if (_shouldBeConnected) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    final delaySeconds = (_reconnectAttempts * 2).clamp(1, _maxReconnectDelaySec);
    LogService.warn('WebSocket', 'Scheduling auto-reconnect in $delaySeconds s (attempt $_reconnectAttempts)');
    statusNotifier.value = WebSocketConnectionStatus.reconnecting;

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (_shouldBeConnected && !_fatalError) unawaited(_doConnect());
    });
  }

  /// Sends one camera frame as a raw binary JPEG WebSocket message.
  bool sendFrame(Uint8List jpegBytes, int frameId) {
    if (!isConnected || _channel == null) {
      LogService.warn('WebSocket', 'Frame #$frameId dropped (stream not ready)');
      return false;
    }
    try {
      _channel!.sink.add(jpegBytes);
      framesSentNotifier.value++;
      final kb = (jpegBytes.length / 1024).toStringAsFixed(1);
      LogService.wsOut('WebSocket', 'Frame #$frameId sent ($kb KB JPEG, binary)');

      // The server should reply with DETECTION_STATUS as soon as it decodes a
      // frame. Silence after this many frames means it is receiving bytes it
      // can't process (JPEG decode failure, or the model stalled).
      if (framesSentNotifier.value == 40 && _inboundCount == 0) {
        LogService.warn(
          'WebSocket',
          '40 frames sent, no analysis received — check the backend console '
          '(JPEG decode failure or model stall on its side).',
        );
      }
      return true;
    } catch (e, stackTrace) {
      LogService.error('WebSocket', 'Failed to transmit Frame #$frameId', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  void _handleInboundMessage(dynamic rawData) {
    try {
      final String text = rawData is String ? rawData : utf8.decode(rawData as List<int>);
      final Map<String, dynamic> jsonMap = json.decode(text) as Map<String, dynamic>;
      final type = (jsonMap['type'] as String?)?.toUpperCase();
      _inboundCount++;

      switch (type) {
        case 'ERROR':
          final message = jsonMap['message']?.toString() ?? 'Unknown server error';
          LogService.error('WebSocket', 'Server rejected the stream: $message');
          errorNotifier.value = message;
          _fatalError = true; // config problem — retrying won't help
          _shouldBeConnected = false;
          _reconnectTimer?.cancel();
          break;

        case 'STREAM_STARTED':
          _streamStarted = true;
          _reconnectAttempts = 0;
          _inboundCount = 0;
          statusNotifier.value = WebSocketConnectionStatus.connected;
          LogService.wsIn('WebSocket', '🟢 Stream accepted by server', payload: text);
          break;

        case 'DROWSINESS_ALERT':
          final event = AiEvent(
            type: 'ai_event',
            vehicleId: (jsonMap['camera_id'] ?? _cameraId).toString(),
            event: (jsonMap['state'] ?? 'drowsy').toString().toUpperCase() == 'DROWSY'
                ? 'DROWSINESS'
                : (jsonMap['state'] ?? 'ALERT').toString(),
            confidence: 1.0,
            timestamp: _epochSeconds(jsonMap['timestamp']),
          );
          latestAiEventNotifier.value = event;
          _aiEventController.add(event);
          alertsNotifier.value++;
          LogService.wsIn('WebSocket', '🚨 Drowsiness alert for ${event.vehicleId}', payload: text);
          break;

        case 'DETECTION_STATUS':
        default:
          final state = jsonMap['state']?.toString() ?? '';
          if (state == 'normal') {
            latestAiEventNotifier.value = null;
            // Throttle the "driver looks fine" heartbeat so it doesn't flood.
            final now = DateTime.now();
            if (now.difference(_lastNormalLoggedAt).inMilliseconds >= 2000) {
              _lastNormalLoggedAt = now;
              LogService.wsIn(
                'WebSocket',
                '✅ Server analysing frames — driver normal (msg #$_inboundCount)',
                payload: text,
              );
            }
          } else {
            LogService.wsIn('WebSocket', 'Server message: $text', payload: text);
          }
      }
    } catch (e, stackTrace) {
      LogService.error('WebSocket', 'Error parsing inbound message', error: e, stackTrace: stackTrace);
    }
  }

  int _epochSeconds(dynamic ts) {
    if (ts is num) return ts.toInt();
    if (ts is String) {
      final parsed = DateTime.tryParse(ts);
      if (parsed != null) return parsed.millisecondsSinceEpoch ~/ 1000;
    }
    return DateTime.now().millisecondsSinceEpoch ~/ 1000;
  }

  /// Disconnects and stops any reconnection loops.
  Future<void> disconnect() async {
    LogService.info('WebSocket', 'Disconnecting WebSocket channel.');
    _shouldBeConnected = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _cleanupSocket();
    statusNotifier.value = WebSocketConnectionStatus.disconnected;
  }

  void _cleanupSocket() {
    _streamStarted = false;
    _subscription?.cancel();
    _subscription = null;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  /// Reset transmission counters for a fresh session.
  void resetCounters() {
    framesSentNotifier.value = 0;
    alertsNotifier.value = 0;
    latestAiEventNotifier.value = null;
    _fatalError = false;
    LogService.info('WebSocket', 'Transmission counters reset.');
  }

  void dispose() {
    disconnect();
    _aiEventController.close();
    statusNotifier.dispose();
    errorNotifier.dispose();
    framesSentNotifier.dispose();
    alertsNotifier.dispose();
    latestAiEventNotifier.dispose();
  }
}
