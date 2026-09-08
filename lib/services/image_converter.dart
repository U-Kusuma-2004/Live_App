import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Holds raw image data detached from Flutter's CameraImage for isolate transfer.
class CameraImageData {
  final int width;
  final int height;
  final ImageFormatGroup formatGroup;
  final List<Uint8List> planeBytes;
  final List<int> bytesPerRow;
  final List<int?> bytesPerPixel;

  CameraImageData({
    required this.width,
    required this.height,
    required this.formatGroup,
    required this.planeBytes,
    required this.bytesPerRow,
    required this.bytesPerPixel,
  });

  factory CameraImageData.fromCameraImage(CameraImage image) {
    return CameraImageData(
      width: image.width,
      height: image.height,
      formatGroup: image.format.group,
      planeBytes: image.planes.map((p) => p.bytes).toList(),
      bytesPerRow: image.planes.map((p) => p.bytesPerRow).toList(),
      bytesPerPixel: image.planes.map((p) => p.bytesPerPixel).toList(),
    );
  }
}

/// Converts a CameraImageData to raw JPEG bytes inside an isolate. The backend
/// reads frames with `websocket.receive_bytes()`, so we send the JPEG as a
/// binary WebSocket frame — no base64, no JSON wrapper.
Uint8List convertCameraImageToJpegBytes(CameraImageData data) {
  try {
    img.Image? rgbImage;

    if (data.formatGroup == ImageFormatGroup.yuv420 ||
        data.formatGroup == ImageFormatGroup.nv21) {
      rgbImage = _convertYUV420ToImage(data);
    } else if (data.formatGroup == ImageFormatGroup.bgra8888) {
      rgbImage = _convertBGRA8888ToImage(data);
    } else {
      rgbImage = _convertYUV420ToImage(data);
    }

    if (rgbImage == null) return Uint8List(0);

    // Quality 60 keeps ~720x480 frames small enough for real-time streaming.
    return Uint8List.fromList(img.encodeJpg(rgbImage, quality: 60));
  } catch (e) {
    debugPrint('[ImageConverter] Isolate error: $e');
    return Uint8List(0);
  }
}

img.Image? _convertYUV420ToImage(CameraImageData data) {
  final width = data.width;
  final height = data.height;

  final yPlane = data.planeBytes[0];
  final uPlane = data.planeBytes[1];
  final vPlane = data.planeBytes[2];

  final yRowStride = data.bytesPerRow[0];
  final uvRowStride = data.bytesPerRow[1];
  final uvPixelStride = data.bytesPerPixel[1] ?? 1;

  final image = img.Image(width: width, height: height);

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final int yIndex = y * yRowStride + x;
      final int uvIndex = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;

      if (yIndex >= yPlane.length) continue;
      final int yValue = yPlane[yIndex];
      final int uValue = uvIndex < uPlane.length ? uPlane[uvIndex] : 128;
      final int vValue = uvIndex < vPlane.length ? vPlane[uvIndex] : 128;

      final int r = (yValue + (1.370705 * (vValue - 128))).round().clamp(0, 255);
      final int g = (yValue - (0.337633 * (uValue - 128)) - (0.698001 * (vValue - 128))).round().clamp(0, 255);
      final int b = (yValue + (1.732446 * (uValue - 128))).round().clamp(0, 255);

      image.setPixelRgb(x, y, r, g, b);
    }
  }

  return image;
}

img.Image? _convertBGRA8888ToImage(CameraImageData data) {
  final width = data.width;
  final height = data.height;
  final plane = data.planeBytes[0];

  final image = img.Image(width: width, height: height);
  int srcIndex = 0;

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      if (srcIndex + 3 < plane.length) {
        final b = plane[srcIndex];
        final g = plane[srcIndex + 1];
        final r = plane[srcIndex + 2];
        image.setPixelRgb(x, y, r, g, b);
      }
      srcIndex += 4;
    }
  }

  return image;
}
