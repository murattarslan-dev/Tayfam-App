package com.murattarslan.tayfam.e2e

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test

/**
 * Köprünün JVM birim testleri, gerçek libsignal ile (masaüstü paketi
 * `org.signal:libsignal-client`, Android paketiyle aynı sürüm).
 *
 * Her çağrı [SignalIslemleri.calistir] üzerinden yapılır ve durum,
 * Dart'ın yapacağı gibi yalnızca çağrılar arasında taşınan baytlardadır:
 * kayıt → işlem → yeni kayıt → sonraki işlem.
 */
class SignalIslemleriTest {

    // -------------------------------------------------------------------
    // Test cihazı: Dart tarafındaki güvenli deponun yerine geçer.
    // -------------------------------------------------------------------

    private class Cihaz(val ad: String, val cihazNo: Int) {
        val kimlik: ByteArray
        val acik: ByteArray
        val kayitKimligi: Int
        val onAnahtarlar = HashMap<Int, ByteArray>()
        val onAnahtarAciklari = HashMap<Int, ByteArray>()
        lateinit var imzali: Map<String, Any?>
        val kyberler = HashMap<Int, Map<String, Any?>>()
        val oturumlar = HashMap<String, ByteArray>()

        init {
            val k = cagir("kimlikUret")
            kimlik = k["kayit"] as ByteArray
            acik = k["acik"] as ByteArray
            kayitKimligi = k["kayitKimligi"] as Int
        }

        fun anahtarlariUret(onAnahtarBaslangic: Int = 100, onAnahtarAdet: Int = 3) {
            @Suppress("UNCHECKED_CAST")
            val liste = cagir(
                "onAnahtarUret",
                "baslangicId" to onAnahtarBaslangic,
                "adet" to onAnahtarAdet,
            )["anahtarlar"] as List<Map<String, Any?>>
            for (o in liste) {
                onAnahtarlar[o["id"] as Int] = o["kayit"] as ByteArray
                onAnahtarAciklari[o["id"] as Int] = o["acik"] as ByteArray
            }
            imzali = cagir("imzaliOnAnahtarUret", "kimlik" to kimlik, "id" to 7)
            kyberler[50] = cagir("kyberOnAnahtarUret", "kimlik" to kimlik, "id" to 50)
            // Son çare Kyber anahtarı.
            kyberler[900] = cagir("kyberOnAnahtarUret", "kimlik" to kimlik, "id" to 900)
        }

        fun paket(onAnahtarId: Int? = 100, kyberId: Int = 50): Map<String, Any?> = mapOf(
            "kayitKimligi" to kayitKimligi,
            "cihazNo" to cihazNo,
            "onAnahtarId" to onAnahtarId,
            "onAnahtar" to onAnahtarId?.let { onAnahtarAciklari.getValue(it) },
            "imzaliOnAnahtarId" to imzali["id"],
            "imzaliOnAnahtar" to imzali["acik"],
            "imzaliOnAnahtarImzasi" to imzali["imza"],
            "kimlikAnahtari" to acik,
            "kyberOnAnahtarId" to kyberId,
            "kyberOnAnahtar" to kyberler.getValue(kyberId)["acik"],
            "kyberOnAnahtarImzasi" to kyberler.getValue(kyberId)["imza"],
        )

        private fun ortak(karsi: Cihaz): Array<Pair<String, Any?>> = arrayOf(
            "kimlik" to kimlik,
            "kayitKimligi" to kayitKimligi,
            "yerelAd" to ad,
            "yerelCihaz" to cihazNo,
            "ad" to karsi.ad,
            "cihaz" to karsi.cihazNo,
        )

        fun paketIsle(karsi: Cihaz, paket: Map<String, Any?>) {
            val s = cagir(
                "paketIsle",
                *ortak(karsi),
                "oturum" to oturumlar[karsi.ad],
                "paket" to paket,
            )
            oturumlar[karsi.ad] = s["oturum"] as ByteArray
        }

