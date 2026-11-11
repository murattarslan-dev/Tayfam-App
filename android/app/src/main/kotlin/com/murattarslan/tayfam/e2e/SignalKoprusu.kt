package com.murattarslan.tayfam.e2e

import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec

/**
 * `tayfam/e2e/signal` platform kanalı (ADR-0010, güncelleme 2026-11-11).
 *
 * İnce ve durumsuz: her çağrı [SignalIslemleri]'ne gider. Çağrılar
 * Flutter'ın arka plan görev kuyruğunda çalışır; ana iş parçacığı
 * bloklanmaz. Hiçbir şey log'lanmaz; hata yalnızca türünü taşır
 * (kod = `SignalHatasiTuru` adı, mesaj ve ayrıntı yok).
 */
class SignalKoprusu private constructor(private val kanal: MethodChannel) :
    MethodChannel.MethodCallHandler {

    companion object {
        const val KANAL = "tayfam/e2e/signal"

        /** Kanalı [messenger] üzerinde kurar. */
        fun kur(messenger: BinaryMessenger): SignalKoprusu {
            val kuyruk = messenger.makeBackgroundTaskQueue()
            val kanal = MethodChannel(messenger, KANAL, StandardMethodCodec.INSTANCE, kuyruk)
            return SignalKoprusu(kanal).also { kanal.setMethodCallHandler(it) }
        }
    }

    /** Kanalı bırakır. */
    fun birak() {
        kanal.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val arg = argumanlar(call.arguments)
        if (arg == null) {
            result.error(SignalHatasiTuru.bilinmeyen.name, null, null)
            return
        }
        try {
            result.success(SignalIslemleri.calistir(call.method, arg))
        } catch (e: SignalHatasi) {
            result.error(e.tur.name, null, null)
        }
    }

    private fun argumanlar(ham: Any?): Map<String, Any?>? {
        if (ham == null) return emptyMap()
        if (ham !is Map<*, *>) return null
        val sonuc = HashMap<String, Any?>(ham.size)
        for ((k, v) in ham) {
            if (k !is String) return null
            sonuc[k] = v
        }
        return sonuc
    }
}
