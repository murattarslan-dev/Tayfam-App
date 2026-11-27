import Foundation
import LibSignalClient

/// Signal motorunun hata türleri. Adlar Dart'taki `SignalHatasiTuru` ve
/// Kotlin'deki `SignalHatasiTuru` ile birebir aynıdır; kanal hata kodu
/// olarak gider.
public enum SignalHatasiTuru: String, Sendable {
  case gecersizMesaj
  case eskiMesaj
  case oturumYok
  case gecersizAnahtar
  case bilinmeyen
}

/// Köprünün tek hata türü. Anahtar ya da içerik taşımaz.
public struct SignalHatasi: Error, Equatable, Sendable {
  public let tur: SignalHatasiTuru
  public init(_ tur: SignalHatasiTuru) { self.tur = tur }
}

/// Durumsuz Signal işlemleri: Android'deki `SignalIslemleri.kt`'nin iOS
/// karşılığı (istemci ADR-0010, ADR-0034 §7).
///
/// Her çağrı gelen serileştirilmiş kayıtlardan bellek içi bir depo kurar,
/// işlemi Signal'in resmi Swift paketi `LibSignalClient` ile yapar, değişen
/// kayıtları döner ve depoyu atar. Hiçbir şey saklanmaz ve log'lanmaz.
///
/// Girdi ve çıktı Flutter'a bağlı değildir: baytlar `Data`, tam sayılar
/// `Int`, eksik değer `NSNull` (ya da anahtarın hiç olmaması). Flutter
/// türlerine çeviri Runner'daki `SignalKoprusu`'ndadır; bu katman macOS'ta
/// ve iOS simülatöründe doğrudan test edilir. Yöntem adları ve alan adları
/// Kotlin köprüsüyle aynıdır; iki platform aynı Dart sözleşmesine cevap
/// verir.
public enum SignalIslemleri {
  static let enBuyukOnAnahtarId = 0xFF_FFFF
  static let guvenlikKoduYineleme = 5200
  static let guvenlikKoduSurumu = 2
  static let gcmEtiket = 16

  /// `yontem`'i `arg` ile çalıştırır; hata olursa yalnızca `SignalHatasi`.
  public static func calistir(_ yontem: String, _ arg: [String: Any]) throws -> [String: Any] {
    do {
      return try yonlendir(yontem, arg)
    } catch let hata as SignalHatasi {
      throw hata
    } catch let hata as SignalError {
      throw SignalHatasi(tur(hata, yontem: yontem))
    } catch {
      throw SignalHatasi(.bilinmeyen)
    }
  }

  /// Bozuk baytları mesaj olarak ayrıştıran yöntemler. Swift paketi
  /// ayrıştırma hatasını tek türle (`protobufError`) bildirir; Android'de
  /// bozuk mesaj `InvalidMessageException`, bozuk anahtar
  /// `InvalidKeyException`'dır. Aynı Dart sonucunu vermek için ayrım
  /// yönteme göre yapılır.
  static let mesajAyristiranYontemler: Set<String> = ["coz", "onAnahtarMesajiIncele"]

  /// libsignal hatası → köprü hata türü (Kotlin'deki istisna eşlemesiyle
  /// aynı sınıflar). Hata metni hiçbir yere taşınmaz.
  static func tur(_ hata: SignalError, yontem: String) -> SignalHatasiTuru {
    switch hata {
    case .duplicatedMessage:
      return .eskiMesaj
    case .protobufError:
      return mesajAyristiranYontemler.contains(yontem) ? .gecersizMesaj : .gecersizAnahtar
    case .invalidMessage, .legacyCiphertextVersion, .unknownCiphertextVersion,
      .unrecognizedMessageVersion:
      return .gecersizMesaj
    case .sessionNotFound, .invalidSession:
      return .oturumYok
    case .invalidKeyIdentifier, .invalidKey, .invalidSignature, .untrustedIdentity,
      .invalidArgument:
      return .gecersizAnahtar
    default:
      return .bilinmeyen
    }
  }

