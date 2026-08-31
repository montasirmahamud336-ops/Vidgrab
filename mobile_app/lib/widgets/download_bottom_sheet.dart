import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/download_service.dart';

class DownloadBottomSheet extends StatefulWidget {
  final Map<String, dynamic>? videoInfo;
  final String rawUrl;
  final VoidCallback? onDownloadStarted;

  const DownloadBottomSheet({
    Key? key,
    this.videoInfo,
    required this.rawUrl,
    this.onDownloadStarted,
  }) : super(key: key);

  @override
  State<DownloadBottomSheet> createState() => _DownloadBottomSheetState();
}

class _DownloadBottomSheetState extends State<DownloadBottomSheet> {
  Map<String, dynamic>? _info;
  bool _isLoading = false;
  String? _error;
  String selectedQuality = 'best';
  String selectedExt = 'mp4';

  @override
  void initState() {
    super.initState();
    if (widget.videoInfo != null) {
      _info = widget.videoInfo;
      _initDefaultQuality();
    } else {
      _fetchVideoInfo();
    }
  }

  void _initDefaultQuality() {
    if (_info != null) {
      final videoQualities = _info!['video_qualities'] as List<dynamic>? ?? [];
      if (videoQualities.isNotEmpty) {
        selectedQuality = videoQualities[0]['value'].toString();
      }
    }
  }

  Future<void> _fetchVideoInfo() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final info = await ApiService.getVideoInfo(widget.rawUrl);
      if (mounted) {
        setState(() {
          _info = info;
          _isLoading = false;
        });
        _initDefaultQuality();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = ApiService.sanitizeErrorMessage(e.toString());
          _isLoading = false;
        });
      }
    }
  }

  void _triggerDownload() async {
    if (_info == null) return;
    final title = _info!['title'] ?? 'Video';
    final thumbnail = _info!['thumbnail'] ?? '';

    final downloadProvider = Provider.of<DownloadProvider>(context, listen: false);
    downloadProvider.startDownload(
      title: title,
      videoUrl: widget.rawUrl,
      quality: selectedQuality,
      ext: selectedExt,
      thumbnail: thumbnail,
    );

    if (widget.onDownloadStarted != null) {
      widget.onDownloadStarted!();
    } else {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('VidGrab: Video download started in background!'),
            backgroundColor: Color(0xFFFACC15),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(30),
        decoration: const BoxDecoration(
          color: Color(0xFF18181B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            CircularProgressIndicator(color: Color(0xFFFACC15)),
            SizedBox(height: 16),
            Text('Analyzing video links...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Color(0xFF18181B),
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 48),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFACC15)),
              onPressed: _fetchVideoInfo,
              child: const Text('Retry', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      );
    }

    final title = _info?['title'] ?? 'Video';
    final thumbnail = _info?['thumbnail']?.toString() ?? '';
    final videoQualities = _info?['video_qualities'] as List<dynamic>? ?? [];
    final audioQualities = _info?['audio_qualities'] as List<dynamic>? ?? [];

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        color: Color(0xFF18181B), // Dark SnapTube theme
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[700],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Thumbnail & Title Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (thumbnail.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    ApiService.getProxyImageUrl(thumbnail),
                    width: 90,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 90,
                      height: 60,
                      color: const Color(0xFF27272A),
                      child: const Icon(Icons.video_library, color: Colors.grey),
                    ),
                  ),
                ),
              if (thumbnail.isNotEmpty) const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, height: 1.3),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Video formats
          if (videoQualities.isNotEmpty) ...[
            const Text('Video Resolutions', style: TextStyle(color: Color(0xFFFACC15), fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            ...videoQualities.map((q) {
              final val = q['value'].toString();
              final label = q['label'].toString();
              final isSel = selectedQuality == val && selectedExt == 'mp4';
              return _buildQualityTile(
                label: label,
                icon: Icons.video_file,
                isSelected: isSel,
                onTap: () => setState(() {
                  selectedQuality = val;
                  selectedExt = 'mp4';
                }),
              );
            }).toList(),
            const SizedBox(height: 12),
          ],

          // Audio formats
          if (audioQualities.isNotEmpty) ...[
            const Text('Audio Formats', style: TextStyle(color: Color(0xFFFACC15), fontWeight: FontWeight.bold, fontSize: 13)),
            const SizedBox(height: 8),
            ...audioQualities.map((q) {
              final val = q['value'].toString();
              final label = q['label'].toString();
              final ext = val.startsWith('mp3') ? 'mp3' : 'm4a';
              final isSel = selectedQuality == val;
              return _buildQualityTile(
                label: label,
                icon: Icons.music_note,
                isSelected: isSel,
                onTap: () => setState(() {
                  selectedQuality = val;
                  selectedExt = ext;
                }),
              );
            }).toList(),
            const SizedBox(height: 16),
          ],

          // Download CTA Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFACC15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              onPressed: _triggerDownload,
              child: const Text(
                'Download in Background',
                style: TextStyle(color: Colors.black, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQualityTile({
    required String label,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF27272A) : const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: isSelected ? const Color(0xFFFACC15) : Colors.white10),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: isSelected ? const Color(0xFFFACC15) : Colors.grey),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(color: isSelected ? Colors.white : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal),
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              color: isSelected ? const Color(0xFFFACC15) : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}
