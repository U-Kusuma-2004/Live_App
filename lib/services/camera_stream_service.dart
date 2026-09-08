import 'dart:async';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'image_converter.dart';
import 'log_service.dart';

enum CameraStreamStatus {
  uninitialized,
  initializing,
  ready,
  streaming,
  error,
}

class CameraStreamService {
  CameraController? _controller;
  List<CameraDescription> _cameras = [];
  CameraDescription? _selectedCamera;
  bool _isSwitching = false;

  final ValueNotifier<CameraStreamStatus> statusNotifier =
      ValueNotifier<CameraStreamStatus>(CameraStreamStatus.uninitialized);
  final ValueNotifier<String?> errorNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<double> currentFpsNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<int> frameCountNotifier = ValueNotifier<int>(0);

  /// Which lens the preview is currently using, so the UI can label the toggle.
  final ValueNotifier<CameraLensDirection> lensDirectionNotifier =
      ValueNotifier<CameraLensDirection>(CameraLensDirection.back);

  CameraController? get controller => _controller;
  bool get isReady => _controller != null && _controller!.value.isInitialized;
  bool get isStreaming => statusNotifier.value == CameraStreamStatus.streaming;
  bool get isSwitchingCamera => _isSwitching;

  /// True when the device has both a front and a back sensor to toggle between.
  bool get canSwitchCamera =>
      _cameras.map((c) => c.lensDirection).toSet().length > 1;

  int _frameId = 0;
  bool _isProcessingFrame = false;
  int _lastFrameTimestampMs = 0;
  static const int _targetIntervalMs = 100; // ~10 FPS

  // FPS calculation window
  int _fpsFrameCount = 0;
  int _fpsWindowStartMs = 0;

  void Function(Uint8List jpegBytes, int frameId)? _onFrameCallback;

  /// Initialize camera hardware (selecting rear camera by default)
  Future<bool> initializeCamera() async {
    statusNotifier.value = CameraStreamStatus.initializing;
    errorNotifier.value = null;
    LogService.info('Camera', 'Scanning device for available cameras...');

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        statusNotifier.value = CameraStreamStatus.error;
        errorNotifier.value = 'No camera hardware found on this device.';
        LogService.error('Camera', 'No camera hardware found on this device');
        return false;
      }

      LogService.info('Camera', 'Found ${_cameras.length} camera(s). Choosing rear sensor.');

