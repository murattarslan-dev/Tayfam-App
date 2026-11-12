package com.murattarslan.tayfam.e2e

import org.signal.libsignal.crypto.Aes256GcmDecryption
import org.signal.libsignal.crypto.Aes256GcmSiv
import org.signal.libsignal.protocol.DuplicateMessageException
import org.signal.libsignal.protocol.IdentityKey
import org.signal.libsignal.protocol.IdentityKeyPair
import org.signal.libsignal.protocol.InvalidKeyException
import org.signal.libsignal.protocol.InvalidKeyIdException
import org.signal.libsignal.protocol.InvalidMacException
import org.signal.libsignal.protocol.InvalidMessageException
import org.signal.libsignal.protocol.InvalidSessionException
import org.signal.libsignal.protocol.InvalidVersionException
import org.signal.libsignal.protocol.LegacyMessageException
import org.signal.libsignal.protocol.NoSessionException
import org.signal.libsignal.protocol.SessionBuilder
import org.signal.libsignal.protocol.SessionCipher
import org.signal.libsignal.protocol.SignalProtocolAddress
import org.signal.libsignal.protocol.UntrustedIdentityException
import org.signal.libsignal.protocol.ecc.ECKeyPair
import org.signal.libsignal.protocol.ecc.ECPublicKey
import org.signal.libsignal.protocol.fingerprint.NumericFingerprintGenerator
import org.signal.libsignal.protocol.kdf.HKDF
import org.signal.libsignal.protocol.kem.KEMKeyPair
import org.signal.libsignal.protocol.kem.KEMKeyType
import org.signal.libsignal.protocol.kem.KEMPublicKey
import org.signal.libsignal.protocol.message.CiphertextMessage
import org.signal.libsignal.protocol.message.PreKeySignalMessage
import org.signal.libsignal.protocol.message.SignalMessage
import org.signal.libsignal.protocol.state.IdentityKeyStore
import org.signal.libsignal.protocol.state.KyberPreKeyRecord
import org.signal.libsignal.protocol.state.KyberPreKeyStore
import org.signal.libsignal.protocol.state.PreKeyBundle
import org.signal.libsignal.protocol.state.PreKeyRecord
import org.signal.libsignal.protocol.state.PreKeyStore
import org.signal.libsignal.protocol.state.SessionRecord
import org.signal.libsignal.protocol.state.SessionStore
import org.signal.libsignal.protocol.state.SignedPreKeyRecord
import org.signal.libsignal.protocol.state.SignedPreKeyStore
import org.signal.libsignal.protocol.util.KeyHelper

/**
 * Signal motorunun hata türleri. Adlar Dart'taki `SignalHatasiTuru` ile
 * birebir aynıdır; kanal hata kodu olarak gider.
 */
enum class SignalHatasiTuru {
    gecersizMesaj,
    eskiMesaj,
    oturumYok,
    gecersizAnahtar,
    bilinmeyen,
}

/** Köprünün tek hata türü. Mesajında anahtar ya da içerik yoktur. */
class SignalHatasi(val tur: SignalHatasiTuru) : Exception(tur.name)

/**
 * Durumsuz Signal işlemleri (ADR-0010, güncelleme 2026-11-11).
 *
 * Her çağrı gelen serileştirilmiş kayıtlardan bellek içi bir depo kurar,
 * işlemi libsignal ile yapar, değişen kayıtları döner ve depoyu atar.
 * Hiçbir şey saklanmaz ve log'lanmaz; libsignal'in kendi log'u da
 * açılmaz (`SignalProtocolLoggerProvider` kurulmaz).
 *
 * Girdi ve çıktı, Flutter'ın `StandardMessageCodec`'inin taşıdığı
 * biçimdedir: `Map<String, Any?>`, `ByteArray`, `Int`/`Long`, `List`.
 * Platform kanalından bağımsızdır; JVM birim testleri doğrudan çağırır.
 */
