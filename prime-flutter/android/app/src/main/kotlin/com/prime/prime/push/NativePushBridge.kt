package com.prime.prime.push

import io.flutter.plugin.common.MethodChannel

interface NativePushBridge {
    fun requestAuthorization(result: MethodChannel.Result)

    fun disableNotifications(result: MethodChannel.Result)

    fun handleActivityResult(requestCode: Int, granted: Boolean)
}