        fun sifrele(karsi: Cihaz, metin: String): Pair<Int, ByteArray> {
            val s = cagir(
                "sifrele",
                *ortak(karsi),
                "oturum" to oturumlar[karsi.ad],
                "duz" to metin.toByteArray(),
            )
            oturumlar[karsi.ad] = s["oturum"] as ByteArray
            return (s["tur"] as Int) to (s["sifreli"] as ByteArray)
        }

        /** Dart'taki akış: tür 3 ise incele, gereken kayıtları ver, çöz, yaz. */
        fun coz(
            karsi: Cihaz,
            mesaj: Pair<Int, ByteArray>,
            yerelAdOverride: String? = null,
            kyberVer: Boolean = true,
        ): Map<String, Any?> {
            val arg = linkedMapOf(*ortak(karsi))
            if (yerelAdOverride != null) arg["yerelAd"] = yerelAdOverride
            arg["tur"] = mesaj.first
            arg["sifreli"] = mesaj.second
            arg["oturum"] = oturumlar[karsi.ad]
            if (mesaj.first == 3) {
                val bilgi = cagir("onAnahtarMesajiIncele", "sifreli" to mesaj.second)
                arg["onAnahtar"] = (bilgi["onAnahtarId"] as Int?)?.let { onAnahtarlar[it] }
                assertEquals(imzali["id"], bilgi["imzaliId"])
                arg["imzaliOnAnahtar"] = imzali["kayit"]
                arg["kyberOnAnahtarlari"] =
                    if (kyberVer) kyberler.values.map { it["kayit"] } else emptyList<ByteArray>()
            }
            val s = SignalIslemleri.calistir("coz", arg)
            // Durum ancak başarıdan sonra yazılır (ADR-0010 kalıcılık sırası).
            oturumlar[karsi.ad] = s["oturum"] as ByteArray
            (s["onAnahtarId"] as Int?)?.let { onAnahtarlar.remove(it) }
            val kyberId = s["kyberId"] as Int?
            if (kyberId != null && kyberId != 900) kyberler.remove(kyberId)
            return s
        }
    }

    private val aliceAd = "8f1c2b3a-4d5e-4f60-8a7b-9c0d1e2f3a4b"
    private val bobAd = "1a2b3c4d-5e6f-4071-8293-a4b5c6d7e8f9"

    private fun ikiCihaz(): Pair<Cihaz, Cihaz> {
        val alice = Cihaz(aliceAd, 1)
        val bob = Cihaz(bobAd, 2)
        bob.anahtarlariUret()
        return alice to bob
    }

    private fun Map<String, Any?>.metin(): String = String(this["duz"] as ByteArray)

    // -------------------------------------------------------------------
    // Anahtar üretimi
    // -------------------------------------------------------------------

    @Test
    fun kimlikVeOnAnahtarlarUretilir() {
        val c = Cihaz(aliceAd, 1)
        assertEquals(33, c.acik.size)
        assertTrue(c.kayitKimligi in 1..16380)

        @Suppress("UNCHECKED_CAST")
        val liste = cagir("onAnahtarUret", "baslangicId" to 0xFFFFFE, "adet" to 3)["anahtarlar"]
            as List<Map<String, Any?>>
        assertEquals(listOf(0xFFFFFE, 0xFFFFFF, 1), liste.map { it["id"] })
        liste.forEach { assertEquals(33, (it["acik"] as ByteArray).size) }

        val imzali = cagir("imzaliOnAnahtarUret", "kimlik" to c.kimlik, "id" to 3)
        assertEquals(64, (imzali["imza"] as ByteArray).size)
        assertTrue(imzali["zaman"] is Long)

        val kyber = cagir("kyberOnAnahtarUret", "kimlik" to c.kimlik, "id" to 4)
        assertEquals(1569, (kyber["acik"] as ByteArray).size)
        assertEquals(64, (kyber["imza"] as ByteArray).size)
    }

    // -------------------------------------------------------------------
    // Oturum, şifreleme, çözme
    // -------------------------------------------------------------------

