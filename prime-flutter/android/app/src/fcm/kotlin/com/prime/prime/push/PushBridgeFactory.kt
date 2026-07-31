package com.prime.prime.push

import com.prime.prime.MainActivity

object PushBridgeFactory {
    fun create(activity: MainActivity): NativePushBridge =
        FcmNativePushBridge(activity)
}
