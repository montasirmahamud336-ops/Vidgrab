import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'services/download_service.dart';
import 'screens/home_screen.dart';
import 'screens/downloads_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/download_bottom_sheet.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => DownloadProvider(),
      child: const SnapTubeApp(),
    ),
  );
}

class SnapTubeApp extends StatelessWidget {
  const SnapTubeApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VidGrab Downloader',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF09090B),
        primaryColor: const Color(0xFFFACC15),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFACC15),
          secondary: Color(0xFFEAB308),
        ),
      ),
      home: const MainNavigationWrapper(),
    );
  }
}

class MainNavigationWrapper extends StatefulWidget {
  const MainNavigationWrapper({Key? key}) : super(key: key);

  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> {
  int _currentIndex = 0;
  String? _sharedUrl;
  bool _isOverlayMode = false;
  StreamSubscription? _intentSubscription;

  @override
  void initState() {
    super.initState();
    _initShareIntent();
  }

  void _initShareIntent() {
    // Listen for shared text/links when app is in memory
    _intentSubscription = ReceiveSharingIntent.getMediaStream().listen((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _processSharedText(value.first.path);
      }
    }, onError: (err) {});

    // Listen for shared text/links when app is opened from closed state
    ReceiveSharingIntent.getInitialMedia().then((List<SharedMediaFile> value) {
      if (value.isNotEmpty) {
        _processSharedText(value.first.path);
      }
    });
  }

  void _processSharedText(String text) {
    final urlRegExp = RegExp(r'https?://[^\s]+');
    final match = urlRegExp.firstMatch(text);
    if (match != null) {
      final url = match.group(0)!;
      setState(() {
        _sharedUrl = url;
        _isOverlayMode = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showQuickShareOverlay(url);
      });
    }
  }

  void _showQuickShareOverlay(String url) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black54, // Semi-transparent backdrop over Facebook/YouTube
      builder: (modalContext) => DownloadBottomSheet(
        rawUrl: url,
        onDownloadStarted: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('VidGrab: Download started in background!'),
              backgroundColor: Color(0xFFFACC15),
            ),
          );
          // Return user directly back to Facebook/YouTube/Instagram
          Future.delayed(const Duration(milliseconds: 500), () {
            SystemNavigator.pop();
          });
        },
      ),
    ).then((_) {
      if (_isOverlayMode) {
        // If bottom sheet dismissed, return to social media app
        SystemNavigator.pop();
      }
    });
  }

  @override
  void dispose() {
    _intentSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // If launched via Share Intent, render transparent Scaffold over social media app!
    if (_isOverlayMode) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Container(),
      );
    }

    final screens = [
      HomeScreen(initialUrl: _sharedUrl),
      const DownloadsScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: const Color(0xFF18181B),
        selectedItemColor: const Color(0xFFFACC15),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Download'),
          BottomNavigationBarItem(icon: Icon(Icons.play_circle_fill), label: 'Play'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