object SignalIslemleri {
    private const val EN_BUYUK_ON_ANAHTAR_ID = 0xFFFFFF
    private const val GUVENLIK_KODU_YINELEME = 5200
    private const val GUVENLIK_KODU_SURUMU = 2
    private const val GCM_ETIKET = 16

    /** [yontem]'i [arg] ile çalıştırır; hata olursa yalnızca [SignalHatasi]. */
    fun calistir(yontem: String, arg: Map<String, Any?>): Map<String, Any?> =
        try {
            yonlendir(yontem, arg)
        } catch (e: SignalHatasi) {
            throw e
        } catch (e: DuplicateMessageException) {
            throw SignalHatasi(SignalHatasiTuru.eskiMesaj)
        } catch (e: InvalidMessageException) {
            throw SignalHatasi(SignalHatasiTuru.gecersizMesaj)
        } catch (e: InvalidMacException) {
            throw SignalHatasi(SignalHatasiTuru.gecersizMesaj)
        } catch (e: InvalidVersionException) {
            throw SignalHatasi(SignalHatasiTuru.gecersizMesaj)
        } catch (e: LegacyMessageException) {
            throw SignalHatasi(SignalHatasiTuru.gecersizMesaj)
        } catch (e: NoSessionException) {
            throw SignalHatasi(SignalHatasiTuru.oturumYok)
        } catch (e: InvalidSessionException) {
            throw SignalHatasi(SignalHatasiTuru.oturumYok)
        } catch (e: InvalidKeyIdException) {
            throw SignalHatasi(SignalHatasiTuru.gecersizAnahtar)
        } catch (e: InvalidKeyException) {
            throw SignalHatasi(SignalHatasiTuru.gecersizAnahtar)
        } catch (e: UntrustedIdentityException) {
            // Köprü kimliği her zaman güvenilir sayar; buraya gelmemeli.
            throw SignalHatasi(SignalHatasiTuru.gecersizAnahtar)
        } catch (e: IllegalArgumentException) {
            throw SignalHatasi(SignalHatasiTuru.gecersizAnahtar)
        } catch (e: Exception) {
            throw SignalHatasi(SignalHatasiTuru.bilinmeyen)
        }

    private fun yonlendir(yontem: String, a: Map<String, Any?>): Map<String, Any?> =
        when (yontem) {
            "kimlikUret" -> kimlikUret()
            "onAnahtarUret" -> onAnahtarUret(a.tam("baslangicId"), a.tam("adet"))
            "imzaliOnAnahtarUret" -> imzaliOnAnahtarUret(a.bayt("kimlik"), a.tam("id"))
            "kyberOnAnahtarUret" -> kyberOnAnahtarUret(a.bayt("kimlik"), a.tam("id"))
            "paketIsle" -> paketIsle(a)
            "sifrele" -> sifrele(a)
            "onAnahtarMesajiIncele" -> onAnahtarMesajiIncele(a.bayt("sifreli"))
            "coz" -> coz(a)
            "hkdf" -> hkdf(a)
            "aesGcmSivSifrele" -> aesGcmSivSifrele(a)
            "aesGcmSivCoz" -> aesGcmSivCoz(a)
            "aes256GcmCoz" -> aes256GcmCoz(a)
            "guvenlikKodu" -> guvenlikKodu(a)
            else -> throw SignalHatasi(SignalHatasiTuru.bilinmeyen)
        }

    // -------------------------------------------------------------------
    // Anahtar üretimi
    // -------------------------------------------------------------------

    private fun kimlikUret(): Map<String, Any?> {
        val cift = IdentityKeyPair.generate()
        return mapOf(
            "kayit" to cift.serialize(),
            "acik" to cift.publicKey.serialize(),
            "kayitKimligi" to KeyHelper.generateRegistrationId(false),
        )
    }

