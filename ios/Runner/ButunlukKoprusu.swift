import CryptoKit
import DeviceCheck
import Flutter
import Foundation
import Security

/// `tayfam/butunluk` platform kanalı: Android'deki `ButunlukKoprusu.kt`'nin
/// iOS karşılığı, App Attest (istemci ADR-0023, ADR-0034 §7; Tayfam-Api
/// ADR-0022 §4).
///
/// Yöntemler: `appAttestUnut` (oturum kapandı: Keychain'deki anahtar
/// kimliğini siler) ve `appAttest` {istek: `giris` | `yenileme`, istekOzeti}.
/// - `giris`: yeni bir anahtar üretir, `clientDataHash` =
///   SHA-256(istekOzeti metni) ile Apple'a onaylatır ve anahtar kimliğini
///   Keychain'e yazar (öncekinin yerine).
/// - `yenileme`: Keychain'deki anahtarla aynı biçimde imza (assertion)
///   üretir.
/// Sonuç `{keyId, veri}` (ikisi de base64 metin) ya da cihaz App Attest'i
/// desteklemiyorsa / anahtar yoksa `nil`.
///
/// İstek özeti Dart'ta hesaplanmış bağlama değeridir; yenileme token'ı bu
/// köprüye gelmez. Hiçbir şey loglanmaz; hata yalnızca türünü taşır
/// (kod = Dart'taki `ButunlukHatasiTuru` adı, mesaj ve ayrıntı yok).
final class ButunlukKoprusu {
  static let kanalAdi = "tayfam/butunluk"

  private let kanal: FlutterMethodChannel
  private let servis: DCAppAttestService

  private init(kanal: FlutterMethodChannel, servis: DCAppAttestService) {
    self.kanal = kanal
    self.servis = servis
  }

  /// Kanalı kurar. Dönen köprüyü çağıran tutmalıdır.
  static func kur(_ kayit: FlutterPluginRegistry) -> ButunlukKoprusu? {
    guard let kayitci = kayit.registrar(forPlugin: "TayfamButunluk") else { return nil }
    let kanal = FlutterMethodChannel(name: kanalAdi, binaryMessenger: kayitci.messenger())
    let kopru = ButunlukKoprusu(kanal: kanal, servis: DCAppAttestService.shared)
    kanal.setMethodCallHandler { [weak kopru] call, result in
      guard let kopru else {
        result(nil)
        return
      }
      kopru.cagri(call, result)
    }
    return kopru
  }

  private func cagri(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    if call.method == "appAttestUnut" {
      AnahtarDeposu.sil()
      result(nil)
      return
    }
    guard call.method == "appAttest" else {
      result(FlutterMethodNotImplemented)
      return
    }
    let arg = call.arguments as? [String: Any]
    guard let istek = arg?["istek"] as? String,
      let ozet = arg?["istekOzeti"] as? String, !ozet.isEmpty
    else {
      result(Self.hata(.yapilandirma))
      return
    }
    // Simülatörde ve App Attest'i desteklemeyen cihazda kanıt yoktur.
    guard servis.isSupported else {
      result(nil)
      return
    }
    let clientDataHash = Data(SHA256.hash(data: Data(ozet.utf8)))
    let bitir: (Any?) -> Void = { deger in DispatchQueue.main.async { result(deger) } }
    switch istek {
    case "giris": onaylat(clientDataHash, bitir)
    case "yenileme": imzala(clientDataHash, bitir)
    default: result(Self.hata(.yapilandirma))
    }
  }

  /// Girişte: yeni anahtar ve attestation. Anahtar kimliği yalnızca
  /// onaydan sonra Keychain'e yazılır.
  private func onaylat(_ clientDataHash: Data, _ bitir: @escaping (Any?) -> Void) {
    servis.generateKey { anahtar, hata in
      guard let anahtar, hata == nil else {
        bitir(Self.eslenmis(hata))
        return
      }
      self.servis.attestKey(anahtar, clientDataHash: clientDataHash) { nesne, hata in
        guard let nesne, hata == nil else {
          bitir(Self.eslenmis(hata))
          return
        }
        guard AnahtarDeposu.yaz(anahtar) else {
          bitir(Self.hata(.bilinmeyen))
          return
        }
        bitir(["keyId": anahtar, "veri": nesne.base64EncodedString()])
      }
    }
  }

  /// Yenilemede: girişte onaylanan anahtarla assertion. Anahtar yoksa
  /// kanıt yoktur; geçersizse (uygulama yeniden kuruldu) silinir.
  private func imzala(_ clientDataHash: Data, _ bitir: @escaping (Any?) -> Void) {
    guard let anahtar = AnahtarDeposu.oku() else {
      bitir(nil)
      return
    }
    servis.generateAssertion(anahtar, clientDataHash: clientDataHash) { nesne, hata in
      guard let nesne, hata == nil else {
        if (hata as? DCError)?.code == .invalidKey { AnahtarDeposu.sil() }
        bitir(Self.eslenmis(hata))
        return
      }
      bitir(["keyId": anahtar, "veri": nesne.base64EncodedString()])
    }
  }

  /// DeviceCheck hatasını türe çevirir; desteklenmeyen özellik kanıtsızlıktır.
  private static func eslenmis(_ e: Error?) -> Any? {
    guard let dc = e as? DCError else { return Self.hata(.bilinmeyen) }
    switch dc.code {
    case .featureUnsupported: return nil
    case .invalidKey: return Self.hata(.anahtarYok)
    case .invalidInput: return Self.hata(.yapilandirma)
    case .serverUnavailable: return Self.hata(.gecici)
    default: return Self.hata(.bilinmeyen)
    }
  }

  private static func hata(_ tur: ButunlukHatasiTuru) -> FlutterError {
    FlutterError(code: tur.rawValue, message: nil, details: nil)
  }
}

/// Dart'taki `ButunlukHatasiTuru` adlarıyla aynı.
enum ButunlukHatasiTuru: String {
  case gecici
  case yapilandirma
  case anahtarYok
  case bilinmeyen
}

/// App Attest anahtar kimliğinin Keychain kaydı (kesin kural 2/4): yalnızca
/// bu cihazda, ilk kilit açılışından sonra okunur; yedeğe ve başka cihaza
/// geçmez (App Attest anahtarı da geçmez).
enum AnahtarDeposu {
  private static var sorgu: [String: Any] {
    [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: "com.murattarslan.tayfam.butunluk",
      kSecAttrAccount as String: "app-attest-anahtari",
    ]
  }

  static func yaz(_ anahtar: String) -> Bool {
    sil()
    var kayit = sorgu
    kayit[kSecValueData as String] = Data(anahtar.utf8)
    kayit[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
    return SecItemAdd(kayit as CFDictionary, nil) == errSecSuccess
  }

  static func oku() -> String? {
    var istek = sorgu
    istek[kSecReturnData as String] = true
    istek[kSecMatchLimit as String] = kSecMatchLimitOne
    var sonuc: CFTypeRef?
    guard SecItemCopyMatching(istek as CFDictionary, &sonuc) == errSecSuccess,
      let veri = sonuc as? Data, let anahtar = String(data: veri, encoding: .utf8),
      !anahtar.isEmpty
    else { return nil }
    return anahtar
  }

  static func sil() {
    SecItemDelete(sorgu as CFDictionary)
  }
}
