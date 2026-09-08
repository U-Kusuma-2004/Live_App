import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../models/gps_payload.dart';
import 'log_service.dart';

enum GpsStatus {
  initializing,
  ready,
  streaming,
  denied,
  disabled,
  error,
}

class GpsService {
  StreamSubscription<Position>? _positionSubscription;
  Timer? _oneSecTimer;

  final ValueNotifier<GpsStatus> statusNotifier =
      ValueNotifier<GpsStatus>(GpsStatus.initializing);
  final ValueNotifier<Position?> currentPositionNotifier =
      ValueNotifier<Position?>(null);
  final ValueNotifier<double> speedKmhNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<double> headingNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<double> accuracyNotifier = ValueNotifier<double>(0.0);

  bool _isStreaming = false;

  /// Starts listening to GPS sensor updates.
  Future<void> initializeGps() async {
    LogService.info('GPS', 'Initializing location services and sensor streams...');
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        LogService.warn('GPS', 'Location service is disabled on the device.');
        statusNotifier.value = GpsStatus.disabled;
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        LogService.info('GPS', 'Requesting location permission...');
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          LogService.warn('GPS', 'Location permission was denied.');
          statusNotifier.value = GpsStatus.denied;
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        LogService.error('GPS', 'Location permission permanently denied.');
        statusNotifier.value = GpsStatus.denied;
        return;
      }

      // Fetch initial position
      try {
        final lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          LogService.gps('GPS', 'Last known fix: ${lastKnown.latitude}, ${lastKnown.longitude}');
          _updatePositionData(lastKnown);
        }
        final initialPos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 4),
          ),
        );
        LogService.gps('GPS', 'Initial fix acquired: lat=${initialPos.latitude}, lng=${initialPos.longitude}, acc=±${initialPos.accuracy.toStringAsFixed(1)}m');
        _updatePositionData(initialPos);
      } catch (e) {
        LogService.warn('GPS', 'Quick initial fix timed out, awaiting stream.');
      }

      // Continuous high-precision position stream
      const locationSettings = LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
      );

      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      ).listen(
        (Position position) {
          _updatePositionData(position);
        },
        onError: (e, stackTrace) {
          LogService.error('GPS', 'GPS Stream error occurred', error: e, stackTrace: stackTrace);
        },
      );

      statusNotifier.value = GpsStatus.ready;
      LogService.info('GPS', 'GPS Service ready and streaming sensor data.');
    } catch (e, stackTrace) {
      LogService.error('GPS', 'Failed to initialize GPS service', error: e, stackTrace: stackTrace);
      statusNotifier.value = GpsStatus.error;
    }
  }

  void _updatePositionData(Position pos) {
    currentPositionNotifier.value = pos;
    // Speed in Position is m/s, convert to km/h (speed * 3.6)
    final kmh = pos.speed > 0 ? (pos.speed * 3.6) : 0.0;
    speedKmhNotifier.value = kmh;
    headingNotifier.value = pos.heading >= 0 ? pos.heading : 0.0;
    accuracyNotifier.value = pos.accuracy;
  }

  /// Starts periodic 1-second transmission callback
  void startTransmission({
    required String vehicleId,
    required void Function(GpsPayload payload) onGpsPacket,
  }) {
    _isStreaming = true;
    statusNotifier.value = GpsStatus.streaming;
    LogService.gps('GPS', 'Started 1 Hz periodic GPS transmission loop');

    _oneSecTimer?.cancel();
    _oneSecTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isStreaming) return;

      final pos = currentPositionNotifier.value;
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      final payload = GpsPayload(
        vehicleId: vehicleId,
        latitude: pos?.latitude ?? 0.0,
        longitude: pos?.longitude ?? 0.0,
        speedKmh: speedKmhNotifier.value,
        heading: headingNotifier.value,
        accuracyM: accuracyNotifier.value,
        timestamp: nowSec,
      );

      onGpsPacket(payload);
    });
  }

  /// Stops transmission loop but keeps GPS sensor warmed up
  void stopTransmission() {
    _isStreaming = false;
    _oneSecTimer?.cancel();
    _oneSecTimer = null;
    statusNotifier.value = GpsStatus.ready;
    LogService.gps('GPS', 'Stopped GPS transmission loop');
  }

  void dispose() {
    stopTransmission();
    _positionSubscription?.cancel();
    _positionSubscription = null;
    statusNotifier.dispose();
    currentPositionNotifier.dispose();
    speedKmhNotifier.dispose();
    headingNotifier.dispose();
    accuracyNotifier.dispose();
  }
}
