import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../models/ai_event.dart';
import '../models/frame_payload.dart';
import '../models/gps_payload.dart';
import '../services/camera_stream_service.dart';
import '../services/gps_service.dart';
import '../services/log_service.dart';
import '../services/permission_service.dart';
import '../services/websocket_service.dart';
import '../widgets/ai_event_banner.dart';
import '../widgets/live_log_console.dart';
import '../widgets/status_badge.dart';
import '../widgets/telemetry_tile.dart';

class LiveStreamScreen extends StatefulWidget {
  final String vehicleId;
  final String webSocketUrl;

  const LiveStreamScreen({
    super.key,
    required this.vehicleId,
    required this.webSocketUrl,
  });

  @override
  State<LiveStreamScreen> createState() => _LiveStreamScreenState();
}

class _LiveStreamScreenState extends State<LiveStreamScreen> {
  final CameraStreamService _cameraService = CameraStreamService();
  final GpsService _gpsService = GpsService();
  final WebSocketService _wsService = WebSocketService();

  bool _isPermissionsGranted = false;
  String? _permissionError;
  bool _isInitializing = true;
  bool _isStreaming = false;
  bool _showLogConsole = true;

  @override
  void initState() {
    super.initState();
    LogService.info('App', 'Entered LiveStreamScreen (Vehicle: "${widget.vehicleId}", URL: "${widget.webSocketUrl}")');
    _bootstrapServices();
  }

  Future<void> _bootstrapServices() async {
    setState(() {
      _isInitializing = true;
      _permissionError = null;
    });

    // 1. Request runtime permissions
    final permissionResult = await PermissionService.requestPermissions();
    if (!permissionResult.isAllGranted) {
      if (mounted) {
        setState(() {
          _isPermissionsGranted = false;
          _permissionError = permissionResult.errorMessage ?? 'Permissions denied.';
          _isInitializing = false;
        });
      }
      return;
    }

    if (!mounted) return;
    setState(() => _isPermissionsGranted = true);

    // 2. Initialize Camera and GPS concurrently
    await Future.wait([
      _cameraService.initializeCamera(),
      _gpsService.initializeGps(),
    ]);

    if (mounted) {
      setState(() => _isInitializing = false);
      LogService.info('App', 'Camera & GPS initialization complete. Ready for streaming.');
    }
  }

  /// START streaming camera + GPS over WebSocket
  Future<void> _onStart() async {
    if (_isStreaming) return;

    LogService.info('App', 'User clicked START streaming button');
    setState(() => _isStreaming = true);
    _wsService.resetCounters();

    // 1. Connect to WebSocket
    await _wsService.connect(widget.webSocketUrl);

    // 2. Start Camera Frame Streaming (~10 FPS)
    await _cameraService.startStreaming(
      vehicleId: widget.vehicleId,
      onFrame: (FramePayload framePayload) {
        _wsService.sendFrame(framePayload);
      },
    );

    // 3. Start GPS Telemetry Transmission (1 Hz)
    _gpsService.startTransmission(
      vehicleId: widget.vehicleId,
      onGpsPacket: (GpsPayload gpsPayload) {
        _wsService.sendGps(gpsPayload);
      },
    );
  }

  /// STOP streaming camera + GPS, cleanly close WebSocket, keep viewfinder alive
  Future<void> _onStop() async {
    if (!_isStreaming) return;

    LogService.info('App', 'User clicked STOP streaming button');
    setState(() => _isStreaming = false);

    // 1. Stop Camera Streaming
    await _cameraService.stopStreaming();

    // 2. Stop GPS transmission
    _gpsService.stopTransmission();

    // 3. Disconnect WebSocket
    await _wsService.disconnect();
    LogService.info('App', 'Streaming halted cleanly. Console in standby.');
  }

  @override
  void dispose() {
    LogService.info('App', 'Exiting LiveStreamScreen');
    _onStop();
    _cameraService.dispose();
    _gpsService.dispose();
    _wsService.dispose();
    super.dispose();
  }

  BadgeStatusType _getWsBadgeType(WebSocketConnectionStatus status) {
    switch (status) {
      case WebSocketConnectionStatus.connected:
        return BadgeStatusType.active;
      case WebSocketConnectionStatus.connecting:
      case WebSocketConnectionStatus.reconnecting:
        return BadgeStatusType.pending;
      case WebSocketConnectionStatus.error:
        return BadgeStatusType.error;
      case WebSocketConnectionStatus.disconnected:
        return BadgeStatusType.inactive;
    }
  }

  BadgeStatusType _getCameraBadgeType(CameraStreamStatus status) {
    switch (status) {
      case CameraStreamStatus.streaming:
        return BadgeStatusType.active;
      case CameraStreamStatus.ready:
        return BadgeStatusType.ready;
      case CameraStreamStatus.initializing:
        return BadgeStatusType.pending;
      case CameraStreamStatus.error:
        return BadgeStatusType.error;
      case CameraStreamStatus.uninitialized:
        return BadgeStatusType.inactive;
    }
  }

