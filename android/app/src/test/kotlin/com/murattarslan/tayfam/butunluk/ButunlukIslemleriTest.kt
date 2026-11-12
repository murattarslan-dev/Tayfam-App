package com.murattarslan.tayfam.butunluk

import com.google.android.play.core.integrity.model.StandardIntegrityErrorCode
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * [ButunlukIslemleri]'nin JVM birim testleri, sahte Play ile (Play
 * Integrity kütüphanesi JVM'de Google Play'e bağlanamaz). Gerçek akış
 * cihazda, Play'den kurulan derlemede denenir (istemci ADR-0023).
 */
class ButunlukIslemleriTest {

    private class SahteHata(val kod: Int?) : Exception()

    /** Geri çağrıları elle tetiklenen sahte Play. */
    private class SahtePlay : PlayButunluk<String> {
        val hazirliklar = mutableListOf<Pair<(String) -> Unit, (Exception) -> Unit>>()
        val istekler = mutableListOf<Triple<String, (String) -> Unit, (Exception) -> Unit>>()
        val projeler = mutableListOf<Long>()
        val ozetler = mutableListOf<String>()
        private var sayac = 0

        override fun hazirla(proje: Long, tamam: (String) -> Unit, hata: (Exception) -> Unit) {
            projeler.add(proje)
            hazirliklar.add(tamam to hata)
        }

        override fun iste(
            saglayici: String,
            istekOzeti: String,
            tamam: (String) -> Unit,
            hata: (Exception) -> Unit,
        ) {
            ozetler.add(istekOzeti)
            istekler.add(Triple(saglayici, tamam, hata))
        }

        override fun hataKodu(e: Exception): Int? = (e as? SahteHata)?.kod

        fun hazirlikBitsin() {
            sayac++
            hazirliklar.removeAt(0).first("saglayici-$sayac")
        }

        fun hazirlikHata(kod: Int?) {
            hazirliklar.removeAt(0).second(SahteHata(kod))
        }
    }

    private class Sonuc {
        var token: String? = null
        var hata: ButunlukHatasiTuru? = null
        var cagri = 0
        val geri: (String?, ButunlukHatasiTuru?) -> Unit = { t, h ->
            cagri++
            token = t
            hata = h
        }
    }

    private val ozet = "RQikIoUgcNuXXdqIefpw7eiSKtDfUXbWostlt13jJbM"
    private val proje = 73439258394L

    @Test
    fun saglayiciBirKezHazirlanirVeTokenDoner() {
        val play = SahtePlay()
        val islemler = ButunlukIslemleri(play)
        val ilk = Sonuc()
        islemler.token(proje, ozet, ilk.geri)
        play.hazirlikBitsin()
        assertEquals(listOf("saglayici-1"), play.istekler.map { it.first })
        play.istekler.removeAt(0).second("token-1")
        assertEquals("token-1", ilk.token)
        assertNull(ilk.hata)

        val ikinci = Sonuc()
        islemler.token(proje, ozet, ikinci.geri)
        play.istekler.removeAt(0).second("token-2")
        assertEquals("token-2", ikinci.token)
        assertEquals(listOf(proje), play.projeler)
        assertEquals(listOf(ozet, ozet), play.ozetler)
    }

    @Test
    fun hazirlikSurerkenGelenIsteklerAyniHazirligiBekler() {
        val play = SahtePlay()
        val islemler = ButunlukIslemleri(play)
        var hazir: ButunlukHatasiTuru? = ButunlukHatasiTuru.bilinmeyen
        islemler.hazirla(proje) { hazir = it }
        val sonuc = Sonuc()
        islemler.token(proje, ozet, sonuc.geri)
        assertEquals(1, play.hazirliklar.size)
        play.hazirlikBitsin()
        assertNull(hazir)
        assertEquals(1, play.istekler.size)
    }

    @Test
    fun saglayiciGecersizseYenidenHazirlanirVeBirKezTekrarlanir() {
        val play = SahtePlay()
        val islemler = ButunlukIslemleri(play)
        val sonuc = Sonuc()
        islemler.token(proje, ozet, sonuc.geri)
        play.hazirlikBitsin()
        play.istekler.removeAt(0).third(
            SahteHata(StandardIntegrityErrorCode.INTEGRITY_TOKEN_PROVIDER_INVALID),
        )
        assertEquals(0, sonuc.cagri)
        play.hazirlikBitsin()
        assertEquals("saglayici-2", play.istekler.single().first)
        play.istekler.removeAt(0).second("token")
        assertEquals("token", sonuc.token)
        assertEquals(1, sonuc.cagri)
    }

