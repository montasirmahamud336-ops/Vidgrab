import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:open_filex/open_filex.dart';
import '../services/download_service.dart';
import '../services/api_service.dart';

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

          if (provider.failedDownloads.isNotEmpty) ...[
            Text('Failed Downloads (${provider.failedDownloads.length})', style: const TextStyle(color: Colors.redAccent, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ...provider.failedDownloads.map((item) => _buildFailedTile(context, item)),
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

  Widget _buildFailedTile(BuildContext context, DownloadItem item) {
    final provider = Provider.of<DownloadProvider>(context, listen: false);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(item.errorMessage ?? 'Download failed', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.redAccent, fontSize: 11)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFFACC15)),
            tooltip: 'Retry',
            onPressed: () => provider.retryDownload(item),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.grey),
            tooltip: 'Dismiss',
            onPressed: () => provider.dismissFailedDownload(item),
          ),
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
              crossAxisAlignment: CrossAxisAlignment.start,
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
    final provider = Provider.of<DownloadProvider>(context, listen: false);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: item.thumbnail.isNotEmpty
              ? Image.network(ApiService.getProxyImageUrl(item.thumbnail), width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.play_circle_fill, color: Color(0xFFFACC15), size: 40))
              : const Icon(Icons.play_circle_fill, color: Color(0xFFFACC15), size: 40),
        ),
        title: Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text('${item.quality.toUpperCase()} • ${item.ext.toUpperCase()}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, color: Colors.grey),
          color: const Color(0xFF27272A),
          onSelected: (value) {
            if (value == 'play' && item.filePath != null) {
              OpenFilex.open(item.filePath!);
            } else if (value == 'delete') {
              provider.deleteDownload(item);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(value: 'play', child: Row(children: [Icon(Icons.play_arrow, color: Colors.white, size: 20), SizedBox(width: 8), Text('Play', style: TextStyle(color: Colors.white))])),
            const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.redAccent, size: 20), SizedBox(width: 8), Text('Delete', style: TextStyle(color: Colors.redAccent))])),
          ],
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
