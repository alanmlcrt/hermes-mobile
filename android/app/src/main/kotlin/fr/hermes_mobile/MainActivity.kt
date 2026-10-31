package fr.hermes_mobile

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Notification
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONObject

class MainActivity : FlutterActivity() {
    private val sessionPattern = Regex("^[A-Za-z0-9_.:-]{1,256}$")
    private var notifications: MethodChannel? = null

    /** `sessionId` validé d'un toucher ; FCM (data en extras) et `show` posent le même extra. */
    private fun openedId(intent: Intent?): String? {
        if (intent == null ||
            intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY != 0) return null
        val room = try { intent.getStringExtra(EXTRA_ROOM) } catch (_: RuntimeException) { null }
        val outcome = try { intent.getStringExtra(EXTRA_OUTCOME) } catch (_: RuntimeException) { null }
        if (validRoom(room) && outcome in setOf("needs_user", "approval")) {
            return JSONObject().put("roomId", room).put("outcome", outcome).toString()
        }
        val id = try { intent.getStringExtra(EXTRA_SESSION) } catch (_: RuntimeException) { null }
        return if (id != null && sessionPattern.matches(id)) id else null
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        val id = openedId(intent) ?: return
        // Consommé une fois : retiré seulement si Dart l'a reçu, sinon
        // `takeOpened` le relira au démarrage de l'interface.
        notifications?.invokeMethod("opened", id, object : MethodChannel.Result {
            override fun success(result: Any?) {
                intent.removeExtra(EXTRA_SESSION)
                intent.removeExtra(EXTRA_ROOM)
                intent.removeExtra(EXTRA_OUTCOME)
            }
            override fun error(code: String, message: String?, details: Any?) {}
            override fun notImplemented() {}
        })
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val methods = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hermes/notifications")
        notifications = methods
        methods.setMethodCallHandler { call, result ->
                val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                val channel = "hermes_turn_complete"
                if (Build.VERSION.SDK_INT >= 26) {
                    manager.createNotificationChannel(NotificationChannel(channel,
                        "Fin du travail Hermes", NotificationManager.IMPORTANCE_HIGH))
                }
                when (call.method) {
                    "createChannel" -> result.success(null)
                    "takeOpened" -> {
                        val id = openedId(intent)
                        intent?.removeExtra(EXTRA_SESSION)
                        intent?.removeExtra(EXTRA_ROOM)
                        intent?.removeExtra(EXTRA_OUTCOME)
                        result.success(id)
                    }
                    "showRoom" -> {
                        val room = call.argument<String>("roomId")
                        val outcome = call.argument<String>("outcome")
                        val body = call.argument<String>("body")
                        if (validRoom(room) && outcome in setOf("needs_user", "approval") && body != null) {
                            val tag = "hermes:room:$room"
                            val open = PendingIntent.getActivity(this, tag.hashCode(),
                                Intent(this, MainActivity::class.java)
                                    .setAction(tag)
                                    .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                                    .putExtra(EXTRA_ROOM, room).putExtra(EXTRA_OUTCOME, outcome),
                                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
                            val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, channel)
                                else Notification.Builder(this).setPriority(Notification.PRIORITY_HIGH)
                            try {
                                manager.notify(tag, 0, builder.setSmallIcon(R.drawable.ic_notification)
                                    .setContentTitle("Hermes").setContentText(body).setContentIntent(open)
                                    .setOnlyAlertOnce(true).setAutoCancel(true).build())
                            } catch (_: SecurityException) { /* Permission révoquée. */ }
                        }
                        result.success(null)
                    }
                    "show" -> {
                        val id = call.argument<String>("sessionId")
                        val outcome = call.argument<String>("outcome")
                        val body = when (outcome) {
                            "succeeded" -> "Hermes a terminé"
                            "failed" -> "Hermes a échoué"
                            "stopped" -> "Hermes s'est arrêté"
                            else -> null
                        }
                        if (id != null && sessionPattern.matches(id) && body != null) {
                            val tag = "hermes:$id:$outcome"
                            // Seul le `sessionId` voyage ; requestCode par tag,
                            // les extras ne distinguant pas deux PendingIntent.
                            val open = PendingIntent.getActivity(this, tag.hashCode(),
                                Intent(this, MainActivity::class.java)
                                    .addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                                    .putExtra(EXTRA_SESSION, id),
                                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
                            val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(this, channel)
                                else Notification.Builder(this)
                                    .setPriority(Notification.PRIORITY_HIGH)
                                    .setDefaults(Notification.DEFAULT_SOUND)
                            try {
                                manager.notify(tag, 0, builder
                                    .setSmallIcon(R.drawable.ic_notification)
                                    .setContentTitle("Hermes").setContentText(body)
                                    .setContentIntent(open)
                                    .setAutoCancel(true).build())
                            } catch (_: SecurityException) { /* Permission revoked in Settings. */ }
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private companion object {
        const val EXTRA_SESSION = "sessionId"
        const val EXTRA_ROOM = "roomId"
        const val EXTRA_OUTCOME = "outcome"
        fun validRoom(id: String?) = id != null && id.isNotEmpty() && id.length <= 256 && id.none { it.code < 32 }
    }
}
