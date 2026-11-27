import Foundation
import XCTest

@testable import TayfamSignal

/// Android'deki `SignalIslemleriTest.kt`'nin iOS karşılığı: aynı senaryolar
/// ve aynı bilinen test vektörleri. İki platform aynı Dart sözleşmesine
/// aynı sonuçlarla cevap vermelidir.
final class SignalIslemleriTests: XCTestCase {

  // MARK: - Test cihazı (Dart tarafındaki güvenli deponun yerine geçer)

  private final class Cihaz {
    let ad: String
    let cihazNo: Int
    let kimlik: Data
    let acik: Data
    let kayitKimligi: Int
    var onAnahtarlar: [Int: Data] = [:]
    var onAnahtarAciklari: [Int: Data] = [:]
    var imzali: [String: Any] = [:]
    var kyberler: [Int: [String: Any]] = [:]
    var oturumlar: [String: Data] = [:]

    init(_ ad: String, _ cihazNo: Int) throws {
      self.ad = ad
      self.cihazNo = cihazNo
      let k = try cagir("kimlikUret")
      kimlik = k["kayit"] as! Data
      acik = k["acik"] as! Data
      kayitKimligi = k["kayitKimligi"] as! Int
    }

    func anahtarlariUret(onAnahtarBaslangic: Int = 100, onAnahtarAdet: Int = 3) throws {
      let liste = try cagir(
        "onAnahtarUret", ["baslangicId": onAnahtarBaslangic, "adet": onAnahtarAdet]
      )["anahtarlar"] as! [[String: Any]]
      for o in liste {
        onAnahtarlar[o["id"] as! Int] = (o["kayit"] as! Data)
        onAnahtarAciklari[o["id"] as! Int] = (o["acik"] as! Data)
      }
      imzali = try cagir("imzaliOnAnahtarUret", ["kimlik": kimlik, "id": 7])
      kyberler[50] = try cagir("kyberOnAnahtarUret", ["kimlik": kimlik, "id": 50])
      // Son çare Kyber anahtarı.
      kyberler[900] = try cagir("kyberOnAnahtarUret", ["kimlik": kimlik, "id": 900])
    }

    func paket(onAnahtarId: Int? = 100, kyberId: Int = 50) -> [String: Any] {
      [
        "kayitKimligi": kayitKimligi,
        "cihazNo": cihazNo,
        "onAnahtarId": onAnahtarId.map { $0 as Any } ?? NSNull(),
        "onAnahtar": onAnahtarId.map { onAnahtarAciklari[$0]! as Any } ?? NSNull(),
        "imzaliOnAnahtarId": imzali["id"]!,
        "imzaliOnAnahtar": imzali["acik"]!,
        "imzaliOnAnahtarImzasi": imzali["imza"]!,
        "kimlikAnahtari": acik,
        "kyberOnAnahtarId": kyberId,
        "kyberOnAnahtar": kyberler[kyberId]!["acik"]!,
        "kyberOnAnahtarImzasi": kyberler[kyberId]!["imza"]!,
      ]
    }

    private func ortak(_ karsi: Cihaz) -> [String: Any] {
      [
        "kimlik": kimlik,
        "kayitKimligi": kayitKimligi,
        "yerelAd": ad,
        "yerelCihaz": cihazNo,
        "ad": karsi.ad,
        "cihaz": karsi.cihazNo,
      ]
    }

    func paketIsle(_ karsi: Cihaz, _ paket: [String: Any]) throws {
      var arg = ortak(karsi)
      arg["oturum"] = oturumlar[karsi.ad] ?? NSNull()
      arg["paket"] = paket
      oturumlar[karsi.ad] = (try cagir("paketIsle", arg)["oturum"] as! Data)
    }

    func sifrele(_ karsi: Cihaz, _ metin: String) throws -> (Int, Data) {
      var arg = ortak(karsi)
      arg["oturum"] = oturumlar[karsi.ad] ?? NSNull()
      arg["duz"] = Data(metin.utf8)
      let s = try cagir("sifrele", arg)
      oturumlar[karsi.ad] = (s["oturum"] as! Data)
      return (s["tur"] as! Int, s["sifreli"] as! Data)
    }

