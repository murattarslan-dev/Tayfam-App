package com.murattarslan.tayfam.butunluk

import com.google.android.play.core.integrity.model.StandardIntegrityErrorCode

/**
 * Bütünlük token'ı alınamamasının türü (istemci ADR-0023 §3). Dart'taki
 * `ButunlukHatasiTuru` adlarıyla aynıdır; kanalda hata kodu olarak gider,
 * mesaj ve ayrıntı taşınmaz.
 */
@Suppress("EnumEntryName")
enum class ButunlukHatasiTuru {
    playYok,
    playEski,
    ag,
    kota,
    gecici,
    yapilandirma,
    saglayiciGecersiz,
    bilinmeyen,
}

/**
 * Köprünün kullandığı iki Play Integrity işlemi. Uygulamada
 * `GooglePlayButunluk` (Play kütüphanesi), JVM testlerinde sahtesi.
 * Geri çağrılar ana iş parçacığında gelir.
 */
interface PlayButunluk<S> {
    /** `prepareIntegrityToken`: token sağlayıcısını hazırlar. */
    fun hazirla(proje: Long, tamam: (S) -> Unit, hata: (Exception) -> Unit)

    /** `StandardIntegrityTokenProvider.request`: [istekOzeti]'ne bağlı token. */
    fun iste(saglayici: S, istekOzeti: String, tamam: (String) -> Unit, hata: (Exception) -> Unit)

    /** Play hatasının `StandardIntegrityErrorCode` değeri; değilse `null`. */
    fun hataKodu(e: Exception): Int?
}

/**
 * Standard request akışı (istemci ADR-0023 §3):
 *
 * - Token sağlayıcısı bir kez hazırlanır ve bellekte tutulur; hazırlık
 *   sürerken gelen istekler aynı hazırlığı bekler.
 * - `INTEGRITY_TOKEN_PROVIDER_INVALID` gelirse sağlayıcı yeniden hazırlanır
 *   ve istek bir kez tekrarlanır.
 * - Hata yalnızca türe çevrilir; token ve istek özeti hiçbir yere
 *   yazılmaz. Log yok.
 *
 * Yalnızca ana iş parçacığından çağrılır (kanal ve Play geri çağrıları);
 * eşzamanlılık denetimi bu yüzden gerekmez.
 */
class ButunlukIslemleri<S>(private val play: PlayButunluk<S>) {
    private var saglayici: S? = null
    private var saglayiciProjesi: Long? = null
    private var bekleyenler: MutableList<(S?, ButunlukHatasiTuru?) -> Unit>? = null
    private var bekleyenProje: Long? = null

    /** Sağlayıcıyı önceden hazırlar; [sonuc] hata türünü ya da `null` alır. */
    fun hazirla(proje: Long, sonuc: (ButunlukHatasiTuru?) -> Unit) {
        saglayiciAl(proje) { _, hata -> sonuc(hata) }
    }

    /**
     * [istekOzeti]'ne bağlı token. [sonuc] ya token'ı ya da hata türünü
     * alır (ikisinden biri `null`).
     */
    fun token(proje: Long, istekOzeti: String, sonuc: (String?, ButunlukHatasiTuru?) -> Unit) {
        if (!ISTEK_OZETI.matches(istekOzeti)) {
            sonuc(null, ButunlukHatasiTuru.yapilandirma)
            return
        }
        iste(proje, istekOzeti, tekrar = false, sonuc)
    }

