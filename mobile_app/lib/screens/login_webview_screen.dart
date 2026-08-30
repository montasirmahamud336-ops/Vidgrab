import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import '../services/api_service.dart';

class LoginWebViewScreen extends StatefulWidget {
  final String platform; // 'youtube' or 'instagram'

  const LoginWebViewScreen({Key? key, required this.platform}) : super(key: key);

  @override
  State<LoginWebViewScreen> createState() => _LoginWebViewScreenState();
}

class _LoginWebViewScreenState extends State<LoginWebViewScreen> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _isCaptured = false;

  bool get isYouTube => widget.platform == 'youtube';
  String get title => isYouTube ? 'Sign in with Google' : 'Log in to Instagram';
  Color get brandColor => isYouTube ? const Color(0xFFFF0000) : const Color(0xFFE1306C);

  @override
  void initState() {
    super.initState();
    _initWebView();
  }

  void _initWebView() {
    final startUrl = isYouTube
        ? 'https://accounts.google.com/ServiceLogin?service=youtube&passive=true&continue=https://m.youtube.com/'
        : 'https://www.instagram.com/accounts/login/';

    final params = const PlatformWebViewControllerCreationParams();
    final controller = WebViewController.fromPlatformCreationParams(params);

    controller
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(
        'Mozilla/5.0 (Linux; Android 13; Pixel 7 Pro) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) {
            if (mounted) setState(() => _progress = progress);
          },
          onPageStarted: (url) {
            _checkAuthSuccess(url);
          },
          onPageFinished: (url) {
            _checkAuthSuccess(url);
          },
        ),
      )
      ..loadRequest(Uri.parse(startUrl));

    if (controller.platform is AndroidWebViewController) {
      AndroidWebViewController.enableDebugging(false);
      (controller.platform as AndroidWebViewController).setMediaPlaybackRequiresUserGesture(false);
    }

    _controller = controller;
  }

  Future<void> _checkAuthSuccess(String url) async {
    if (_isCaptured) return;
    final lower = url.toLowerCase();

    if (isYouTube) {
      if ((lower.contains('m.youtube.com') || lower.contains('www.youtube.com')) &&
          !lower.contains('accounts.google.com') &&
          !lower.contains('servicelogin')) {
        await _captureYouTubeSession();
      }
    } else {
      if (lower.contains('instagram.com') &&
          !lower.contains('accounts/login') &&
          !lower.contains('accounts/emailsignup') &&
          !lower.contains('accounts/onetap')) {
        await _captureInstagramSession();
      }
    }
  }

  Future<void> _captureYouTubeSession() async {
    try {
      final jsCookies = await _controller.runJavaScriptReturningResult('document.cookie');
      String rawCookies = jsCookies.toString().replaceAll('"', '').trim();

      if (rawCookies.contains('SAPISID') || rawCookies.contains('SID') || rawCookies.contains('LOGIN_INFO') || rawCookies.contains('SSID')) {
        _isCaptured = true;
        await ApiService.setYtCookies(rawCookies);
        HapticFeedback.mediumImpact();

        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('YouTube connected with Google successfully! 🎉'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (_) {}
  }

  Future<void> _captureInstagramSession() async {
    try {
      final jsCookies = await _controller.runJavaScriptReturningResult('document.cookie');
      String rawCookies = jsCookies.toString().replaceAll('"', '').trim();

      if (rawCookies.contains('sessionid') || rawCookies.contains('ds_user_id')) {
        _isCaptured = true;
        await ApiService.setIgCookies(rawCookies);
        HapticFeedback.mediumImpact();

        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Instagram connected successfully! 🎉'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (_) {}
  }

  void _manualCapture() async {
    if (isYouTube) {
      await _captureYouTubeSession();
    } else {
      await _captureInstagramSession();
    }

    if (!_isCaptured && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete the login process first.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09090B),
      appBar: AppBar(
        backgroundColor: const Color(0xFF18181B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: brandColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () => _controller.reload(),
          ),
          TextButton.icon(
            icon: const Icon(Icons.check_circle, color: Color(0xFFFACC15), size: 18),
            label: const Text('Done', style: TextStyle(color: Color(0xFFFACC15), fontWeight: FontWeight.bold)),
            onPressed: _manualCapture,
          ),
        ],
        bottom: _progress < 100
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  value: _progress / 100.0,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation<Color>(brandColor),
                ),
              )
            : null,
      ),
      body: WebViewWidget(controller: _controller),
    );
  }
}