    /// Dart'taki akış: tür 3 ise incele, gereken kayıtları ver, çöz, yaz.
    func coz(
      _ karsi: Cihaz, _ mesaj: (Int, Data), yerelAdOverride: String? = nil,
      kyberVer: Bool = true
    ) throws -> [String: Any] {
      var arg = ortak(karsi)
      if let o = yerelAdOverride { arg["yerelAd"] = o }
      arg["tur"] = mesaj.0
      arg["sifreli"] = mesaj.1
      arg["oturum"] = oturumlar[karsi.ad] ?? NSNull()
      if mesaj.0 == 3 {
        let bilgi = try cagir("onAnahtarMesajiIncele", ["sifreli": mesaj.1])
        if let id = bilgi["onAnahtarId"] as? Int, let k = onAnahtarlar[id] {
          arg["onAnahtar"] = k
        }
        XCTAssertEqual(imzali["id"] as? Int, bilgi["imzaliId"] as? Int)
        arg["imzaliOnAnahtar"] = imzali["kayit"]!
        arg["kyberOnAnahtarlari"] = kyberVer ? kyberler.values.map { $0["kayit"]! } : [Any]()
      }
      let s = try SignalIslemleri.calistir("coz", arg)
      // Durum ancak başarıdan sonra yazılır (ADR-0010 kalıcılık sırası).
      oturumlar[karsi.ad] = (s["oturum"] as! Data)
      if let id = s["onAnahtarId"] as? Int { onAnahtarlar[id] = nil }
      if let id = s["kyberId"] as? Int, id != 900 { kyberler[id] = nil }
      return s
    }
  }

  private static let aliceAd = "8f1c2b3a-4d5e-4f60-8a7b-9c0d1e2f3a4b"
  private static let bobAd = "1a2b3c4d-5e6f-4071-8293-a4b5c6d7e8f9"

  private func ikiCihaz() throws -> (Cihaz, Cihaz) {
    let alice = try Cihaz(Self.aliceAd, 1)
    let bob = try Cihaz(Self.bobAd, 2)
    try bob.anahtarlariUret()
    return (alice, bob)
  }

  private func metin(_ s: [String: Any]) -> String? {
    (s["duz"] as? Data).flatMap { String(data: $0, encoding: .utf8) }
  }

  private func bos(_ deger: Any?) -> Bool { deger == nil || deger is NSNull }

  // MARK: - Anahtar üretimi

  func testKimlikVeOnAnahtarlarUretilir() throws {
    let c = try Cihaz(Self.aliceAd, 1)
    XCTAssertEqual(c.acik.count, 33)
    XCTAssertTrue((1...16380).contains(c.kayitKimligi))

    let liste = try cagir("onAnahtarUret", ["baslangicId": 0xFF_FFFE, "adet": 3])["anahtarlar"]
      as! [[String: Any]]
    XCTAssertEqual(liste.map { $0["id"] as! Int }, [0xFF_FFFE, 0xFF_FFFF, 1])
    for o in liste { XCTAssertEqual((o["acik"] as! Data).count, 33) }

    let imzali = try cagir("imzaliOnAnahtarUret", ["kimlik": c.kimlik, "id": 3])
    XCTAssertEqual((imzali["imza"] as! Data).count, 64)
    XCTAssertTrue(imzali["zaman"] is Int)

    let kyber = try cagir("kyberOnAnahtarUret", ["kimlik": c.kimlik, "id": 4])
    XCTAssertEqual((kyber["acik"] as! Data).count, 1569)
    XCTAssertEqual((kyber["imza"] as! Data).count, 64)
  }

  // MARK: - Oturum, şifreleme, çözme

