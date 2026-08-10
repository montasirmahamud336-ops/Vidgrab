import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/download_bottom_sheet.dart';

class HomeScreen extends StatefulWidget {
  final String? initialUrl;

  const HomeScreen({Key? key, this.initialUrl}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _urlController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialUrl != null && widget.initialUrl!.isNotEmpty) {
      _urlController.text = widget.initialUrl!;
      _handleSearch(widget.initialUrl!);
    }
  }

  Future<void> _handleSearch(String url) async {
    if (url.trim().isEmpty) return;
    setState(() => _isLoading = true);

    try {
      final info = await ApiService.getVideoInfo(url.trim());
      setState(() => _isLoading = false);

      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => DownloadBottomSheet(videoInfo: info, rawUrl: url.trim()),
      );
    } catch (e) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
      );
    }
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
              const SizedBox(height: 20),
              // SnapTube Logo & Header
              const Center(
                child: Text(
                  'Snaptube',
                  style: TextStyle(
                    color: Color(0xFFFACC15),
                    fontSize: 36,
                    fontWeight: FontWeight.black,
                    letterSpacing: -1,
                  ),
                ),
              ),
              const SizedBox(height: 30),

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
    return Column(
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
    );
  }
}
