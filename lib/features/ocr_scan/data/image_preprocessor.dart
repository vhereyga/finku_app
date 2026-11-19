import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Parameter pra-pemrosesan gambar struk sebelum ekstraksi Google ML Kit (`FR-OCR-02`).
class ImagePreprocessRequest {
  const ImagePreprocessRequest({
    required this.bytes,
    this.skewHintDegrees = 0.0,
    this.applyContrastStretch = true,
  });

  final Uint8List bytes;
  final double skewHintDegrees;
  final bool applyContrastStretch;
}

/// Pra-pemrosesan gambar struk (auto-crop, deskew hingga 30°, contrast stretching)
/// yang dijalankan di background isolate agar tidak memblokir UI thread (`Cold Start / < 2.5s`).
class ImagePreprocessor {
  ImagePreprocessor._();

  static Future<Uint8List> preprocessReceipt(ImagePreprocessRequest request) {
    return compute(_preprocessInIsolate, request);
  }

  static Uint8List _preprocessInIsolate(ImagePreprocessRequest req) {
    final decoded = img.decodeImage(req.bytes);
    if (decoded == null) return req.bytes;

    var working = img.bakeOrientation(decoded);

    // 1. Batasi dimensi maks agar ML Kit cepat (< 2.5 detik)
    if (working.width > 1280) {
      working = img.copyResize(working, width: 1280);
    }

    // 2. Auto-crop area tepi gelap di luar kertas struk (`FR-OCR-02`)
    working = _autoCropMargins(working);

    // 3. Koreksi kemiringan (deskew hingga ±30° untuk `TC-OCR-03`)
    final angleToFix = req.skewHintDegrees != 0.0
        ? req.skewHintDegrees.clamp(-30.0, 30.0)
        : _estimateSkewAngle(working);
    if (angleToFix.abs() >= 1.0) {
      working = img.copyRotate(working, angle: -angleToFix);
    }

    // 4. Contrast stretching & konversi grayscale untuk struk kusut/pudar (`TC-OCR-02`)
    working = img.grayscale(working);
    if (req.applyContrastStretch) {
      working = _stretchContrast(working);
    }

    return Uint8List.fromList(img.encodeJpg(working, quality: 90));
  }

  static img.Image _autoCropMargins(img.Image source) {
    final w = source.width;
    final h = source.height;
    if (w < 40 || h < 40) return source;

    var minX = w;
    var minY = h;
    var maxX = 0;
    var maxY = 0;

    // Sampling tiap 4 piksel untuk efisiensi 60 FPS / < 150ms
    for (var y = 0; y < h; y += 4) {
      for (var x = 0; x < w; x += 4) {
        final pixel = source.getPixel(x, y);
        final lum = (0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b);
        if (lum > 110) {
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
          if (y < minY) minY = y;
          if (y > maxY) maxY = y;
        }
      }
    }

    if (maxX - minX < w * 0.3 || maxY - minY < h * 0.3) {
      return source;
    }

    final padX = (w * 0.02).round();
    final padY = (h * 0.02).round();
    final cropX = math.max(0, minX - padX);
    final cropY = math.max(0, minY - padY);
    final cropW = math.min(w - cropX, (maxX - minX) + padX * 2);
    final cropH = math.min(h - cropY, (maxY - minY) + padY * 2);

    return img.copyCrop(source, x: cropX, y: cropY, width: cropW, height: cropH);
  }

  /// Estimasi kemiringan sederhana hingga ±30° menggunakan variansi proyeksi horizontal.
  static double _estimateSkewAngle(img.Image source) {
    final thumb = img.copyResize(source, width: math.min(180, source.width));
    var bestAngle = 0.0;
    var bestScore = -1.0;

    for (var angle = -30; angle <= 30; angle += 5) {
      final rotated = angle == 0
          ? thumb
          : img.copyRotate(thumb, angle: angle.toDouble());
      final rowSums = List<double>.filled(rotated.height, 0);
      for (var y = 0; y < rotated.height; y += 2) {
        var darkCount = 0.0;
        for (var x = 0; x < rotated.width; x += 2) {
          final p = rotated.getPixel(x, y);
          final lum = 0.299 * p.r + 0.587 * p.g + 0.114 * p.b;
          if (lum < 140) darkCount += 1;
        }
        rowSums[y] = darkCount;
      }
      final mean = rowSums.reduce((a, b) => a + b) / rowSums.length;
      var variance = 0.0;
      for (final v in rowSums) {
        variance += (v - mean) * (v - mean);
      }
      if (variance > bestScore) {
        bestScore = variance;
        bestAngle = -angle.toDouble();
      }
    }
    return bestAngle;
  }

  static img.Image _stretchContrast(img.Image gray) {
    var minLum = 255;
    var maxLum = 0;
    for (var y = 0; y < gray.height; y += 3) {
      for (var x = 0; x < gray.width; x += 3) {
        final l = gray.getPixel(x, y).r.toInt();
        if (l < minLum) minLum = l;
        if (l > maxLum) maxLum = l;
      }
    }
    final range = math.max(1, maxLum - minLum);
    if (range >= 230) return gray;

    final out = img.Image.from(gray);
    for (var y = 0; y < out.height; y++) {
      for (var x = 0; x < out.width; x++) {
        final p = out.getPixel(x, y);
        final stretched = (((p.r - minLum) * 255) / range).clamp(0, 255).toInt();
        out.setPixelRgb(x, y, stretched, stretched, stretched);
      }
    }
    return out;
  }
}