  func testIlkMesajCevapVeDurumsuzTur() throws {
    let (alice, bob) = try ikiCihaz()
    try alice.paketIsle(bob, bob.paket())

    let m1 = try alice.sifrele(bob, "merhaba")
    XCTAssertEqual(m1.0, 3)

    let bilgi = try cagir("onAnahtarMesajiIncele", ["sifreli": m1.1])
    XCTAssertEqual(bilgi["onAnahtarId"] as? Int, 100)
    XCTAssertEqual(bilgi["gondericiKimligi"] as? Data, alice.acik)
    XCTAssertEqual(bilgi["kayitKimligi"] as? Int, alice.kayitKimligi)

    let c1 = try bob.coz(alice, m1)
    XCTAssertEqual(metin(c1), "merhaba")
    XCTAssertEqual(c1["onAnahtarId"] as? Int, 100)
    XCTAssertEqual(c1["kyberId"] as? Int, 50)
    XCTAssertEqual(c1["imzaliId"] as? Int, 7)
    XCTAssertEqual(c1["kyberTaban"] as? Data, bilgi["tabanAnahtar"] as? Data)
    XCTAssertEqual(c1["karsiKimlik"] as? Data, alice.acik)
    XCTAssertNil(bob.onAnahtarlar[100])

    // Cevap: Bob'un bekleyen ön anahtar kurulumu yok → tür 2.
    let r1 = try bob.sifrele(alice, "selam")
    XCTAssertEqual(r1.0, 2)
    let cr1 = try alice.coz(bob, r1)
    XCTAssertEqual(metin(cr1), "selam")
    XCTAssertEqual(cr1["karsiKimlik"] as? Data, bob.acik)
    XCTAssertTrue(bos(cr1["onAnahtarId"]))
    XCTAssertTrue(bos(cr1["kyberId"]))

    // Alice cevabı aldıktan sonra tür 2 gönderir.
    let m2 = try alice.sifrele(bob, "nasılsın")
    XCTAssertEqual(m2.0, 2)
    XCTAssertEqual(metin(try bob.coz(alice, m2)), "nasılsın")
  }

  func testCokluVeSiraDisiMesaj() throws {
    let (alice, bob) = try ikiCihaz()
    try alice.paketIsle(bob, bob.paket())
    let m = try (1...3).map { try alice.sifrele(bob, "ilk\($0)") }
    for x in m { XCTAssertEqual(x.0, 3) }
    XCTAssertEqual(metin(try bob.coz(alice, m[2])), "ilk3")
    XCTAssertEqual(metin(try bob.coz(alice, m[0])), "ilk1")
    XCTAssertEqual(metin(try bob.coz(alice, m[1])), "ilk2")

    XCTAssertEqual(metin(try bob.coz(alice, try alice.sifrele(bob, "x"))), "x")
    _ = try alice.coz(bob, try bob.sifrele(alice, "cevap"))
    let n = try (1...5).map { try alice.sifrele(bob, "m\($0)") }
    for x in n { XCTAssertEqual(x.0, 2) }
    for i in [4, 0, 2, 1, 3] {
      XCTAssertEqual(metin(try bob.coz(alice, n[i])), "m\(i + 1)")
    }
  }

  func testTekrarEdilenMesajEskiMesajdir() throws {
    let (alice, bob) = try ikiCihaz()
    try alice.paketIsle(bob, bob.paket())
    _ = try bob.coz(alice, try alice.sifrele(bob, "a"))
    _ = try alice.coz(bob, try bob.sifrele(alice, "b"))
    let m = try alice.sifrele(bob, "c")
    _ = try bob.coz(alice, m)
    hataBekle(.eskiMesaj) { _ = try bob.coz(alice, m) }
  }

  func testBozukSifreliMetinGecersizMesajdir() throws {
    let (alice, bob) = try ikiCihaz()
    try alice.paketIsle(bob, bob.paket())
    _ = try bob.coz(alice, try alice.sifrele(bob, "a"))
    _ = try alice.coz(bob, try bob.sifrele(alice, "b"))
    let (tur, sifreli) = try alice.sifrele(bob, "c")
    var bozuk = sifreli
    bozuk[bozuk.count - 12] ^= 1
    let once = bob.oturumlar[Self.aliceAd]
    hataBekle(.gecersizMesaj) { _ = try bob.coz(alice, (tur, bozuk)) }
    // Hata durumunda durum değişmez.
    XCTAssertEqual(bob.oturumlar[Self.aliceAd], once)
    hataBekle(.gecersizMesaj) { _ = try bob.coz(alice, (2, Data(repeating: 7, count: 40))) }
    hataBekle(.gecersizMesaj) {
      _ = try cagir("onAnahtarMesajiIncele", ["sifreli": Data(count: 10)])
    }
    // Bozulmamış hâli hâlâ çözülür.
    XCTAssertEqual(metin(try bob.coz(alice, (tur, sifreli))), "c")
  }

  func testAdresBagiUyusmazsaGecersizMesaj() throws {
    let (alice, bob) = try ikiCihaz()
    try alice.paketIsle(bob, bob.paket())
    let m = try alice.sifrele(bob, "a")
    hataBekle(.gecersizMesaj) {
      _ = try bob.coz(alice, m, yerelAdOverride: "00000000-0000-4000-8000-000000000001")
    }
  }

