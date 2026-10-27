import 'dart:typed_data';
import 'package:flutter/foundation.dart';
// Conditional import for universal platform support
import 'web_file_downloader_stub.dart'
    if (dart.library.html) 'web_file_downloader_web.dart';

class WebFileDownloader {
  /// Initiates a browser or platform file download given raw bytes, filename, and mimeType
  static void downloadBytes({
    required Uint8List bytes,
    required String filename,
    required String mimeType,
  }) {
    saveFileBytes(bytes, filename, mimeType);
  }
}
