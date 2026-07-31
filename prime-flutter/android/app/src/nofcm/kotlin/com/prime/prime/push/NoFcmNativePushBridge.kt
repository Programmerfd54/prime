package com.prime.prime.push

import com.prime.prime.MainActivity
import io.flutter.plugin.common.MethodChannel

class NoFcmNativePushBridge(
    private val activity: MainActivity,
) : NativePushBridge {
    override fun requestAuthorization(result: MethodChannel.Result) {
        result.success(
            mapOf(
                "degraded" to true,
                "granted" to false,
                "token" to null,
                "pending_notification" to activity.consumePendingNotification(),
            ),
        )
    }

    override fun disableNotifications(result: MethodChannel.Result) {
        result.success(null)
    }

    override fun handleActivityResult(requestCode: Int, granted: Boolean) {
        // No-op without FCM.
    }
}
