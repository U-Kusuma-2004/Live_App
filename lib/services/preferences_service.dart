import 'package:shared_preferences/shared_preferences.dart';

/// Service for managing local persistence of vehicle configuration.
class PreferencesService {
  static const String _keyVehicleId = 'vehicle_id';
  static const String _keyUserId = 'user_id';
  static const String _keyUserName = 'user_name';
  static const String _keyWebSocketUrl = 'websocket_url';

  static const String defaultVehicleId = 'TRUCK_001';
  static const String defaultUserId = '';
  static const String defaultUserName = '';
  static const String defaultWebSocketUrl = 'wss://your-runpod-endpoint.ngrok-free.app/ws';

  /// Loads saved configuration, falling back to defaults if not set.
  static Future<Map<String, String>> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'vehicleId': prefs.getString(_keyVehicleId) ?? defaultVehicleId,
      'userId': prefs.getString(_keyUserId) ?? defaultUserId,
      'userName': prefs.getString(_keyUserName) ?? defaultUserName,
      'webSocketUrl': prefs.getString(_keyWebSocketUrl) ?? defaultWebSocketUrl,
    };
  }

  /// Saves the connection identity and WebSocket URL locally.
  static Future<void> saveConfig({
    required String vehicleId,
    required String userId,
    required String userName,
    required String webSocketUrl,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyVehicleId, vehicleId.trim());
    await prefs.setString(_keyUserId, userId.trim());
    await prefs.setString(_keyUserName, userName.trim());
    await prefs.setString(_keyWebSocketUrl, webSocketUrl.trim());
  }

  /// Clears stored preferences (utility)
  static Future<void> clearConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyVehicleId);
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserName);
    await prefs.remove(_keyWebSocketUrl);
  }
}
