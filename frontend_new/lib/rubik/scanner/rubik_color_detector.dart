import 'dart:io';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../model/cube_model.dart';

/// Kết quả nhận diện màu từ ảnh tĩnh đã chụp
class DetectedFaceColors {
  final List<Color> colors; // 9 màu ô
  final List<Offset> normalizedPoints; // 9 tọa độ chuẩn hóa (0.0 -> 1.0) trên ảnh

  DetectedFaceColors({
    required this.colors,
    required this.normalizedPoints,
  });
}

/// Kết quả lấy mẫu trực tiếp theo thời gian thực từ Camera Stream
class LiveColorResult {
  final List<Color> classifiedColors; // 9 màu Rubik chuẩn (Đỏ, Vàng, Xanh...)
  final List<Color> rawRgbColors;      // 9 màu RGB thực tế camera đang nhìn thấy

  const LiveColorResult({
    required this.classifiedColors,
    required this.rawRgbColors,
  });
}

class RubikColorDetector {
  /// Tính toán 9 tọa độ chuẩn hóa (0.0 -> 1.0) dựa trên độ co dãn cự ly (spread)
  /// Tâm ô số 4 luôn cố định tại (0.5, 0.5)
  static List<Offset> computeNormalizedPoints(double spread) {
    final clampedSpread = spread.clamp(0.35, 0.90);
    final step = clampedSpread / 2.0;
    final list = <Offset>[];

    for (int row = 0; row < 3; row++) {
      final y = 0.5 + (row - 1) * step;
      for (int col = 0; col < 3; col++) {
        final x = 0.5 + (col - 1) * step;
        list.add(Offset(x, y));
      }
    }
    return list;
  }

  /// Trích xuất 9 ô màu trực tiếp từ luồng CameraImage (Realtime Live Stream)
  /// Tốc độ xử lý siêu tốc (< 0.1ms) vì chỉ lấy mẫu quanh 9 điểm thay vì decode toàn bộ frame
  static LiveColorResult extractColorsFromCameraImage({
    required CameraImage image,
    required List<Offset> normalizedPoints,
    required int sensorOrientation,
    Color? expectedCenterColor,
  }) {
    final rawColors = <Color>[];
    final classified = <Color>[];

    final width = image.width;
    final height = image.height;

    // Camera sensor thường có tỉ lệ 4:3 hoặc 16:9. Khung ngắm màn hình là crop vuông ở tâm.
    final minDim = math.min(width, height);
    final cropStartX = (width - minDim) ~/ 2;
    final cropStartY = (height - minDim) ~/ 2;

    for (int i = 0; i < normalizedPoints.length; i++) {
      final norm = normalizedPoints[i];
      final nx = norm.dx.clamp(0.0, 1.0);
      final ny = norm.dy.clamp(0.0, 1.0);

      // Chuyển đổi tọa độ màn hình (nx, ny) sang tọa độ pixel sensor theo góc quay sensorOrientation
      int px;
      int py;

      switch (sensorOrientation) {
        case 90:
          // Android phổ biến nhất: camera sau ở chế độ dọc Portrait
          px = cropStartX + (ny * minDim).round();
          py = cropStartY + ((1.0 - nx) * minDim).round();
          break;
        case 270:
          px = cropStartX + ((1.0 - ny) * minDim).round();
          py = cropStartY + (nx * minDim).round();
          break;
        case 180:
          px = cropStartX + ((1.0 - nx) * minDim).round();
          py = cropStartY + ((1.0 - ny) * minDim).round();
          break;
        case 0:
        default:
          px = cropStartX + (nx * minDim).round();
          py = cropStartY + (ny * minDim).round();
          break;
      }

      px = px.clamp(0, width - 1);
      py = py.clamp(0, height - 1);

      // Lấy trung bình màu trong vùng lân cận để lọc nhiễu hạt & phản quang
      final sampleRgb = _sampleAreaRgb(image, px, py, radius: 2);
      rawColors.add(sampleRgb);

      if (i == 4 && expectedCenterColor != null) {
        classified.add(expectedCenterColor);
      } else {
        final r = (sampleRgb.r * 255.0).round().clamp(0, 255);
        final g = (sampleRgb.g * 255.0).round().clamp(0, 255);
        final b = (sampleRgb.b * 255.0).round().clamp(0, 255);
        classified.add(classifyRgb(r, g, b));
      }
    }

    return LiveColorResult(
      classifiedColors: classified,
      rawRgbColors: rawColors,
    );
  }

