package com.cloudapicc.cloud_api_cc

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        crearCanalDeChats()
    }

    /**
     * Crea el canal al que el backend manda las notificaciones de mensajes.
     *
     * El id tiene que ser el mismo que viaja en el payload de FCM
     * (config/push.php -> fcm.channel_id, "chats"): desde Android 8 una
     * notificación dirigida a un canal que no existe se descarta sin avisar, y
     * el agente se quedaría esperando un aviso que nunca llega.
     *
     * Es idempotente, así que llamarlo en cada arranque no molesta. Ojo: la
     * importancia solo se aplica al crearlo. Si el usuario la baja después,
     * manda su elección y la app no puede volver a subirla.
     */
    private fun crearCanalDeChats() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val canal = NotificationChannel(
            CANAL_CHATS,
            "Chats",
            // HIGH es lo que hace que aparezca encima de la pantalla y suene.
            // Es un chat de atención al cliente: llegar callado es casi lo
            // mismo que no llegar.
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Mensajes nuevos de clientes en WhatsApp"
        }

        getSystemService(NotificationManager::class.java).createNotificationChannel(canal)
    }

    private companion object {
        const val CANAL_CHATS = "chats"
    }
}
