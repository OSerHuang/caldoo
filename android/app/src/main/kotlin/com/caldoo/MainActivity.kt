package com.caldoo

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * The single Flutter activity.
 *
 * Besides hosting the Flutter UI it wires [AutoBackupChannel] — the automatic
 * off-app backup — onto a MethodChannel and forwards the Storage Access
 * Framework result of its file picker. Nothing else is native in this app.
 */
class MainActivity : FlutterActivity() {

    private var autoBackupChannel: AutoBackupChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val channel = AutoBackupChannel(this)
        autoBackupChannel = channel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, AutoBackupChannel.CHANNEL)
            .setMethodCallHandler { call, result -> channel.handle(call, result) }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        val channel = autoBackupChannel
        if (channel != null && channel.onActivityResult(requestCode, resultCode, data)) {
            return
        }
        super.onActivityResult(requestCode, resultCode, data)
    }
}
