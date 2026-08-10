import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:open_filex/open_filex.dart';
import '../services/download_service.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DownloadProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF18181B),
        title: const Text('My Downloads', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          if (provider.activeDownloads.isNotEmpty) ...[
            Text('Downloading (${provider.activeDownloads.length})', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...provider.activeDownloads.map((item) => _buildActiveTile(item)),
            const SizedBox(height: 24),
          ],

          Text('Downloaded (${provider.completedDownloads.length})', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          if (provider.completedDownloads.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Text('No downloaded files yet', style: TextStyle(color: Colors.grey)),
              ),
            )
          else
            ...provider.completedDownloads.map((item) => _buildCompletedTile(context, item)),
        ],
      ),
    );
  }

  Widget _buildActiveTile(DownloadItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.downloading, color: Color(0xFFFACC15), size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAlignment.start,
              children: [
                Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                LinearProgressIndicator(value: item.progress, backgroundColor: Colors.white12, color: const Color(0xFFFACC15)),
                const SizedBox(height: 4),
                Text('${(item.progress * 100).toStringAsFixed(1)}%', style: const TextStyle(color: Colors.grey, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedTile(BuildContext context, DownloadItem item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: item.thumbnail.isNotEmpty
              ? Image.network(item.thumbnail, width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.play_circle_fill, color: Color(0xFFFACC15), size: 40))
              : const Icon(Icons.play_circle_fill, color: Color(0xFFFACC15), size: 40),
        ),
        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text('${item.quality.toUpperCase()} • MP4', style: const TextStyle(color: Colors.grey, fontSize: 12)),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert, color: Colors.grey),
          onPressed: () {},
        ),
        onTap: () {
          if (item.filePath != null) {
            OpenFilex.open(item.filePath!);
          }
        },
      ),
    );
  }
}