  /// Lấy mẫu RGB trung bình tại điểm (centerX, centerY) với định dạng YUV420 hoặc BGRA8888
  static Color _sampleAreaRgb(
    CameraImage image,
    int centerX,
    int centerY, {
    int radius = 2,
  }) {
    int totalR = 0;
    int totalG = 0;
    int totalB = 0;
    int count = 0;

    final width = image.width;
    final height = image.height;
    final isYuv = image.format.group == ImageFormatGroup.yuv420;
    final isBgra = image.format.group == ImageFormatGroup.bgra8888;

    for (int dy = -radius; dy <= radius; dy += 2) {
      for (int dx = -radius; dx <= radius; dx += 2) {
        final x = (centerX + dx).clamp(0, width - 1);
        final y = (centerY + dy).clamp(0, height - 1);

        if (isYuv && image.planes.length >= 3) {
          final yPlane = image.planes[0];
          final uPlane = image.planes[1];
          final vPlane = image.planes[2];

          final yRowStride = yPlane.bytesPerRow;
          final yPixelStride = yPlane.bytesPerPixel ?? 1;
          final yIndex = y * yRowStride + x * yPixelStride;

          final uvRowStride = uPlane.bytesPerRow;
          final uvPixelStride = uPlane.bytesPerPixel ?? 1;
          final uvX = x ~/ 2;
          final uvY = y ~/ 2;

          final uIndex = uvY * uvRowStride + uvX * uvPixelStride;
          final vIndex = uvY * vPlane.bytesPerRow + uvX * (vPlane.bytesPerPixel ?? 1);

          if (yIndex < yPlane.bytes.length &&
              uIndex < uPlane.bytes.length &&
              vIndex < vPlane.bytes.length) {
            final yVal = yPlane.bytes[yIndex];
            final uVal = uPlane.bytes[uIndex];
            final vVal = vPlane.bytes[vIndex];

            // Chuyển đổi YUV sang RGB (BT.601)
            final c = yVal - 16;
            final d = uVal - 128;
            final e = vVal - 128;

            final r = ((298 * c + 409 * e + 128) >> 8).clamp(0, 255);
            final g = ((298 * c - 100 * d - 208 * e + 128) >> 8).clamp(0, 255);
            final b = ((298 * c + 516 * d + 128) >> 8).clamp(0, 255);

            totalR += r;
            totalG += g;
            totalB += b;
            count++;
          }
        } else if (isBgra && image.planes.isNotEmpty) {
          final plane = image.planes[0];
          final rowStride = plane.bytesPerRow;
          final index = y * rowStride + x * 4;
          if (index + 2 < plane.bytes.length) {
            final b = plane.bytes[index];
            final g = plane.bytes[index + 1];
            final r = plane.bytes[index + 2];

            totalR += r;
            totalG += g;
            totalB += b;
            count++;
          }
        }
      }
    }

    if (count == 0) return const Color(0xFF888888);

    return Color.fromARGB(
      255,
      (totalR ~/ count).clamp(0, 255),
      (totalG ~/ count).clamp(0, 255),
      (totalB ~/ count).clamp(0, 255),
    );
  }

  /// Cắt ảnh chụp từ camera thành ảnh vuông chính tâm (Center Square Crop)
  /// để ảnh tĩnh trùng khớp 1:1 với khung ngắm camera, triệt tiêu hoàn toàn hiện tượng zoom lệch
  static Future<File> cropToSquareImage(String filePath) async {
    return await compute(_cropToSquareInIsolate, filePath);
  }

  static File _cropToSquareInIsolate(String filePath) {
    final file = File(filePath);
    if (!file.existsSync()) return file;

    final bytes = file.readAsBytesSync();
    final rawImage = img.decodeImage(bytes);
    if (rawImage == null) return file;

    // Chuẩn hóa góc quay EXIF của điện thoại
    final image = img.bakeOrientation(rawImage);
    final width = image.width;
    final height = image.height;

    final minDim = math.min(width, height);
    final startX = (width - minDim) ~/ 2;
    final startY = (height - minDim) ~/ 2;

    final cropped = img.copyCrop(
      image,
      x: startX,
      y: startY,
      width: minDim,
      height: minDim,
    );

    final squarePath = filePath.endsWith('_sq.jpg') ? filePath : '${filePath}_sq.jpg';
    final squareFile = File(squarePath);
    squareFile.writeAsBytesSync(img.encodeJpg(cropped, quality: 92));
    return squareFile;
  }

  /// Phân tích ảnh tĩnh và trích xuất 9 ô màu bằng background isolate
  static Future<DetectedFaceColors> processImage(
    String filePath, {
    Color? expectedCenterColor,
    double spread = 0.65,
  }) async {
    try {
      return await compute(_analyzeImageInIsolate, {
        'path': filePath,
        'centerColorValue': expectedCenterColor?.toARGB32(),
        'spread': spread,
      });
    } catch (e) {
      debugPrint('Error processing image in isolate: $e');
      return DetectedFaceColors(
        colors: List.filled(9, expectedCenterColor ?? RubikColors.white),
        normalizedPoints: computeNormalizedPoints(spread),
      );
    }
  }

