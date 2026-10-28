package com.wavelog_mobile

import android.content.Intent
import android.hardware.usb.UsbManager
import android.net.Uri
import android.os.Bundle
import android.provider.OpenableColumns
import android.view.WindowManager
import android.widget.Toast
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {

    private val encoderThread = Executors.newSingleThreadExecutor()

    private var pendingFileName: String? = null
    private var pendingFileContent: String? = null
    private var intentChannel: MethodChannel? = null
    private var rigSerial: RigSerialPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── VideoEncoder channel (unchanged) ────────────────────────────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.wavelog_mobile/video_encoder"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "initEncoder" -> encoderThread.submit {
                    try {
                        VideoEncoderPlugin.initEncoder(
                            w          = call.argument<Int>("width")!!,
                            h          = call.argument<Int>("height")!!,
                            fps        = call.argument<Int>("fps")!!,
                            outputPath = call.argument<String>("outputPath")!!
                        )
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("INIT_ERROR", e.message, null)
                    }
                }
                "addFrame" -> encoderThread.submit {
                    try {
                        VideoEncoderPlugin.addFrame(call.arguments as ByteArray)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("FRAME_ERROR", e.message, null)
                    }
                }
                "finalizeEncoder" -> encoderThread.submit {
                    try {
                        VideoEncoderPlugin.finalizeEncoder()
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("FINALIZE_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // ── Keep the screen on while logging ────────────────────────────
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.wavelog_mobile/screen"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "setKeepScreenOn" -> {
                    if (call.arguments == true) {
                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    } else {
                        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        // ── Radio CAT over USB serial ────────────────────────────────────
        rigSerial = RigSerialPlugin(applicationContext, flutterEngine.dartExecutor.binaryMessenger)

        // ── Intent handler channel ───────────────────────────────────────
        intentChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.wavelog_mobile/intent_handler"
        ).also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialFile" -> {
                        val name    = pendingFileName
                        val content = pendingFileContent
                        if (name != null && content != null) {
                            pendingFileName    = null
                            pendingFileContent = null
                            result.success(mapOf("name" to name, "content" to content))
                        } else {
                            result.success(null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        rigSerial?.close()
        rigSerial = null
        super.cleanUpFlutterEngine(flutterEngine)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // Android 15 (API 35) draws edge-to-edge by default for apps
        // targeting SDK 35+ (we target 37). The androidx.activity
        // enableEdgeToEdge() extension only works on ComponentActivity,
        // but Flutter's FlutterActivity extends the plain android.app.
        // Activity — so this uses the lower-level call it wraps directly,
        // which is compatible with any Activity. Flutter's own
        // SafeArea/MediaQuery.padding on the Dart side then handles the
        // resulting system-bar insets.
        WindowCompat.setDecorFitsSystemWindows(window, false)
        super.onCreate(savedInstanceState)
        handleViewIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        // Radio plugged in while the app runs (singleTop): connect to it.
        // On a cold start the Dart side checks for it itself.
        if (intent.action == UsbManager.ACTION_USB_DEVICE_ATTACHED) {
            rigSerial?.onDeviceAttached()
            return
        }
        if (handleViewIntent(intent)) {
            // Engine may not be ready yet — guard with null check
            intentChannel?.invokeMethod(
                "onNewFile",
                mapOf("name" to pendingFileName!!, "content" to pendingFileContent!!)
            )
            pendingFileName    = null
            pendingFileContent = null
        }
    }

    private fun handleViewIntent(intent: Intent?): Boolean {
        if (intent?.action != Intent.ACTION_VIEW) return false
        val uri = intent.data ?: return false
        val name = getDisplayName(uri)
        val ext  = name.substringAfterLast('.', "").lowercase()
        return try {
            // "Open with" offers the app for any file (see the manifest), so
            // a file without the extension counts only if its start has the
            // ADIF header end. Anything else, e.g. a Cabrillo log, gets a
            // message instead of a silent start.
            if (ext != "adi" && ext != "adif" && !startsAsAdif(uri)) {
                Toast.makeText(this, getString(R.string.open_not_adif, name),
                    Toast.LENGTH_LONG).show()
                return false
            }
            val text = contentResolver.openInputStream(uri)
                ?.bufferedReader()
                ?.use { it.readText() }
                ?: return false
            pendingFileName    = name
            pendingFileContent = text
            true
        } catch (_: Exception) {
            false
        }
    }

    private fun startsAsAdif(uri: Uri): Boolean {
        val head = contentResolver.openInputStream(uri)?.use { input ->
            val buf = ByteArray(16 * 1024)
            val n = input.read(buf)
            if (n > 0) String(buf, 0, n, Charsets.ISO_8859_1) else ""
        } ?: return false
        return head.contains("<eoh>", ignoreCase = true)
    }

    private fun getDisplayName(uri: Uri): String {
        contentResolver.query(uri, null, null, null, null)?.use { cursor ->
            val col = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
            if (col >= 0 && cursor.moveToFirst()) {
                cursor.getString(col)?.let { return it }
            }
        }
        return uri.lastPathSegment ?: "import.adif"
    }
}