  func testTekKullanimlikOnAnahtarsizPaket() throws {
    let (alice, bob) = try ikiCihaz()
    try alice.paketIsle(bob, bob.paket(onAnahtarId: nil))
    let m = try alice.sifrele(bob, "ön anahtarsız")
    let bilgi = try cagir("onAnahtarMesajiIncele", ["sifreli": m.1])
    XCTAssertTrue(bos(bilgi["onAnahtarId"]))
    let c = try bob.coz(alice, m)
    XCTAssertEqual(metin(c), "ön anahtarsız")
    XCTAssertTrue(bos(c["onAnahtarId"]))
    XCTAssertEqual(bob.onAnahtarlar.count, 3)
  }

  func testKyberZorunludur() throws {
    let (alice, bob) = try ikiCihaz()
    // Kyber alanları olmayan paket kabul edilmez.
    let kybersiz = bob.paket().filter { !$0.key.hasPrefix("kyber") }
    hataBekle(.bilinmeyen) { try alice.paketIsle(bob, kybersiz) }
    // Kyber imzası geçersiz paket kabul edilmez.
    var bozukImza = bob.paket()
    bozukImza["kyberOnAnahtarImzasi"] = Data(count: 64)
    hataBekle(.gecersizAnahtar) { try alice.paketIsle(bob, bozukImza) }
    // İmzalı ön anahtar imzası geçersiz paket kabul edilmez.
    var bozukEc = bob.paket()
    bozukEc["imzaliOnAnahtarImzasi"] = Data(count: 64)
    hataBekle(.gecersizAnahtar) { try alice.paketIsle(bob, bozukEc) }

    // Alıcı Kyber kaydını veremezse mesaj çözülmez.
    try alice.paketIsle(bob, bob.paket())
    let m = try alice.sifrele(bob, "a")
    hataBekle(.gecersizAnahtar) { _ = try bob.coz(alice, m, kyberVer: false) }
    XCTAssertEqual(metin(try bob.coz(alice, m)), "a")
  }

  func testSonCareKyberKullanimiBildirilir() throws {
    let (alice, bob) = try ikiCihaz()
    try alice.paketIsle(bob, bob.paket(kyberId: 900))
    let m = try alice.sifrele(bob, "son çare")
    let bobOnce = bob.onAnahtarlar
    let c1 = try bob.coz(alice, m)
    XCTAssertEqual(c1["kyberId"] as? Int, 900)
    XCTAssertEqual(c1["imzaliId"] as? Int, 7)
    XCTAssertNotNil(bob.kyberler[900])
    // Aynı mesaj, oturum silinmiş bir durumda yeniden oynatılırsa aynı
    // üçlü bildirilir; Dart bunu görülmüş küme ile reddeder.
    bob.oturumlar[Self.aliceAd] = nil
    bob.onAnahtarlar.merge(bobOnce) { $1 }
    let c2 = try bob.coz(alice, m)
    XCTAssertEqual(c2["kyberId"] as? Int, c1["kyberId"] as? Int)
    XCTAssertEqual(c2["imzaliId"] as? Int, c1["imzaliId"] as? Int)
    XCTAssertEqual(c2["kyberTaban"] as? Data, c1["kyberTaban"] as? Data)
  }

  func testOturumsuzSifrelemeVeCozmeOturumYok() throws {
    let (alice, bob) = try ikiCihaz()
    hataBekle(.bilinmeyen) { _ = try alice.sifrele(bob, "a") }
    hataBekle(.oturumYok) { _ = try bob.coz(alice, (2, Data(count: 60))) }
  }

  // MARK: - Simetrik yapı taşları (bilinen test vektörleri)

  func testHkdfRfc5869Vektorleri() throws {
    // RFC 5869 A.1
    let c1 = try cagir(
      "hkdf",
      [
        "girdi": hex("0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b"),
        "tuz": hex("000102030405060708090a0b0c"),
        "bilgi": hex("f0f1f2f3f4f5f6f7f8f9"),
        "uzunluk": 42,
      ])["cikti"] as! Data
    XCTAssertEqual(
      c1,
      hex("3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865"))
    // RFC 5869 A.3 (tuz ve bilgi boş)
    let c3 = try cagir(
      "hkdf",
      [
        "girdi": hex("0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b"),
        "tuz": NSNull(),
        "bilgi": Data(),
        "uzunluk": 42,
      ])["cikti"] as! Data
    XCTAssertEqual(
      c3,
      hex("8da4e775a563c18f715f802a063c5a31b8a11f5c5ee1879ec3454e5f3c738d2d9d201395faa4b61a96c8"))
  }

