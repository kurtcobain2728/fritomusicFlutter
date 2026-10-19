package com.frito.music

import android.accounts.AccountManager
import android.content.Intent
import android.media.MediaScannerConnection
import android.net.Uri
import android.webkit.CookieManager
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity: AudioServiceActivity() {
    private val CHANNEL = "com.frito.music/platform"
    private var accountPickerResult: MethodChannel.Result? = null
    private var imagePickerResult: MethodChannel.Result? = null
    private val REQUEST_CODE_PICK_ACCOUNT = 1001
    private val REQUEST_CODE_PICK_IMAGE = 1002

    private var equalizerManager: EqualizerManager? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        if (equalizerManager == null) {
            equalizerManager = EqualizerManager(this)
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickGoogleAccount" -> {
                    accountPickerResult = result
                    try {
                        val intent = AccountManager.newChooseAccountIntent(
                            null,
                            null,
                            arrayOf("com.google"),
                            null,
                            null,
                            null,
                            null
                        )
                        startActivityForResult(intent, REQUEST_CODE_PICK_ACCOUNT)
                    } catch (e: Exception) {
                        result.error("ERROR", e.localizedMessage, null)
                        accountPickerResult = null
                    }
                }
                "getCookies" -> {
                    try {
                        val cm = CookieManager.getInstance()
                        cm.flush()
                        val cookieMap = mutableMapOf<String, String>()
                        listOf(
                            "https://accounts.google.com",
                            "https://www.youtube.com",
                            "https://music.youtube.com"
                        ).forEach { url ->
                            val cookieString = cm.getCookie(url) ?: ""
                            cookieString.split(";").forEach { pair ->
                                val parts = pair.trim().split("=", limit = 2)
                                if (parts.size >= 2) {
                                    val key = parts[0].trim()
                                    val value = parts[1].trim()
                                    if (key.isNotEmpty()) {
                                        cookieMap[key] = value
                                    }
                                }
                            }
                        }
                        val cleanCookie = cookieMap.entries.joinToString("; ") { "${it.key}=${it.value}" }
                        result.success(cleanCookie)
                    } catch (e: Exception) {
                        result.error("COOKIE_ERROR", e.localizedMessage, null)
                    }
                }
                "pickBackgroundImage" -> {
                    imagePickerResult = result
                    try {
                        val intent = Intent(Intent.ACTION_GET_CONTENT).apply {
                            type = "image/*"
                            addCategory(Intent.CATEGORY_OPENABLE)
                        }
                        startActivityForResult(Intent.createChooser(intent, "Seleccionar imagen de fondo"), REQUEST_CODE_PICK_IMAGE)
                    } catch (e: Exception) {
                        result.error("IMAGE_PICK_ERROR", e.localizedMessage, null)
                        imagePickerResult = null
                    }
                }
                "initEqualizer" -> {
                    val audioSessionId = call.argument<Int>("audioSessionId") ?: 0
                    if (audioSessionId > 0) {
                        equalizerManager?.attachAudioSession(audioSessionId)
                    }
                    result.success(equalizerManager?.getData())
                }
                "setEqualizerEnabled" -> {
                    val enabled = call.argument<Boolean>("enabled") ?: false
                    equalizerManager?.setEnabled(enabled)
                    result.success(true)
                }
                "setBandLevel" -> {
                    val bandIndex = call.argument<Int>("bandIndex") ?: 0
                    val level = call.argument<Int>("level") ?: 0
                    equalizerManager?.setBandLevel(bandIndex.toShort(), level.toShort())
                    result.success(true)
                }
                "usePreset" -> {
                    val presetIndex = call.argument<Int>("presetIndex") ?: -1
                    equalizerManager?.usePreset(presetIndex.toShort())
                    result.success(equalizerManager?.getData())
                }
                "getEqualizerData" -> {
                    result.success(equalizerManager?.getData())
                }
                "scanFile" -> {
                    val filePath = call.argument<String>("path")
                    if (!filePath.isNullOrEmpty()) {
                        MediaScannerConnection.scanFile(this, arrayOf(filePath), null, null)
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == REQUEST_CODE_PICK_ACCOUNT) {
            if (resultCode == RESULT_OK && data != null) {
                val accountName = data.getStringExtra(AccountManager.KEY_ACCOUNT_NAME)
                accountPickerResult?.success(accountName)
            } else {
                accountPickerResult?.success(null)
            }
            accountPickerResult = null
        } else if (requestCode == REQUEST_CODE_PICK_IMAGE) {
            if (resultCode == RESULT_OK && data?.data != null) {
                try {
                    val uri: Uri = data.data!!
                    val destFile = File(filesDir, "custom_background.jpg")
                    contentResolver.openInputStream(uri)?.use { input ->
                        FileOutputStream(destFile).use { output ->
                            input.copyTo(output)
                        }
                    }
                    imagePickerResult?.success(destFile.absolutePath)
                } catch (e: Exception) {
                    imagePickerResult?.error("IO_ERROR", e.localizedMessage, null)
                }
            } else {
                imagePickerResult?.success(null)
            }
            imagePickerResult = null
        }
    }
}
