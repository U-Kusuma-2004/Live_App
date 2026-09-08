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
import '../theme/app_theme.dart';
import '../widgets/ai_event_banner.dart';
import '../widgets/live_log_console.dart';
import '../widgets/pressable.dart';
import '../widgets/status_badge.dart';
import '../widgets/telemetry_tile.dart';
import '../widgets/tilt_card.dart';

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
    LogService.info('App',
        'Entered LiveStreamScreen (Vehicle: "${widget.vehicleId}", URL: "${widget.webSocketUrl}")');
    _bootstrapServices();
  }

  Future<void> _bootstrapServices() async {
    setState(() {
      _isInitializing = true;
      _permissionError = null;
    });

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

    await Future.wait([
      _cameraService.initializeCamera(),
      _gpsService.initializeGps(),
    ]);

    if (mounted) {
      setState(() => _isInitializing = false);
      LogService.info('App', 'Camera & GPS initialization complete. Ready for streaming.');
    }
  }

  Future<void> _onStart() async {
    if (_isStreaming) return;
    LogService.info('App', 'User clicked START streaming button');
    setState(() => _isStreaming = true);
    _wsService.resetCounters();

    await _wsService.connect(widget.webSocketUrl, vehicleId: widget.vehicleId);
    await _cameraService.startStreaming(
      vehicleId: widget.vehicleId,
      onFrame: (FramePayload p) => _wsService.sendFrame(p),
    );
    _gpsService.startTransmission(
      vehicleId: widget.vehicleId,
      onGpsPacket: (GpsPayload p) => _wsService.sendGps(p),
    );
  }

  Future<void> _onStop() async {
    if (!_isStreaming) return;
    LogService.info('App', 'User clicked STOP streaming button');
    setState(() => _isStreaming = false);

    await _cameraService.stopStreaming();
    _gpsService.stopTransmission();
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

  BadgeStatusType _wsBadge(WebSocketConnectionStatus s) {
    switch (s) {
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

  BadgeStatusType _cameraBadge(CameraStreamStatus s) {
    switch (s) {
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

  BadgeStatusType _gpsBadge(GpsStatus s) {
    switch (s) {
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

  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 4,
        leadingWidth: 44,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          color: AppColors.inkSoft,
          onPressed: () {
            _onStop();
            Navigator.of(context).pop();
          },
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Live console',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 1),
            Row(
              children: [
                Flexible(
                  child: Text(
                    widget.vehicleId,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.brand,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              _showLogConsole ? Icons.terminal_rounded : Icons.terminal_outlined,
            ),
            color: _showLogConsole ? AppColors.brand : AppColors.inkFaint,
            tooltip: 'Toggle live monitor',
            onPressed: () => setState(() => _showLogConsole = !_showLogConsole),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _isInitializing
            ? _busy('Starting camera and sensors…')
            : !_isPermissionsGranted
                ? _permissionFallback()
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final landscape = constraints.maxWidth > constraints.maxHeight;
                      if (landscape) {
                        return Row(
                          children: [
                            Expanded(flex: 5, child: _viewfinderArea()),
                            Expanded(
                              flex: 5,
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(16),
                                child: _dashboard(),
                              ),
                            ),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          Expanded(
                            flex: _showLogConsole ? 5 : 6,
                            child: _viewfinderArea(),
                          ),
                          Expanded(
                            flex: _showLogConsole ? 7 : 6,
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                              child: _dashboard(),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
      ),
    );
  }

  Widget _busy(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(message,
              style: const TextStyle(color: AppColors.inkSoft, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _permissionFallback() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.stop.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock_outline_rounded,
                  size: 30, color: AppColors.stop),
            ),
            const SizedBox(height: 18),
            Text('Camera and location needed',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              _permissionError ??
                  'Grant camera and location access so the console can stream the feed and GPS.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.inkSoft, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 22),
            Pressable(
              onPressed: _bootstrapServices,
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 22),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.refresh_rounded, size: 18),
                  SizedBox(width: 8),
                  Text('Try again'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------

  Widget _viewfinderArea() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: TiltCard(
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
          tween: Tween(begin: 0.96, end: 1),
          builder: (context, scale, child) =>
              Transform.scale(scale: scale, child: child),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: const Color(0xFF0C0F14),
              borderRadius: BorderRadius.circular(AppRadii.hero),
              boxShadow: AppShadows.raised,
              border: Border.all(
                color: _isStreaming
                    ? AppColors.brand.withValues(alpha: 0.9)
                    : AppColors.line,
                width: _isStreaming ? 1.6 : 1,
              ),
            ),
            child: _viewfinder(),
          ),
        ),
      ),
    );
  }

  Widget _viewfinder() {
    final controller = _cameraService.controller;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_cameraService.isReady && controller != null)
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: controller.value.previewSize?.height ?? 720,
              height: controller.value.previewSize?.width ?? 480,
              child: CameraPreview(controller),
            ),
          )
        else
          const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.videocam_off_outlined, size: 38, color: Color(0xFF56606E)),
                SizedBox(height: 10),
                Text('Camera warming up…',
                    style: TextStyle(color: Color(0xFF7A8494), fontSize: 12)),
              ],
            ),
          ),

        // Recording rail — the one bold, subject-grounded flourish.
        if (_isStreaming)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              height: 3,
              decoration: BoxDecoration(
                color: AppColors.brand,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brand.withValues(alpha: 0.7),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ),

        Positioned(
          top: 12,
          left: 12,
          child: _hudChip(
            icon: _isStreaming ? Icons.fiber_manual_record_rounded : Icons.pause_rounded,
            iconColor: _isStreaming ? AppColors.stop : const Color(0xFFB6BECC),
            label: _isStreaming ? 'Recording · 10 fps' : 'Standby',
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: ValueListenableBuilder<double>(
            valueListenable: _cameraService.currentFpsNotifier,
            builder: (context, fps, _) => _hudChip(
              label: '${fps.toStringAsFixed(1)} fps',
              labelColor: const Color(0xFF7CC4FF),
            ),
          ),
        ),
      ],
    );
  }

  Widget _hudChip({
    IconData? icon,
    Color? iconColor,
    required String label,
    Color labelColor = Colors.white,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 10, color: iconColor),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: labelColor,
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              fontFamily: kMonoFont,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------

  Widget _dashboard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Connection strip — three equal pills, WS moved out of the AppBar.
        Row(
          children: [
            Expanded(
              child: ValueListenableBuilder<CameraStreamStatus>(
                valueListenable: _cameraService.statusNotifier,
                builder: (context, s, _) => StatusBadge(
                  label: 'Camera',
                  value: s.name,
                  statusType: _cameraBadge(s),
                  compact: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ValueListenableBuilder<GpsStatus>(
                valueListenable: _gpsService.statusNotifier,
                builder: (context, s, _) => StatusBadge(
                  label: 'GPS',
                  value: s.name,
                  statusType: _gpsBadge(s),
                  compact: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ValueListenableBuilder<WebSocketConnectionStatus>(
                valueListenable: _wsService.statusNotifier,
                builder: (context, s, _) => StatusBadge(
                  label: 'Link',
                  value: s.name,
                  statusType: _wsBadge(s),
                  compact: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        ValueListenableBuilder<AiEvent?>(
          valueListenable: _wsService.latestAiEventNotifier,
          builder: (context, e, _) => AiEventBanner(event: e),
        ),
        const SizedBox(height: 12),

        _sectionTitle('Telemetry'),
        const SizedBox(height: 8),
        ValueListenableBuilder<Position?>(
          valueListenable: _gpsService.currentPositionNotifier,
          builder: (context, pos, _) {
            final lat = pos?.latitude.toStringAsFixed(4) ?? '0.0000';
            final lng = pos?.longitude.toStringAsFixed(4) ?? '0.0000';
            return TelemetryTile(
              title: 'Coordinates',
              value: '$lat, $lng',
              icon: Icons.my_location_rounded,
              accentColor: AppColors.brand,
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ValueListenableBuilder<double>(
                valueListenable: _gpsService.speedKmhNotifier,
                builder: (context, v, _) => TelemetryTile(
                  title: 'Speed',
                  value: v.toStringAsFixed(1),
                  unit: 'km/h',
                  icon: Icons.speed_rounded,
                  accentColor: AppColors.go,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ValueListenableBuilder<double>(
                valueListenable: _gpsService.accuracyNotifier,
                builder: (context, v, _) => TelemetryTile(
                  title: 'Accuracy',
                  value: '±${v.toStringAsFixed(1)}',
                  unit: 'm',
                  icon: Icons.gps_fixed_rounded,
                  accentColor: AppColors.brand,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ValueListenableBuilder<int>(
                valueListenable: _wsService.framesSentNotifier,
                builder: (context, v, _) => TelemetryTile(
                  title: 'Frames sent',
                  value: '$v',
                  icon: Icons.movie_outlined,
                  accentColor: AppColors.brand,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ValueListenableBuilder<int>(
                valueListenable: _wsService.gpsSentNotifier,
                builder: (context, v, _) => TelemetryTile(
                  title: 'GPS sent',
                  value: '$v',
                  icon: Icons.satellite_alt_outlined,
                  accentColor: AppColors.go,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        Row(
          children: [
            Expanded(
              child: Pressable(
                onPressed: _isStreaming ? null : _onStart,
                color: AppColors.go,
                pressedColor: AppColors.goPressed,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_arrow_rounded, size: 20),
                    SizedBox(width: 6),
                    Text('Start stream'),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Pressable(
                onPressed: _isStreaming ? _onStop : null,
                color: AppColors.stop,
                pressedColor: AppColors.stopPressed,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.stop_rounded, size: 20),
                    SizedBox(width: 6),
                    Text('Stop'),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        AnimatedSize(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: _showLogConsole
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _sectionTitle('Live monitor'),
                    const SizedBox(height: 8),
                    LiveLogConsole(
                      maxHeight: 220,
                      onClose: () => setState(() => _showLogConsole = false),
                    ),
                  ],
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppColors.ink,
        letterSpacing: -0.1,
      ),
    );
  }
}
