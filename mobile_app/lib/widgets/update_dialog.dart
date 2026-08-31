import 'package:flutter/material.dart';
import '../services/update_service.dart';

class UpdateDialog extends StatefulWidget {
  final AppVersionInfo versionInfo;

  const UpdateDialog({Key? key, required this.versionInfo}) : super(key: key);

  static Future<void> show(BuildContext context, AppVersionInfo info) {
    return showDialog(
      context: context,
      barrierDismissible: !info.forceUpdate,
      builder: (_) => UpdateDialog(versionInfo: info),
    );
  }

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _isDownloading = false;
  double _progress = 0.0;
  String _downloadStatus = '';
  String? _errorMessage;

  void _startUpdate() {
    setState(() {
      _isDownloading = true;
      _progress = 0.0;
      _errorMessage = null;
      _downloadStatus = 'Connecting to server...';
    });

    UpdateService.downloadAndInstallApk(
      apkUrl: widget.versionInfo.apkUrl,
      onProgress: (progress, received, total) {
        if (mounted) {
          setState(() {
            _progress = progress;
            final receivedMB = (received / (1024 * 1024)).toStringAsFixed(1);
            final totalMB = total > 0 ? (total / (1024 * 1024)).toStringAsFixed(1) : '?';
            _downloadStatus = '$receivedMB MB / $totalMB MB (${(progress * 100).toInt()}%)';
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _isDownloading = false;
            _errorMessage = error;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final info = widget.versionInfo;

    return PopScope(
      canPop: !info.forceUpdate && !_isDownloading,
      child: Dialog(
        backgroundColor: const Color(0xFF18181B),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFFFACC15), width: 1.2),
        ),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with update badge
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFACC15).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.system_update, color: Color(0xFFFACC15), size: 26),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          info.forceUpdate ? 'Important Update Required' : 'New Update Available',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Version ${info.latestVersion}',
                          style: const TextStyle(
                            color: Color(0xFFFACC15),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Changelog section
              if (info.changelog.isNotEmpty) ...[
                const Text(
                  "What's New:",
                  style: TextStyle(color: Colors.grey, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF27272A),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    info.changelog,
                    style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Zero Data Loss assurance notice
              Row(
                children: const [
                  Icon(Icons.shield_outlined, color: Colors.greenAccent, size: 16),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Zero Data Loss: All your downloaded files and settings will be preserved.',
                      style: TextStyle(color: Colors.greenAccent, fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Progress Bar or Error Display
              if (_isDownloading) ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: _progress > 0 ? _progress : null,
                      backgroundColor: const Color(0xFF27272A),
                      color: const Color(0xFFFACC15),
                      minHeight: 8,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        _downloadStatus,
                        style: const TextStyle(color: Color(0xFFFACC15), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ] else if (_errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.redAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Action Buttons
              if (!_isDownloading)
                Row(
                  children: [
                    if (!info.forceUpdate) ...[
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.grey),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Later', style: TextStyle(color: Colors.grey)),
                        ),
                      ),
                      const SizedBox(width: 12),
                    ],
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFFACC15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _startUpdate,
                        icon: const Icon(Icons.download, color: Colors.black, size: 20),
                        label: const Text(
                          'Update Now',
                          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