    private fun iste(
        proje: Long,
        istekOzeti: String,
        tekrar: Boolean,
        sonuc: (String?, ButunlukHatasiTuru?) -> Unit,
    ) {
        saglayiciAl(proje) { s, hata ->
            if (s == null) {
                sonuc(null, hata ?: ButunlukHatasiTuru.bilinmeyen)
                return@saglayiciAl
            }
            play.iste(
                s,
                istekOzeti,
                { token ->
                    if (token.isEmpty()) {
                        sonuc(null, ButunlukHatasiTuru.bilinmeyen)
                    } else {
                        sonuc(token, null)
                    }
                },
                { e ->
                    val kod = play.hataKodu(e)
                    if (kod == StandardIntegrityErrorCode.INTEGRITY_TOKEN_PROVIDER_INVALID) {
                        if (saglayici === s) {
                            saglayici = null
                            saglayiciProjesi = null
                        }
                        if (tekrar) {
                            sonuc(null, ButunlukHatasiTuru.saglayiciGecersiz)
                        } else {
                            iste(proje, istekOzeti, tekrar = true, sonuc)
                        }
                    } else {
                        sonuc(null, hataTuru(kod))
                    }
                },
            )
        }
    }

    private fun saglayiciAl(proje: Long, geri: (S?, ButunlukHatasiTuru?) -> Unit) {
        val mevcut = saglayici
        if (mevcut != null && saglayiciProjesi == proje) {
            geri(mevcut, null)
            return
        }
        val bekleyen = bekleyenler
        if (bekleyen != null && bekleyenProje == proje) {
            bekleyen.add(geri)
            return
        }
        val liste = mutableListOf(geri)
        bekleyenler = liste
        bekleyenProje = proje
        play.hazirla(
            proje,
            { s ->
                if (bekleyenler === liste) {
                    bekleyenler = null
                    bekleyenProje = null
                }
                saglayici = s
                saglayiciProjesi = proje
                liste.forEach { it(s, null) }
            },
            { e ->
                if (bekleyenler === liste) {
                    bekleyenler = null
                    bekleyenProje = null
                }
                val tur = hataTuru(play.hataKodu(e))
                liste.forEach { it(null, tur) }
            },
        )
    }

    companion object {
        /** base64url, dolgusuz SHA-256 (43 karakter; istemci ADR-0023 §2). */
        private val ISTEK_OZETI = Regex("^[A-Za-z0-9_-]{43}$")

        /** `StandardIntegrityErrorCode` → tür. */
        fun hataTuru(kod: Int?): ButunlukHatasiTuru = when (kod) {
            StandardIntegrityErrorCode.PLAY_STORE_NOT_FOUND,
            StandardIntegrityErrorCode.PLAY_SERVICES_NOT_FOUND,
            -> ButunlukHatasiTuru.playYok

            StandardIntegrityErrorCode.API_NOT_AVAILABLE,
            StandardIntegrityErrorCode.PLAY_STORE_VERSION_OUTDATED,
            StandardIntegrityErrorCode.PLAY_SERVICES_VERSION_OUTDATED,
            -> ButunlukHatasiTuru.playEski

            StandardIntegrityErrorCode.NETWORK_ERROR -> ButunlukHatasiTuru.ag

            StandardIntegrityErrorCode.TOO_MANY_REQUESTS -> ButunlukHatasiTuru.kota

            StandardIntegrityErrorCode.GOOGLE_SERVER_UNAVAILABLE,
            StandardIntegrityErrorCode.CLIENT_TRANSIENT_ERROR,
            StandardIntegrityErrorCode.INTERNAL_ERROR,
            StandardIntegrityErrorCode.CANNOT_BIND_TO_SERVICE,
            -> ButunlukHatasiTuru.gecici

            StandardIntegrityErrorCode.CLOUD_PROJECT_NUMBER_IS_INVALID,
            StandardIntegrityErrorCode.APP_NOT_INSTALLED,
            StandardIntegrityErrorCode.APP_UID_MISMATCH,
            StandardIntegrityErrorCode.REQUEST_HASH_TOO_LONG,
            -> ButunlukHatasiTuru.yapilandirma

            StandardIntegrityErrorCode.INTEGRITY_TOKEN_PROVIDER_INVALID ->
                ButunlukHatasiTuru.saglayiciGecersiz

            else -> ButunlukHatasiTuru.bilinmeyen
        }
    }
}