  BadgeStatusType _getGpsBadgeType(GpsStatus status) {
    switch (status) {
      case GpsStatus.streaming:
        return BadgeStatusType.active;
      case GpsStatus.ready:
        return BadgeStatusType.ready;
      case GpsStatus.initializing:
        return BadgeStatusType.pending;
      case GpsStatus.error:
      case GpsStatus.denied:
      case GpsStatus.disabled:
        return BadgeStatusType.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryCyan = Color(0xFF00E5FF);
    const bgDark = Color(0xFF0A0E17);
    const surfaceDark = Color(0xFF131B2A);
    const borderDark = Color(0xFF22304A);

    return Scaffold(
      backgroundColor: bgDark,
      appBar: AppBar(
        backgroundColor: surfaceDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Color(0xFF94A3B8)),
          onPressed: () {
            _onStop();
            Navigator.of(context).pop();
          },
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: primaryCyan.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: primaryCyan.withValues(alpha: 0.4)),
              ),
              child: Text(
                widget.vehicleId,
                style: const TextStyle(
                  color: primaryCyan,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              'LIVE CONSOLE',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
        actions: [
          // Toggle in-app log monitor
          IconButton(
            icon: Icon(
              Icons.terminal_rounded,
              color: _showLogConsole ? primaryCyan : const Color(0xFF64748B),
              size: 20,
            ),
            tooltip: 'Toggle Logs Console',
            onPressed: () => setState(() => _showLogConsole = !_showLogConsole),
          ),
          ValueListenableBuilder<WebSocketConnectionStatus>(
            valueListenable: _wsService.statusNotifier,
            builder: (context, status, _) {
              return Padding(
                padding: const EdgeInsets.only(right: 16.0),
                child: Center(
                  child: StatusBadge(
                    label: 'WS',
                    value: status.name,
                    statusType: _getWsBadgeType(status),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: _isInitializing
            ? const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: primaryCyan),
                    SizedBox(height: 16),
                    Text(
                      'Initializing Camera & Sensors...',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                    ),
                  ],
                ),
              )
            : !_isPermissionsGranted
                ? _buildPermissionFallback()
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final isLandscape = constraints.maxWidth > constraints.maxHeight;

                      if (isLandscape) {
                        return Row(
                          children: [
                            Expanded(
                              flex: 5,
                              child: _buildCameraViewfinder(),
                            ),
                            Container(width: 1, color: borderDark),
                            Expanded(
                              flex: 5,
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(16),
                                child: _buildDashboardContent(),
                              ),
                            ),
                          ],
                        );
                      }

                      return Column(
                        children: [
                          // Top viewfinder
                          Expanded(
                            flex: _showLogConsole ? 4 : 5,
                            child: _buildCameraViewfinder(),
                          ),
                          Container(height: 1, color: borderDark),
                          // Bottom telemetry, controls and live log monitor
                          Expanded(
                            flex: _showLogConsole ? 6 : 5,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: _buildDashboardContent(),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
      ),
    );
  }

  Widget _buildPermissionFallback() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.security_rounded, size: 48, color: Color(0xFFFF3366)),
            const SizedBox(height: 16),
            const Text(
              'Permissions Required',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              _permissionError ?? 'Please grant Camera and Location access to proceed.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _bootstrapServices,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00E5FF),
                foregroundColor: const Color(0xFF0A0E17),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Grant Permissions'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCameraViewfinder() {
    final controller = _cameraService.controller;

    return Container(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Live Camera Preview
          if (_cameraService.isReady && controller != null)
            Center(
              child: CameraPreview(controller),
            )
          else
            const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.videocam_off_outlined, size: 42, color: Color(0xFF475569)),
                  SizedBox(height: 10),
                  Text(
                    'Camera Hardware Initializing...',
                    style: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  ),
                ],
              ),
            ),

          // HUD Viewfinder Reticle Overlay
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(
                    _isStreaming ? Icons.circle : Icons.stop_circle_outlined,
                    size: 10,
                    color: _isStreaming ? const Color(0xFFFF3366) : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _isStreaming ? 'REC / 10 FPS' : 'STANDBY',
                    style: TextStyle(
                      color: _isStreaming ? const Color(0xFFFF3366) : const Color(0xFF94A3B8),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Target FPS and Frame count badge
          Positioned(
            top: 16,
            right: 16,
            child: ValueListenableBuilder<double>(
              valueListenable: _cameraService.currentFpsNotifier,
              builder: (context, fps, _) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${fps.toStringAsFixed(1)} FPS',
                    style: const TextStyle(
                      color: Color(0xFF00E5FF),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'monospace',
                    ),
                  ),
                );
              },
            ),
          ),

