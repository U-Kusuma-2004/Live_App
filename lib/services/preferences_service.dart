import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing local persistence of vehicle configuration.
class PreferencesService {
  static const String _keyVehicleId = 'vehicle_id';
  static const String _keyWebSocketUrl = 'websocket_url';

  static const String defaultVehicleId = 'TRUCK_001';
  static const String defaultWebSocketUrl = 'wss://your-runpod-endpoint.ngrok-free.app/ws';

  /// Loads saved configuration, falling back to defaults if not set.
  static Future<Map<String, String>> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final vehicleId = prefs.getString(_keyVehicleId) ?? defaultVehicleId;
    final webSocketUrl = prefs.getString(_keyWebSocketUrl) ?? defaultWebSocketUrl;
    return {
      'vehicleId': vehicleId,
      'webSocketUrl': webSocketUrl,
    };
  }

  /// Saves the vehicle ID and WebSocket URL locally.
  static Future<void> saveConfig({
    required String vehicleId,
    required String webSocketUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyVehicleId, vehicleId.trim());
    await prefs.setString(_keyWebSocketUrl, webSocketUrl.trim());
  }

  /// Clears stored preferences (utility)
  static Future<void> clearConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyVehicleId);
    await prefs.remove(_keyWebSocketUrl);
  }
}
