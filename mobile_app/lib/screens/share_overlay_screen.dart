import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  StreamSubscription? _mediaSubscription;
  bool _hasParsed = false;


  @override
  void initState() {
    super.initState();
    _initSharingIntent();
  }

  void _initSharingIntent() async {
    // 1. Live Native Intent Listener (from Kotlin onNewIntent / onCreate)
    NativeService.setSharedIntentListener((text) {
      if (text.isNotEmpty) {
        _extractUrl(text);
      }
    });

    // 2. Direct native Intent EXTRA_TEXT / ClipData capture with instant polling
    for (int delayMs in [0, 60, 150, 300, 600]) {
      if (delayMs > 0) await Future.delayed(Duration(milliseconds: delayMs));
      if (_sharedUrl != null) break;
      try {
        final nativeText = await NativeService.getSharedText();
        if (nativeText != null && nativeText.isNotEmpty) {
          _extractUrl(nativeText);
          if (_sharedUrl != null) break;
        }
      } catch (_) {}
    }

    // 3. Initial shared media / text files
    try {
      final initialMedia = await ReceiveSharingIntent.getInitialMedia();
      for (final file in initialMedia) {
        if (file.path.isNotEmpty) {
          _extractUrl(file.path);
          break;
        }
      }
      ReceiveSharingIntent.reset();
    } catch (_) {}

    // 4. Stream listeners for dynamic sharing
    try {
      _mediaSubscription = ReceiveSharingIntent.getMediaStream().listen((List<SharedMediaFile> value) {
        for (final file in value) {
          if (file.path.isNotEmpty) {
            _extractUrl(file.path);
            break;
          }
        }
      }, onError: (_) {});
    } catch (_) {}
    // 5. Clipboard fallback if still empty after 700ms
    Future.delayed(const Duration(milliseconds: 700), () async {
      if (_sharedUrl == null && mounted) {
        try {
          final clip = await Clipboard.getData(Clipboard.kTextPlain);
          if (clip?.text != null && clip!.text!.isNotEmpty) {
            _extractUrl(clip.text!);
          }
        } catch (_) {}
      }
    });
  }

  void _extractUrl(String text) {
    if (_hasParsed && _sharedUrl != null) return;
    final urlRegExp = RegExp(r'https?://[^\s]+');
    final match = urlRegExp.firstMatch(text);
    if (match != null) {
      String clean = match.group(0)!;
      clean = clean.replaceAll(RegExp(r'[\)\]\},;."\x27]+$'), '');
      if (mounted) {
        setState(() {
          _sharedUrl = clean;
          _hasParsed = true;
        });
      }
    }
  }

  void _closeOverlay() {
    NativeService.finishActivity();
  }

  @override
  void dispose() {
    _mediaSubscription?.cancel();
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
