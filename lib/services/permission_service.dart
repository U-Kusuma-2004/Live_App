import 'package:permission_handler/permission_handler.dart';
import 'log_service.dart';

class PermissionCheckResult {
  final bool isCameraGranted;
  final bool isLocationGranted;
  final String? errorMessage;

  const PermissionCheckResult({
    required this.isCameraGranted,
    required this.isLocationGranted,
    this.errorMessage,
  });

  bool get isAllGranted => isCameraGranted && isLocationGranted;
}

/// Handles checking and requesting necessary hardware permissions.
class PermissionService {
  /// Requests camera and location permissions.
  static Future<PermissionCheckResult> requestPermissions() async {
    LogService.info('Permissions', 'Requesting CAMERA & LOCATION permissions...');
    Map<Permission, PermissionStatus> statuses = await [
      Permission.camera,
      Permission.locationWhenInUse,
    ].request();

    final cameraGranted = statuses[Permission.camera]?.isGranted ?? false;
    final locationGranted = statuses[Permission.locationWhenInUse]?.isGranted ?? false;

    LogService.info(
      'Permissions',
      'Result -> Camera: ${statuses[Permission.camera]?.name}, Location: ${statuses[Permission.locationWhenInUse]?.name}',
    );

    String? error;
    if (!cameraGranted && !locationGranted) {
      error = 'Camera and Location permissions are required for live streaming & telemetry.';
      LogService.warn('Permissions', error);
    } else if (!cameraGranted) {
      error = 'Camera permission is required to stream video.';
      LogService.warn('Permissions', error);
    } else if (!locationGranted) {
      error = 'Location permission is required for vehicle GPS & speed.';
      LogService.warn('Permissions', error);
    }

    return PermissionCheckResult(
      isCameraGranted: cameraGranted,
      isLocationGranted: locationGranted,
      errorMessage: error,
    );
  }

  /// Checks current permission status without prompting if already determined.
  static Future<PermissionCheckResult> checkPermissions() async {
    final cameraStatus = await Permission.camera.status;
    final locationStatus = await Permission.locationWhenInUse.status;

    LogService.info(
      'Permissions',
      'Current status -> Camera: ${cameraStatus.name}, Location: ${locationStatus.name}',
    );

    return PermissionCheckResult(
      isCameraGranted: cameraStatus.isGranted,
      isLocationGranted: locationStatus.isGranted,
    );
  }

  /// Opens app settings if permissions were permanently denied.
  static Future<bool> openSettings() async {
    LogService.info('Permissions', 'Opening system app settings.');
    return await openAppSettings();
  }
}