  func testAesGcmSivBilinenVektor() throws {
    let anahtar = hex("bae8e37fc83441b16034566b7a806c46bb91c3c5aedb64a6c590bc84d1a5e269")
    let nonce = hex("e4b47801afc0577e34699b9e")
    let aad = hex("874296d5cc1fd16132")
    let duz = hex("671fdd4fbdc66f146545fc880c94a95198")
    let sifreli = try cagir(
      "aesGcmSivSifrele", ["anahtar": anahtar, "nonce": nonce, "duz": duz, "aad": aad]
    )["sifreli"] as! Data
    XCTAssertEqual(sifreli, hex("9209cfae7372e0a3ec2e5d072d5e26b7b9f3acb73908e54cddf7be1864914e13cf"))
    let geri = try cagir(
      "aesGcmSivCoz", ["anahtar": anahtar, "nonce": nonce, "sifreli": sifreli, "aad": aad]
    )["duz"] as? Data
    XCTAssertEqual(geri, duz)
    var bozuk = sifreli
    bozuk[0] ^= 1
    XCTAssertTrue(
      bos(
        try cagir(
          "aesGcmSivCoz", ["anahtar": anahtar, "nonce": nonce, "sifreli": bozuk, "aad": aad]
        )["duz"]))
    hataBekle(.gecersizAnahtar) {
      _ = try cagir(
        "aesGcmSivSifrele",
        ["anahtar": Data(count: 16), "nonce": nonce, "duz": duz, "aad": aad])
    }
  }

  private let gcmAnahtar = hex("feffe9928665731c6d6a8f9467308308feffe9928665731c6d6a8f9467308308")
  private let gcmNonce = hex("cafebabefacedbaddecaf888")
  private let gcmAad = hex("feedfacedeadbeeffeedfacedeadbeefabaddad2")
  private let gcmDuz = hex(
    "d9313225f88406e5a55909c5aff5269a86a7a9531534f7da2e4c303d8a318a72"
      + "1c3c0c95956809532fcf0e2449a6b525b16aedf5aa0de657ba637b39")
  private let gcmSifreliVeEtiket = hex(
    "522dc1f099567d07f47f37a32a84427d643a8cdcbfe5c0c97598a2bd2555d1aa"
      + "8cb08e48590dbb3da7b08b1056828838c5f61e6393ba7a0abcc9f662"
      + "76fc6ece0f4e1768cddf8853bb2d551b")

  private func gcmCoz(_ girdi: Data, aad: Data? = nil) throws -> Data? {
    try cagir(
      "aes256GcmCoz",
      [
        "anahtar": gcmAnahtar, "nonce": gcmNonce, "sifreliVeEtiket": girdi,
        "aad": aad ?? gcmAad,
      ])["duz"] as? Data
  }

  func testAes256GcmNistVektoru() throws {
    // NIST GCM spesifikasyonu (McGrew–Viega) Test Case 16.
    XCTAssertEqual(try gcmCoz(gcmSifreliVeEtiket), gcmDuz)
    var bozukEtiket = gcmSifreliVeEtiket
    bozukEtiket[bozukEtiket.count - 1] ^= 1
    XCTAssertNil(try gcmCoz(bozukEtiket))
    var bozukGovde = gcmSifreliVeEtiket
    bozukGovde[3] ^= 1
    XCTAssertNil(try gcmCoz(bozukGovde))
    XCTAssertNil(try gcmCoz(gcmSifreliVeEtiket, aad: Data()))
    XCTAssertNil(try gcmCoz(Data(count: 5)))
  }

