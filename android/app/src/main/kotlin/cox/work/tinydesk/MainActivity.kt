package cox.work.tinydesk

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.BufferedReader
import java.io.InputStreamReader

class MainActivity : FlutterActivity() {
    private var pendingPickResult: MethodChannel.Result? = null
    private var pendingSaveResult: MethodChannel.Result? = null
    private var pendingSaveBytes: ByteArray? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, "opencode/file").setMethodCallHandler { call, result ->
            when (call.method) {
                "pickPrivateKey" -> {
                    if (pendingPickResult != null) {
                        result.error("PICK_BUSY", "另一个文件选择正在进行", null)
                        return@setMethodCallHandler
                    }
                    pendingPickResult = result
                    val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "*/*"
                    }
                    startActivityForResult(intent, PICK_KEY_REQUEST)
                }
                "saveFile" -> {
                    if (pendingSaveResult != null) {
                        result.error("SAVE_BUSY", "另一个保存正在进行", null)
                        return@setMethodCallHandler
                    }
                    val name = call.argument<String>("name") ?: "download"
                    val bytes = call.argument<ByteArray>("bytes")
                    if (bytes == null) {
                        result.error("BAD_ARGS", "缺少文件内容", null)
                        return@setMethodCallHandler
                    }
                    pendingSaveResult = result
                    pendingSaveBytes = bytes
                    val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "*/*"
                        putExtra(Intent.EXTRA_TITLE, name)
                    }
                    startActivityForResult(intent, SAVE_FILE_REQUEST)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, "opencode/webdata").setMethodCallHandler { call, result ->
            if (call.method == "clearCookies") {
                android.webkit.CookieManager.getInstance().removeAllCookies(null)
                android.webkit.WebStorage.getInstance().deleteAllData()
                android.webkit.CookieManager.getInstance().flush()
                result.success(true)
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(messenger, "opencode/background").setMethodCallHandler { call, result ->
            when (call.method) {
                "start" -> {
                    BackgroundService.start(this)
                    result.success(true)
                }
                "stop" -> {
                    BackgroundService.stop(this)
                    result.success(true)
                }
                "update" -> {
                    BackgroundService.update(this)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        when (requestCode) {
            PICK_KEY_REQUEST -> {
                val result = pendingPickResult ?: return
                pendingPickResult = null
                if (resultCode != Activity.RESULT_OK) {
                    result.success("")
                    return
                }
                val uri = data?.data
                if (uri == null) {
                    result.success("")
                    return
                }
                try {
                    val text = contentResolver.openInputStream(uri)?.use { input ->
                        BufferedReader(InputStreamReader(input)).readText()
                    } ?: ""
                    result.success(text)
                } catch (error: Exception) {
                    result.error("PICK_FAILED", error.message, null)
                }
            }
            SAVE_FILE_REQUEST -> {
                val result = pendingSaveResult ?: return
                pendingSaveResult = null
                val bytes = pendingSaveBytes
                pendingSaveBytes = null
                if (resultCode != Activity.RESULT_OK || bytes == null) {
                    result.success(null)
                    return
                }
                val uri = data?.data
                if (uri == null) {
                    result.success(null)
                    return
                }
                try {
                    contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
                    result.success(uri.toString())
                } catch (error: Exception) {
                    result.error("SAVE_FAILED", error.message, null)
                }
            }
        }
    }

    companion object {
        private const val PICK_KEY_REQUEST = 4201
        private const val SAVE_FILE_REQUEST = 4202
    }
}
