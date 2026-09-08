import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/ai_event.dart';
import '../models/frame_payload.dart';
import '../models/gps_payload.dart';
import 'log_service.dart';

enum WebSocketConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

class WebSocketService {
  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _reconnectTimer;

  String? _currentUrl;
  String _vehicleId = 'UNKNOWN';
  bool _shouldBeConnected = false;
  bool _streamStarted = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectDelaySec = 10;

  final ValueNotifier<WebSocketConnectionStatus> statusNotifier =
      ValueNotifier<WebSocketConnectionStatus>(WebSocketConnectionStatus.disconnected);

  final ValueNotifier<String?> errorNotifier = ValueNotifier<String?>(null);

  final StreamController<AiEvent> _aiEventController = StreamController<AiEvent>.broadcast();
  Stream<AiEvent> get aiEventStream => _aiEventController.stream;

  final ValueNotifier<int> framesSentNotifier = ValueNotifier<int>(0);
  final ValueNotifier<int> gpsSentNotifier = ValueNotifier<int>(0);
  final ValueNotifier<AiEvent?> latestAiEventNotifier = ValueNotifier<AiEvent?>(null);

  WebSocketConnectionStatus get status => statusNotifier.value;

  /// True only once the socket is open AND the START_STREAM handshake has been
  /// sent — frame / GPS packets must not go out before that.
  bool get isConnected =>
      statusNotifier.value == WebSocketConnectionStatus.connected && _streamStarted;

  /// Connects to the given WebSocket URL and performs the START_STREAM handshake.
  Future<void> connect(String url, {required String vehicleId}) async {
    _currentUrl = url.trim();
    _vehicleId = vehicleId;
    _shouldBeConnected = true;
    _reconnectAttempts = 0;
    LogService.info('WebSocket', 'Initiating connection to $_currentUrl');
    await _doConnect();
  }

  /// The backend requires this as the very first message on the socket; sending
  /// a frame or GPS packet first makes it reply {"type":"ERROR"} and hang up.
  /// Adjust the shape here if the server expects a different handshake.
  String _startStreamMessage() => json.encode({
        'type': 'START_STREAM',
        'vehicle_id': _vehicleId,
        'timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      });

  Future<void> _doConnect() async {
    if (!_shouldBeConnected || _currentUrl == null || _currentUrl!.isEmpty) return;

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
      final uri = Uri.parse(_currentUrl!);
      final channel = WebSocketChannel.connect(uri);
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

      // Handshake FIRST, then the console may start streaming.
      channel.sink.add(_startStreamMessage());
      _streamStarted = true;
      _reconnectAttempts = 0;
      statusNotifier.value = WebSocketConnectionStatus.connected;
      LogService.wsOut(
        'WebSocket',
        '🟢 Connected — START_STREAM sent for $_vehicleId',
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
    statusNotifier.value = WebSocketConnectionStatus.disconnected;
    if (_shouldBeConnected) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectAttempts++;
    final delaySeconds = (_reconnectAttempts * 2).clamp(1, _maxReconnectDelaySec);
    LogService.warn('WebSocket', 'Scheduling auto-reconnect in $delaySeconds s (attempt $_reconnectAttempts)');
    statusNotifier.value = WebSocketConnectionStatus.reconnecting;

    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () {
      if (_shouldBeConnected) {
        unawaited(_doConnect());
      }
    });
  }

  /// Sends a camera video frame
  bool sendFrame(FramePayload payload) {
    if (!isConnected || _channel == null) {
      LogService.warn('WebSocket', 'Frame #${payload.frameId} dropped (socket not connected)');
      return false;
    }
    try {
      final jsonPayload = payload.toJson();
      _channel!.sink.add(jsonPayload);
      framesSentNotifier.value++;

      final kbSize = (payload.image.length / 1024).toStringAsFixed(1);
      // Detailed API payload log
      LogService.wsOut(
        'WebSocket',
        'Frame #${payload.frameId} sent ($kbSize KB base64)',
        payload: '{"type":"frame","vehicle_id":"${payload.vehicleId}","frame_id":${payload.frameId},"timestamp":${payload.timestamp},"image_len":${payload.image.length}}',
      );
      return true;
    } catch (e, stackTrace) {
      LogService.error('WebSocket', 'Failed to transmit Frame #${payload.frameId}', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Sends a GPS telemetry packet
  bool sendGps(GpsPayload payload) {
    if (!isConnected || _channel == null) {
      LogService.warn('WebSocket', 'GPS packet dropped (socket not connected)');
      return false;
    }
    try {
      final jsonPayload = payload.toJson();
      _channel!.sink.add(jsonPayload);
      gpsSentNotifier.value++;

      // Detailed API payload log
      LogService.wsOut(
        'WebSocket',
        'GPS sent (lat: ${payload.latitude}, lng: ${payload.longitude}, speed: ${payload.speedKmh} km/h)',
        payload: jsonPayload,
      );
      return true;
    } catch (e, stackTrace) {
      LogService.error('WebSocket', 'Failed to transmit GPS telemetry', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Handles inbound JSON messages from RunPod backend
  void _handleInboundMessage(dynamic rawData) {
    try {
      final String text = rawData is String ? rawData : utf8.decode(rawData as List<int>);
      final Map<String, dynamic> jsonMap = json.decode(text) as Map<String, dynamic>;

      final type = jsonMap['type'] as String?;
      if (type != null && type.toUpperCase() == 'ERROR') {
        final message = jsonMap['message']?.toString() ?? 'Unknown server error';
        LogService.warn('WebSocket', 'Server rejected stream: $message');
        errorNotifier.value = message;
      } else if (type == 'ai_event' || jsonMap.containsKey('event')) {
        final event = AiEvent.fromMap(jsonMap);
        latestAiEventNotifier.value = event;
        _aiEventController.add(event);

        // Detailed Response log
        LogService.wsIn(
          'WebSocket',
          '🚨 AI Event: ${event.event} (${event.formattedConfidence}) for ${event.vehicleId}',
          payload: text,
        );
      } else {
        // Generic server response log
        LogService.wsIn('WebSocket', 'Inbound message received: $text', payload: text);
      }
    } catch (e, stackTrace) {
      LogService.error('WebSocket', 'Error parsing inbound message', error: e, stackTrace: stackTrace);
    }
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

  /// Reset transmission counters
  void resetCounters() {
    framesSentNotifier.value = 0;
    gpsSentNotifier.value = 0;
    latestAiEventNotifier.value = null;
    LogService.info('WebSocket', 'Transmission counters reset.');
  }

  void dispose() {
    disconnect();
    _aiEventController.close();
    statusNotifier.dispose();
    errorNotifier.dispose();
    framesSentNotifier.dispose();
    gpsSentNotifier.dispose();
    latestAiEventNotifier.dispose();
  }
}