    @Test
    fun ikinciKezGecersizseHataDoner() {
        val play = SahtePlay()
        val islemler = ButunlukIslemleri(play)
        val sonuc = Sonuc()
        islemler.token(proje, ozet, sonuc.geri)
        val gecersiz = StandardIntegrityErrorCode.INTEGRITY_TOKEN_PROVIDER_INVALID
        play.hazirlikBitsin()
        play.istekler.removeAt(0).third(SahteHata(gecersiz))
        play.hazirlikBitsin()
        play.istekler.removeAt(0).third(SahteHata(gecersiz))
        assertNull(sonuc.token)
        assertEquals(ButunlukHatasiTuru.saglayiciGecersiz, sonuc.hata)
        assertEquals(1, sonuc.cagri)
        assertEquals(0, play.hazirliklar.size)
    }

    @Test
    fun hazirlikHatasiTureCevrilirVeSonrakiIstekYenidenHazirlar() {
        val play = SahtePlay()
        val islemler = ButunlukIslemleri(play)
        val sonuc = Sonuc()
        islemler.token(proje, ozet, sonuc.geri)
        play.hazirlikHata(StandardIntegrityErrorCode.PLAY_SERVICES_NOT_FOUND)
        assertEquals(ButunlukHatasiTuru.playYok, sonuc.hata)

        islemler.token(proje, ozet, Sonuc().geri)
        assertEquals(1, play.hazirliklar.size)
    }

    @Test
    fun istekHatasiTureCevrilir() {
        val play = SahtePlay()
        val islemler = ButunlukIslemleri(play)
        val sonuc = Sonuc()
        islemler.token(proje, ozet, sonuc.geri)
        play.hazirlikBitsin()
        play.istekler.removeAt(0).third(SahteHata(StandardIntegrityErrorCode.NETWORK_ERROR))
        assertEquals(ButunlukHatasiTuru.ag, sonuc.hata)
        // Sağlayıcı geçerli kalır; yeniden hazırlanmaz.
        islemler.token(proje, ozet, Sonuc().geri)
        assertEquals(0, play.hazirliklar.size)
        assertEquals(1, play.istekler.size)
    }

    @Test
    fun gecersizIstekOzetiPlayeGitmez() {
        val play = SahtePlay()
        val islemler = ButunlukIslemleri(play)
        for (kotu in listOf("", "kisa", "$ozet=", ozet.dropLast(1) + "+")) {
            val sonuc = Sonuc()
            islemler.token(proje, kotu, sonuc.geri)
            assertEquals(ButunlukHatasiTuru.yapilandirma, sonuc.hata)
        }
        assertEquals(0, play.hazirliklar.size)
    }

    @Test
    fun hataKodlariEslenir() {
        val beklenen = mapOf(
            StandardIntegrityErrorCode.PLAY_STORE_NOT_FOUND to ButunlukHatasiTuru.playYok,
            StandardIntegrityErrorCode.PLAY_SERVICES_NOT_FOUND to ButunlukHatasiTuru.playYok,
            StandardIntegrityErrorCode.API_NOT_AVAILABLE to ButunlukHatasiTuru.playEski,
            StandardIntegrityErrorCode.PLAY_STORE_VERSION_OUTDATED to ButunlukHatasiTuru.playEski,
            StandardIntegrityErrorCode.PLAY_SERVICES_VERSION_OUTDATED to ButunlukHatasiTuru.playEski,
            StandardIntegrityErrorCode.NETWORK_ERROR to ButunlukHatasiTuru.ag,
            StandardIntegrityErrorCode.TOO_MANY_REQUESTS to ButunlukHatasiTuru.kota,
            StandardIntegrityErrorCode.GOOGLE_SERVER_UNAVAILABLE to ButunlukHatasiTuru.gecici,
            StandardIntegrityErrorCode.CLIENT_TRANSIENT_ERROR to ButunlukHatasiTuru.gecici,
            StandardIntegrityErrorCode.INTERNAL_ERROR to ButunlukHatasiTuru.gecici,
            StandardIntegrityErrorCode.CANNOT_BIND_TO_SERVICE to ButunlukHatasiTuru.gecici,
            StandardIntegrityErrorCode.CLOUD_PROJECT_NUMBER_IS_INVALID to
                ButunlukHatasiTuru.yapilandirma,
            StandardIntegrityErrorCode.APP_NOT_INSTALLED to ButunlukHatasiTuru.yapilandirma,
            StandardIntegrityErrorCode.APP_UID_MISMATCH to ButunlukHatasiTuru.yapilandirma,
            StandardIntegrityErrorCode.REQUEST_HASH_TOO_LONG to ButunlukHatasiTuru.yapilandirma,
            StandardIntegrityErrorCode.INTEGRITY_TOKEN_PROVIDER_INVALID to
                ButunlukHatasiTuru.saglayiciGecersiz,
        )
        for ((kod, tur) in beklenen) {
            assertEquals("kod $kod", tur, ButunlukIslemleri.hataTuru(kod))
        }
        assertEquals(ButunlukHatasiTuru.bilinmeyen, ButunlukIslemleri.hataTuru(null))
        assertEquals(ButunlukHatasiTuru.bilinmeyen, ButunlukIslemleri.hataTuru(12345))
    }
}