    private fun onAnahtarUret(baslangicId: Int, adet: Int): Map<String, Any?> {
        if (adet < 0 || adet > 1000) throw SignalHatasi(SignalHatasiTuru.bilinmeyen)
        var id = baslangicId
        val liste = ArrayList<Map<String, Any?>>(adet)
        repeat(adet) {
            if (id < 1 || id > EN_BUYUK_ON_ANAHTAR_ID) id = 1
            val cift = ECKeyPair.generate()
            val kayit = PreKeyRecord(id, cift)
            liste.add(
                mapOf(
                    "id" to id,
                    "kayit" to kayit.serialize(),
                    "acik" to cift.publicKey.serialize(),
                ),
            )
            id++
        }
        return mapOf("anahtarlar" to liste)
    }

    private fun imzaliOnAnahtarUret(kimlik: ByteArray, id: Int): Map<String, Any?> {
        val kimlikCifti = IdentityKeyPair(kimlik)
        val cift = ECKeyPair.generate()
        val acik = cift.publicKey.serialize()
        val imza = kimlikCifti.privateKey.calculateSignature(acik)
        val zaman = System.currentTimeMillis()
        val kayit = SignedPreKeyRecord(id, zaman, cift, imza)
        return mapOf(
            "id" to id,
            "kayit" to kayit.serialize(),
            "acik" to acik,
            "imza" to imza,
            "zaman" to zaman,
        )
    }

    private fun kyberOnAnahtarUret(kimlik: ByteArray, id: Int): Map<String, Any?> {
        val kimlikCifti = IdentityKeyPair(kimlik)
        val cift = KEMKeyPair.generate(KEMKeyType.KYBER_1024)
        val acik = cift.publicKey.serialize()
        val imza = kimlikCifti.privateKey.calculateSignature(acik)
        val kayit = KyberPreKeyRecord(id, System.currentTimeMillis(), cift, imza)
        return mapOf(
            "id" to id,
            "kayit" to kayit.serialize(),
            "acik" to acik,
            "imza" to imza,
        )
    }

    // -------------------------------------------------------------------
    // Oturum
    // -------------------------------------------------------------------

    private fun paketIsle(a: Map<String, Any?>): Map<String, Any?> {
        val depo = TekCagriDeposu(a.bayt("kimlik"), a.tam("kayitKimligi"))
        val yerel = a.adres("yerelAd", "yerelCihaz")
        val karsi = a.adres("ad", "cihaz")
        a.baytVeyaNull("oturum")?.let { depo.oturumYukle(karsi, it) }
        val p = a.harita("paket")
        val onAnahtarId = p.tamVeyaNull("onAnahtarId")
        val onAnahtar = p.baytVeyaNull("onAnahtar")
        if ((onAnahtarId == null) != (onAnahtar == null)) {
            throw SignalHatasi(SignalHatasiTuru.gecersizAnahtar)
        }
        val paket = PreKeyBundle(
            p.tam("kayitKimligi"),
            p.tam("cihazNo"),
            onAnahtarId ?: PreKeyBundle.NULL_PRE_KEY_ID,
            onAnahtar?.let { ECPublicKey(it) },
            p.tam("imzaliOnAnahtarId"),
            ECPublicKey(p.bayt("imzaliOnAnahtar")),
            p.bayt("imzaliOnAnahtarImzasi"),
            IdentityKey(p.bayt("kimlikAnahtari")),
            p.tam("kyberOnAnahtarId"),
            KEMPublicKey(p.bayt("kyberOnAnahtar")),
            p.bayt("kyberOnAnahtarImzasi"),
        )
        SessionBuilder(depo, depo, depo, depo, karsi, yerel).process(paket)
        return mapOf("oturum" to depo.oturumBaytlari(karsi))
    }

