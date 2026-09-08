import 'dart:convert';

/// Data model representing an AI event received from the RunPod WebSocket server.
class AiEvent {
  final String type;
  final String vehicleId;
  final String event;
  final double confidence;
  final int timestamp;

  const AiEvent({
    this.type = 'ai_event',
    required this.vehicleId,
    required this.event,
    required this.confidence,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'vehicle_id': vehicleId,
      'event': event,
      'confidence': confidence,
      'timestamp': timestamp,
    };
  }

  String toJson() => json.encode(toMap());

  factory AiEvent.fromMap(Map<String, dynamic> map) {
    return AiEvent(
      type: map['type'] as String? ?? 'ai_event',
      vehicleId: map['vehicle_id'] as String? ?? '',
      event: map['event'] as String? ?? 'UNKNOWN_EVENT',
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0.0,
      timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
    );
  }

  factory AiEvent.fromJson(String source) =>
      AiEvent.fromMap(json.decode(source) as Map<String, dynamic>);

  String get formattedConfidence => '${(confidence * 100).toStringAsFixed(0)}%';

  @override
  String toString() {
    return 'AiEvent(vehicleId: $vehicleId, event: $event, confidence: $confidence, timestamp: $timestamp)';
  }
}
