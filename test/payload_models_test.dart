import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:liveapp/models/ai_event.dart';
import 'package:liveapp/models/frame_payload.dart';
import 'package:liveapp/models/gps_payload.dart';

void main() {
  group('GpsPayload Serialization', () {
    test('Serializes to expected JSON structure matching prompt specification', () {
      const payload = GpsPayload(
        vehicleId: 'TRUCK_001',
        latitude: 17.3850,
        longitude: 78.4867,
        speedKmh: 42.5,
        heading: 180.2,
        accuracyM: 4.2,
        timestamp: 1725770000,
      );

      final map = payload.toMap();
      expect(map['type'], 'gps');
      expect(map['vehicle_id'], 'TRUCK_001');
      expect(map['latitude'], 17.385);
      expect(map['longitude'], 78.4867);
      expect(map['speed_kmh'], 42.5);
      expect(map['heading'], 180.2);
      expect(map['accuracy_m'], 4.2);
      expect(map['timestamp'], 1725770000);

      final jsonString = payload.toJson();
      final decoded = json.decode(jsonString);
      expect(decoded['type'], 'gps');
      expect(decoded['vehicle_id'], 'TRUCK_001');
    });

    test('Deserializes correctly from JSON', () {
      const jsonStr = '''
      {
        "type": "gps",
        "vehicle_id": "TRUCK_002",
        "latitude": 12.9716,
        "longitude": 77.5946,
        "speed_kmh": 65.0,
        "heading": 90.0,
        "accuracy_m": 3.5,
        "timestamp": 1725771234
      }
      ''';

      final payload = GpsPayload.fromJson(jsonStr);
      expect(payload.type, 'gps');
      expect(payload.vehicleId, 'TRUCK_002');
      expect(payload.latitude, 12.9716);
      expect(payload.longitude, 77.5946);
      expect(payload.speedKmh, 65.0);
      expect(payload.heading, 90.0);
      expect(payload.accuracyM, 3.5);
      expect(payload.timestamp, 1725771234);
    });
  });

  group('FramePayload Serialization', () {
    test('Serializes to expected JSON structure matching prompt specification', () {
      const payload = FramePayload(
        vehicleId: 'TRUCK_001',
        timestamp: 1725770000,
        frameId: 12345,
        image: '/9j/4AAQSkZJRgABAQEASABIAAD/...',
      );

      final map = payload.toMap();
      expect(map['type'], 'frame');
      expect(map['vehicle_id'], 'TRUCK_001');
      expect(map['timestamp'], 1725770000);
      expect(map['frame_id'], 12345);
      expect(map['image'], '/9j/4AAQSkZJRgABAQEASABIAAD/...');
    });

    test('Deserializes correctly from JSON', () {
      const jsonStr = '''
      {
        "type": "frame",
        "vehicle_id": "TRUCK_003",
        "timestamp": 1725779999,
        "frame_id": 999,
        "image": "base64sample"
      }
      ''';

      final payload = FramePayload.fromJson(jsonStr);
      expect(payload.vehicleId, 'TRUCK_003');
      expect(payload.frameId, 999);
      expect(payload.image, 'base64sample');
    });
  });

  group('AiEvent Serialization & Parsing', () {
    test('Parses AI Event from server correctly', () {
      const jsonStr = '''
      {
        "type": "ai_event",
        "vehicle_id": "TRUCK_001",
        "event": "DROWSINESS",
        "confidence": 0.94,
        "timestamp": 1725770000
      }
      ''';

      final event = AiEvent.fromJson(jsonStr);
      expect(event.type, 'ai_event');
      expect(event.vehicleId, 'TRUCK_001');
      expect(event.event, 'DROWSINESS');
      expect(event.confidence, 0.94);
      expect(event.formattedConfidence, '94%');
    });
  });
}
