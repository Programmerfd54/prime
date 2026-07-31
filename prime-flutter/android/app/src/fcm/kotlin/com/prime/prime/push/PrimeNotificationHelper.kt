package com.prime.prime.push

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.google.firebase.messaging.RemoteMessage
import com.prime.prime.MainActivity
import com.prime.prime.R

object PrimeNotificationHelper {
    const val CHANNEL_ID = "prime_team"
    private const val CHANNEL_NAME = "Команда PRIME"
    private const val CHANNEL_DESCRIPTION =
        "Сбор команды, отчёты, поддержка и ранний старт цикла"
    private const val EARLY_START_GROUP = "prime_early_start"

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        val existing = manager.getNotificationChannel(CHANNEL_ID)
        if (existing != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = CHANNEL_DESCRIPTION
            enableVibration(true)
        }
        manager.createNotificationChannel(channel)
    }

    fun clearDelivered(context: Context) {
        NotificationManagerCompat.from(context).cancelAll()
    }

    fun showRemoteMessage(context: Context, message: RemoteMessage) {
        ensureChannel(context)
        val data = message.data
        val title = message.notification?.title ?: data["title"] ?: "PRIME"
        val body = message.notification?.body ?: data["body"] ?: ""
        val notificationId = (data["notification_id"] ?: data["request_id"] ?: title)
            .hashCode()

        if (data["type"] == "early_start_request") {
            showEarlyStart(context, notificationId, title, body, data)
            return
        }

        val openIntent = openIntent(context, data, action = "open")
        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(openIntent)
        notify(context, notificationId, builder.build())
    }

    private fun showEarlyStart(
        context: Context,
        notificationId: Int,
        title: String,
        body: String,
        data: Map<String, String>,
    ) {
        val confirm = actionIntent(context, data, "confirm", 1)
        val wait = actionIntent(context, data, "keep_waiting", 2)
        val openSearch = actionIntent(context, data, "open_search", 3)
        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(openIntent(context, data, "open"))
            .addAction(0, "Подтвердить старт", confirm)
            .addAction(0, "Продолжить ждать", wait)
            .addAction(0, "Открыть поиск", openSearch)
            .setGroup(EARLY_START_GROUP)
        notify(context, notificationId, builder.build())
    }

    private fun openIntent(
        context: Context,
        data: Map<String, String>,
        action: String,
    ): PendingIntent = actionIntent(context, data, action, 0)

    private fun actionIntent(
        context: Context,
        data: Map<String, String>,
        action: String,
        requestCode: Int,
    ): PendingIntent {
        val intent = Intent(context, MainActivity::class.java).apply {
            this.action = MainActivity.ACTION_NOTIFICATION
            putExtra("action", action)
            data.forEach { (key, value) -> putExtra(key, value) }
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0
        return PendingIntent.getActivity(context, requestCode, intent, flags)
    }

    private fun notify(context: Context, id: Int, notification: android.app.Notification) {
        try {
            NotificationManagerCompat.from(context).notify(id, notification)
        } catch (_: SecurityException) {
            // POST_NOTIFICATIONS denied — foreground SSE still covers the product path.
        }
    }
}
