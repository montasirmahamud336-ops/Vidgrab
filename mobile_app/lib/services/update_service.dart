import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'api_service.dart';
import 'native_service.dart';

class AppVersionInfo {
  final String latestVersion;
  final int versionCode;
  final int minVersionCode;
  final bool forceUpdate;
  final String changelog;
  final String apkUrl;
  final String releaseDate;

  AppVersionInfo({
    required this.latestVersion,
    required this.versionCode,
    required this.minVersionCode,
    required this.forceUpdate,
    required this.changelog,
    required this.apkUrl,
    required this.releaseDate,
  });

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) {
    return AppVersionInfo(
      latestVersion: json['latest_version'] ?? '3.0.0',
      versionCode: json['version_code'] is int ? json['version_code'] : int.tryParse(json['version_code'].toString()) ?? 300,
      minVersionCode: json['min_version_code'] is int ? json['min_version_code'] : int.tryParse(json['min_version_code'].toString()) ?? 300,
      forceUpdate: json['force_update'] == true,
      changelog: json['changelog'] ?? '',
      apkUrl: json['apk_url'] ?? '/download-apk',
      releaseDate: json['release_date'] ?? '',
    );
  }
}

class UpdateService {
  // Current app installed version details
  static const int currentVersionCode = 300;
  static const String currentVersionName = "3.0.0";

  /// Checks the VPS backend for updates.
  /// Returns [AppVersionInfo] if a newer version is available, or null if up to date.
  static Future<AppVersionInfo?> checkUpdate() async {
    try {
      final endpoint = Uri.parse('${ApiService.baseUrl}/api/app-version');
      final response = await http.get(endpoint).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final info = AppVersionInfo.fromJson(data);

        // Check if remote version code is higher than current version code
        if (info.versionCode > currentVersionCode || (info.forceUpdate && info.minVersionCode > currentVersionCode)) {
          return info;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Downloads the APK and triggers the Android system package installer
  static Future<void> downloadAndInstallApk({
    required String apkUrl,
    required void Function(double progress, int receivedBytes, int totalBytes) onProgress,
    required void Function(String error) onError,
  }) async {
    try {
      String fullUrl = apkUrl.startsWith('http') ? apkUrl : '${ApiService.baseUrl}$apkUrl';
      final client = http.Client();
      final request = http.Request('GET', Uri.parse(fullUrl));
      final response = await client.send(request);

      if (response.statusCode != 200) {
        onError('Failed to download update (Server error: ${response.statusCode})');
        return;
      }

      final totalBytes = response.contentLength ?? 0;
      final tempDir = await getTemporaryDirectory();
      final apkFile = File('${tempDir.path}/VidGrab_update_${DateTime.now().millisecondsSinceEpoch}.apk');
      final sink = apkFile.openWrite();

      int receivedBytes = 0;
      await for (final chunk in response.stream) {
        receivedBytes += chunk.length;
        sink.add(chunk);

        final progress = totalBytes > 0 ? (receivedBytes / totalBytes).clamp(0.0, 1.0) : 0.0;
        onProgress(progress, receivedBytes, totalBytes);
      }

      await sink.close();

      // Launch native Android package installer (Preserves all user data and settings)
      final success = await NativeService.installApk(apkFile.path);
      if (!success) {
        onError('Could not open Android installer. Please enable Install Unknown Apps permission for VidGrab in Settings.');
      }
    } catch (e) {
      onError('Update failed: ${e.toString()}');
    }
  }
}
