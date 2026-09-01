import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

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
    final lower = videoUrl.toLowerCase();

    // 1. Direct On-Device YouTube Engine (100% immune to VPS datacenter blocks & bot challenges)
    if (lower.contains('youtube.com') || lower.contains('youtu.be')) {
      final yt = YoutubeExplode();
      try {
        final rawIdMatch = RegExp(r'(?:v=|\/shorts\/|\/embed\/|\/live\/|youtu\.be\/|\/v\/)([a-zA-Z0-9_-]{11})').firstMatch(videoUrl);
        final vidParam = rawIdMatch != null ? rawIdMatch.group(1)! : videoUrl.trim();
        
        // Fast direct metadata extraction
        final video = await yt.videos.get(vidParam).timeout(const Duration(seconds: 8));

        final qualities = <Map<String, String>>[
          {'label': 'Best Quality (HD)', 'value': 'best'},
          {'label': '1080p Full HD', 'value': '1080'},
          {'label': '720p HD', 'value': '720'},
          {'label': '480p SD', 'value': '480'},
          {'label': '360p SD', 'value': '360'},
        ];

        final audioQualities = [
          {'label': 'MP3 (High Quality)', 'value': 'mp3_best'},
          {'label': 'M4A (High Quality)', 'value': 'm4a_best'},
        ];

        return {
          'is_playlist': false,
          'title': video.title,
          'uploader': video.author,
          'thumbnail': video.thumbnails.highResUrl,
          'duration': video.duration?.inSeconds,
          'video_qualities': qualities,
          'audio_qualities': audioQualities,
          '_is_direct_yt': true,
        };
      } catch (e) {
        // If on-device fails, only try VPS if cookies are present
        final userCookies = await getUserCookiesForUrl(videoUrl);
        if (userCookies == null) {
          throw Exception('Could not extract YouTube video: ${e.toString()}');
        }
      } finally {
        yt.close();
      }
    }

    // 2. VPS Backend Engine (for Instagram, TikTok, Facebook, or fallback)
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

  // ─── Direct On-Device Stream Resolver for YouTube (Zero VPS dependence) ───
  static Future<String?> resolveDirectYouTubeStreamUrl(String videoUrl, String quality) async {
    try {
      final rawIdMatch = RegExp(r'(?:v=|\/shorts\/|\/embed\/|\/live\/|youtu\.be\/|\/v\/)([a-zA-Z0-9_-]{11})').firstMatch(videoUrl);
      final vidId = rawIdMatch != null ? rawIdMatch.group(1)! : '';
      if (vidId.isEmpty) return null;

      final instances = [
        'https://inv.tux.pizza/api/v1/videos/$vidId',
        'https://invidious.nerdvpn.de/api/v1/videos/$vidId',
        'https://vid.puffyan.us/api/v1/videos/$vidId',
        'https://invidious.private.coffee/api/v1/videos/$vidId',
      ];

      for (final inst in instances) {
        try {
          final res = await http.get(Uri.parse(inst)).timeout(const Duration(seconds: 4));
          if (res.statusCode == 200) {
            final data = jsonDecode(utf8.decode(res.bodyBytes));
            final formatStreams = data['formatStreams'] as List<dynamic>?;
            final adaptiveFormats = data['adaptiveFormats'] as List<dynamic>?;

            final isAudio = quality.startsWith('mp3') || quality.startsWith('m4a');
            if (isAudio && adaptiveFormats != null) {
              final audios = adaptiveFormats.where((f) => (f['type'] as String? ?? '').contains('audio')).toList();
              if (audios.isNotEmpty) {
                return audios.first['url'] as String?;
              }
            }

            if (formatStreams != null && formatStreams.isNotEmpty) {
              if (quality == '360') {
                final match = formatStreams.firstWhere((f) => (f['qualityLabel'] as String? ?? '').contains('360'), orElse: () => formatStreams.first);
                return match['url'] as String?;
              } else if (quality == '720') {
                final match = formatStreams.firstWhere((f) => (f['qualityLabel'] as String? ?? '').contains('720'), orElse: () => formatStreams.first);
                return match['url'] as String?;
              } else {
                return formatStreams.first['url'] as String?;
              }
            }
          }
        } catch (_) {}
      }
    } catch (_) {}
    return null;
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


