package com.myna.audiobook

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// NOTE: Must extend FlutterFragmentActivity (not FlutterActivity) for audio_service
// to show media notifications and lockscreen controls on Android.
// See: https://pub.dev/packages/audio_service#android-setup
class MainActivity: FlutterFragmentActivity() {

    private val CHANNEL = "com.myna.audiobook/notification_diagnostics"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getNotificationDiagnostics" -> {
                    val diagnostics = getNotificationDiagnostics()
                    result.success(diagnostics)
                }
                "openChannelSettings" -> {
                    val channelId = call.argument<String>("channelId") ?: "app.myna.audio"
                    val opened = openChannelSettings(channelId)
                    result.success(opened)
                }
                "openAppNotificationSettings" -> {
                    val opened = openAppNotificationSettings()
                    result.success(opened)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    /**
     * Collects notification-related diagnostics for debugging lockscreen/notification issues.
     * Returns a Map with:
     * - sdkInt: Android SDK version
     * - notifEnabled: App-level notifications enabled
     * - postNotifGranted: POST_NOTIFICATIONS permission granted (Android 13+)
     * - channelExists: Whether the audio channel exists
     * - channelImportance: Importance level (0-5)
     * - channelImportanceName: Human-readable importance
     * - channelBlocked: Whether channel is blocked by user
     * - channelLockscreenVisibility: Lockscreen visibility setting
     * - channelCanShowBadge: Whether channel can show badge
     */
    private fun getNotificationDiagnostics(): Map<String, Any?> {
        val notificationManager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        val notificationManagerCompat = NotificationManagerCompat.from(this)

        val sdkInt = Build.VERSION.SDK_INT

        // App-level notifications enabled
        val notifEnabled = notificationManagerCompat.areNotificationsEnabled()

        // POST_NOTIFICATIONS permission (Android 13+ / SDK 33+)
        val postNotifGranted = if (sdkInt >= 33) {
            ContextCompat.checkSelfPermission(
                this,
                android.Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            true // Not required on older versions
        }

        // Channel-specific diagnostics
        val channelId = "app.myna.audio"
        var channelExists = false
        var channelImportance = -1
        var channelImportanceName = "unknown"
        var channelBlocked = false
        var channelLockscreenVisibility = -999
        var channelCanShowBadge = false

        if (sdkInt >= Build.VERSION_CODES.O) {
            val channel: NotificationChannel? = notificationManager.getNotificationChannel(channelId)
            channelExists = channel != null

            if (channel != null) {
                channelImportance = channel.importance
                channelImportanceName = importanceToName(channel.importance)

                // On SDK 28+ we can check if channel is blocked
                if (sdkInt >= Build.VERSION_CODES.P) {
                    channelBlocked = notificationManager.getNotificationChannel(channelId)
                        ?.importance == NotificationManager.IMPORTANCE_NONE
                }

                channelLockscreenVisibility = channel.lockscreenVisibility
                channelCanShowBadge = channel.canShowBadge()
            }
        } else {
            // Pre-Oreo: no channels, just check if notifications are enabled
            channelExists = true // Concept doesn't exist
            channelImportance = 3 // Default importance
            channelImportanceName = "default_preO"
        }

        return mapOf(
            "sdkInt" to sdkInt,
            "notifEnabled" to notifEnabled,
            "postNotifGranted" to postNotifGranted,
            "channelExists" to channelExists,
            "channelImportance" to channelImportance,
            "channelImportanceName" to channelImportanceName,
            "channelBlocked" to channelBlocked,
            "channelLockscreenVisibility" to channelLockscreenVisibility,
            "channelCanShowBadge" to channelCanShowBadge
        )
    }

    /**
     * Convert NotificationManager importance int to human-readable name.
     */
    private fun importanceToName(importance: Int): String {
        return when (importance) {
            NotificationManager.IMPORTANCE_NONE -> "NONE"
            NotificationManager.IMPORTANCE_MIN -> "MIN"
            NotificationManager.IMPORTANCE_LOW -> "LOW"
            NotificationManager.IMPORTANCE_DEFAULT -> "DEFAULT"
            NotificationManager.IMPORTANCE_HIGH -> "HIGH"
            NotificationManager.IMPORTANCE_MAX -> "MAX"
            else -> "UNKNOWN($importance)"
        }
    }

    /**
     * Open system settings for a specific notification channel.
     * Only works on Android O (API 26) and above.
     * Returns true if the intent was launched, false otherwise.
     */
    private fun openChannelSettings(channelId: String): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val intent = Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS).apply {
                    putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    putExtra(Settings.EXTRA_CHANNEL_ID, channelId)
                }
                startActivity(intent)
                true
            } else {
                // Fall back to app notification settings on older Android
                openAppNotificationSettings()
            }
        } catch (e: Exception) {
            // If channel settings fail, try app notification settings
            openAppNotificationSettings()
        }
    }

    /**
     * Open system settings for app-level notifications.
     * Returns true if the intent was launched, false otherwise.
     */
    private fun openAppNotificationSettings(): Boolean {
        return try {
            val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).apply {
                    putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                }
            } else {
                // For older Android versions, open app details
                Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                    data = Uri.fromParts("package", packageName, null)
                }
            }
            startActivity(intent)
            true
        } catch (e: Exception) {
            false
        }
    }
}