    @Test
    fun ilkMesajCevapVeDurumsuzTur() {
        val (alice, bob) = ikiCihaz()
        alice.paketIsle(bob, bob.paket())

        val m1 = alice.sifrele(bob, "merhaba")
        assertEquals(3, m1.first)

        val bilgi = cagir("onAnahtarMesajiIncele", "sifreli" to m1.second)
        assertEquals(100, bilgi["onAnahtarId"])
        assertArrayEquals(alice.acik, bilgi["gondericiKimligi"] as ByteArray)
        assertEquals(alice.kayitKimligi, bilgi["kayitKimligi"])

        val c1 = bob.coz(alice, m1)
        assertEquals("merhaba", c1.metin())
        assertEquals(100, c1["onAnahtarId"])
        assertEquals(50, c1["kyberId"])
        assertEquals(7, c1["imzaliId"])
        assertArrayEquals(bilgi["tabanAnahtar"] as ByteArray, c1["kyberTaban"] as ByteArray)
        assertArrayEquals(alice.acik, c1["karsiKimlik"] as ByteArray)
        assertTrue(bob.onAnahtarlar[100] == null)

        // Cevap: Bob'un bekleyen ön anahtar kurulumu yok → tür 2.
        val r1 = bob.sifrele(alice, "selam")
        assertEquals(2, r1.first)
        val cr1 = alice.coz(bob, r1)
        assertEquals("selam", cr1.metin())
        assertArrayEquals(bob.acik, cr1["karsiKimlik"] as ByteArray)
        assertNull(cr1["onAnahtarId"])
        assertNull(cr1["kyberId"])

        // Alice cevabı aldıktan sonra tür 2 gönderir.
        val m2 = alice.sifrele(bob, "nasılsın")
        assertEquals(2, m2.first)
        assertEquals("nasılsın", bob.coz(alice, m2).metin())
    }

    @Test
    fun cokluVeSiraDisiMesaj() {
        val (alice, bob) = ikiCihaz()
        alice.paketIsle(bob, bob.paket())
        // Cevap gelmeden üç tür 3 mesaj; sıra dışı çözülür.
        val m = (1..3).map { alice.sifrele(bob, "ilk$it") }
        m.forEach { assertEquals(3, it.first) }
        assertEquals("ilk3", bob.coz(alice, m[2]).metin())
        assertEquals("ilk1", bob.coz(alice, m[0]).metin())
        assertEquals("ilk2", bob.coz(alice, m[1]).metin())

        bob.coz(alice, alice.sifrele(bob, "x")).also { assertEquals("x", it.metin()) }
        alice.coz(bob, bob.sifrele(alice, "cevap"))
        val n = (1..5).map { alice.sifrele(bob, "m$it") }
        n.forEach { assertEquals(2, it.first) }
        for (i in listOf(4, 0, 2, 1, 3)) {
            assertEquals("m${i + 1}", bob.coz(alice, n[i]).metin())
        }
    }

    @Test
    fun tekrarEdilenMesajEskiMesajdir() {
        val (alice, bob) = ikiCihaz()
        alice.paketIsle(bob, bob.paket())
        bob.coz(alice, alice.sifrele(bob, "a"))
        alice.coz(bob, bob.sifrele(alice, "b"))
        val m = alice.sifrele(bob, "c")
        bob.coz(alice, m)
        hataBekle(SignalHatasiTuru.eskiMesaj) { bob.coz(alice, m) }
    }

    @Test
    fun bozukSifreliMetinGecersizMesajdir() {
        val (alice, bob) = ikiCihaz()
        alice.paketIsle(bob, bob.paket())
        bob.coz(alice, alice.sifrele(bob, "a"))
        alice.coz(bob, bob.sifrele(alice, "b"))
        val (tur, sifreli) = alice.sifrele(bob, "c")
        val bozuk = sifreli.copyOf().also { it[it.size - 12] = (it[it.size - 12].toInt() xor 1).toByte() }
        val once = bob.oturumlar[aliceAd]
        hataBekle(SignalHatasiTuru.gecersizMesaj) { bob.coz(alice, tur to bozuk) }
        // Hata durumunda durum değişmez.
        assertArrayEquals(once, bob.oturumlar[aliceAd])
        hataBekle(SignalHatasiTuru.gecersizMesaj) { bob.coz(alice, 2 to ByteArray(40) { 7 }) }
        hataBekle(SignalHatasiTuru.gecersizMesaj) {
            cagir("onAnahtarMesajiIncele", "sifreli" to ByteArray(10))
        }
        // Bozulmamış hâli hâlâ çözülür.
        assertEquals("c", bob.coz(alice, tur to sifreli).metin())
    }