          // Corner HUD crosshairs
          const Positioned(
            top: 12,
            left: 12,
            child: Icon(Icons.crop_free, color: Colors.white24, size: 28),
          ),
          const Positioned(
            bottom: 12,
            right: 12,
            child: Icon(Icons.crop_free, color: Colors.white24, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardContent() {
    const primaryCyan = Color(0xFF00E5FF);
    const neonGreen = Color(0xFF00F5A0);
    const dangerRed = Color(0xFFFF3366);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Status Row (WebSocket, Camera, GPS)
        Row(
          children: [
            Expanded(
              child: ValueListenableBuilder<CameraStreamStatus>(
                valueListenable: _cameraService.statusNotifier,
                builder: (context, status, _) {
                  return StatusBadge(
                    label: 'Camera',
                    value: status.name,
                    statusType: _getCameraBadgeType(status),
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ValueListenableBuilder<GpsStatus>(
                valueListenable: _gpsService.statusNotifier,
                builder: (context, status, _) {
                  return StatusBadge(
                    label: 'GPS',
                    value: status.name,
                    statusType: _getGpsBadgeType(status),
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // AI Event Real-Time Alert Banner
        ValueListenableBuilder<AiEvent?>(
          valueListenable: _wsService.latestAiEventNotifier,
          builder: (context, aiEvent, _) {
            return AiEventBanner(event: aiEvent);
          },
        ),
        const SizedBox(height: 12),

        // Telemetry Grid
        // 1. GPS Coordinates
        ValueListenableBuilder<Position?>(
          valueListenable: _gpsService.currentPositionNotifier,
          builder: (context, pos, _) {
            final lat = pos != null ? pos.latitude.toStringAsFixed(4) : '0.0000';
            final lng = pos != null ? pos.longitude.toStringAsFixed(4) : '0.0000';
            return TelemetryTile(
              title: 'GPS Coordinates',
              value: '$lat, $lng',
              icon: Icons.navigation_rounded,
              accentColor: primaryCyan,
            );
          },
        ),
        const SizedBox(height: 8),

        // 2. Speed and Accuracy in 2-column row
        Row(
          children: [
            Expanded(
              child: ValueListenableBuilder<double>(
                valueListenable: _gpsService.speedKmhNotifier,
                builder: (context, speed, _) {
                  return TelemetryTile(
                    title: 'Speed',
                    value: speed.toStringAsFixed(1),
                    unit: 'km/h',
                    icon: Icons.speed_rounded,
                    accentColor: neonGreen,
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ValueListenableBuilder<double>(
                valueListenable: _gpsService.accuracyNotifier,
                builder: (context, accuracy, _) {
                  return TelemetryTile(
                    title: 'Accuracy',
                    value: '±${accuracy.toStringAsFixed(1)}',
                    unit: 'm',
                    icon: Icons.gps_fixed_rounded,
                    accentColor: primaryCyan,
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),

        // 3. Frames Sent & GPS Packets Sent Counters
        Row(
          children: [
            Expanded(
              child: ValueListenableBuilder<int>(
                valueListenable: _wsService.framesSentNotifier,
                builder: (context, frames, _) {
                  return TelemetryTile(
                    title: 'Frames Sent',
                    value: frames.toString(),
                    unit: 'pkts',
                    icon: Icons.video_file_outlined,
                    accentColor: primaryCyan,
                  );
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ValueListenableBuilder<int>(
                valueListenable: _wsService.gpsSentNotifier,
                builder: (context, gpsCount, _) {
                  return TelemetryTile(
                    title: 'GPS Sent',
                    value: gpsCount.toString(),
                    unit: 'pkts',
                    icon: Icons.satellite_alt_rounded,
                    accentColor: neonGreen,
                  );
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // Action Buttons: START & STOP
        Row(
          children: [
            // START Button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isStreaming ? null : _onStart,
                style: ElevatedButton.styleFrom(
                  backgroundColor: neonGreen,
                  foregroundColor: const Color(0xFF0A0E17),
                  disabledBackgroundColor: const Color(0xFF1E293B),
                  disabledForegroundColor: const Color(0xFF475569),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: _isStreaming ? 0 : 4,
                  shadowColor: neonGreen.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.play_arrow_rounded, size: 22),
                label: const Text(
                  'START',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // STOP Button
            Expanded(
              child: ElevatedButton.icon(
                onPressed: !_isStreaming ? null : _onStop,
                style: ElevatedButton.styleFrom(
                  backgroundColor: dangerRed,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFF1E293B),
                  disabledForegroundColor: const Color(0xFF475569),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  elevation: !_isStreaming ? 0 : 4,
                  shadowColor: dangerRed.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.stop_rounded, size: 22),
                label: const Text(
                  'STOP',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // In-App Live Terminal / Diagnostic Log Monitor
        if (_showLogConsole) ...[
          LiveLogConsole(
            maxHeight: 220,
            isCollapsible: true,
            onClose: () => setState(() => _showLogConsole = false),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}
