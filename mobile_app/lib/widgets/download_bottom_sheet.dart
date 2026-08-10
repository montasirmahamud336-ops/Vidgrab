import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/download_service.dart';

class DownloadBottomSheet extends StatefulWidget {
  final Map<String, dynamic> videoInfo;
  final String rawUrl;

  const DownloadBottomSheet({Key? key, required this.videoInfo, required this.rawUrl}) : super(key: key);

  @override
  State<DownloadBottomSheet> createState() => _DownloadBottomSheetState();
}

class _DownloadBottomSheetState extends State<DownloadBottomSheet> {
  String selectedQuality = 'best';
  String selectedExt = 'mp4';

  @override
  void initState() {
    super.initState();
    final videoQualities = widget.videoInfo['video_qualities'] as List<dynamic>? ?? [];
    if (videoQualities.isNotEmpty) {
      selectedQuality = videoQualities[0]['value'].toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.videoInfo['title'] ?? 'Video';
    final thumbnail = widget.videoInfo['thumbnail'] ?? '';
    final videoQualities = widget.videoInfo['video_qualities'] as List<dynamic>? ?? [];
    final audioQualities = widget.videoInfo['audio_qualities'] as List<dynamic>? ?? [];

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: const BoxDecoration(
        color: Color(0xFF18181B), // Dark SnapTube theme
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAlignment.start,
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

          // Title & Header
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: thumbnail.isNotEmpty
                    ? Image.network(thumbnail, width: 60, height: 60, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.movie, size: 40, color: Color(0xFFFACC15)))
                    : const Icon(Icons.movie, size: 40, color: Color(0xFFFACC15)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          const Text('Download', style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),

          // Audio section
          const Text('Music', style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 6),
          ...audioQualities.map((aq) {
            final val = aq['value'].toString();
            final label = aq['label'].toString();
            final isSelected = selectedQuality == val;
            return _buildQualityTile(
              label: label,
              icon: Icons.music_note,
              isSelected: isSelected,
              onTap: () {
                setState(() {
                  selectedQuality = val;
                  selectedExt = val.contains('mp3') ? 'mp3' : 'm4a';
                });
              },
            );
          }),

          const SizedBox(height: 12),
          // Video section
          const Text('Video', style: TextStyle(color: Colors.grey, fontSize: 12)),
          const SizedBox(height: 6),
          ...videoQualities.map((vq) {
            final val = vq['value'].toString();
            final label = vq['label'].toString();
            final isSelected = selectedQuality == val;
            return _buildQualityTile(
              label: label,
              icon: Icons.videocam,
              isSelected: isSelected,
              onTap: () {
                setState(() {
                  selectedQuality = val;
                  selectedExt = 'mp4';
                });
              },
            );
          }),

          const SizedBox(height: 20),

          // Yellow CTA Button - "Watch ad to download"
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFACC15), // SnapTube Yellow
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
              onPressed: () {
                Navigator.pop(context);
                Provider.of<DownloadProvider>(context, listen: false).startDownload(
                  title: title,
                  videoUrl: widget.rawUrl,
                  quality: selectedQuality,
                  ext: selectedExt,
                  thumbnail: thumbnail,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Download started in background...'),
                    backgroundColor: Color(0xFFFACC15),
                  ),
                );
              },
              child: const Text(
                'Watch ad to download',
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 10),
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
