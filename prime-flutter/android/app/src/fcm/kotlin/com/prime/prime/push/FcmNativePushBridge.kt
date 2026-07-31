package com.prime.prime.push

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.google.android.gms.tasks.Tasks
import com.google.firebase.messaging.FirebaseMessaging
import com.prime.prime.MainActivity
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.TimeUnit

class FcmNativePushBridge(
    private val activity: MainActivity,
) : NativePushBridge {
    private var pendingResult: MethodChannel.Result? = null

    override fun requestAuthorization(result: MethodChannel.Result) {
        PrimeNotificationHelper.ensureChannel(activity.applicationContext)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            val granted = ContextCompat.checkSelfPermission(
                activity,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
            if (!granted) {
                pendingResult = result
                ActivityCompat.requestPermissions(
                    activity,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    MainActivity.REQUEST_POST_NOTIFICATIONS,
                )
                return
            }
        }
        completeAuthorization(result, granted = true)
    }

    override fun disableNotifications(result: MethodChannel.Result) {
        try {
            Tasks.await(FirebaseMessaging.getInstance().deleteToken(), 10, TimeUnit.SECONDS)
        } catch (_: Exception) {
            // Best effort — token will expire server-side on unregister.
        }
        PrimeNotificationHelper.clearDelivered(activity.applicationContext)
        result.success(null)
    }

    override fun handleActivityResult(requestCode: Int, granted: Boolean) {
        if (requestCode != MainActivity.REQUEST_POST_NOTIFICATIONS) return
        val result = pendingResult ?: return
        pendingResult = null
        completeAuthorization(result, granted = granted)
    }

    private fun completeAuthorization(result: MethodChannel.Result, granted: Boolean) {
        if (!granted) {
            result.success(
                mapOf(
                    "degraded" to false,
                    "granted" to false,
                    "token" to null,
                    "pending_notification" to activity.consumePendingNotification(),
                ),
            )
            return
        }
        try {
            val token = Tasks.await(FirebaseMessaging.getInstance().token, 15, TimeUnit.SECONDS)
            result.success(
                mapOf(
                    "degraded" to false,
                    "granted" to true,
                    "token" to token,
                    "pending_notification" to activity.consumePendingNotification(),
                ),
            )
        } catch (error: Exception) {
            result.success(
                mapOf(
                    "degraded" to true,
                    "granted" to true,
                    "token" to null,
                    "pending_notification" to activity.consumePendingNotification(),
                    "error" to (error.message ?: "fcm_token_error"),
                ),
            )
        }
    }
}
