import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/api_service.dart';
import '../services/native_service.dart';
import '../services/update_service.dart';
import '../widgets/download_bottom_sheet.dart';
import '../widgets/update_dialog.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _checkForUpdates();
    _checkSharedIntent();
  }

  void _checkSharedIntent() async {
    NativeService.setSharedIntentListener((text) {
      if (text.isNotEmpty && mounted) {
        _extractAndHandleUrl(text);
      }
    });

    try {
      final text = await NativeService.getSharedText();
      if (text != null && text.isNotEmpty && mounted) {
        _extractAndHandleUrl(text);
      }
    } catch (_) {}
  }

  void _extractAndHandleUrl(String text) {
    final urlRegExp = RegExp(r'https?://[^\s<>"]+');
    final match = urlRegExp.firstMatch(text);
    if (match != null) {
      String clean = match.group(0)!;
      clean = clean.replaceAll(RegExp(r'[\)\]\},;."\x27]+$'), '');
      _urlController.text = clean;
      _handleSearch(clean);
    }
  }

  void _checkForUpdates() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;
    final updateInfo = await UpdateService.checkUpdate();
    if (updateInfo != null && mounted) {
      UpdateDialog.show(context, updateInfo);
    }
  }

  Future<void> _handleSearch(String url) async {
    final cleanUrl = url.trim();
    if (cleanUrl.isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final info = await ApiService.getVideoInfo(cleanUrl);
      setState(() => _isLoading = false);

      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => DownloadBottomSheet(videoInfo: info, rawUrl: cleanUrl),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ApiService.sanitizeErrorMessage(e.toString())),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _onShortcutTap(String platformName) async {
    HapticFeedback.lightImpact();
    // Try to auto-paste from clipboard if available
    ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
    String pastedText = data?.text?.trim() ?? '';
    
    if (pastedText.isNotEmpty && (pastedText.startsWith('http://') || pastedText.startsWith('https://'))) {
      _urlController.text = pastedText;
      _handleSearch(pastedText);
      return;
    }

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF18181B),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.link, color: Color(0xFFFACC15)),
                const SizedBox(width: 10),
                Text('Download from $platformName', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Text('Copy any video link from $platformName and paste it below:', style: const TextStyle(color: Colors.grey, fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: _urlController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Paste $platformName URL here...',
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: const Color(0xFF27272A),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.content_paste, color: Color(0xFFFACC15)),
                  onPressed: () async {
                    ClipboardData? cb = await Clipboard.getData(Clipboard.kTextPlain);
                    if (cb?.text != null) {
                      _urlController.text = cb!.text!.trim();
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFACC15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                onPressed: () {
                  Navigator.pop(ctx);
                  _handleSearch(_urlController.text);
                },
                child: const Text('Analyze Video', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              const SizedBox(height: 10),
              // VidGrab Logo & Header
              Center(
                child: Column(
                  children: [
                    Image.asset(
                      'assets/logo.png',
                      height: 56,
                      errorBuilder: (_, __, ___) => const Icon(Icons.video_library, size: 56, color: Color(0xFFFACC15)),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'VidGrab',
                      style: TextStyle(
                        color: Color(0xFFFACC15),
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Search Bar
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF18181B),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white12),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const Icon(Icons.download, color: Colors.grey),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _urlController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'Search or paste video link...',
                          hintStyle: TextStyle(color: Colors.grey),
                          border: InputBorder.none,
                        ),
                        onSubmitted: _handleSearch,
                      ),
                    ),
                    IconButton(
                      icon: _isLoading
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFACC15)))
                          : const CircleAvatar(
                              backgroundColor: Color(0xFFFACC15),
                              radius: 18,
                              child: Icon(Icons.search, color: Colors.black, size: 20),
                            ),
                      onPressed: () => _handleSearch(_urlController.text),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Quick Site Shortcuts (YouTube, Facebook, Instagram, TikTok, WhatsApp)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Supported Sites',
                  style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  _buildSiteShortcut('YouTube', Icons.play_circle_fill, Colors.red),
                  _buildSiteShortcut('Facebook', Icons.facebook, Colors.blue),
                  _buildSiteShortcut('Instagram', Icons.camera_alt, Colors.pink),
                  _buildSiteShortcut('TikTok', Icons.music_note, Colors.cyan),
                  _buildSiteShortcut('Twitter/X', Icons.tag, Colors.lightBlue),
                  _buildSiteShortcut('WhatsApp', Icons.chat, Colors.green),
                  _buildSiteShortcut('Vimeo', Icons.video_library, Colors.blueAccent),
                  _buildSiteShortcut('More', Icons.more_horiz, Colors.grey),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSiteShortcut(String name, IconData icon, Color color) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _onShortcutTap(name),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: const Color(0xFF18181B),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 6),
            Text(name, style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
