import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'api_service.dart';

class DownloadItem {
  final String id;
  final String title;
  final String videoUrl;
  final String quality;
  final String ext;
  final String thumbnail;
  double progress;
  num bytesDownloaded;
  num totalBytes;
  String status; // 'downloading', 'completed', 'failed'
  String? filePath;
  String? errorMessage;

  DownloadItem({
    required this.id,
    required this.title,
    required this.videoUrl,
    required this.quality,
    required this.ext,
    required this.thumbnail,
    this.progress = 0.0,
    this.bytesDownloaded = 0,
    this.totalBytes = 0,
    this.status = 'downloading',
    this.filePath,
    this.errorMessage,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'videoUrl': videoUrl,
        'quality': quality,
        'ext': ext,
        'thumbnail': thumbnail,
        'status': status,
        'filePath': filePath,
      };

  factory DownloadItem.fromJson(Map<String, dynamic> json) => DownloadItem(
        id: json['id'] ?? '',
        title: json['title'] ?? 'Video',
        videoUrl: json['videoUrl'] ?? '',
        quality: json['quality'] ?? 'best',
        ext: json['ext'] ?? 'mp4',
        thumbnail: json['thumbnail'] ?? '',
        status: json['status'] ?? 'completed',
        filePath: json['filePath'],
        progress: 1.0,
      );
}

class DownloadProvider extends ChangeNotifier {
  final List<DownloadItem> _activeDownloads = [];
  final List<DownloadItem> _completedDownloads = [];
  final List<DownloadItem> _failedDownloads = [];

  List<DownloadItem> get activeDownloads => _activeDownloads;
  List<DownloadItem> get completedDownloads => _completedDownloads;
  List<DownloadItem> get failedDownloads => _failedDownloads;

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  DownloadProvider() {
    _initNotifications();
    _loadPersistedDownloads();
  }

  void _initNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _notificationsPlugin.initialize(initSettings);
  }

  Future<void> _loadPersistedDownloads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? savedJson = prefs.getString('vidgrab_completed_downloads');
      if (savedJson != null) {
        final List<dynamic> decoded = jsonDecode(savedJson);
        _completedDownloads.clear();
        for (var item in decoded) {
          final download = DownloadItem.fromJson(Map<String, dynamic>.from(item));
          if (download.filePath != null && File(download.filePath!).existsSync()) {
            _completedDownloads.add(download);
          }
        }
      }

