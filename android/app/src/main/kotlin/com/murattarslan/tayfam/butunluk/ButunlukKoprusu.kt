package com.murattarslan.tayfam.butunluk

import android.content.Context
import com.google.android.play.core.integrity.IntegrityManagerFactory
import com.google.android.play.core.integrity.StandardIntegrityException
import com.google.android.play.core.integrity.StandardIntegrityManager
import com.google.android.play.core.integrity.StandardIntegrityManager.PrepareIntegrityTokenRequest
import com.google.android.play.core.integrity.StandardIntegrityManager.StandardIntegrityTokenProvider
import com.google.android.play.core.integrity.StandardIntegrityManager.StandardIntegrityTokenRequest
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * `tayfam/butunluk` platform kanalı (istemci ADR-0023; Tayfam-Api
 * ADR-0022): Play Integrity API, standard request.
 *
 * Yöntemler:
 * - `hazirla` {proje}: token sağlayıcısını hazırlar (uygulama açılışı).
 * - `token` {proje, istekOzeti}: istek özetine bağlı bütünlük token'ı.
 *
 * Bulut proje numarası Dart'tan gelir (public değer, derlemede
 * `--dart-define` ile değiştirilebilir). Hiçbir şey loglanmaz; hata yalnızca
 * türünü taşır (kod = [ButunlukHatasiTuru] adı, mesaj ve ayrıntı yok).
 */
class ButunlukKoprusu private constructor(
    private val kanal: MethodChannel,
    private val islemler: ButunlukIslemleri<StandardIntegrityTokenProvider>,
) : MethodChannel.MethodCallHandler {

    companion object {
        const val KANAL = "tayfam/butunluk"

        /** Kanalı [messenger] üzerinde kurar. */
        fun kur(messenger: BinaryMessenger, context: Context): ButunlukKoprusu {
            val kanal = MethodChannel(messenger, KANAL)
            val yonetici = IntegrityManagerFactory.createStandard(context.applicationContext)
            val islemler = ButunlukIslemleri(GooglePlayButunluk(yonetici))
            return ButunlukKoprusu(kanal, islemler).also { kanal.setMethodCallHandler(it) }
        }
    }

    /** Kanalı bırakır. */
    fun birak() {
        kanal.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val arg = call.arguments as? Map<*, *>
        val proje = (arg?.get("proje") as? Number)?.toLong()
        if (proje == null || proje <= 0) {
            result.error(ButunlukHatasiTuru.yapilandirma.name, null, null)
            return
        }
        when (call.method) {
            "hazirla" -> islemler.hazirla(proje) { hata ->
                if (hata == null) result.success(null) else result.error(hata.name, null, null)
            }
            "token" -> {
                val istekOzeti = arg?.get("istekOzeti") as? String
                if (istekOzeti == null) {
                    result.error(ButunlukHatasiTuru.yapilandirma.name, null, null)
                    return
                }
                islemler.token(proje, istekOzeti) { token, hata ->
                    if (token != null) {
                        result.success(token)
                    } else {
                        result.error((hata ?: ButunlukHatasiTuru.bilinmeyen).name, null, null)
                    }
                }
            }
            else -> result.notImplemented()
        }
    }
}

/** Play kütüphanesiyle [PlayButunluk]. Görev geri çağrıları ana iş parçacığında. */
internal class GooglePlayButunluk(
    private val yonetici: StandardIntegrityManager,
) : PlayButunluk<StandardIntegrityTokenProvider> {

    override fun hazirla(
        proje: Long,
        tamam: (StandardIntegrityTokenProvider) -> Unit,
        hata: (Exception) -> Unit,
    ) {
        val istek = PrepareIntegrityTokenRequest.builder().setCloudProjectNumber(proje).build()
        yonetici.prepareIntegrityToken(istek)
            .addOnSuccessListener { tamam(it) }
            .addOnFailureListener { hata(it) }
    }

    override fun iste(
        saglayici: StandardIntegrityTokenProvider,
        istekOzeti: String,
        tamam: (String) -> Unit,
        hata: (Exception) -> Unit,
    ) {
        val istek = StandardIntegrityTokenRequest.builder().setRequestHash(istekOzeti).build()
        saglayici.request(istek)
            .addOnSuccessListener { tamam(it.token()) }
            .addOnFailureListener { hata(it) }
    }

    override fun hataKodu(e: Exception): Int? = (e as? StandardIntegrityException)?.errorCode
}
