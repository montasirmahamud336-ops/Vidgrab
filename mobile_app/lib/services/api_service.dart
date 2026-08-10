import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Default server URL - can be updated in App Settings
  static String baseUrl = 'http://localhost:8000';

  static Future<void> loadBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString('vps_url');
    if (savedUrl != null && savedUrl.isNotEmpty) {
      baseUrl = savedUrl.endsWith('/') ? savedUrl.substring(0, savedUrl.length - 1) : savedUrl;
    }
  }

  static Future<void> saveBaseUrl(String newUrl) async {
    baseUrl = newUrl.endsWith('/') ? newUrl.substring(0, newUrl.length - 1) : newUrl;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vps_url', baseUrl);
  }

  // Fetch video info (qualities, title, thumbnail, duration)
  static Future<Map<String, dynamic>> getVideoInfo(String videoUrl) async {
    await loadBaseUrl();
    final endpoint = Uri.parse('$baseUrl/info');
    final response = await http.post(
      endpoint,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'url': videoUrl, 'quality': 'best'}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } else {
      final err = jsonDecode(response.body);
      throw Exception(err['detail'] ?? 'Failed to analyze video URL');
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
    await loadBaseUrl();
    try {
      final response = await http.get(Uri.parse('$baseUrl/ads-config'));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (_) {}
    return {};
  }
}
