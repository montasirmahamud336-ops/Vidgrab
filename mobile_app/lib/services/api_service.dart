import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Private VPS backend endpoint - completely hidden from UI
  static const String _baseUrl = 'http://192.64.118.232:8080';

  static String get baseUrl => _baseUrl;

  static Future<void> loadBaseUrl() async {
    // Preserves private backend URL safely
  }

  // ─── Direct Account Session Cookies ───
  static Future<String?> getYtCookies() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final c = prefs.getString('vidgrab_yt_cookies')?.trim();
      return (c != null && c.isNotEmpty) ? c : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> setYtCookies(String? cookies) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (cookies == null || cookies.trim().isEmpty) {
        await prefs.remove('vidgrab_yt_cookies');
      } else {
        await prefs.setString('vidgrab_yt_cookies', cookies.trim());
      }
    } catch (_) {}
  }

  static Future<String?> getIgCookies() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final c = prefs.getString('vidgrab_ig_cookies')?.trim();
      return (c != null && c.isNotEmpty) ? c : null;
    } catch (_) {
      return null;
    }
  }

  static Future<void> setIgCookies(String? cookies) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (cookies == null || cookies.trim().isEmpty) {
        await prefs.remove('vidgrab_ig_cookies');
      } else {
        await prefs.setString('vidgrab_ig_cookies', cookies.trim());
      }
    } catch (_) {}
  }

  static Future<String?> getUserCookiesForUrl(String url) async {
    final lower = url.toLowerCase();
    if (lower.contains('youtu.be') || lower.contains('youtube.com')) {
      return getYtCookies();
    }
    if (lower.contains('instagram.com')) {
      return getIgCookies();
    }
    return null;
  }

  // ─── Proxy Image for Instagram / CDN thumbnails ───
  static String getProxyImageUrl(String imageUrl) {
    if (imageUrl.isEmpty) return '';
    final lower = imageUrl.toLowerCase();
    if (lower.contains('cdninstagram.com') || lower.contains('fbcdn.net') || lower.contains('tiktokcdn.com')) {
      return '$_baseUrl/api/proxy-image?url=${Uri.encodeComponent(imageUrl)}';
    }
    return imageUrl;
  }

  static String sanitizeErrorMessage(String error) {
    String clean = error.replaceAll(RegExp(r'http://[0-9.]+(:\d+)?'), '')
                         .replaceAll(RegExp(r'https?://[^\s]+'), '')
                         .replaceAll(RegExp(r'192\.64\.118\.\d+'), '')
                         .replaceAll('Exception: ', '')
                         .trim();
    if (clean.isEmpty || clean.contains('SocketException') || clean.contains('Connection refused') || clean.contains('ClientException')) {
      return 'Server connection failed. Please check internet or server status.';
    }
    if (clean.contains('TimeoutException') || clean.contains('Future not completed')) {
      return 'Analysis timed out. Please tap Retry.';
    }
    if (clean.contains('yt-dlp') || clean.contains('ExtractorError') || clean.contains('HTTP Error 404')) {
      return 'Could not extract video. Connect account cookies in Settings for restricted/bot-checked links.';
    }
    return clean;
  }

  // ─── Fetch video info ───
  static Future<Map<String, dynamic>> getVideoInfo(String videoUrl) async {
    await loadBaseUrl();
    try {
      final endpoint = Uri.parse('$_baseUrl/info');
      final userCookies = await getUserCookiesForUrl(videoUrl);

      final Map<String, dynamic> bodyPayload = {
        'url': videoUrl,
        'quality': 'best',
      };
      if (userCookies != null) {
        bodyPayload['user_cookies'] = userCookies;
      }

      final response = await http.post(
        endpoint,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(bodyPayload),
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

  // ─── Get download stream URL with user cookies ───
  static Future<String> getDownloadFileUrl(String videoUrl, String quality, {String? title}) async {
    await loadBaseUrl();
    final userCookies = await getUserCookiesForUrl(videoUrl);
    final Uri uri = Uri.parse('$_baseUrl/download-file').replace(queryParameters: {
      'url': videoUrl,
      'quality': quality,
      if (title != null && title.isNotEmpty) 'title': title,
      if (userCookies != null) 'user_cookies': userCookies,
    });
    return uri.toString();
  }

  // ─── Server health check ───
  static Future<bool> checkServerHealth() async {
    await loadBaseUrl();
    try {
      final response = await http.get(Uri.parse('$_baseUrl/ads-config')).timeout(const Duration(seconds: 4));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ─── Fetch public ads config ───
  static Future<Map<String, dynamic>> getAdsConfig() async {
    await loadBaseUrl();
    try {
      final response = await http.get(Uri.parse('$_baseUrl/ads-config')).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (_) {}
    return {};
  }
}

