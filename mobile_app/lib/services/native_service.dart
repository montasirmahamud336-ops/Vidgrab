import 'dart:io';
import 'package:flutter/services.dart';

class NativeService {
  static const MethodChannel _channel = MethodChannel('com.vidgrab.snaptube/native');

  /// Forces Android to show the system app chooser dialog ("Open with...")
  static Future<void> openWith(String filePath, {String mimeType = '*/*'}) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('openWith', {
        'filePath': filePath,
        'mimeType': mimeType,
      });
    } catch (_) {}
  }

  /// Triggers MediaScannerConnection to index the file into Gallery and File Manager
  static Future<void> scanFile(String filePath) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('scanFile', {
        'filePath': filePath,
      });
    } catch (_) {}
  }
}