    @Test
    fun adresBagiUyusmazsaGecersizMesaj() {
        val (alice, bob) = ikiCihaz()
        alice.paketIsle(bob, bob.paket())
        val m = alice.sifrele(bob, "a")
        hataBekle(SignalHatasiTuru.gecersizMesaj) {
            bob.coz(alice, m, yerelAdOverride = "00000000-0000-4000-8000-000000000001")
        }
    }

    @Test
    fun tekKullanimlikOnAnahtarsizPaket() {
        val (alice, bob) = ikiCihaz()
        alice.paketIsle(bob, bob.paket(onAnahtarId = null))
        val m = alice.sifrele(bob, "ön anahtarsız")
        val bilgi = cagir("onAnahtarMesajiIncele", "sifreli" to m.second)
        assertNull(bilgi["onAnahtarId"])
        val c = bob.coz(alice, m)
        assertEquals("ön anahtarsız", c.metin())
        assertNull(c["onAnahtarId"])
        assertEquals(3, bob.onAnahtarlar.size)
    }

    @Test
    fun kyberZorunludur() {
        val (alice, bob) = ikiCihaz()
        // Kyber alanları olmayan paket kabul edilmez.
        val kybersiz = bob.paket().filterKeys { !it.startsWith("kyber") }
        hataBekle(SignalHatasiTuru.bilinmeyen) { alice.paketIsle(bob, kybersiz) }
        // Kyber imzası geçersiz paket kabul edilmez.
        val bozukImza = bob.paket().toMutableMap().also {
            it["kyberOnAnahtarImzasi"] = ByteArray(64)
        }
        hataBekle(SignalHatasiTuru.gecersizAnahtar) { alice.paketIsle(bob, bozukImza) }
        // İmzalı ön anahtar imzası geçersiz paket kabul edilmez.
        val bozukEc = bob.paket().toMutableMap().also {
            it["imzaliOnAnahtarImzasi"] = ByteArray(64)
        }
        hataBekle(SignalHatasiTuru.gecersizAnahtar) { alice.paketIsle(bob, bozukEc) }

        // Alıcı Kyber kaydını veremezse mesaj çözülmez.
        alice.paketIsle(bob, bob.paket())
        val m = alice.sifrele(bob, "a")
        hataBekle(SignalHatasiTuru.gecersizAnahtar) { bob.coz(alice, m, kyberVer = false) }
        assertEquals("a", bob.coz(alice, m).metin())
    }

    @Test
    fun sonCareKyberKullanimiBildirilir() {
        val (alice, bob) = ikiCihaz()
        alice.paketIsle(bob, bob.paket(kyberId = 900))
        val m = alice.sifrele(bob, "son çare")
        val bobOnce = HashMap(bob.onAnahtarlar)
        val c1 = bob.coz(alice, m)
        assertEquals(900, c1["kyberId"])
        assertEquals(7, c1["imzaliId"])
        assertTrue(bob.kyberler.containsKey(900))
        // Aynı mesaj, oturum silinmiş bir durumda yeniden oynatılırsa aynı
        // üçlü bildirilir; Dart bunu görülmüş küme ile reddeder.
        bob.oturumlar.remove(aliceAd)
        bob.onAnahtarlar.putAll(bobOnce)
        val c2 = bob.coz(alice, m)
        assertEquals(c1["kyberId"], c2["kyberId"])
        assertEquals(c1["imzaliId"], c2["imzaliId"])
        assertArrayEquals(c1["kyberTaban"] as ByteArray, c2["kyberTaban"] as ByteArray)
    }

    @Test
    fun oturumsuzSifrelemeVeCozmeOturumYok() {
        val (alice, bob) = ikiCihaz()
        hataBekle(SignalHatasiTuru.bilinmeyen) { alice.sifrele(bob, "a") }
        hataBekle(SignalHatasiTuru.oturumYok) { bob.coz(alice, 2 to ByteArray(60)) }
    }

