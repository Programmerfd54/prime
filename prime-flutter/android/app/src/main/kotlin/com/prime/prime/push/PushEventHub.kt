package com.prime.prime.push

import io.flutter.plugin.common.MethodChannel

object PushEventHub {
    private var channel: MethodChannel? = null
    private var pendingToken: String? = null
    private var pendingNotification: Map<String, Any>? = null

    fun attach(methodChannel: MethodChannel) {
        channel = methodChannel
        pendingToken?.let { token ->
            pendingToken = null
            deliverToken(token)
        }
        pendingNotification?.let { payload ->
            pendingNotification = null
            deliver(payload, "notificationOpened")
        }
    }

    fun detach() {
        channel = null
    }

    fun deliverToken(token: String) {
        val active = channel
        if (active == null) {
            pendingToken = token
            return
        }
        active.invokeMethod("token", mapOf("token" to token))
    }

    fun deliver(payload: Map<String, Any>, method: String) {
        val active = channel
        if (active == null) {
            pendingNotification = payload
            return
        }
        active.invokeMethod(method, payload)
    }
}
