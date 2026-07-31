package com.prime.prime.push

import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class PrimeFirebaseMessagingService : FirebaseMessagingService() {
    override fun onNewToken(token: String) {
        PushEventHub.deliverToken(token)
    }

    override fun onMessageReceived(message: RemoteMessage) {
        PrimeNotificationHelper.showRemoteMessage(applicationContext, message)
    }
}
