package com.murattarslan.tayfam

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Push bildirimleri için küçük platform kanalı (istemci ADR-0019 §4):
 * bildirim kanallarını kurar ve uygulamanın sistem bildirim ayarlarını
 * açar. Kanal adları ve açıklamaları Dart'tan (çeviri dosyasından) gelir.
 * Bildirim içeriği bu kanaldan geçmez.
 */
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tayfam/bildirim")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "kanallariKur" -> {
                        kanallariKur(call.arguments)
                        result.success(null)
                    }
                    "ayarlariAc" -> result.success(ayarlariAc())
                    else -> result.notImplemented()
                }
            }
    }

    /** Yalnızca beklenen biçimdeki kanalları kurar; gerisini yok sayar. */
    private fun kanallariKur(arguman: Any?) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val yonetici = getSystemService(NotificationManager::class.java) ?: return
        val liste = arguman as? List<*> ?: return
        for (oge in liste) {
            val kanal = oge as? Map<*, *> ?: continue
            val id = kanal["id"] as? String ?: continue
            val ad = kanal["ad"] as? String ?: continue
            val aciklama = kanal["aciklama"] as? String ?: continue
            val yuksek = kanal["yuksek"] as? Boolean ?: false
            if (!KANALLAR.contains(id)) continue
            val onem = if (yuksek) {
                NotificationManager.IMPORTANCE_HIGH
            } else {
                NotificationManager.IMPORTANCE_DEFAULT
            }
            val yeni = NotificationChannel(id, ad, onem)
            yeni.description = aciklama
            // Kilit ekranında içerik zaten yok; yine de gizli gösterilir.
            yeni.lockscreenVisibility = android.app.Notification.VISIBILITY_PRIVATE
            yonetici.createNotificationChannel(yeni)
        }
    }

    private fun ayarlariAc(): Boolean {
        val niyet = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
        } else {
            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                .setData(Uri.fromParts("package", packageName, null))
        }
        return try {
            startActivity(niyet)
            true
        } catch (e: android.content.ActivityNotFoundException) {
            false
        }
    }

    private companion object {
        /** Sunucunun kullandığı kanallar (Tayfam-Api ADR-0019 §4). */
        val KANALLAR = setOf("tayfam_messages", "tayfam_alerts", "tayfam_general")
    }
}