  static DetectedFaceColors _analyzeImageInIsolate(Map<String, dynamic> params) {
    final filePath = params['path'] as String;
    final centerColorVal = params['centerColorValue'] as int?;
    final spread = (params['spread'] as num?)?.toDouble() ?? 0.65;
    final expectedCenter =
        centerColorVal != null ? Color(centerColorVal) : null;

    final defaultPoints = computeNormalizedPoints(spread);

    final file = File(filePath);
    if (!file.existsSync()) {
      return DetectedFaceColors(
        colors: List.filled(9, expectedCenter ?? RubikColors.white),
        normalizedPoints: defaultPoints,
      );
    }

    final bytes = file.readAsBytesSync();
    final rawImage = img.decodeImage(bytes);
    if (rawImage == null) {
      return DetectedFaceColors(
        colors: List.filled(9, expectedCenter ?? RubikColors.white),
        normalizedPoints: defaultPoints,
      );
    }

    // Xử lý góc xoay EXIF của ảnh chụp từ điện thoại
    final image = img.bakeOrientation(rawImage);
    final width = image.width;
    final height = image.height;

    final minDim = math.min(width, height);
    final boxSize = (minDim * spread.clamp(0.35, 0.90)).round();
    final startX = (width - boxSize) ~/ 2;
    final startY = (height - boxSize) ~/ 2;
    final step = boxSize / 2.0;

    final detected = <Color>[];
    final normPoints = <Offset>[];

    for (int row = 0; row < 3; row++) {
      for (int col = 0; col < 3; col++) {
        final cx = (startX + col * step).round();
        final cy = (startY + row * step).round();

        normPoints.add(Offset(cx / width, cy / height));

        // Lấy trung bình màu trong vùng bán kính sampleRadius
        final sampleRadius = (step * 0.12).round().clamp(3, 20);
        double rSum = 0, gSum = 0, bSum = 0;
        int count = 0;

        for (int dx = -sampleRadius; dx <= sampleRadius; dx++) {
          for (int dy = -sampleRadius; dy <= sampleRadius; dy++) {
            final px = cx + dx;
            final py = cy + dy;
            if (px >= 0 && px < width && py >= 0 && py < height) {
              final pixel = image.getPixel(px, py);
              rSum += pixel.r;
              gSum += pixel.g;
              bSum += pixel.b;
              count++;
            }
          }
        }

        final avgR = count > 0 ? (rSum / count).round().clamp(0, 255) : 0;
        final avgG = count > 0 ? (gSum / count).round().clamp(0, 255) : 0;
        final avgB = count > 0 ? (bSum / count).round().clamp(0, 255) : 0;

        detected.add(classifyRgb(avgR, avgG, avgB));
      }
    }

    // Ô tâm (index 4) luôn là màu tâm chuẩn của mặt hiện tại
    if (expectedCenter != null) {
      detected[4] = expectedCenter;
    }

    return DetectedFaceColors(
      colors: detected,
      normalizedPoints: normPoints,
    );
  }

  /// Phân loại màu sắc theo không gian màu HSV & RGB
  static Color classifyRgb(int r, int g, int b) {
    final rNorm = r / 255.0;
    final gNorm = g / 255.0;
    final bNorm = b / 255.0;

    final cMax = math.max(rNorm, math.max(gNorm, bNorm));
    final cMin = math.min(rNorm, math.min(gNorm, bNorm));
    final delta = cMax - cMin;

    final v = cMax;
    final s = cMax == 0 ? 0.0 : delta / cMax;

    double h = 0.0;
    if (delta > 0.0001) {
      if (cMax == rNorm) {
        h = 60 * (((gNorm - bNorm) / delta) % 6);
      } else if (cMax == gNorm) {
        h = 60 * (((bNorm - rNorm) / delta) + 2);
      } else {
        h = 60 * (((rNorm - gNorm) / delta) + 4);
      }
    }
    if (h < 0) h += 360;

    // 1. Trắng (White): Độ bão hòa màu rất thấp
    if (s < 0.20 && v > 0.35) {
      return RubikColors.white;
    }
    if (s < 0.28 && (r - g).abs() < 28 && (g - b).abs() < 28 && v > 0.45) {
      return RubikColors.white;
    }

    // 2. Xanh dương (Blue)
    if (h >= 170 && h < 265) {
      return RubikColors.blue;
    }

    // 3. Xanh lá (Green)
    if (h >= 75 && h < 170) {
      return RubikColors.green;
    }

    // 4. Vàng (Yellow)
    if (h >= 45 && h < 75) {
      return RubikColors.yellow;
    }

    // 5. Cam (Orange)
    if (h >= 12 && h < 45) {
      return RubikColors.orange;
    }

    // 6. Đỏ (Red)
    return RubikColors.red;
  }
}
