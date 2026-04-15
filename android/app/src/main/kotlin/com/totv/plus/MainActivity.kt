package com.totv.plus

import android.app.PictureInPictureParams
import android.content.pm.PackageManager
import android.content.res.Configuration
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.os.Build
import android.util.Rational
import android.view.WindowManager
import androidx.core.view.WindowCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL     = "totv_secure"
    private val PIP_CHANNEL = "totv_pip"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ★ Android 14+: Edge-to-edge display (إجباري من targetSdk 35)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM) {
            WindowCompat.setDecorFitsSystemWindows(window, false)
        }

        // ── Security Channel ─────────────────────────────────
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecureFlag" -> {
                        val enable = call.argument<Boolean>("enable") ?: false
                        if (enable) window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        else        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(enable)
                    }
                    "checkVpn" -> result.success(isVpnActive())
                    "getAndroidVersion" -> result.success(Build.VERSION.SDK_INT)
                    else -> result.notImplemented()
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
                                val builder = PictureInPictureParams.Builder()
                                    .setAspectRatio(Rational(16, 9))
                                // ★ Android 12+: auto-enter PiP on home button
                                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                    builder.setAutoEnterEnabled(false)
                                }
                                enterPictureInPictureMode(builder.build())
                                result.success(true)
                            } catch (e: Exception) {
                                result.success(false)
                            }
                        } else {
                            result.success(false)
                        }
                    }
                    "isPiPSupported" -> {
                        val supported = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O &&
                            packageManager.hasSystemFeature(PackageManager.FEATURE_PICTURE_IN_PICTURE)
                        result.success(supported)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onPictureInPictureModeChanged(
        isInPictureInPictureMode: Boolean,
        newConfig: Configuration
    ) {
        super.onPictureInPictureModeChanged(isInPictureInPictureMode, newConfig)
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            MethodChannel(messenger, PIP_CHANNEL)
                .invokeMethod("pipStatusChanged", isInPictureInPictureMode)
        }
    }

    private fun isVpnActive(): Boolean {
        return try {
            val cm = getSystemService(CONNECTIVITY_SERVICE) as ConnectivityManager
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                val network = cm.activeNetwork ?: return false
                val caps    = cm.getNetworkCapabilities(network) ?: return false
                caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN)
            } else {
                @Suppress("DEPRECATION")
                val interfaces = java.net.NetworkInterface.getNetworkInterfaces()
                interfaces?.toList()?.any { iface ->
                    iface.isUp && (
                        iface.name.startsWith("tun") ||
                        iface.name.startsWith("ppp") ||
                        iface.name.startsWith("tap") ||
                        iface.name.startsWith("wg")
                    )
                } ?: false
            }
        } catch (e: Exception) { false }
    }
}
