import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'services/download_service.dart';
import 'screens/home_screen.dart';
import 'screens/downloads_screen.dart';
import 'screens/settings_screen.dart';

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
      title: 'SnapTube Downloader',
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
  late StreamSubscription _intentSubscription;

  @override
  void initState() {
    super.initState();
    _initShareIntent();
  }

  void _initShareIntent() {
    // Listen for shared text/links when app is in memory
    _intentSubscription = ReceiveSharingIntent.getTextStream().listen((String text) {
      _processSharedText(text);
    }, onError: (err) {});

    // Listen for shared text/links when app is opened from closed state
    ReceiveSharingIntent.getInitialText().then((String? text) {
      if (text != null && text.isNotEmpty) {
        _processSharedText(text);
      }
    });
  }

  void _processSharedText(String text) {
    final urlRegExp = RegExp(r'https?://[^\s]+');
    final match = urlRegExp.firstMatch(text);
    if (match != null) {
      setState(() {
        _sharedUrl = match.group(0);
        _currentIndex = 0; // Switch to Search/Home tab
      });
    }
  }

  @override
  void dispose() {
    _intentSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
