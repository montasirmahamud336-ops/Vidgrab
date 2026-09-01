package com.vidgrab.snaptube

import android.content.Intent
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Environment
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterActivityLaunchConfigs.BackgroundMode
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class ShareActivity: FlutterActivity() {
    private val CHANNEL = "com.vidgrab.snaptube/native"
    private var methodChannel: MethodChannel? = null
    private var latestSharedText: String = ""

    override fun getBackgroundMode(): BackgroundMode {
        return BackgroundMode.transparent
    }

    override fun getInitialRoute(): String {
        return "/share_overlay"
    }

    private fun extractSharedText(targetIntent: Intent?): String {
        if (targetIntent == null) return ""
        
        // 1. Extra Text (Standard)
        val extraText = targetIntent.getStringExtra(Intent.EXTRA_TEXT)
        if (!extraText.isNullOrBlank()) return extraText

        // 2. CharSequence Extra
        val csExtra = targetIntent.getCharSequenceExtra(Intent.EXTRA_TEXT)
        if (!csExtra.isNullOrBlank()) return csExtra.toString()

        // 3. ClipData (Used by Android 12, 13, 14, 15 YouTube & Instagram app shares)
        val clipData = targetIntent.clipData
        if (clipData != null && clipData.itemCount > 0) {
            for (i in 0 until clipData.itemCount) {
                val item = clipData.getItemAt(i)
                val text = item.text?.toString()
                if (!text.isNullOrBlank()) return text
                val uri = item.uri?.toString()
                if (!uri.isNullOrBlank()) return uri
            }
        }

        // 4. Data URI
        val dataUri = targetIntent.dataString
        if (!dataUri.isNullOrBlank()) return dataUri

        // 5. Subject
        val subject = targetIntent.getStringExtra(Intent.EXTRA_SUBJECT)
        if (!subject.isNullOrBlank()) return subject

        return ""
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val shared = extractSharedText(intent)
        if (shared.isNotBlank()) {
            latestSharedText = shared
            methodChannel?.invokeMethod("onSharedIntentReceived", shared)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Capture initial intent on launch
        val initialShared = extractSharedText(intent)
        if (initialShared.isNotBlank()) {
            latestSharedText = initialShared
        }

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "openWith" -> {
                    val filePath = call.argument<String>("filePath")
                    val mimeType = call.argument<String>("mimeType") ?: "*/*"
                    if (filePath != null) {
                        try {
                            val file = File(filePath)
                            val uri: Uri = FileProvider.getUriForFile(
                                context,
                                "${context.packageName}.customfileprovider",
                                file
                            )
                            val viewIntent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(uri, mimeType)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            val chooserIntent = Intent.createChooser(viewIntent, "Open with").apply {
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            context.startActivity(chooserIntent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("ERROR", e.localizedMessage, null)
                        }
                    } else {
                        result.error("INVALID_PATH", "File path is null", null)
                    }
                }
                "scanFile" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath != null) {
                        MediaScannerConnection.scanFile(
                            context,
                            arrayOf(filePath),
                            null
                        ) { path, uri -> }
                        result.success(true)
                    } else {
                        result.error("INVALID_PATH", "File path is null", null)
                    }
                }
                "getPublicDownloadsPath" -> {
                    try {
                        val downloadDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                        val vidgrabDir = File(downloadDir, "VidGrab")
                        if (!vidgrabDir.exists()) {
                            vidgrabDir.mkdirs()
                        }
                        result.success(vidgrabDir.absolutePath)
                    } catch (e: Exception) {
                        result.error("ERROR", e.localizedMessage, null)
                    }
                }
                "installApk" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath != null) {
                        try {
                            val file = File(filePath)
                            val apkUri: Uri = FileProvider.getUriForFile(
                                context,
                                "${context.packageName}.customfileprovider",
                                file
                            )
                            val installIntent = Intent(Intent.ACTION_VIEW).apply {
                                setDataAndType(apkUri, "application/vnd.android.package-archive")
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            context.startActivity(installIntent)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("INSTALL_ERROR", e.localizedMessage, null)
                        }
                    } else {
                        result.error("INVALID_PATH", "APK path is null", null)
                    }
                }
                "getSharedText" -> {
                    val current = extractSharedText(intent)
                    val out = if (current.isNotBlank()) current else latestSharedText
                    result.success(out)
                }
                "finishActivity" -> {
                    finish()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }
}


