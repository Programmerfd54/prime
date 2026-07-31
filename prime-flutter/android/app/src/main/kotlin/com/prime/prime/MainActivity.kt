package com.prime.prime

import android.content.Intent
import android.os.Bundle
import com.prime.prime.push.PushBridgeFactory
import com.prime.prime.push.PushEventHub
import com.prime.prime.push.NativePushBridge
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "prime/native_push"
    private var pushChannel: MethodChannel? = null
    private lateinit var pushBridge: NativePushBridge
    private var pendingNotification: Map<String, Any>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        pushBridge = PushBridgeFactory.create(this)
        pushChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        pushChannel?.let { PushEventHub.attach(it) }
        pushChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "requestAuthorization" -> pushBridge.requestAuthorization(result)
                "disableNotifications" -> pushBridge.disableNotifications(result)
                else -> result.notImplemented()
            }
        }
        pendingNotification?.let {
            deliverNotification(it, "notificationOpened")
            pendingNotification = null
        }
    }

    override fun onDestroy() {
        PushEventHub.detach()
        super.onDestroy()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        captureLaunchIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureLaunchIntent(intent)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQUEST_POST_NOTIFICATIONS) {
            val granted = grantResults.isNotEmpty() &&
                grantResults[0] == android.content.pm.PackageManager.PERMISSION_GRANTED
            pushBridge.handleActivityResult(requestCode, granted)
        }
    }

    fun consumePendingNotification(): Map<String, Any>? {
        val pending = pendingNotification
        pendingNotification = null
        return pending
    }

    private fun captureLaunchIntent(intent: Intent?) {
        if (intent == null) return
        when (intent.action) {
            ACTION_NOTIFICATION, "PRIME_NOTIFICATION_OPEN" -> {
                deliverNotification(extractPayload(intent.extras), methodForAction(intent))
                intent.action = null
            }
            Intent.ACTION_VIEW -> captureDeepLink(intent)
        }
    }

    private fun captureDeepLink(intent: Intent) {
        val data = intent.data ?: return
        if (data.scheme != "prime") return
        val payload = mutableMapOf<String, Any>(
            "deep_link" to data.toString(),
            "action" to "open",
        )
        data.getQueryParameter("skill_id")?.let { payload["skill_id"] = it }
        data.getQueryParameter("group_id")?.let { payload["group_id"] = it }
        data.getQueryParameter("early_start")?.let { payload["request_id"] = it }
        deliverNotification(payload, "notificationOpened")
    }

    private fun methodForAction(intent: Intent): String {
        val action = intent.getStringExtra("action") ?: "open"
        return if (action == "open") "notificationOpened" else "notificationAction"
    }

    private fun extractPayload(extras: Bundle?): Map<String, Any> {
        if (extras == null) return emptyMap()
        val payload = mutableMapOf<String, Any>()
        for (key in extras.keySet()) {
            if (key.startsWith("google.") || key.startsWith("gcm.") || key == "from") continue
            when (val value = extras.get(key)) {
                is String -> payload[key] = value
                is Int -> payload[key] = value
                is Long -> payload[key] = value
                is Boolean -> payload[key] = value
            }
        }
        if (!payload.containsKey("action")) {
            payload["action"] = "open"
        }
        return payload
    }

    private fun deliverNotification(payload: Map<String, Any>, method: String) {
        val channel = pushChannel
        if (channel == null) {
            pendingNotification = payload
            return
        }
        PushEventHub.deliver(payload, method)
    }

    companion object {
        const val ACTION_NOTIFICATION = "com.prime.prime.NOTIFICATION"
        const val REQUEST_POST_NOTIFICATIONS = 9101
    }
}
