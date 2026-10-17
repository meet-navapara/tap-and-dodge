package com.ujjwal.tapandodge

import android.content.Intent
import android.os.Bundle
import android.provider.Settings
import android.webkit.WebSettings
import android.webkit.WebView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val settingsChannel = "tap_and_dodge/settings"

    /// Kept alive so Chromium / JavascriptEngine stays warm for AdMob.
    private var adWebViewWarmup: WebView? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        try {
            adWebViewWarmup = WebView(this).apply {
                settings.javaScriptEnabled = true
                settings.domStorageEnabled = true
                settings.cacheMode = WebSettings.LOAD_DEFAULT
                // about:blank boots the JS engine without network.
                loadUrl("about:blank")
            }
        } catch (_: Exception) {
            // Best-effort; Dart-side AdMob retries still apply.
        }
    }

    override fun onDestroy() {
        try {
            adWebViewWarmup?.apply {
                stopLoading()
                destroy()
            }
        } catch (_: Exception) {
        }
        adWebViewWarmup = null
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            settingsChannel,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "openNetworkSettings" -> {
                    try {
                        startActivity(Intent(Settings.ACTION_WIRELESS_SETTINGS))
                        result.success(null)
                    } catch (_: Exception) {
                        try {
                            startActivity(Intent(Settings.ACTION_SETTINGS))
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("UNAVAILABLE", e.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