  private static func yonlendir(_ yontem: String, _ a: [String: Any]) throws -> [String: Any] {
    switch yontem {
    case "kimlikUret": return kimlikUret()
    case "onAnahtarUret": return try onAnahtarUret(baslangicId: a.tam("baslangicId"), adet: a.tam("adet"))
    case "imzaliOnAnahtarUret": return try imzaliOnAnahtarUret(kimlik: a.bayt("kimlik"), id: a.tam("id"))
    case "kyberOnAnahtarUret": return try kyberOnAnahtarUret(kimlik: a.bayt("kimlik"), id: a.tam("id"))
    case "paketIsle": return try paketIsle(a)
    case "sifrele": return try sifrele(a)
    case "onAnahtarMesajiIncele": return try onAnahtarMesajiIncele(a.bayt("sifreli"))
    case "coz": return try coz(a)
    case "hkdf": return try hkdfTuret(a)
    case "aesGcmSivSifrele": return try aesGcmSivSifrele(a)
    case "aesGcmSivCoz": return try aesGcmSivCoz(a)
    case "aes256GcmSifrele": return try aes256GcmSifrele(a)
    case "aes256GcmCoz": return try aes256GcmCoz(a)
    case "guvenlikKodu": return try guvenlikKodu(a)
    default: throw SignalHatasi(.bilinmeyen)
    }
  }

  // MARK: - Anahtar üretimi

  private static func kimlikUret() -> [String: Any] {
    let cift = IdentityKeyPair.generate()
    return [
      "kayit": cift.serialize(),
      "acik": cift.identityKey.serialize(),
      // libsignal-android `KeyHelper.generateRegistrationId(false)` ile aynı
      // aralık; `random(in:)` sistemin CSPRNG'sini kullanır.
      "kayitKimligi": Int.random(in: 1...16380),
    ]
  }

  private static func onAnahtarUret(baslangicId: Int, adet: Int) throws -> [String: Any] {
    guard (0...1000).contains(adet) else { throw SignalHatasi(.bilinmeyen) }
    var id = baslangicId
    var liste: [[String: Any]] = []
    liste.reserveCapacity(adet)
    for _ in 0..<adet {
      if id < 1 || id > enBuyukOnAnahtarId { id = 1 }
      let ozel = PrivateKey.generate()
      let kayit = try PreKeyRecord(id: UInt32(id), privateKey: ozel)
      liste.append([
        "id": id,
        "kayit": kayit.serialize(),
        "acik": ozel.publicKey.serialize(),
      ])
      id += 1
    }
    return ["anahtarlar": liste]
  }

  private static func imzaliOnAnahtarUret(kimlik: Data, id: Int) throws -> [String: Any] {
    let kimlikCifti = try IdentityKeyPair(bytes: kimlik)
    let ozel = PrivateKey.generate()
    let acik = ozel.publicKey.serialize()
    let imza = kimlikCifti.privateKey.generateSignature(message: acik)
    let zaman = simdiMs()
    let kayit = try SignedPreKeyRecord(
      id: try kimlikNo(id), timestamp: UInt64(zaman), privateKey: ozel, signature: imza)
    return [
      "id": id,
      "kayit": kayit.serialize(),
      "acik": acik,
      "imza": imza,
      "zaman": zaman,
    ]
  }

  private static func kyberOnAnahtarUret(kimlik: Data, id: Int) throws -> [String: Any] {
    let kimlikCifti = try IdentityKeyPair(bytes: kimlik)
    // libsignal'in tek KEM türü Kyber1024'tür (Android'deki KYBER_1024).
    let cift = KEMKeyPair.generate()
    let acik = cift.publicKey.serialize()
    let imza = kimlikCifti.privateKey.generateSignature(message: acik)
    let kayit = try KyberPreKeyRecord(
      id: try kimlikNo(id), timestamp: UInt64(simdiMs()), keyPair: cift, signature: imza)
    return [
      "id": id,
      "kayit": kayit.serialize(),
      "acik": acik,
      "imza": imza,
    ]
  }

  // MARK: - Oturum