    private fun sifrele(a: Map<String, Any?>): Map<String, Any?> {
        val depo = TekCagriDeposu(a.bayt("kimlik"), a.tam("kayitKimligi"))
        val yerel = a.adres("yerelAd", "yerelCihaz")
        val karsi = a.adres("ad", "cihaz")
        depo.oturumYukle(karsi, a.bayt("oturum"))
        val mesaj = SessionCipher(depo, depo, depo, depo, depo, yerel, karsi)
            .encrypt(a.bayt("duz"))
        val tur = when (mesaj.type) {
            CiphertextMessage.PREKEY_TYPE -> 3
            CiphertextMessage.WHISPER_TYPE -> 2
            else -> throw SignalHatasi(SignalHatasiTuru.bilinmeyen)
        }
        return mapOf(
            "tur" to tur,
            "sifreli" to mesaj.serialize(),
            "oturum" to depo.oturumBaytlari(karsi),
        )
    }

    private fun onAnahtarMesajiIncele(sifreli: ByteArray): Map<String, Any?> {
        val m = PreKeySignalMessage(sifreli)
        return mapOf(
            "onAnahtarId" to m.preKeyId.orElse(null),
            "imzaliId" to m.signedPreKeyId,
            "gondericiKimligi" to m.identityKey.serialize(),
            "kayitKimligi" to m.registrationId,
            "tabanAnahtar" to m.baseKey.serialize(),
        )
    }

    private fun coz(a: Map<String, Any?>): Map<String, Any?> {
        val depo = TekCagriDeposu(a.bayt("kimlik"), a.tam("kayitKimligi"))
        val yerel = a.adres("yerelAd", "yerelCihaz")
        val karsi = a.adres("ad", "cihaz")
        val oturum = a.baytVeyaNull("oturum")
        oturum?.let { depo.oturumYukle(karsi, it) }
        val sifreli = a.bayt("sifreli")
        val sifreleyici = SessionCipher(depo, depo, depo, depo, depo, yerel, karsi)
        val duz = when (a.tam("tur")) {
            CiphertextMessage.PREKEY_TYPE -> {
                a.baytVeyaNull("onAnahtar")?.let { depo.onAnahtarEkle(PreKeyRecord(it)) }
                a.baytVeyaNull("imzaliOnAnahtar")?.let {
                    depo.imzaliOnAnahtarEkle(SignedPreKeyRecord(it))
                }
                for (k in a.liste("kyberOnAnahtarlari")) {
                    depo.kyberOnAnahtarEkle(KyberPreKeyRecord(k as ByteArray))
                }
                sifreleyici.decrypt(PreKeySignalMessage(sifreli))
            }
            CiphertextMessage.WHISPER_TYPE -> {
                if (oturum == null) throw SignalHatasi(SignalHatasiTuru.oturumYok)
                sifreleyici.decrypt(SignalMessage(sifreli))
            }
            else -> throw SignalHatasi(SignalHatasiTuru.gecersizMesaj)
        }
        val yeniOturum = depo.oturumKaydi(karsi)
            ?: throw SignalHatasi(SignalHatasiTuru.oturumYok)
        val kyber = depo.kyberKullanimi
        return mapOf(
            "duz" to duz,
            "oturum" to yeniOturum.serialize(),
            "onAnahtarId" to depo.silinenOnAnahtar,
            "imzaliId" to kyber?.imzaliId,
            "kyberId" to kyber?.kyberId,
            "kyberTaban" to kyber?.tabanAnahtar,
            "karsiKimlik" to yeniOturum.remoteIdentityKey.serialize(),
        )
    }

    // -------------------------------------------------------------------
    // Simetrik yapı taşları
    // -------------------------------------------------------------------

    private fun hkdf(a: Map<String, Any?>): Map<String, Any?> {
        val uzunluk = a.tam("uzunluk")
        if (uzunluk < 1 || uzunluk > 255 * 32) throw SignalHatasi(SignalHatasiTuru.bilinmeyen)
        val tuz = a.baytVeyaNull("tuz")
        val cikti = if (tuz == null) {
            HKDF.deriveSecrets(a.bayt("girdi"), a.bayt("bilgi"), uzunluk)
        } else {
            HKDF.deriveSecrets(a.bayt("girdi"), tuz, a.bayt("bilgi"), uzunluk)
        }
        return mapOf("cikti" to cikti)
    }