      // Also scan VidGrab download directory for external files
      await _scanDownloadDirectory();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> _savePersistedDownloads() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_completedDownloads.map((e) => e.toJson()).toList());
      await prefs.setString('vidgrab_completed_downloads', encoded);
    } catch (_) {}
  }

  Future<void> _scanDownloadDirectory() async {
    try {
      Directory? dir;
      if (Platform.isAndroid) {
        final externalDir = Directory('/storage/emulated/0/Download/VidGrab');
        if (await externalDir.exists()) dir = externalDir;
      }
      dir ??= await getExternalStorageDirectory();

      if (dir != null && await dir.exists()) {
        final entities = dir.listSync();
        for (var entity in entities) {
          if (entity is File) {
            final path = entity.path;
            final basename = path.split(Platform.pathSeparator).last;
            final isAlreadyListed = _completedDownloads.any((d) => d.filePath == path);

            if (!isAlreadyListed && (basename.endsWith('.mp4') || basename.endsWith('.mp3') || basename.endsWith('.m4a'))) {
              final ext = basename.split('.').last;
              final title = basename.replaceAll(RegExp(r'\.(mp4|mp3|m4a)$'), '').replaceAll('_', ' ');
              _completedDownloads.add(
                DownloadItem(
                  id: entity.statSync().modified.millisecondsSinceEpoch.toString(),
                  title: title,
                  videoUrl: '',
                  quality: ext == 'mp3' ? 'mp3' : 'HD',
                  ext: ext,
                  thumbnail: '',
                  status: 'completed',
                  filePath: path,
                  progress: 1.0,
                ),
              );
            }
          }
        }
      }
    } catch (_) {}
  }

  Future<void> deleteDownload(DownloadItem item) async {
    try {
      if (item.filePath != null) {
        final file = File(item.filePath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (_) {}
    _completedDownloads.remove(item);
    _savePersistedDownloads();
    notifyListeners();
  }

  Future<void> startDownload({
    required String title,
    required String videoUrl,
    required String quality,
    required String ext,
    required String thumbnail,
  }) async {
    if (Platform.isAndroid) {
      try {
        await Permission.storage.request();
        await Permission.notification.request();
      } catch (_) {}
    }

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final item = DownloadItem(
      id: id,
      title: title,
      videoUrl: videoUrl,
      quality: quality,
      ext: ext,
      thumbnail: thumbnail,
    );

    _activeDownloads.insert(0, item);
    notifyListeners();

    _showStartNotification(item);
    _runDownload(item);
  }

  Future<void> _runDownload(DownloadItem item) async {
    final notificationId = item.id.hashCode;
    int lastNotifTime = 0;
    int lastNotifPct = -1;

    try {
      Directory dir;
      if (Platform.isAndroid) {
        try {
          final externalDir = Directory('/storage/emulated/0/Download/VidGrab');
          if (!await externalDir.exists()) {
            await externalDir.create(recursive: true);
          }
          dir = externalDir;
        } catch (_) {
          try {
            dir = Directory('/storage/emulated/0/Download');
            if (!await dir.exists()) {
              await dir.create(recursive: true);
            }
          } catch (_) {
            dir = (await getExternalStorageDirectory()) ?? (await getApplicationDocumentsDirectory());
          }
        }
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      final safeTitle = item.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').replaceAll(' ', '_');
      final fileName = '${safeTitle}_${item.quality}.${item.ext}';
      final file = File('${dir.path}/$fileName');

      final lowerUrl = item.videoUrl.toLowerCase();
      bool downloadedDirectly = false;

      // ── 1. ON-DEVICE YOUTUBE STREAMING (100% immune to datacenter/VPS IP bot checks) ──
      if (lowerUrl.contains('youtube.com') || lowerUrl.contains('youtu.be')) {
        final yt = YoutubeExplode();
        try {
          final video = await yt.videos.get(item.videoUrl).timeout(const Duration(seconds: 15));
          final manifest = await yt.videos.streamsClient.getManifest(video.id).timeout(const Duration(seconds: 15));

          StreamInfo? streamInfo;
          if (item.quality.startsWith('mp3') || item.quality.startsWith('m4a')) {
            streamInfo = manifest.audioOnly.isNotEmpty ? manifest.audioOnly.withHighestBitrate() : null;
          } else if (item.quality == '360') {
            final matching = manifest.muxed.where((s) => s.qualityLabel.contains('360'));
            streamInfo = matching.isNotEmpty ? matching.first : (manifest.muxed.isNotEmpty ? manifest.muxed.first : null);
          } else if (item.quality == '720') {
            final matching = manifest.muxed.where((s) => s.qualityLabel.contains('720'));
            streamInfo = matching.isNotEmpty ? matching.first : (manifest.muxed.isNotEmpty ? manifest.muxed.withHighestBitrate() : null);
          } else {
            streamInfo = manifest.muxed.isNotEmpty ? manifest.muxed.withHighestBitrate() : (manifest.audioOnly.isNotEmpty ? manifest.audioOnly.withHighestBitrate() : null);
          }

          if (streamInfo != null) {
            item.totalBytes = streamInfo.size.totalBytes;
            int received = 0;
            final stream = yt.videos.streamsClient.get(streamInfo);
            final sink = file.openWrite();

            await for (final chunk in stream) {
              received += chunk.length;
              sink.add(chunk);

              item.bytesDownloaded = received;
              if (item.totalBytes > 0) {
                item.progress = (received / item.totalBytes).clamp(0.0, 1.0);
              }
              notifyListeners();

              final now = DateTime.now().millisecondsSinceEpoch;
              final currentPct = (item.progress * 100).toInt();
              if (now - lastNotifTime > 500 || currentPct >= lastNotifPct + 3) {
                lastNotifTime = now;
                lastNotifPct = currentPct;
                _updateProgressNotification(item);
              }
            }

            await sink.close();
            downloadedDirectly = true;
          }
        } catch (_) {
          // If direct on-device fails, fallback to VPS endpoint below
        } finally {
          yt.close();
        }
      }

      // ── 2. VPS BACKEND STREAMING (for Instagram, TikTok, Facebook or fallback) ──
      if (!downloadedDirectly) {
        final downloadUrl = await ApiService.getDownloadFileUrl(item.videoUrl, item.quality, title: item.title);
        final client = http.Client();
        final response = await client.send(http.Request('GET', Uri.parse(downloadUrl)));

        if (response.statusCode != 200) {
          final errText = await response.stream.bytesToString();
          try {
            final decoded = jsonDecode(errText);
            final msg = decoded['detail'] ?? errText;
            throw Exception(msg);
          } catch (_) {
            throw Exception(errText.isNotEmpty ? errText : 'Server error ${response.statusCode}');
          }
        }

        item.totalBytes = response.contentLength ?? 0;
        int received = 0;

        final sink = file.openWrite();
        await response.stream.forEach((chunk) {
          received += chunk.length;
          sink.add(chunk);

          item.bytesDownloaded = received;
          if (item.totalBytes > 0) {
            item.progress = (received / item.totalBytes).clamp(0.0, 1.0);
          }
          notifyListeners();

          final now = DateTime.now().millisecondsSinceEpoch;
          final currentPct = (item.progress * 100).toInt();
          if (now - lastNotifTime > 500 || currentPct >= lastNotifPct + 3) {
            lastNotifTime = now;
            lastNotifPct = currentPct;
            _updateProgressNotification(item);
          }
        });

        await sink.close();
      }

      item.status = 'completed';
      item.filePath = file.path;
      item.progress = 1.0;

      _activeDownloads.remove(item);
      _completedDownloads.insert(0, item);
      _savePersistedDownloads();
      notifyListeners();

      await _notificationsPlugin.cancel(notificationId);
      _showCompletedNotification(item.title);
    } catch (e) {
      item.status = 'failed';
      item.errorMessage = ApiService.sanitizeErrorMessage(e.toString());
      _activeDownloads.remove(item);
      if (!_failedDownloads.contains(item)) {
        _failedDownloads.insert(0, item);
      }
      notifyListeners();

      await _notificationsPlugin.cancel(notificationId);
      _showFailedNotification(item.title, item.errorMessage ?? 'Download failed');
    }
  }

  void retryDownload(DownloadItem item) {
    _failedDownloads.remove(item);
    item.status = 'downloading';
    item.errorMessage = null;
    item.progress = 0.0;
    _activeDownloads.insert(0, item);
    notifyListeners();
    _runDownload(item);
  }

  void dismissFailedDownload(DownloadItem item) {
    _failedDownloads.remove(item);
    notifyListeners();
  }

  void _showStartNotification(DownloadItem item) async {
    const androidDetails = AndroidNotificationDetails(
      'vidgrab_downloads',
      'VidGrab Downloads',
      channelDescription: 'VidGrab Background Download Notifications',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: 100,
      progress: 0,
      ongoing: true,
      onlyAlertOnce: true,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(
      item.id.hashCode,
      'VidGrab: Starting Download',
      item.title,
      notificationDetails,
    );
  }

  void _updateProgressNotification(DownloadItem item) async {
    final pct = (item.progress * 100).toInt();
    final downloadedMB = (item.bytesDownloaded / (1024 * 1024)).toStringAsFixed(1);
    final totalMB = item.totalBytes > 0 ? '${(item.totalBytes / (1024 * 1024)).toStringAsFixed(1)} MB' : '...';

    final androidDetails = AndroidNotificationDetails(
      'vidgrab_downloads',
      'VidGrab Downloads',
      channelDescription: 'VidGrab Background Download Progress',
      importance: Importance.low,
      priority: Priority.low,
      showProgress: true,
      maxProgress: 100,
      progress: pct,
      onlyAlertOnce: true,
      ongoing: true,
    );
    final notificationDetails = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(
      item.id.hashCode,
      'Downloading $pct% • ${item.title}',
      '$downloadedMB MB / $totalMB',
      notificationDetails,
    );
  }

  void _showFailedNotification(String title, String error) async {
    const androidDetails = AndroidNotificationDetails(
      'vidgrab_downloads',
      'VidGrab Downloads',
      channelDescription: 'VidGrab Background Download Notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      'Download Failed',
      '$title: $error',
      notificationDetails,
    );
  }

  void _showCompletedNotification(String title) async {
    const androidDetails = AndroidNotificationDetails(
      'vidgrab_downloads',
      'VidGrab Downloads',
      channelDescription: 'VidGrab Background Download Notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      'Download Complete! 🎉',
      title,
      notificationDetails,
    );
  }
}