    // -------------------------------------------------------------------
    // Simetrik yapı taşları (bilinen test vektörleri)
    // -------------------------------------------------------------------

    @Test
    fun hkdfRfc5869Vektorleri() {
        // RFC 5869 A.1
        val c1 = cagir(
            "hkdf",
            "girdi" to hex("0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b"),
            "tuz" to hex("000102030405060708090a0b0c"),
            "bilgi" to hex("f0f1f2f3f4f5f6f7f8f9"),
            "uzunluk" to 42,
        )["cikti"] as ByteArray
        assertArrayEquals(
            hex("3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865"),
            c1,
        )
        // RFC 5869 A.3 (tuz ve bilgi boş)
        val c3 = cagir(
            "hkdf",
            "girdi" to hex("0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b"),
            "tuz" to null,
            "bilgi" to ByteArray(0),
            "uzunluk" to 42,
        )["cikti"] as ByteArray
        assertArrayEquals(
            hex("8da4e775a563c18f715f802a063c5a31b8a11f5c5ee1879ec3454e5f3c738d2d9d201395faa4b61a96c8"),
            c3,
        )
    }

    @Test
    fun aesGcmSivBilinenVektor() {
        val anahtar = hex("bae8e37fc83441b16034566b7a806c46bb91c3c5aedb64a6c590bc84d1a5e269")
        val nonce = hex("e4b47801afc0577e34699b9e")
        val aad = hex("874296d5cc1fd16132")
        val duz = hex("671fdd4fbdc66f146545fc880c94a95198")
        val sifreli = cagir(
            "aesGcmSivSifrele",
            "anahtar" to anahtar, "nonce" to nonce, "duz" to duz, "aad" to aad,
        )["sifreli"] as ByteArray
        assertArrayEquals(hex("9209cfae7372e0a3ec2e5d072d5e26b7b9f3acb73908e54cddf7be1864914e13cf"), sifreli)
        val geri = cagir(
            "aesGcmSivCoz",
            "anahtar" to anahtar, "nonce" to nonce, "sifreli" to sifreli, "aad" to aad,
        )["duz"] as ByteArray
        assertArrayEquals(duz, geri)
        val bozuk = sifreli.copyOf().also { it[0] = (it[0].toInt() xor 1).toByte() }
        assertNull(
            cagir(
                "aesGcmSivCoz",
                "anahtar" to anahtar, "nonce" to nonce, "sifreli" to bozuk, "aad" to aad,
            )["duz"],
        )
        hataBekle(SignalHatasiTuru.gecersizAnahtar) {
            cagir(
                "aesGcmSivSifrele",
                "anahtar" to ByteArray(16), "nonce" to nonce, "duz" to duz, "aad" to aad,
            )
        }
    }

    @Test
    fun aes256GcmNistVektoru() {
        // NIST GCM spesifikasyonu (McGrew–Viega) Test Case 16.
        val anahtar = hex("feffe9928665731c6d6a8f9467308308feffe9928665731c6d6a8f9467308308")
        val nonce = hex("cafebabefacedbaddecaf888")
        val aad = hex("feedfacedeadbeeffeedfacedeadbeefabaddad2")
        val duz = hex(
            "d9313225f88406e5a55909c5aff5269a86a7a9531534f7da2e4c303d8a318a72" +
                "1c3c0c95956809532fcf0e2449a6b525b16aedf5aa0de657ba637b39",
        )
        val sifreliVeEtiket = hex(
            "522dc1f099567d07f47f37a32a84427d643a8cdcbfe5c0c97598a2bd2555d1aa" +
                "8cb08e48590dbb3da7b08b1056828838c5f61e6393ba7a0abcc9f662" +
                "76fc6ece0f4e1768cddf8853bb2d551b",
        )
        fun coz(girdi: ByteArray, a: ByteArray = aad) = cagir(
            "aes256GcmCoz",
            "anahtar" to anahtar, "nonce" to nonce, "sifreliVeEtiket" to girdi, "aad" to a,
        )["duz"] as ByteArray?
        assertArrayEquals(duz, coz(sifreliVeEtiket))
        val bozukEtiket = sifreliVeEtiket.copyOf().also {
            it[it.size - 1] = (it[it.size - 1].toInt() xor 1).toByte()
        }
        assertNull(coz(bozukEtiket))
        val bozukGovde = sifreliVeEtiket.copyOf().also { it[3] = (it[3].toInt() xor 1).toByte() }
        assertNull(coz(bozukGovde))
        assertNull(coz(sifreliVeEtiket, a = ByteArray(0)))
        assertNull(coz(ByteArray(5)))
    }

