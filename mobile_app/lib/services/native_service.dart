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

  /// Gets the real public downloads directory /storage/emulated/0/Download/VidGrab
  static Future<String?> getPublicDownloadsPath() async {
    if (!Platform.isAndroid) return null;
    try {
      final path = await _channel.invokeMethod<String>('getPublicDownloadsPath');
      return path;
    } catch (_) {
      return null;
    }
  }

  /// Closes the current activity (for transparent share overlay)
  static Future<void> finishActivity() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('finishActivity');
    } catch (_) {}
  }
}

