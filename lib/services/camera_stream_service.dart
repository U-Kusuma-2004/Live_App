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

  final ValueNotifier<CameraStreamStatus> statusNotifier =
      ValueNotifier<CameraStreamStatus>(CameraStreamStatus.uninitialized);
  final ValueNotifier<String?> errorNotifier = ValueNotifier<String?>(null);
  final ValueNotifier<double> currentFpsNotifier = ValueNotifier<double>(0.0);
  final ValueNotifier<int> frameCountNotifier = ValueNotifier<int>(0);

  CameraController? get controller => _controller;
  bool get isReady => _controller != null && _controller!.value.isInitialized;
  bool get isStreaming => statusNotifier.value == CameraStreamStatus.streaming;

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
      _selectedCamera = _cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.back,
        orElse: () => _cameras.first,
      );

      _controller = CameraController(
        _selectedCamera!,
        ResolutionPreset.medium, // 720p / 480p ideal for real-time edge streaming
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _controller!.initialize();
      statusNotifier.value = CameraStreamStatus.ready;
      LogService.info(
        'Camera',
        'Camera ready (${_selectedCamera!.lensDirection.name}, preview size: ${_controller!.value.previewSize})',
      );
      return true;
    } catch (e, stackTrace) {
      LogService.error('Camera', 'Failed to initialize camera hardware', error: e, stackTrace: stackTrace);
      statusNotifier.value = CameraStreamStatus.error;
      errorNotifier.value = e.toString();
      return false;
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
  }
}