    private fun aesGcmSivSifrele(a: Map<String, Any?>): Map<String, Any?> {
        val nonce = a.bayt("nonce")
        if (nonce.size != 12) throw SignalHatasi(SignalHatasiTuru.gecersizAnahtar)
        val sifreli = Aes256GcmSiv(a.bayt("anahtar")).encrypt(a.bayt("duz"), nonce, a.bayt("aad"))
        return mapOf("sifreli" to sifreli)
    }

    private fun aesGcmSivCoz(a: Map<String, Any?>): Map<String, Any?> {
        val nonce = a.bayt("nonce")
        if (nonce.size != 12) throw SignalHatasi(SignalHatasiTuru.gecersizAnahtar)
        val siv = Aes256GcmSiv(a.bayt("anahtar"))
        val duz = try {
            siv.decrypt(a.bayt("sifreli"), nonce, a.bayt("aad"))
        } catch (e: InvalidMessageException) {
            null
        }
        return mapOf("duz" to duz)
    }

    /**
     * AES-256-GCM çözme. Düz metin, etiket doğrulanmadan dışarı çıkmaz:
     * doğrulama başarısızsa ara tampon sıfırlanır ve `null` döner.
     */
    private fun aes256GcmCoz(a: Map<String, Any?>): Map<String, Any?> {
        val anahtar = a.bayt("anahtar")
        val nonce = a.bayt("nonce")
        if (anahtar.size != 32 || nonce.size != 12) {
            throw SignalHatasi(SignalHatasiTuru.gecersizAnahtar)
        }
        val girdi = a.bayt("sifreliVeEtiket")
        if (girdi.size < GCM_ETIKET) return mapOf("duz" to null)
        val govdeBoyu = girdi.size - GCM_ETIKET
        val tampon = girdi.copyOf(govdeBoyu)
        val etiket = girdi.copyOfRange(govdeBoyu, girdi.size)
        val cozucu = Aes256GcmDecryption(anahtar, nonce, a.bayt("aad"))
        cozucu.decrypt(tampon)
        return if (cozucu.verifyTag(etiket)) {
            mapOf("duz" to tampon)
        } else {
            tampon.fill(0)
            mapOf("duz" to null)
        }
    }

    // -------------------------------------------------------------------
    // Güvenlik kodu
    // -------------------------------------------------------------------

    private fun guvenlikKodu(a: Map<String, Any?>): Map<String, Any?> {
        val parmakIzi = NumericFingerprintGenerator(GUVENLIK_KODU_YINELEME).createFor(
            GUVENLIK_KODU_SURUMU,
            a.bayt("yerelTanimlayici"),
            IdentityKey(a.bayt("yerelKimlik")),
            a.bayt("karsiTanimlayici"),
            IdentityKey(a.bayt("karsiKimlik")),
        )
        return mapOf("kod" to parmakIzi.displayableFingerprint.displayText)
    }

    // -------------------------------------------------------------------
    // Girdi okuma (biçim hatası → bilinmeyen; içerik hata mesajına girmez)
    // -------------------------------------------------------------------

    private fun Map<String, Any?>.bayt(ad: String): ByteArray =
        this[ad] as? ByteArray ?: throw SignalHatasi(SignalHatasiTuru.bilinmeyen)

    private fun Map<String, Any?>.baytVeyaNull(ad: String): ByteArray? =
        when (val d = this[ad]) {
            null -> null
            is ByteArray -> d
            else -> throw SignalHatasi(SignalHatasiTuru.bilinmeyen)
        }

    private fun Map<String, Any?>.tam(ad: String): Int =
        tamVeyaNull(ad) ?: throw SignalHatasi(SignalHatasiTuru.bilinmeyen)

