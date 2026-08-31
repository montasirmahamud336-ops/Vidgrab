import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/download_service.dart';
import '../services/update_service.dart';
import '../widgets/update_dialog.dart';
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

  void _showEditStorageDialog(BuildContext context) {
    final provider = Provider.of<DownloadProvider>(context, listen: false);
    final current = provider.customStorageDir;
    final controller = TextEditingController(text: current);

    final presets = [
      {'label': 'Downloads / VidGrab (Recommended)', 'path': '/storage/emulated/0/Download/VidGrab'},
      {'label': 'Main Downloads Folder', 'path': '/storage/emulated/0/Download'},
      {'label': 'Movies / VidGrab', 'path': '/storage/emulated/0/Movies/VidGrab'},
      {'label': 'DCIM / VidGrab (Gallery)', 'path': '/storage/emulated/0/DCIM/VidGrab'},
    ];

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF18181B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: const Color(0xFFFACC15).withValues(alpha: 0.3)),
          ),
          title: const Row(
            children: [
              Icon(Icons.folder_open_rounded, color: Color(0xFFFACC15), size: 24),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Storage Folder',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Choose where downloaded videos & audios are saved:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                const SizedBox(height: 14),
                ...presets.map((p) {
                  final isSelected = controller.text.trim() == p['path'];
                  return InkWell(
                    onTap: () {
                      setDialogState(() {
                        controller.text = p['path']!;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFFACC15).withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: isSelected ? const Color(0xFFFACC15) : Colors.white10),
                      ),
                      child: Row(
                        children: [
                          Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_off, color: isSelected ? const Color(0xFFFACC15) : Colors.grey, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p['label']!, style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontSize: 12, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                                Text(p['path']!, style: const TextStyle(color: Colors.grey, fontSize: 10)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 8),
                const Text('Or type custom folder path:', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                TextField(
                  controller: controller,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: Colors.black26,
                    hintText: '/storage/emulated/0/...',
                    hintStyle: const TextStyle(color: Colors.white24, fontSize: 11),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white24)),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Color(0xFFFACC15))),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFACC15),
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final target = controller.text.trim();
                if (target.isNotEmpty) {
                  await provider.setCustomStorageDir(target);
                  if (mounted) {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Storage directory updated to: $target'), backgroundColor: const Color(0xFF18181B)),
                    );
                    setState(() {});
                  }
                }
              },
              child: const Text('Save & Apply', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }


  void _checkManualUpdates() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)),
            SizedBox(width: 12),
            Text('Checking for new updates...'),
          ],
        ),
        backgroundColor: Color(0xFFFACC15),
        duration: Duration(seconds: 1),
      ),
    );

    final info = await UpdateService.checkUpdate();
    if (!mounted) return;

    if (info != null) {
      UpdateDialog.show(context, info);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You are using the latest version of VidGrab (v3.0.0)!'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
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
        elevation: 0,
        title: const Text(
          'Settings & Accounts',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // ── Account Connections for Bot Bypass ──
          const Text(
            'Account Connections',
            style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Connect your personal accounts to download private, restricted, or bot-checked videos with 100% success.',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 16),

          _buildConnectionCard(
            platformName: 'Google / YouTube',
            icon: Icons.play_arrow,
            brandColor: Colors.redAccent,
            isConnected: _isYtConnected,
            description: 'Bypasses YouTube bot challenges and enables 1080p/4K audio downloads.',
            buttonText: _isYtConnected ? 'Re-authenticate Google' : 'Sign in with Google',
            onConnect: _openGoogleLogin,
            onDisconnect: () async {
              await ApiService.setYtCookies(null);
              _loadSettings();
            },
          ),

          const SizedBox(height: 12),

          _buildConnectionCard(
            platformName: 'Instagram',
            icon: Icons.camera_alt,
            brandColor: Colors.pinkAccent,
            isConnected: _isIgConnected,
            description: 'Enables downloading private reels, stories, and login-only posts.',
            buttonText: _isIgConnected ? 'Re-authenticate Instagram' : 'Sign in with Instagram',
            onConnect: _openInstagramLogin,
            onDisconnect: () async {
              await ApiService.setIgCookies(null);
              _loadSettings();
            },
          ),

          const SizedBox(height: 24),

          // ── Storage & Maintenance ──
          const Text(
            'Storage & Maintenance',
            style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          Consumer<DownloadProvider>(
            builder: (context, provider, child) {
              return _buildSimpleTile(
                icon: Icons.folder,
                iconColor: const Color(0xFFFACC15),
                title: 'Download Storage Directory',
                subtitle: provider.customStorageDir,
                trailing: TextButton(
                  onPressed: () => _showEditStorageDialog(context),
                  child: const Text('Edit', style: TextStyle(color: Color(0xFFFACC15), fontWeight: FontWeight.bold)),
                ),
                onTap: () => _showEditStorageDialog(context),
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

          // ── App Info & Updates ──
          const Text('App Updates & About', style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),

          _buildSimpleTile(
            icon: Icons.system_update,
            iconColor: const Color(0xFFFACC15),
            title: 'Check for Updates',
            subtitle: 'Version 3.0.0 • Tap to check for newer releases',
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: _checkManualUpdates,
          ),

          _buildSimpleTile(
            icon: Icons.info_outline,
            iconColor: Colors.white70,
            title: 'About VidGrab Downloader',
            subtitle: 'Official Zero-Data-Loss Build',
            trailing: const Icon(Icons.verified, color: Color(0xFFFACC15), size: 20),
            onTap: () {
              showAboutDialog(
                context: context,
                applicationName: 'VidGrab Downloader',
                applicationVersion: 'v3.0.0 (Official)',
                applicationLegalese: '© 2026 VidGrab by DrawnDimension',
                children: const [
                  SizedBox(height: 10),
                  Text('VidGrab provides fast, private, and high-quality video downloading across YouTube, Instagram, Facebook, and TikTok with zero bot interruptions and in-app updates.'),
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


