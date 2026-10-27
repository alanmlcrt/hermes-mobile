package fr.hermes_mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Notification
import android.content.Context
import android.os.Build

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hermes/notifications")
            .setMethodCallHandler { call, result ->
                val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                val channel = "hermes_turn_complete"
                if (Build.VERSION.SDK_INT >= 26) {
                    manager.createNotificationChannel(NotificationChannel(channel,
                        "Fin du travail Hermes", NotificationManager.IMPORTANCE_HIGH))
                }
                when (call.method) {
                    "createChannel" -> result.success(null)
                    "show" -> {
                        val id = call.argument<String>("subscriptionId")
                        val outcome = call.argument<String>("outcome")
                        val body = when (outcome) {
                            "succeeded" -> "Hermes a terminé"
                            "failed" -> "Hermes a échoué"
                            "stopped" -> "Hermes s'est arrêté"
                            else -> null
                        }
                        if (id != null && Regex("^[A-Za-z0-9_-]{22,128}$").matches(id) && body != null) {
                            val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, channel)
                                else Notification.Builder(this)
                                    .setPriority(Notification.PRIORITY_HIGH)
                                    .setDefaults(Notification.DEFAULT_SOUND)
                            try {
                                manager.notify("hermes:$id:$outcome", 0, builder
                                    .setSmallIcon(R.drawable.ic_notification)
                                    .setContentTitle("Hermes").setContentText(body)
                                    .setAutoCancel(true).build())
                            } catch (_: SecurityException) { /* Permission revoked in Settings. */ }
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
