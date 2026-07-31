package com.prime.prime.push

import android.app.Service
import android.content.Intent
import android.os.IBinder

/**
 * Stub kept on classpath when [google-services.json] is absent so manifest merge stays stable.
 * The real Firebase service replaces this source file when FCM is enabled at build time.
 */
class PrimeFirebaseMessagingService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null
}
