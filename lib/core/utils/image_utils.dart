import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ImageUtils {
  static const int maxSizeKB = 200;

  static Future<String> compressAndEncode(XFile xFile) async {
    final bytes = await xFile.readAsBytes();
    Uint8List compressed;

    if (!kIsWeb) {
      final result = await FlutterImageCompress.compressWithList(
        bytes,
        minWidth: 800,
        minHeight: 800,
        quality: 70,
        format: CompressFormat.jpeg,
      );

      if (result.lengthInBytes > maxSizeKB * 1024) {
        final result2 = await FlutterImageCompress.compressWithList(
          bytes,
          minWidth: 600,
          minHeight: 600,
          quality: 50,
          format: CompressFormat.jpeg,
        );
        compressed = result2;
      } else {
        compressed = result;
      }
    } else {
      // Web: no native compression, use raw bytes (already small for QR codes)
      compressed = bytes;
    }

    if (compressed.lengthInBytes > maxSizeKB * 1024) {
      throw Exception(
        'Image is too large (${(compressed.lengthInBytes / 1024).round()}KB). '
        'Please use a smaller image (max ${maxSizeKB}KB).',
      );
    }

    return 'data:image/jpeg;base64,${base64Encode(compressed)}';
  }

  static int getSizeKB(String base64DataUrl) {
    final data =
        base64DataUrl.contains(',') ? base64DataUrl.split(',').last : base64DataUrl;
    return ((data.length * 3) / 4 / 1024).round();
  }
}
