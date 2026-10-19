package com.totv.plus

import android.app.PictureInPictureParams
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.graphics.Color
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.util.Rational
import android.view.WindowInsets
import android.view.WindowManager
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsControllerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL     = "totv_secure"
    private val PIP_CHANNEL = "totv_pip"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ★ Edge-to-edge — mandatory API 35, good practice from API 21
        WindowCompat.setDecorFitsSystemWindows(window, false)

        // ★ Transparent system bars
        window.statusBarColor     = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT

        // ★ API 26+: dark icons = false (our app is dark theme → light icons)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            WindowInsetsControllerCompat(window, window.decorView).apply {
                isAppearanceLightStatusBars     = false
                isAppearanceLightNavigationBars = false
            }
        }

        // ★ API 30+: hide system bars smoothly for fullscreen video
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.insetsController?.systemBarsBehavior =
                android.view.WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        }

        // ── Security Channel ──────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecureFlag" -> {
                        val enable = call.argument<Boolean>("enable") ?: false
                        try {
                            if (enable) window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            else        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                            result.success(enable)
                        } catch (e: Exception) { result.success(false) }
                    }
                    "checkVpn"          -> result.success(isVpnActive())
                    "getAndroidVersion" -> result.success(Build.VERSION.SDK_INT)
                    else                -> result.notImplemented()
                }
            }

        // ── PiP Channel ──────────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PIP_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enterPiP" -> {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                            packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)) {
                            try {
                                val params = PictureInPictureParams.Builder()
                                    .setAspectRatio(Rational(16, 9))
                                    .apply {
                                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S)
                                            setAutoEnterEnabled(false)
                                    }.build()
                                enterPictureInPictureMode(params)
                                result.success(true)
                            } catch (e: Exception) { result.success(false) }
                        } else result.success(false)
                    }
                    "isPiPSupported" -> result.success(
                        Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                        packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
                    )
                    else -> result.notImplemented()
                }
            }
    }

    override fun onPictureInPictureModeChanged(isInPiP: Boolean, config: Configuration) {
        super.onPictureInPictureModeChanged(isInPiP, config)
        flutterEngine?.dartExecutor?.binaryMessenger?.let {
            MethodChannel(it, PIP_CHANNEL).invokeMethod("pipStatusChanged", isInPiP)
        }
    }

    private fun isVpnActive(): Boolean = try {
        val cm = getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
            cm.getNetworkCapabilities(cm.activeNetwork)
                ?.hasTransport(NetworkCapabilities.TRANSPORT_VPN) ?: false
        else
            @Suppress("DEPRECATION")
            java.net.NetworkInterface.getNetworkInterfaces()
                ?.toList()?.any { it.isUp && (it.name.startsWith("tun")
                    || it.name.startsWith("ppp") || it.name.startsWith("tap")) }
                ?: false
    } catch (_: Exception) { false }
}