  func testAes256GcmSifreleNistVektoruVeGidisDonus() throws {
    func sifrele(_ d: Data) throws -> Data {
      try cagir(
        "aes256GcmSifrele", ["anahtar": gcmAnahtar, "nonce": gcmNonce, "duz": d, "aad": gcmAad]
      )["sifreliVeEtiket"] as! Data
    }
    let girdi = gcmDuz
    XCTAssertEqual(try sifrele(girdi), gcmSifreliVeEtiket)
    // Girdi yerinde değiştirilmez.
    XCTAssertEqual(girdi, gcmDuz)
    let buyuk = Data((0..<300_000).map { UInt8($0 % 251) })
    let sifreli = try sifrele(buyuk)
    XCTAssertEqual(sifreli.count, buyuk.count + 16)
    XCTAssertEqual(try gcmCoz(sifreli), buyuk)
    hataBekle(.gecersizAnahtar) {
      _ = try cagir(
        "aes256GcmSifrele",
        ["anahtar": Data(count: 16), "nonce": gcmNonce, "duz": gcmDuz, "aad": gcmAad])
    }
  }

  // MARK: - Güvenlik kodu

  func testGuvenlikKoduBilinenVektorVeIkiTaraftaEsit() throws {
    // libsignal NumericFingerprintGeneratorTest (sürüm 2).
    let aliceKimlik = hex("0506863bc66d02b40d27b8d49ca7c09e9239236f9d7d25d6fcca5ce13c7064d868")
    let bobKimlik = hex("05f781b6fb32fed9ba1cf2de978d4d5da28dc34046ae814402b5c0dbd96fda907b")
    let aliceId = Data("+14152222222".utf8)
    let bobId = Data("+14153333333".utf8)
    let a = try cagir(
      "guvenlikKodu",
      [
        "yerelKimlik": aliceKimlik, "yerelTanimlayici": aliceId,
        "karsiKimlik": bobKimlik, "karsiTanimlayici": bobId,
      ])["kod"] as? String
    let b = try cagir(
      "guvenlikKodu",
      [
        "yerelKimlik": bobKimlik, "yerelTanimlayici": bobId,
        "karsiKimlik": aliceKimlik, "karsiTanimlayici": aliceId,
      ])["kod"] as? String
    XCTAssertEqual(a, "300354477692869396892869876765458257569162576843440918079131")
    XCTAssertEqual(a, b)

    let (alice, bob) = try ikiCihaz()
    let x = try cagir(
      "guvenlikKodu",
      [
        "yerelKimlik": alice.acik, "yerelTanimlayici": Data(Self.aliceAd.utf8),
        "karsiKimlik": bob.acik, "karsiTanimlayici": Data(Self.bobAd.utf8),
      ])["kod"] as! String
    let y = try cagir(
      "guvenlikKodu",
      [
        "yerelKimlik": bob.acik, "yerelTanimlayici": Data(Self.bobAd.utf8),
        "karsiKimlik": alice.acik, "karsiTanimlayici": Data(Self.aliceAd.utf8),
      ])["kod"] as? String
    XCTAssertEqual(x.count, 60)
    XCTAssertEqual(x, y)
  }

  // MARK: - Biçim

  func testBilinmeyenYontemVeBicimHatasi() {
    hataBekle(.bilinmeyen) { _ = try cagir("yok") }
    hataBekle(.bilinmeyen) { _ = try cagir("imzaliOnAnahtarUret", ["kimlik": "metin", "id": 1]) }
    hataBekle(.gecersizAnahtar) {
      _ = try cagir("imzaliOnAnahtarUret", ["kimlik": Data(count: 10), "id": 1])
    }
    // Bool tam sayı yerine geçmez.
    hataBekle(.bilinmeyen) { _ = try cagir("onAnahtarUret", ["baslangicId": true, "adet": 1]) }
  }

  // MARK: -

  private func hataBekle(
    _ tur: SignalHatasiTuru, file: StaticString = #filePath, line: UInt = #line,
    _ blok: () throws -> Void
  ) {
    do {
      try blok()
      XCTFail("SignalHatasi(\(tur)) bekleniyordu", file: file, line: line)
    } catch let hata as SignalHatasi {
      XCTAssertEqual(hata.tur, tur, file: file, line: line)
    } catch {
      XCTFail("yalnızca SignalHatasi beklenir", file: file, line: line)
    }
  }
}

private func cagir(_ yontem: String, _ arg: [String: Any] = [:]) throws -> [String: Any] {
  try SignalIslemleri.calistir(yontem, arg)
}

private func hex(_ s: String) -> Data {
  var d = Data(capacity: s.count / 2)
  var i = s.startIndex
  while i < s.endIndex {
    let j = s.index(i, offsetBy: 2)
    d.append(UInt8(s[i..<j], radix: 16)!)
    i = j
  }
  return d
}