      // Select rear camera if available, otherwise first camera
      final target = _cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );
      return _openCamera(target);
    } catch (e, stackTrace) {
      LogService.error('Camera', 'Failed to initialize camera hardware', error: e, stackTrace: stackTrace);
      statusNotifier.value = CameraStreamStatus.error;
      errorNotifier.value = e.toString();
      return false;
    }
  }

  /// Disposes any current controller and opens [camera].
  Future<bool> _openCamera(CameraDescription camera) async {
    try {
      await _controller?.dispose();
      _controller = null;

      final controller = CameraController(
        camera,
        ResolutionPreset.medium, // 720p / 480p ideal for real-time edge streaming
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await controller.initialize();

      _controller = controller;
      _selectedCamera = camera;
      lensDirectionNotifier.value = camera.lensDirection;
      statusNotifier.value =
          isStreaming ? CameraStreamStatus.streaming : CameraStreamStatus.ready;
      errorNotifier.value = null;
      LogService.info(
        'Camera',
        'Camera ready (${camera.lensDirection.name}, preview size: ${controller.value.previewSize})',
      );
      return true;
    } catch (e, stackTrace) {
      LogService.error('Camera', 'Failed to open ${camera.lensDirection.name} camera',
          error: e, stackTrace: stackTrace);
      statusNotifier.value = CameraStreamStatus.error;
      errorNotifier.value = e.toString();
      return false;
    }
  }

  /// Toggles between the front and back sensor. Keeps streaming across the swap
  /// if a stream is active.
  Future<void> switchCamera() async {
    if (_isSwitching || !canSwitchCamera) return;
    _isSwitching = true;
    try {
      final current = _selectedCamera?.lensDirection ?? CameraLensDirection.back;
      final wantFront = current != CameraLensDirection.front;
      final next = _cameras.firstWhere(
        (c) => wantFront
            ? c.lensDirection == CameraLensDirection.front
            : c.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.firstWhere(
          (c) => c.lensDirection != current,
          orElse: () => _selectedCamera!,
        ),
      );
      if (next.lensDirection == current) return;

      LogService.camera('Camera', 'Switching to ${next.lensDirection.name} camera');
      final wasStreaming = isStreaming;

      if (_controller?.value.isStreamingImages ?? false) {
        try {
          await _controller!.stopImageStream();
        } catch (_) {}
      }

      final ok = await _openCamera(next);
      if (ok && wasStreaming && _onFrameCallback != null) {
        _isProcessingFrame = false;
        try {
          await _controller!.startImageStream(_handleCameraImage);
        } catch (e, stackTrace) {
          LogService.error('Camera', 'Failed to resume stream after switch',
              error: e, stackTrace: stackTrace);
        }
      }
    } finally {
      _isSwitching = false;
    }
  }

  /// Starts streaming camera frames at ~10 FPS to the callback as JPEG bytes.
  Future<void> startStreaming({
    required void Function(Uint8List jpegBytes, int frameId) onFrame,
  }) async {
    if (_controller == null || !_controller!.value.isInitialized) {
      final ok = await initializeCamera();
      if (!ok) return;
    }

    _onFrameCallback = onFrame;
    _frameId = 0;
    _fpsFrameCount = 0;
    _fpsWindowStartMs = DateTime.now().millisecondsSinceEpoch;
    frameCountNotifier.value = 0;
    currentFpsNotifier.value = 0.0;
    statusNotifier.value = CameraStreamStatus.streaming;
    LogService.camera('Camera', 'Started image stream (~10 FPS target)');

    try {
      if (!_controller!.value.isStreamingImages) {
        await _controller!.startImageStream(_handleCameraImage);
      }
    } catch (e, stackTrace) {
      LogService.error('Camera', 'Failed to start image stream', error: e, stackTrace: stackTrace);
      statusNotifier.value = CameraStreamStatus.error;
      errorNotifier.value = e.toString();
    }
  }

  void _handleCameraImage(CameraImage image) {
    if (!isStreaming) return;

    final nowMs = DateTime.now().millisecondsSinceEpoch;

    // Throttle to target FPS (~10 FPS -> 100ms)
    if (nowMs - _lastFrameTimestampMs < _targetIntervalMs) {
      return;
    }

    // Drop frame if isolate worker is still encoding previous frame
    if (_isProcessingFrame) {
      return;
    }

    _isProcessingFrame = true;
    _lastFrameTimestampMs = nowMs;
    final currentFrameId = ++_frameId;

    // Prepare detached data for isolate execution
    final imageData = CameraImageData.fromCameraImage(image);

    // Run YUV/BGRA -> JPEG conversion in a background isolate
    compute(convertCameraImageToJpegBytes, imageData).then((jpegBytes) {
      _isProcessingFrame = false;
      if (!isStreaming || jpegBytes.isEmpty) return;

      frameCountNotifier.value = currentFrameId;
      _updateFpsMeter();

      _onFrameCallback?.call(jpegBytes, currentFrameId);
    }).catchError((err, stackTrace) {
      _isProcessingFrame = false;
      LogService.error('Camera', 'Frame encoding isolate failed (Frame #$currentFrameId)', error: err, stackTrace: stackTrace);
    });
  }

  void _updateFpsMeter() {
    _fpsFrameCount++;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final elapsed = nowMs - _fpsWindowStartMs;

    if (elapsed >= 1000) {
      final fps = (_fpsFrameCount * 1000.0) / elapsed;
      currentFpsNotifier.value = double.parse(fps.toStringAsFixed(1));
      _fpsFrameCount = 0;
      _fpsWindowStartMs = nowMs;
    }
  }

  /// Stops streaming frames but keeps the viewfinder preview running
  Future<void> stopStreaming() async {
    LogService.camera('Camera', 'Stopping image stream (total frames sent: $_frameId)');
    if (statusNotifier.value == CameraStreamStatus.streaming) {
      statusNotifier.value = CameraStreamStatus.ready;
      currentFpsNotifier.value = 0.0;
    }

    if (_controller != null && _controller!.value.isStreamingImages) {
      try {
        await _controller!.stopImageStream();
      } catch (e, stackTrace) {
        LogService.error('Camera', 'Error stopping image stream', error: e, stackTrace: stackTrace);
      }
    }
  }

  /// Dispose camera hardware completely
  Future<void> dispose() async {
    await stopStreaming();
    await _controller?.dispose();
    _controller = null;
    statusNotifier.dispose();
    errorNotifier.dispose();
    currentFpsNotifier.dispose();
    frameCountNotifier.dispose();
    lensDirectionNotifier.dispose();
  }
}
