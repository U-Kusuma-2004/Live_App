import 'dart:convert';

/// Data model representing a camera video frame sent to the WebSocket server.
class FramePayload {
  final String type;
  final String vehicleId;
  final int timestamp; // Unix epoch in seconds
  final int frameId;
  final String image; // Base64 encoded JPEG frame string

  const FramePayload({
    this.type = 'frame',
    required this.vehicleId,
    required this.timestamp,
    required this.frameId,
    required this.image,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'vehicle_id': vehicleId,
      'timestamp': timestamp,
      'frame_id': frameId,
      'image': image,
    };
  }

  String toJson() => json.encode(toMap());

  factory FramePayload.fromMap(Map<String, dynamic> map) {
    return FramePayload(
      type: map['type'] as String? ?? 'frame',
      vehicleId: map['vehicle_id'] as String? ?? '',
      timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
      frameId: (map['frame_id'] as num?)?.toInt() ?? 0,
      image: map['image'] as String? ?? '',
    );
  }

  factory FramePayload.fromJson(String source) =>
      FramePayload.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'FramePayload(vehicleId: $vehicleId, frameId: $frameId, timestamp: $timestamp, imageBytesLength: ${image.length})';
  }
}
