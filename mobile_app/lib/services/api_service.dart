import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Hardcoded private server URL
  static const String baseUrl = 'http://192.64.118.232:8080';

  static Future<void> loadBaseUrl() async {
    // No-op for security: preserve private server URL
  }

  static String sanitizeErrorMessage(String error) {
    // Hide IP addresses, internal domains, and stack traces from UI
    String clean = error.replaceAll(RegExp(r'http://[0-9.]+(:\d+)?'), '')
                         .replaceAll(RegExp(r'https?://[^\s]+'), '')
                         .replaceAll(RegExp(r'192\.64\.118\.\d+'), '')
                         .replaceAll('Exception: ', '')
                         .trim();
    if (clean.isEmpty || clean.contains('SocketException') || clean.contains('Connection refused') || clean.contains('ClientException')) {
      return 'Server unavailable. Please check your internet connection and try again.';
    }
    if (clean.contains('TimeoutException') || clean.contains('Future not completed')) {
      return 'Analysis timed out. Please tap Retry.';
    }
    if (clean.contains('yt-dlp') || clean.contains('ExtractorError') || clean.contains('HTTP Error 404')) {
      return 'Could not extract video. Private or restricted links are not supported.';
    }
    return clean;
  }

  // Fetch video info (qualities, title, thumbnail, duration)
  static Future<Map<String, dynamic>> getVideoInfo(String videoUrl) async {
    try {
      final endpoint = Uri.parse('$baseUrl/info');
      final response = await http.post(
        endpoint,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'url': videoUrl, 'quality': 'best'}),
      ).timeout(const Duration(seconds: 90));

      if (response.statusCode == 200) {
        return jsonDecode(utf8.decode(response.bodyBytes));
      } else {
        try {
          final err = jsonDecode(response.body);
          final msg = err['detail']?.toString() ?? 'Failed to analyze video URL';
          throw Exception(sanitizeErrorMessage(msg));
        } catch (_) {
          throw Exception('Unable to process this video link. Please verify the URL.');
        }
      }
    } catch (e) {
      throw Exception(sanitizeErrorMessage(e.toString()));
    }
  }

  // Get download stream URL for direct background download
  static String getDownloadFileUrl(String videoUrl, String quality, {String? title}) {
    final Uri uri = Uri.parse('$baseUrl/download-file').replace(queryParameters: {
      'url': videoUrl,
      'quality': quality,
      if (title != null) 'title': title,
    });
    return uri.toString();
  }

  // Fetch public ads config
  static Future<Map<String, dynamic>> getAdsConfig() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/ads-config')).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (_) {}
    return {};
  }
}