  private static func paketIsle(_ a: [String: Any]) throws -> [String: Any] {
    let depo = try TekCagriDeposu(kimlik: a.bayt("kimlik"), kayitKimligi: a.tam("kayitKimligi"))
    let yerel = try a.adres("yerelAd", "yerelCihaz")
    let karsi = try a.adres("ad", "cihaz")
    if let oturum = try a.baytVeyaNil("oturum") { try depo.oturumYukle(karsi, oturum) }
    let p = try a.harita("paket")
    let onAnahtarId = try p.tamVeyaNil("onAnahtarId")
    let onAnahtar = try p.baytVeyaNil("onAnahtar")
    if (onAnahtarId == nil) != (onAnahtar == nil) { throw SignalHatasi(.gecersizAnahtar) }

    let kayitKimligi = try kimlikNo(p.tam("kayitKimligi"))
    let cihazNo = try kimlikNo(p.tam("cihazNo"))
    let imzaliId = try kimlikNo(p.tam("imzaliOnAnahtarId"))
    let imzali = try PublicKey(p.bayt("imzaliOnAnahtar"))
    let imzaliImza = try p.bayt("imzaliOnAnahtarImzasi")
    let kimlikAnahtari = try IdentityKey(bytes: p.bayt("kimlikAnahtari"))
    let kyberId = try kimlikNo(p.tam("kyberOnAnahtarId"))
    let kyber = try KEMPublicKey(p.bayt("kyberOnAnahtar"))
    let kyberImza = try p.bayt("kyberOnAnahtarImzasi")

    let paket: PreKeyBundle
    if let onAnahtarId = onAnahtarId, let onAnahtar = onAnahtar {
      paket = try PreKeyBundle(
        registrationId: kayitKimligi,
        deviceId: cihazNo,
        prekeyId: try kimlikNo(onAnahtarId),
        prekey: try PublicKey(onAnahtar),
        signedPrekeyId: imzaliId,
        signedPrekey: imzali,
        signedPrekeySignature: imzaliImza,
        identity: kimlikAnahtari,
        kyberPrekeyId: kyberId,
        kyberPrekey: kyber,
        kyberPrekeySignature: kyberImza)
    } else {
      paket = try PreKeyBundle(
        registrationId: kayitKimligi,
        deviceId: cihazNo,
        signedPrekeyId: imzaliId,
        signedPrekey: imzali,
        signedPrekeySignature: imzaliImza,
        identity: kimlikAnahtari,
        kyberPrekeyId: kyberId,
        kyberPrekey: kyber,
        kyberPrekeySignature: kyberImza)
    }
    try processPreKeyBundle(
      paket, for: karsi, ourAddress: yerel,
      sessionStore: depo, identityStore: depo, context: NullContext())
    return ["oturum": try depo.oturumBaytlari(karsi)]
  }

  private static func sifrele(_ a: [String: Any]) throws -> [String: Any] {
    let depo = try TekCagriDeposu(kimlik: a.bayt("kimlik"), kayitKimligi: a.tam("kayitKimligi"))
    let yerel = try a.adres("yerelAd", "yerelCihaz")
    let karsi = try a.adres("ad", "cihaz")
    try depo.oturumYukle(karsi, a.bayt("oturum"))
    let mesaj = try signalEncrypt(
      message: a.bayt("duz"), for: karsi, localAddress: yerel,
      sessionStore: depo, identityStore: depo, context: NullContext())
    let tur: Int
    switch mesaj.messageType {
    case .preKey: tur = 3
    case .whisper: tur = 2
    default: throw SignalHatasi(.bilinmeyen)
    }
    return [
      "tur": tur,
      "sifreli": mesaj.serialize(),
      "oturum": try depo.oturumBaytlari(karsi),
    ]
  }

  private static func onAnahtarMesajiIncele(_ sifreli: Data) throws -> [String: Any] {
    let m = try PreKeySignalMessage(bytes: sifreli)
    return [
      "onAnahtarId": (try m.preKeyId()).map { Int($0) as Any } ?? NSNull(),
      "imzaliId": Int(m.signedPreKeyId),
      "gondericiKimligi": m.identityKey.serialize(),
      "kayitKimligi": Int(try m.registrationId()),
      "tabanAnahtar": m.baseKey.serialize(),
    ]
  }