    private fun Map<String, Any?>.tamVeyaNull(ad: String): Int? =
        when (val d = this[ad]) {
            null -> null
            is Int -> d
            is Long -> if (d in Int.MIN_VALUE..Int.MAX_VALUE) d.toInt() else
                throw SignalHatasi(SignalHatasiTuru.bilinmeyen)
            else -> throw SignalHatasi(SignalHatasiTuru.bilinmeyen)
        }

    @Suppress("UNCHECKED_CAST")
    private fun Map<String, Any?>.harita(ad: String): Map<String, Any?> =
        this[ad] as? Map<String, Any?> ?: throw SignalHatasi(SignalHatasiTuru.bilinmeyen)

    private fun Map<String, Any?>.liste(ad: String): List<Any?> =
        when (val d = this[ad]) {
            null -> emptyList()
            is List<*> -> d
            else -> throw SignalHatasi(SignalHatasiTuru.bilinmeyen)
        }

    private fun Map<String, Any?>.adres(adAlani: String, cihazAlani: String): SignalProtocolAddress {
        val ad = this[adAlani] as? String ?: throw SignalHatasi(SignalHatasiTuru.bilinmeyen)
        val cihaz = tam(cihazAlani)
        if (cihaz < 1 || cihaz > 127) throw SignalHatasi(SignalHatasiTuru.bilinmeyen)
        return SignalProtocolAddress(ad, cihaz)
    }
}

/** Son çare Kyber tekrar denetimi için libsignal'in bildirdiği kullanım. */
class KyberKullanimi(val kyberId: Int, val imzaliId: Int, val tabanAnahtar: ByteArray)

/**
 * Tek çağrılık bellek içi depo. Kimliği her zaman güvenilir sayar (TOFU
 * Dart'ta); tüketilen ön anahtarları ve Kyber kullanımını kaydeder.
 */
