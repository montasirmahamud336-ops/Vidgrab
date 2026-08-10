import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
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
  });
}

class DownloadProvider extends ChangeNotifier {
  final List<DownloadItem> _activeDownloads = [];
  final List<DownloadItem> _completedDownloads = [];

  List<DownloadItem> get activeDownloads => _activeDownloads;
  List<DownloadItem> get completedDownloads => _completedDownloads;

  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  DownloadProvider() {
    _initNotifications();
  }

  void _initNotifications() async {
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _notificationsPlugin.initialize(initSettings);
  }

  Future<void> startDownload({
    required String title,
    required String videoUrl,
    required String quality,
    required String ext,
    required String thumbnail,
  }) async {
    // Request storage permissions on Android
    if (Platform.isAndroid) {
      await Permission.storage.request();
      await Permission.notification.request();
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

    _runDownload(item);
  }

  Future<void> _runDownload(DownloadItem item) async {
    try {
      final downloadUrl = ApiService.getDownloadFileUrl(item.videoUrl, item.quality, title: item.title);
      final request = http.Request('GET', Uri.parse(downloadUrl));
      final response = await http.Client().send(request);

      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) {
          dir = await getExternalStorageDirectory();
        }
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      final safeTitle = item.title.replaceAll(RegExp(r'[<>:"/\\|?*]'), '_').replaceAll(' ', '_');
      final fileName = '${safeTitle}_${item.quality}.${item.ext}';
      final file = File('${dir!.path}/$fileName');

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
      });

      await sink.close();

      item.status = 'completed';
      item.filePath = file.path;
      item.progress = 1.0;

      _activeDownloads.remove(item);
      _completedDownloads.insert(0, item);
      notifyListeners();

      _showCompletedNotification(item.title);
    } catch (e) {
      item.status = 'failed';
      notifyListeners();
    }
  }

  void _showCompletedNotification(String title) async {
    const androidDetails = AndroidNotificationDetails(
      'snaptube_downloads',
      'Media Downloads',
      channelDescription: 'SnapTube Background Download Notifications',
      importance: Importance.high,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);
    await _notificationsPlugin.show(
      0,
      'Download Complete!',
      title,
      notificationDetails,
    );
  }
}