  private static func coz(_ a: [String: Any]) throws -> [String: Any] {
    let depo = try TekCagriDeposu(kimlik: a.bayt("kimlik"), kayitKimligi: a.tam("kayitKimligi"))
    let yerel = try a.adres("yerelAd", "yerelCihaz")
    let karsi = try a.adres("ad", "cihaz")
    let oturum = try a.baytVeyaNil("oturum")
    if let oturum = oturum { try depo.oturumYukle(karsi, oturum) }
    let sifreli = try a.bayt("sifreli")
    let duz: Data
    switch try a.tam("tur") {
    case 3:
      if let k = try a.baytVeyaNil("onAnahtar") { try depo.onAnahtarEkle(PreKeyRecord(bytes: k)) }
      if let k = try a.baytVeyaNil("imzaliOnAnahtar") {
        try depo.imzaliOnAnahtarEkle(SignedPreKeyRecord(bytes: k))
      }
      for k in try a.liste("kyberOnAnahtarlari") {
        guard let b = k as? Data else { throw SignalHatasi(.bilinmeyen) }
        try depo.kyberOnAnahtarEkle(KyberPreKeyRecord(bytes: b))
      }
      duz = try signalDecryptPreKey(
        message: PreKeySignalMessage(bytes: sifreli), from: karsi, localAddress: yerel,
        sessionStore: depo, identityStore: depo, preKeyStore: depo,
        signedPreKeyStore: depo, kyberPreKeyStore: depo, context: NullContext())
    case 2:
      guard oturum != nil else { throw SignalHatasi(.oturumYok) }
      duz = try signalDecrypt(
        message: SignalMessage(bytes: sifreli), from: karsi, to: yerel,
        sessionStore: depo, identityStore: depo, context: NullContext())
    default:
      throw SignalHatasi(.gecersizMesaj)
    }
    let yeniOturum = try depo.oturumBaytlari(karsi)
    // Android `SessionRecord.remoteIdentityKey` okur. Swift paketinde bu
    // erişim yok; libsignal her başarılı çözmeden sonra karşı kimliği
    // depoya bildirir (etkin oturumda `saveIdentity`, arşivlenmiş oturumda
    // `recordReceivedIdentity`; arşivden çözülen oturum etkin olur), yani
    // aynı değerdir.
    guard let karsiKimlik = depo.sonKarsiKimlik else { throw SignalHatasi(.oturumYok) }
    let kyber = depo.kyberKullanimi
    return [
      "duz": duz,
      "oturum": yeniOturum,
      "onAnahtarId": depo.silinenOnAnahtar.map { Int($0) as Any } ?? NSNull(),
      "imzaliId": kyber.map { Int($0.imzaliId) as Any } ?? NSNull(),
      "kyberId": kyber.map { Int($0.kyberId) as Any } ?? NSNull(),
      "kyberTaban": kyber.map { $0.tabanAnahtar as Any } ?? NSNull(),
      "karsiKimlik": karsiKimlik.serialize(),
    ]
  }

  // MARK: - Simetrik yapı taşları

  private static func hkdfTuret(_ a: [String: Any]) throws -> [String: Any] {
    let uzunluk = try a.tam("uzunluk")
    guard (1...(255 * 32)).contains(uzunluk) else { throw SignalHatasi(.bilinmeyen) }
    // Android'de tuzsuz `HKDF.deriveSecrets` boş tuz kullanır; aynısı.
    let tuz = try a.baytVeyaNil("tuz") ?? Data()
    let cikti = try hkdf(
      outputLength: uzunluk, inputKeyMaterial: a.bayt("girdi"), salt: tuz, info: a.bayt("bilgi"))
    return ["cikti": cikti]
  }

  private static func aesGcmSivSifrele(_ a: [String: Any]) throws -> [String: Any] {
    let nonce = try a.bayt("nonce")
    guard nonce.count == 12 else { throw SignalHatasi(.gecersizAnahtar) }
    let sifreli = try Aes256GcmSiv(key: a.bayt("anahtar"))
      .encrypt(a.bayt("duz"), nonce: nonce, associatedData: a.bayt("aad"))
    return ["sifreli": sifreli]
  }

