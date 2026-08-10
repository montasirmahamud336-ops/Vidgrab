# SnapTube Downloader Mobile Application (Flutter)

Production-ready SnapTube Clone Android & iOS Mobile Application integrated with your VidGrab VPS FastAPI backend.

## Key Features

1. **Android Share Sheet Integration (`action.SEND`)**:
   - Sharing a link from Facebook, Instagram, YouTube, TikTok, X, etc., opens VidGrab in the Android Share Sheet menu.
   - Automatically populates and analyzes the video URL.

2. **SnapTube Quality Selector Bottom Sheet**:
   - Signature Dark/Gold theme (`#FACC15`).
   - Categorized Audio (MP3 128k/192k/320k, M4A) & Video (1080p, 720p, 480p, 360p) choices with format sizes.
   - Yellow CTA "Watch ad to download" button.

3. **Background Download Service**:
   - Background downloads with status bar notifications (`flutter_local_notifications`).
   - Downloads saved directly to phone's `/storage/emulated/0/Download` directory.

4. **3-Tab Navigation**:
   - **Download (Home)**: SnapTube logo, search input, quick site shortcuts.
   - **Play (Downloads)**: Active downloads progress queue + completed file list with thumbnail & offline opener.
   - **Settings**: VPS server URL configuration, WhatsApp status saver, phone clean tools.

## How to Build & Run

### Prerequisites
- Flutter SDK 3.0+
- Android Studio / VS Code

### Steps

```bash
# 1. Navigate to mobile_app directory
cd mobile_app

# 2. Get dependencies
flutter pub get

# 3. Run on connected Android phone or emulator
flutter run

# 4. Build Release APK for installation
flutter build apk --release
```

The compiled APK will be located at:
`mobile_app/build/app/outputs/flutter-apk/app-release.apk`
