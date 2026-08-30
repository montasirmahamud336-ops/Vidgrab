import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../services/api_service.dart';
import 'login_webview_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isYtConnected = false;
  bool _isIgConnected = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final yt = await ApiService.getYtCookies();
    final ig = await ApiService.getIgCookies();

    if (mounted) {
      setState(() {
        _isYtConnected = yt != null && yt.isNotEmpty;
        _isIgConnected = ig != null && ig.isNotEmpty;
      });
    }
  }

  void _openGoogleLogin() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginWebViewScreen(platform: 'youtube'),
      ),
    );
    if (result == true || mounted) {
      _loadSettings();
    }
  }

  void _openInstagramLogin() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginWebViewScreen(platform: 'instagram'),
      ),
    );
    if (result == true || mounted) {
      _loadSettings();
    }
  }

  Future<void> _cleanJunkCache() async {
    int deletedCount = 0;
    try {
      final tempDir = await getTemporaryDirectory();
      if (await tempDir.exists()) {
        final list = tempDir.listSync();
        for (var f in list) {
          try {
            await f.delete(recursive: true);
            deletedCount++;
          } catch (_) {}
        }
      }
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cache cleaned! $deletedCount temporary files removed.'),
          backgroundColor: const Color(0xFFFACC15),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF18181B),
        title: const Text('Settings', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Account Connections Section ──
          const Text('Account Connections (Anti-Restriction)', style: TextStyle(color: Color(0xFFFACC15), fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          // YouTube Card
          _buildConnectionCard(
            platformName: 'YouTube / Google',
            icon: Icons.play_circle_fill,
            brandColor: const Color(0xFFFF0000),
            isConnected: _isYtConnected,
            description: 'Sign in with Google to bypass YouTube bot restrictions & download HD/4K videos smoothly.',
            buttonText: _isYtConnected ? 'Reconnect with Google' : 'Continue with Google',
            onConnect: _openGoogleLogin,
            onDisconnect: () async {
              await ApiService.setYtCookies(null);
              _loadSettings();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Google account disconnected'), backgroundColor: Colors.grey),
                );
              }
            },
          ),
          const SizedBox(height: 14),

          // Instagram Card
          _buildConnectionCard(
            platformName: 'Instagram',
            icon: Icons.camera_alt,
            brandColor: const Color(0xFFE1306C),
            isConnected: _isIgConnected,
            description: 'Sign in to Instagram to unlock full HD downloads and access private or restricted reels.',
            buttonText: _isIgConnected ? 'Reconnect Instagram' : 'Login with Instagram',
            onConnect: _openInstagramLogin,
            onDisconnect: () async {
              await ApiService.setIgCookies(null);
              _loadSettings();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Instagram account disconnected'), backgroundColor: Colors.grey),
                );
              }
            },
          ),

          const SizedBox(height: 24),

          // ── Storage & Maintenance ──
          const Text('Storage & Maintenance', style: TextStyle(color: Color(0xFFFACC15), fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          _buildSimpleTile(
            icon: Icons.folder,
            iconColor: Colors.amber,
            title: 'Download Storage Directory',
            subtitle: '/storage/emulated/0/Download/VidGrab',
            trailing: const Icon(Icons.check, color: Colors.green, size: 20),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Downloaded media is saved to /Download/VidGrab/'), backgroundColor: Color(0xFF18181B)),
              );
            },
          ),

          _buildSimpleTile(
            icon: Icons.cleaning_services,
            iconColor: Colors.tealAccent,
            title: 'Clean Cache & Buffers',
            subtitle: 'Clear temporary stream files and optimize memory',
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: _cleanJunkCache,
          ),

          const SizedBox(height: 24),

          // ── App Info ──
          const Text('About', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          _buildSimpleTile(
            icon: Icons.info_outline,
            iconColor: Colors.white70,
            title: 'VidGrab Downloader',
            subtitle: 'Version 3.0.0 (Official Release)',
            trailing: const Icon(Icons.verified, color: Color(0xFFFACC15), size: 20),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'VidGrab Downloader',
                applicationVersion: 'v3.0.0 (Official)',
                applicationLegalese: '© 2026 VidGrab by DrawnDimension',
                children: const [
                  SizedBox(height: 10),
                  Text('VidGrab provides fast, private, and high-quality video downloading across YouTube, Instagram, Facebook, and TikTok with zero bot interruptions.'),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionCard({
    required String platformName,
    required IconData icon,
    required Color brandColor,
    required bool isConnected,
    required String description,
    required String buttonText,
    required VoidCallback onConnect,
    required VoidCallback onDisconnect,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isConnected ? Colors.green.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: brandColor.withValues(alpha: 0.15),
                    child: Icon(icon, color: brandColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Text(platformName, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isConnected ? Colors.green : Colors.grey).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: (isConnected ? Colors.green : Colors.grey).withValues(alpha: 0.4)),
                ),
                child: Text(
                  isConnected ? 'Connected ✅' : 'Not Connected',
                  style: TextStyle(color: isConnected ? Colors.green : Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isConnected ? const Color(0xFF27272A) : const Color(0xFFFACC15),
                    foregroundColor: isConnected ? Colors.white : Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                  icon: Icon(icon, size: 18, color: isConnected ? brandColor : Colors.black),
                  label: Text(buttonText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: onConnect,
                ),
              ),
              if (isConnected) const SizedBox(width: 10),
              if (isConnected)
                IconButton(
                  icon: const Icon(Icons.logout, color: Colors.redAccent, size: 20),
                  tooltip: 'Disconnect',
                  onPressed: onDisconnect,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Widget trailing,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor: iconColor.withValues(alpha: 0.12),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        trailing: trailing,
      ),
    );
  }
}