internal class TekCagriDeposu(kimlik: ByteArray, private val kayitKimligi: Int) :
    IdentityKeyStore, SessionStore, PreKeyStore, SignedPreKeyStore, KyberPreKeyStore {

    private val kimlikCifti = IdentityKeyPair(kimlik)
    private val oturumlar = HashMap<SignalProtocolAddress, ByteArray>()
    private val onAnahtarlar = HashMap<Int, PreKeyRecord>()
    private val imzaliOnAnahtarlar = HashMap<Int, SignedPreKeyRecord>()
    private val kyberOnAnahtarlar = HashMap<Int, KyberPreKeyRecord>()

    var silinenOnAnahtar: Int? = null
        private set
    var kyberKullanimi: KyberKullanimi? = null
        private set

    fun oturumYukle(adres: SignalProtocolAddress, kayit: ByteArray) {
        // Ayrıştırılabildiğini doğrula.
        SessionRecord(kayit)
        oturumlar[adres] = kayit
    }

    fun oturumKaydi(adres: SignalProtocolAddress): SessionRecord? =
        oturumlar[adres]?.let { SessionRecord(it) }

    fun oturumBaytlari(adres: SignalProtocolAddress): ByteArray =
        oturumlar[adres] ?: throw SignalHatasi(SignalHatasiTuru.oturumYok)

    fun onAnahtarEkle(k: PreKeyRecord) { onAnahtarlar[k.id] = k }
    fun imzaliOnAnahtarEkle(k: SignedPreKeyRecord) { imzaliOnAnahtarlar[k.id] = k }
    fun kyberOnAnahtarEkle(k: KyberPreKeyRecord) { kyberOnAnahtarlar[k.id] = k }

    // IdentityKeyStore
    override fun getIdentityKeyPair(): IdentityKeyPair = kimlikCifti
    override fun getLocalRegistrationId(): Int = kayitKimligi
    override fun saveIdentity(
        address: SignalProtocolAddress,
        identityKey: IdentityKey,
    ): IdentityKeyStore.IdentityChange = IdentityKeyStore.IdentityChange.NEW_OR_UNCHANGED
    override fun isTrustedIdentity(
        address: SignalProtocolAddress,
        identityKey: IdentityKey,
        direction: IdentityKeyStore.Direction,
    ): Boolean = true
    override fun getIdentity(address: SignalProtocolAddress): IdentityKey? = null

    // SessionStore
    override fun loadSession(address: SignalProtocolAddress): SessionRecord? = oturumKaydi(address)
    override fun loadExistingSessions(addresses: List<SignalProtocolAddress>): List<SessionRecord> =
        addresses.map {
            oturumKaydi(it) ?: throw NoSessionException(it, "oturum yok")
        }
    override fun getSubDeviceSessions(name: String): List<Int> = emptyList()
    override fun storeSession(address: SignalProtocolAddress, record: SessionRecord) {
        oturumlar[address] = record.serialize()
    }
    override fun containsSession(address: SignalProtocolAddress): Boolean =
        oturumlar.containsKey(address)
    override fun deleteSession(address: SignalProtocolAddress) { oturumlar.remove(address) }
    override fun deleteAllSessions(name: String) {
        oturumlar.keys.removeAll { it.name == name }
    }

    // PreKeyStore
    override fun loadPreKey(preKeyId: Int): PreKeyRecord =
        onAnahtarlar[preKeyId] ?: throw InvalidKeyIdException("ön anahtar yok")
    override fun storePreKey(preKeyId: Int, record: PreKeyRecord) { onAnahtarlar[preKeyId] = record }
    override fun containsPreKey(preKeyId: Int): Boolean = onAnahtarlar.containsKey(preKeyId)
    override fun removePreKey(preKeyId: Int) {
        onAnahtarlar.remove(preKeyId)
        silinenOnAnahtar = preKeyId
    }

    // SignedPreKeyStore
    override fun loadSignedPreKey(signedPreKeyId: Int): SignedPreKeyRecord =
        imzaliOnAnahtarlar[signedPreKeyId] ?: throw InvalidKeyIdException("imzalı ön anahtar yok")
    override fun loadSignedPreKeys(): List<SignedPreKeyRecord> = imzaliOnAnahtarlar.values.toList()
    override fun storeSignedPreKey(signedPreKeyId: Int, record: SignedPreKeyRecord) {
        imzaliOnAnahtarlar[signedPreKeyId] = record
    }
    override fun containsSignedPreKey(signedPreKeyId: Int): Boolean =
        imzaliOnAnahtarlar.containsKey(signedPreKeyId)
    override fun removeSignedPreKey(signedPreKeyId: Int) { imzaliOnAnahtarlar.remove(signedPreKeyId) }

    // KyberPreKeyStore
    override fun loadKyberPreKey(kyberPreKeyId: Int): KyberPreKeyRecord =
        kyberOnAnahtarlar[kyberPreKeyId] ?: throw InvalidKeyIdException("Kyber ön anahtarı yok")
    override fun loadKyberPreKeys(): List<KyberPreKeyRecord> = kyberOnAnahtarlar.values.toList()
    override fun storeKyberPreKey(kyberPreKeyId: Int, record: KyberPreKeyRecord) {
        kyberOnAnahtarlar[kyberPreKeyId] = record
    }
    override fun containsKyberPreKey(kyberPreKeyId: Int): Boolean =
        kyberOnAnahtarlar.containsKey(kyberPreKeyId)

    /**
     * Tekrar denetimi Dart'tadır (son çare anahtarı hangisi, orada
     * bilinir): burada yalnızca libsignal'in bildirdiği üçlü kaydedilir.
     */
    override fun markKyberPreKeyUsed(kyberPreKeyId: Int, signedPreKeyId: Int, baseKey: ECPublicKey) {
        kyberKullanimi = KyberKullanimi(kyberPreKeyId, signedPreKeyId, baseKey.serialize())
    }
}