  private static func aesGcmSivCoz(_ a: [String: Any]) throws -> [String: Any] {
    let nonce = try a.bayt("nonce")
    guard nonce.count == 12 else { throw SignalHatasi(.gecersizAnahtar) }
    let siv = try Aes256GcmSiv(key: a.bayt("anahtar"))
    let sifreli = try a.bayt("sifreli")
    let aad = try a.bayt("aad")
    do {
      return ["duz": try siv.decrypt(sifreli, nonce: nonce, associatedData: aad)]
    } catch SignalError.invalidMessage(_), SignalError.verificationFailed(_) {
      // Android'de `InvalidMessageException` → null; doğrulanamayan metin dönmez.
      return ["duz": NSNull()]
    }
  }

  /// AES-256-GCM şifreleme (birebir mesaj eki; istemci ADR-0028 §2).
  /// Dönüş: şifreli metin ‖ 16 bayt etiket. Anahtar ve nonce çağıranındır
  /// (Dart'ta `Random.secure()`); köprü hiçbir şey saklamaz.
  private static func aes256GcmSifrele(_ a: [String: Any]) throws -> [String: Any] {
    let anahtar = try a.bayt("anahtar")
    let nonce = try a.bayt("nonce")
    guard anahtar.count == 32, nonce.count == 12 else { throw SignalHatasi(.gecersizAnahtar) }
    var tampon = try a.bayt("duz")
    let sifreleyici = try Aes256GcmEncryption(
      key: anahtar, nonce: nonce, associatedData: a.bayt("aad"))
    try sifreleyici.encrypt(&tampon)
    tampon.append(try sifreleyici.computeTag())
    return ["sifreliVeEtiket": tampon]
  }

  /// AES-256-GCM çözme. Düz metin etiket doğrulanmadan dışarı çıkmaz:
  /// doğrulama başarısızsa ara tampon sıfırlanır ve `NSNull` döner.
  private static func aes256GcmCoz(_ a: [String: Any]) throws -> [String: Any] {
    let anahtar = try a.bayt("anahtar")
    let nonce = try a.bayt("nonce")
    guard anahtar.count == 32, nonce.count == 12 else { throw SignalHatasi(.gecersizAnahtar) }
    let girdi = try a.bayt("sifreliVeEtiket")
    guard girdi.count >= gcmEtiket else { return ["duz": NSNull()] }
    let govdeBoyu = girdi.count - gcmEtiket
    var tampon = Data(girdi.prefix(govdeBoyu))
    let etiket = Data(girdi.suffix(gcmEtiket))
    let cozucu = try Aes256GcmDecryption(key: anahtar, nonce: nonce, associatedData: a.bayt("aad"))
    try cozucu.decrypt(&tampon)
    if try cozucu.verifyTag(etiket) {
      return ["duz": tampon]
    }
    tampon.resetBytes(in: 0..<tampon.count)
    return ["duz": NSNull()]
  }

  // MARK: - Güvenlik kodu

  private static func guvenlikKodu(_ a: [String: Any]) throws -> [String: Any] {
    let parmakIzi = try NumericFingerprintGenerator(iterations: guvenlikKoduYineleme).create(
      version: guvenlikKoduSurumu,
      localIdentifier: a.bayt("yerelTanimlayici"),
      localKey: IdentityKey(bytes: a.bayt("yerelKimlik")).publicKey,
      remoteIdentifier: a.bayt("karsiTanimlayici"),
      remoteKey: IdentityKey(bytes: a.bayt("karsiKimlik")).publicKey)
    return ["kod": parmakIzi.displayable.formatted]
  }

  // MARK: - Yardımcılar

  private static func simdiMs() -> Int { Int(Date().timeIntervalSince1970 * 1000) }

  /// Kimlik ve sayaç alanları libsignal'de `UInt32`'dir; aralık dışı değer
  /// biçim hatasıdır.
  static func kimlikNo(_ deger: Int) throws -> UInt32 {
    guard let sonuc = UInt32(exactly: deger) else { throw SignalHatasi(.bilinmeyen) }
    return sonuc
  }
}

/// libsignal'in depo bağlamı; köprü bağlam taşımaz.
struct NullContext: StoreContext {}

/// Son çare Kyber tekrar denetimi için libsignal'in bildirdiği kullanım.
struct KyberKullanimi {
  let kyberId: UInt32
  let imzaliId: UInt32
  let tabanAnahtar: Data
}

