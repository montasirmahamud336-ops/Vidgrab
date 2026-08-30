import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import '../services/download_service.dart';
import '../services/api_service.dart';
import '../services/native_service.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({Key? key}) : super(key: key);

  String _getMimeType(DownloadItem item) {
    final lowerExt = item.ext.toLowerCase();
    final lowerQ = item.quality.toLowerCase();
    if (lowerExt == 'mp3' || lowerQ.startsWith('mp3')) {
      return 'audio/mpeg';
    }
    if (lowerExt == 'm4a' || lowerQ.startsWith('m4a')) {
      return 'audio/mp4';
    }
    return 'video/mp4';
  }

  void _playFile(BuildContext context, DownloadItem item) {
    if (item.filePath == null || !File(item.filePath!).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File not found in storage'), backgroundColor: Colors.redAccent),
      );
      return;
    }
    final mime = _getMimeType(item);
    OpenFilex.open(item.filePath!, type: mime);
  }

  void _openWith(BuildContext context, DownloadItem item) {
    if (item.filePath == null || !File(item.filePath!).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File not found in storage'), backgroundColor: Colors.redAccent),
      );
      return;
    }
    final mime = _getMimeType(item);
    NativeService.openWith(item.filePath!, mimeType: mime);
  }

  void _shareFile(BuildContext context, DownloadItem item) {
    if (item.filePath == null || !File(item.filePath!).existsSync()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('File not found in storage'), backgroundColor: Colors.redAccent),
      );
      return;
    }
    Share.shareXFiles([XFile(item.filePath!)], text: item.title);
  }

  void _showInfoDialog(BuildContext context, DownloadItem item) {
    final file = item.filePath != null ? File(item.filePath!) : null;
    final exists = file != null && file.existsSync();
    final sizeStr = item.formattedFileSize;
    final fileName = item.filePath != null ? item.filePath!.split(Platform.pathSeparator).last : 'Unknown';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: const Color(0xFFFACC15).withValues(alpha: 0.3)),
        ),
        title: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Color(0xFFFACC15), size: 24),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'File Details',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoRow('Title', item.title),
              _buildInfoRow('File Name', fileName),
              _buildInfoRow('Quality & Format', '${item.quality.toUpperCase()} • ${item.ext.toUpperCase()}'),
              _buildInfoRow('File Size', sizeStr.isNotEmpty ? sizeStr : (exists ? '${(file.lengthSync() / (1024 * 1024)).toStringAsFixed(1)} MB' : 'Unknown')),
              _buildInfoRow('Platform', item.platform ?? 'Online Media'),
              if (item.dateDownloaded != null)
                _buildInfoRow('Downloaded At', item.dateDownloaded!),
              _buildInfoRow('Storage Path', item.filePath ?? '/storage/emulated/0/Download/VidGrab'),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.folder_open_rounded, color: Color(0xFFFACC15), size: 18),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Stored in your phone\'s internal "Download/VidGrab" folder.',
                        style: TextStyle(color: Colors.grey, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close', style: TextStyle(color: Color(0xFFFACC15), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          SelectableText(value, style: const TextStyle(color: Colors.white, fontSize: 13)),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, DownloadItem item) {
    final provider = Provider.of<DownloadProvider>(context, listen: false);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF18181B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Colors.redAccent),
        ),
        title: const Text('Delete Download?', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          'Are you sure you want to permanently delete "${item.title}" from your phone storage?',
          style: const TextStyle(color: Colors.grey, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.of(ctx).pop();
              provider.deleteDownload(item);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('File deleted from device storage'), backgroundColor: Colors.redAccent),
              );
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
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
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Storage directory updated to: $target'), backgroundColor: const Color(0xFF18181B)),
                  );
                }
              },
              child: const Text('Save & Apply', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

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
          // Storage Location Card
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF18181B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFACC15).withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.folder_special_rounded, color: Color(0xFFFACC15), size: 24),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Download Storage Folder', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                      Text(provider.customStorageDir, style: const TextStyle(color: Colors.grey, fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                InkWell(
                  onTap: () => _showEditStorageDialog(context),
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFACC15).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFACC15).withValues(alpha: 0.4)),
                    ),
                    child: const Text('Change', style: TextStyle(color: Color(0xFFFACC15), fontSize: 11, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),

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
    final sizeStr = item.formattedFileSize;
    final isAudio = item.ext.toLowerCase() == 'mp3' || item.quality.toLowerCase().startsWith('mp3') || item.ext.toLowerCase() == 'm4a';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF18181B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: item.thumbnail.isNotEmpty
              ? Image.network(
                  ApiService.getProxyImageUrl(item.thumbnail),
                  width: 52,
                  height: 52,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(
                    isAudio ? Icons.music_note_rounded : Icons.play_circle_fill,
                    color: const Color(0xFFFACC15),
                    size: 38,
                  ),
                )
              : Icon(
                  isAudio ? Icons.music_note_rounded : Icons.play_circle_fill,
                  color: const Color(0xFFFACC15),
                  size: 38,
                ),
        ),
        title: Text(
          item.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 3),
          child: Text(
            '${item.quality.toUpperCase()} • ${item.ext.toUpperCase()}${sizeStr.isNotEmpty ? " • $sizeStr" : ""}',
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ),
        trailing: PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: Colors.grey),
          color: const Color(0xFF27272A),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          onSelected: (value) {
            switch (value) {
              case 'play':
                _playFile(context, item);
                break;
              case 'open_with':
                _openWith(context, item);
                break;
              case 'share':
                _shareFile(context, item);
                break;
              case 'info':
                _showInfoDialog(context, item);
                break;
              case 'delete':
                _confirmDelete(context, item);
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'play',
              child: Row(
                children: [
                  Icon(Icons.play_arrow_rounded, color: Color(0xFFFACC15), size: 20),
                  SizedBox(width: 10),
                  Text('Play', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'open_with',
              child: Row(
                children: [
                  Icon(Icons.open_in_new_rounded, color: Colors.cyanAccent, size: 20),
                  SizedBox(width: 10),
                  Text('Open with...', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'share',
              child: Row(
                children: [
                  Icon(Icons.share_rounded, color: Colors.lightGreenAccent, size: 20),
                  SizedBox(width: 10),
                  Text('Share / Move', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'info',
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Colors.orangeAccent, size: 20),
                  SizedBox(width: 10),
                  Text('Details / Info', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            const PopupMenuDivider(height: 1),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                  SizedBox(width: 10),
                  Text('Delete', style: TextStyle(color: Colors.redAccent)),
                ],
              ),
            ),
          ],
        ),
        onTap: () => _playFile(context, item),
      ),
    );
  }
}

