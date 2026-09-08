import 'dart:convert';

/// Data model representing GPS telemetry sent to the WebSocket server.
class GpsPayload {
  final String type;
  final String vehicleId;
  final double latitude;
  final double longitude;
  final double speedKmh;
  final double heading;
  final double accuracyM;
  final int timestamp; // Unix epoch in seconds

  const GpsPayload({
    this.type = 'gps',
    required this.vehicleId,
    required this.latitude,
    required this.longitude,
    required this.speedKmh,
    required this.heading,
    required this.accuracyM,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'vehicle_id': vehicleId,
      'latitude': double.parse(latitude.toStringAsFixed(6)),
      'longitude': double.parse(longitude.toStringAsFixed(6)),
      'speed_kmh': double.parse(speedKmh.toStringAsFixed(1)),
      'heading': double.parse(heading.toStringAsFixed(1)),
      'accuracy_m': double.parse(accuracyM.toStringAsFixed(1)),
      'timestamp': timestamp,
    };
  }

  String toJson() => json.encode(toMap());

  factory GpsPayload.fromMap(Map<String, dynamic> map) {
    return GpsPayload(
      type: map['type'] as String? ?? 'gps',
      vehicleId: map['vehicle_id'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
      speedKmh: (map['speed_kmh'] as num?)?.toDouble() ?? 0.0,
      heading: (map['heading'] as num?)?.toDouble() ?? 0.0,
      accuracyM: (map['accuracy_m'] as num?)?.toDouble() ?? 0.0,
      timestamp: (map['timestamp'] as num?)?.toInt() ?? 0,
    );
  }

  factory GpsPayload.fromJson(String source) =>
      GpsPayload.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  String toString() {
    return 'GpsPayload(vehicleId: $vehicleId, lat: $latitude, lng: $longitude, speed: $speedKmh km/h, heading: $heading°, accuracy: $accuracyM m, time: $timestamp)';
  }
}