    // -------------------------------------------------------------------
    // Güvenlik kodu
    // -------------------------------------------------------------------

    @Test
    fun guvenlikKoduBilinenVektorVeIkiTaraftaEsit() {
        // libsignal NumericFingerprintGeneratorTest (sürüm 2).
        val aliceKimlik = hex("0506863bc66d02b40d27b8d49ca7c09e9239236f9d7d25d6fcca5ce13c7064d868")
        val bobKimlik = hex("05f781b6fb32fed9ba1cf2de978d4d5da28dc34046ae814402b5c0dbd96fda907b")
        val aliceId = "+14152222222".toByteArray()
        val bobId = "+14153333333".toByteArray()
        val a = cagir(
            "guvenlikKodu",
            "yerelKimlik" to aliceKimlik, "yerelTanimlayici" to aliceId,
            "karsiKimlik" to bobKimlik, "karsiTanimlayici" to bobId,
        )["kod"]
        val b = cagir(
            "guvenlikKodu",
            "yerelKimlik" to bobKimlik, "yerelTanimlayici" to bobId,
            "karsiKimlik" to aliceKimlik, "karsiTanimlayici" to aliceId,
        )["kod"]
        assertEquals("300354477692869396892869876765458257569162576843440918079131", a)
        assertEquals(a, b)

        val (alice, bob) = ikiCihaz()
        val x = cagir(
            "guvenlikKodu",
            "yerelKimlik" to alice.acik, "yerelTanimlayici" to aliceAd.toByteArray(),
            "karsiKimlik" to bob.acik, "karsiTanimlayici" to bobAd.toByteArray(),
        )["kod"] as String
        val y = cagir(
            "guvenlikKodu",
            "yerelKimlik" to bob.acik, "yerelTanimlayici" to bobAd.toByteArray(),
            "karsiKimlik" to alice.acik, "karsiTanimlayici" to aliceAd.toByteArray(),
        )["kod"]
        assertEquals(60, x.length)
        assertEquals(x, y)
    }

    @Test
    fun bilinmeyenYontemVeBicimHatasi() {
        hataBekle(SignalHatasiTuru.bilinmeyen) { cagir("yok") }
        hataBekle(SignalHatasiTuru.bilinmeyen) { cagir("imzaliOnAnahtarUret", "kimlik" to "metin", "id" to 1) }
        hataBekle(SignalHatasiTuru.gecersizAnahtar) {
            cagir("imzaliOnAnahtarUret", "kimlik" to ByteArray(10), "id" to 1)
        }
    }

    @Test
    fun hataMesajindaIcerikYok() {
        try {
            cagir("imzaliOnAnahtarUret", "kimlik" to ByteArray(10), "id" to 1)
            fail("hata bekleniyordu")
        } catch (e: SignalHatasi) {
            assertEquals(e.tur.name, e.message)
            assertNull(e.cause)
        }
    }

    // -------------------------------------------------------------------

    private fun hataBekle(tur: SignalHatasiTuru, blok: () -> Unit) {
        try {
            blok()
            fail("SignalHatasi($tur) bekleniyordu")
        } catch (e: SignalHatasi) {
            assertEquals(tur, e.tur)
        }
    }

    companion object {
        fun cagir(yontem: String, vararg arg: Pair<String, Any?>): Map<String, Any?> =
            SignalIslemleri.calistir(yontem, mapOf(*arg)).also { assertNotNull(it) }

        fun hex(s: String): ByteArray =
            ByteArray(s.length / 2) { s.substring(it * 2, it * 2 + 2).toInt(16).toByte() }
    }
}