/// Tek çağrılık bellek içi depo. Kimliği her zaman güvenilir sayar (TOFU
/// Dart'ta); tüketilen ön anahtarları, Kyber kullanımını ve son çözmede
/// görülen karşı kimliği kaydeder.
final class TekCagriDeposu: IdentityKeyStore, SessionStore, PreKeyStore, SignedPreKeyStore,
  KyberPreKeyStore
{
  private let kimlikCifti: IdentityKeyPair
  private let kayitKimligi: UInt32
  private var oturumlar: [ProtocolAddress: Data] = [:]
  private var onAnahtarlar: [UInt32: PreKeyRecord] = [:]
  private var imzaliOnAnahtarlar: [UInt32: SignedPreKeyRecord] = [:]
  private var kyberOnAnahtarlar: [UInt32: KyberPreKeyRecord] = [:]

  private(set) var silinenOnAnahtar: UInt32?
  private(set) var kyberKullanimi: KyberKullanimi?
  private(set) var sonKarsiKimlik: IdentityKey?

  init(kimlik: Data, kayitKimligi: Int) throws {
    kimlikCifti = try IdentityKeyPair(bytes: kimlik)
    self.kayitKimligi = try SignalIslemleri.kimlikNo(kayitKimligi)
  }

  func oturumYukle(_ adres: ProtocolAddress, _ kayit: Data) throws {
    // Ayrıştırılabildiğini doğrula.
    _ = try SessionRecord(bytes: kayit)
    oturumlar[adres] = kayit
  }

  func oturumBaytlari(_ adres: ProtocolAddress) throws -> Data {
    guard let kayit = oturumlar[adres] else { throw SignalHatasi(.oturumYok) }
    return kayit
  }

  func onAnahtarEkle(_ k: PreKeyRecord) { onAnahtarlar[k.id] = k }
  func imzaliOnAnahtarEkle(_ k: SignedPreKeyRecord) { imzaliOnAnahtarlar[k.id] = k }
  func kyberOnAnahtarEkle(_ k: KyberPreKeyRecord) { kyberOnAnahtarlar[k.id] = k }

  // IdentityKeyStore
  func identityKeyPair(context: StoreContext) throws -> IdentityKeyPair { kimlikCifti }
  func localRegistrationId(context: StoreContext) throws -> UInt32 { kayitKimligi }
  func saveIdentity(_ identity: IdentityKey, for address: ProtocolAddress, context: StoreContext)
    throws -> IdentityChange
  {
    sonKarsiKimlik = identity
    return .newOrUnchanged
  }
  func recordReceivedIdentity(
    _ identity: IdentityKey, for address: ProtocolAddress, context: StoreContext
  ) throws {
    sonKarsiKimlik = identity
  }
  func isTrustedIdentity(
    _ identity: IdentityKey, for address: ProtocolAddress, direction: Direction,
    context: StoreContext
  ) throws -> Bool { true }
  func identity(for address: ProtocolAddress, context: StoreContext) throws -> IdentityKey? { nil }

  // SessionStore
  func loadSession(for address: ProtocolAddress, context: StoreContext) throws -> SessionRecord? {
    try oturumlar[address].map { try SessionRecord(bytes: $0) }
  }
  func loadExistingSessions(for addresses: [ProtocolAddress], context: StoreContext) throws
    -> [SessionRecord]
  {
    try addresses.map { adres in
      guard let kayit = oturumlar[adres] else { throw SignalHatasi(.oturumYok) }
      return try SessionRecord(bytes: kayit)
    }
  }
  func storeSession(_ record: SessionRecord, for address: ProtocolAddress, context: StoreContext)
    throws
  {
    oturumlar[address] = record.serialize()
  }

  // PreKeyStore
  func loadPreKey(id: UInt32, context: StoreContext) throws -> PreKeyRecord {
    guard let k = onAnahtarlar[id] else { throw SignalHatasi(.gecersizAnahtar) }
    return k
  }
  func storePreKey(_ record: PreKeyRecord, id: UInt32, context: StoreContext) throws {
    onAnahtarlar[id] = record
  }
  func removePreKey(id: UInt32, context: StoreContext) throws {
    onAnahtarlar[id] = nil
    silinenOnAnahtar = id
  }

  // SignedPreKeyStore
  func loadSignedPreKey(id: UInt32, context: StoreContext) throws -> SignedPreKeyRecord {
    guard let k = imzaliOnAnahtarlar[id] else { throw SignalHatasi(.gecersizAnahtar) }
    return k
  }
  func storeSignedPreKey(_ record: SignedPreKeyRecord, id: UInt32, context: StoreContext) throws {
    imzaliOnAnahtarlar[id] = record
  }

  // KyberPreKeyStore
  func loadKyberPreKey(id: UInt32, context: StoreContext) throws -> KyberPreKeyRecord {
    guard let k = kyberOnAnahtarlar[id] else { throw SignalHatasi(.gecersizAnahtar) }
    return k
  }
  func storeKyberPreKey(_ record: KyberPreKeyRecord, id: UInt32, context: StoreContext) throws {
    kyberOnAnahtarlar[id] = record
  }
  /// Tekrar denetimi Dart'tadır (son çare anahtarı hangisi, orada bilinir):
  /// burada yalnızca libsignal'in bildirdiği üçlü kaydedilir.
  func markKyberPreKeyUsed(
    id: UInt32, signedPreKeyId: UInt32, baseKey: PublicKey, context: StoreContext
  ) throws {
    kyberKullanimi = KyberKullanimi(
      kyberId: id, imzaliId: signedPreKeyId, tabanAnahtar: baseKey.serialize())
  }
}

