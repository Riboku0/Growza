package com.example.istudy

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var saveResult: MethodChannel.Result? = null
    private var saveText: String? = null
    private val saveRequest = 8123

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "growza/files").setMethodCallHandler { call, result ->
            if (call.method != "saveText") { result.notImplemented(); return@setMethodCallHandler }
            if (saveResult != null) { result.error("busy", "A save is already open", null); return@setMethodCallHandler }
            val name = call.argument<String>("name") ?: "Growza-backup.json"
            val text = call.argument<String>("text")
            if (text == null || text.toByteArray(Charsets.UTF_8).size > 10 * 1024 * 1024 || !name.matches(Regex("[A-Za-z0-9._-]{1,100}"))) {
                result.error("invalid", "Invalid backup", null); return@setMethodCallHandler
            }
            saveResult = result; saveText = text
            try {
                startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                    addCategory(Intent.CATEGORY_OPENABLE); type = "application/json"; putExtra(Intent.EXTRA_TITLE, name)
                }, saveRequest)
            } catch (_: Exception) { saveResult = null; saveText = null; result.error("unavailable", "Cannot open file picker", null) }
        }
    }
    @Deprecated("Activity result bridge required by the document picker")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != saveRequest) { super.onActivityResult(requestCode, resultCode, data); return }
        val result = saveResult ?: return
        val text = saveText
        saveResult = null; saveText = null
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null || text == null) { result.success(false); return }
        Thread {
            try {
                contentResolver.openOutputStream(uri, "wt").use { stream ->
                    requireNotNull(stream); stream.write(text.toByteArray(Charsets.UTF_8)); stream.flush()
                }
                runOnUiThread { result.success(true) }
            } catch (_: Exception) { runOnUiThread { result.error("save_failed", "Could not save backup", null) } }
        }.start()
    }
}
