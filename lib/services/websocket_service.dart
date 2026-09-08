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
  bool _shouldBeConnected = false;
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
  bool get isConnected => statusNotifier.value == WebSocketConnectionStatus.connected;

  /// Connects to the given WebSocket URL.
  Future<void> connect(String url) async {
    _currentUrl = url.trim();
    _shouldBeConnected = true;
    _reconnectAttempts = 0;
    LogService.info('WebSocket', 'Initiating connection to $_currentUrl');
    _doConnect();
  }

  void _doConnect() {
    if (!_shouldBeConnected || _currentUrl == null || _currentUrl!.isEmpty) return;

    _cleanupSocket();

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
      _channel = WebSocketChannel.connect(uri);

      // Listen for socket connection & messages
      _subscription = _channel!.stream.listen(
        (data) {
          if (statusNotifier.value != WebSocketConnectionStatus.connected) {
            statusNotifier.value = WebSocketConnectionStatus.connected;
            _reconnectAttempts = 0;
            LogService.info('WebSocket', '🟢 Connected successfully to $_currentUrl');
          }
          _handleInboundMessage(data);
        },
        onDone: () {
          LogService.warn('WebSocket', 'Connection closed by remote server.');
          _handleDisconnect();
        },
        onError: (error, stackTrace) {
          LogService.error('WebSocket', 'Socket stream error', error: error, stackTrace: stackTrace);
          errorNotifier.value = error.toString();
          _handleDisconnect();
        },
        cancelOnError: true,
      );

      // In web_socket_channel, stream listen triggers connect
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_shouldBeConnected && statusNotifier.value == WebSocketConnectionStatus.connecting) {
          statusNotifier.value = WebSocketConnectionStatus.connected;
          LogService.info('WebSocket', '🟢 Handshake established with $_currentUrl');
        }
      });
    } catch (e, stackTrace) {
      LogService.error('WebSocket', 'Exception during connection setup', error: e, stackTrace: stackTrace);
      errorNotifier.value = e.toString();
      _handleDisconnect();
    }
  }

  void _handleDisconnect() {
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
        _doConnect();
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
      if (type == 'ai_event' || jsonMap.containsKey('event')) {
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