// MARK: - Girdi okuma (biçim hatası → bilinmeyen; içerik hata mesajına girmez)

extension Dictionary where Key == String, Value == Any {
  private func deger(_ ad: String) -> Any? {
    guard let d = self[ad], !(d is NSNull) else { return nil }
    return d
  }

  func bayt(_ ad: String) throws -> Data {
    guard let d = try baytVeyaNil(ad) else { throw SignalHatasi(.bilinmeyen) }
    return d
  }

  func baytVeyaNil(_ ad: String) throws -> Data? {
    guard let d = deger(ad) else { return nil }
    guard let b = d as? Data else { throw SignalHatasi(.bilinmeyen) }
    return b
  }

  func tam(_ ad: String) throws -> Int {
    guard let d = try tamVeyaNil(ad) else { throw SignalHatasi(.bilinmeyen) }
    return d
  }

  func tamVeyaNil(_ ad: String) throws -> Int? {
    guard let d = deger(ad) else { return nil }
    // Bool da NSNumber'dır ve `as? Int` ile 0/1'e döner; tam sayı beklenen
    // yerde kabul edilmez.
    if let n = d as? NSNumber, CFGetTypeID(n) == CFBooleanGetTypeID() {
      throw SignalHatasi(.bilinmeyen)
    }
    switch d {
    case let i as Int: return i
    case let i as Int32: return Int(i)
    case let i as Int64:
      guard let s = Int(exactly: i) else { throw SignalHatasi(.bilinmeyen) }
      return s
    case let n as NSNumber:
      guard let s = Int(exactly: n.doubleValue) else { throw SignalHatasi(.bilinmeyen) }
      return s
    default: throw SignalHatasi(.bilinmeyen)
    }
  }

  func harita(_ ad: String) throws -> [String: Any] {
    guard let d = deger(ad) as? [String: Any] else { throw SignalHatasi(.bilinmeyen) }
    return d
  }

  func liste(_ ad: String) throws -> [Any] {
    guard let d = deger(ad) else { return [] }
    guard let l = d as? [Any] else { throw SignalHatasi(.bilinmeyen) }
    return l
  }

  func adres(_ adAlani: String, _ cihazAlani: String) throws -> ProtocolAddress {
    guard let ad = deger(adAlani) as? String else { throw SignalHatasi(.bilinmeyen) }
    let cihaz = try tam(cihazAlani)
    guard (1...127).contains(cihaz) else { throw SignalHatasi(.bilinmeyen) }
    return try ProtocolAddress(name: ad, deviceId: UInt32(cihaz))
  }
}
