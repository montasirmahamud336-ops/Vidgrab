import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
      initialRoute: '/',
      routes: {
        '/': (_) => const MainNavigationWrapper(),
        '/share_overlay': (_) => const MainNavigationWrapper(),
      },
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

  @override
  Widget build(BuildContext context) {
    final screens = [
      const HomeScreen(),
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
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (index == 1) {
            Provider.of<DownloadProvider>(context, listen: false).reloadDownloads();
          }
        },
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

