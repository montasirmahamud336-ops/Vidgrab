import 'dart:async';
import 'package:flutter/material.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../services/native_service.dart';
import '../widgets/download_bottom_sheet.dart';

class ShareOverlayScreen extends StatefulWidget {
  const ShareOverlayScreen({Key? key}) : super(key: key);

  @override
  State<ShareOverlayScreen> createState() => _ShareOverlayScreenState();
}

class _ShareOverlayScreenState extends State<ShareOverlayScreen> {
  String? _sharedUrl;
  StreamSubscription? _intentSubscription;
  bool _hasParsed = false;

  @override
  void initState() {
    super.initState();
    _initSharingIntent();
  }

  void _initSharingIntent() {
    // 1. Initial shared text when activity launched from external app (YouTube, IG, TikTok, FB)
    ReceiveSharingIntent.getInitialMedia().then((List<SharedMediaFile> value) {
      for (final file in value) {
        if (file.path.isNotEmpty) {
          _extractUrl(file.path);
          break;
        }
      }
      ReceiveSharingIntent.reset();
    });

    // 2. Stream listener in case intent fires while alive
    _intentSubscription = ReceiveSharingIntent.getMediaStream().listen((List<SharedMediaFile> value) {
      for (final file in value) {
        if (file.path.isNotEmpty) {
          _extractUrl(file.path);
          break;
        }
      }
    }, onError: (_) {});
  }

  void _extractUrl(String text) {
    if (_hasParsed) return;
    final urlRegExp = RegExp(r'https?://[^\s]+');
    final match = urlRegExp.firstMatch(text);
    if (match != null) {
      setState(() {
        _sharedUrl = match.group(0)!;
        _hasParsed = true;
      });
    }
  }

  void _closeOverlay() {
    NativeService.finishActivity();
  }

  @override
  void dispose() {
    _intentSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black.withValues(alpha: 0.45),
      body: Stack(
        children: [
          // Tap background outside modal to close overlay and return to social media
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeOverlay,
              child: const SizedBox.expand(),
            ),
          ),

          // Bottom Download Sheet
          Align(
            alignment: Alignment.bottomCenter,
            child: _sharedUrl != null
                ? DownloadBottomSheet(
                    rawUrl: _sharedUrl!,
                    onDownloadStarted: () {
                      _closeOverlay();
                    },
                  )
                : Container(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF18181B),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFFACC15).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Color(0xFFFACC15), strokeWidth: 2.5),
                        ),
                        SizedBox(width: 14),
                        Text(
                          'VidGrab: Capturing shared link...',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
