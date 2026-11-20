package com.murattarslan.tayfam

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.media.AudioManager
import android.media.ToneGenerator
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.WindowManager
import com.murattarslan.tayfam.butunluk.ButunlukKoprusu
import com.murattarslan.tayfam.e2e.SignalKoprusu
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Platform kanalları:
 * - `tayfam/bildirim` (istemci ADR-0019 §4): bildirim kanallarını kurar ve
 *   uygulamanın sistem bildirim ayarlarını açar. Kanal adları ve
 *   açıklamaları Dart'tan (çeviri dosyasından) gelir. Bildirim içeriği bu
 *   kanaldan geçmez.
 * - `tayfam/e2e/signal` (istemci ADR-0010, ADR-0020): Signal köprüsü.
 * - `tayfam/butunluk` (istemci ADR-0023): Play Integrity köprüsü.
 * - `tayfam/kronometre` (istemci ADR-0031 §3): kronometre ekranı açıkken
 *   ekranın kapanmasını engeller (yalnızca bu pencere bayrağı; izin
 *   gerekmez) ve süre dolunca kısa bir uyarı sesi çalar. QR ile katılım
 *   ekranı (istemci ADR-0032 §3) aynı kanalla ekranı açık tutar ve
 *   `parlaklik` ile bu pencerenin parlaklığını en yükseğe çıkarır (sistem
 *   ayarı değişmez, izin gerekmez).
 */
class MainActivity : FlutterActivity() {
    private var signalKoprusu: SignalKoprusu? = null
    private var butunlukKoprusu: ButunlukKoprusu? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        signalKoprusu = SignalKoprusu.kur(flutterEngine.dartExecutor.binaryMessenger)
        butunlukKoprusu = ButunlukKoprusu.kur(flutterEngine.dartExecutor.binaryMessenger, this)
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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "tayfam/kronometre")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "ekraniAcikTut" -> {
                        ekraniAcikTut(call.arguments == true)
                        result.success(null)
                    }
                    "uyar" -> {
                        uyariSesi()
                        result.success(null)
                    }
                    "parlaklik" -> {
                        parlaklik(call.arguments == true)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** Kronometre ekranı açıkken ekran kendiliğinden kapanmaz. */
    private fun ekraniAcikTut(acik: Boolean) {
        runOnUiThread {
            if (acik) {
                window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            } else {
                window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
            }
        }
    }

    /**
     * QR ekranı açıkken yalnızca bu pencerenin parlaklığı en yükseğe çıkar;
     * kapanınca sistem ayarına döner.
     */
    private fun parlaklik(artir: Boolean) {
        runOnUiThread {
            val ayar = window.attributes
            ayar.screenBrightness = if (artir) {
                WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_FULL
            } else {
                WindowManager.LayoutParams.BRIGHTNESS_OVERRIDE_NONE
            }
            window.attributes = ayar
        }
    }

    /** Kısa uyarı sesi (bildirim ses düzeyinde); ses kullanılamazsa sessiz geçer. */
    private fun uyariSesi() {
        val ton = try {
            ToneGenerator(AudioManager.STREAM_NOTIFICATION, UYARI_SES_DUZEYI)
        } catch (e: RuntimeException) {
            return
        }
        ton.startTone(ToneGenerator.TONE_PROP_BEEP2, UYARI_SURESI_MS)
        Handler(Looper.getMainLooper()).postDelayed({ ton.release() }, UYARI_SURESI_MS + 200L)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        signalKoprusu?.birak()
        signalKoprusu = null
        butunlukKoprusu?.birak()
        butunlukKoprusu = null
        super.cleanUpFlutterEngine(flutterEngine)
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

        /** Kronometre uyarı sesinin düzeyi (0–100) ve süresi. */
        const val UYARI_SES_DUZEYI = 80
        const val UYARI_SURESI_MS = 600
    }
}
