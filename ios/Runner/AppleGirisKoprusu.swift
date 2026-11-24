import AuthenticationServices
import Flutter
import UIKit

/// `tayfam/apple-giris` (istemci ADR-0034 §5, Tayfam-Api ADR-0045): Apple'ın
/// kendi çerçevesiyle (AuthenticationServices) Apple ile giriş. Dart tarafı
/// `KanalAppleKimlikSaglayici`'dır.
///
/// `girisYap({nonce})` Apple'ın penceresini açar ve kimlik token'ı,
/// yetkilendirme kodu ve (Apple yalnızca ilk yetkilendirmede verir) adı
/// döndürür. Kullanıcı vazgeçerse hata kodu `iptal`, başka her sorunda
/// `basarisiz`'dır; mesaj ve ayrıntı taşınmaz. Hiçbir şey saklanmaz ve
/// loglanmaz.
final class AppleGirisKoprusu: NSObject, ASAuthorizationControllerDelegate,
  ASAuthorizationControllerPresentationContextProviding
{
  static let kanalAdi = "tayfam/apple-giris"

  /// Süren girişin cevabı; aynı anda tek giriş.
  private var bekleyen: FlutterResult?
  /// İstek sürerken denetleyici bırakılmasın diye tutulur.
  private var denetleyici: ASAuthorizationController?

  /// Kanalı kurar. Dönen köprüyü çağıran tutmalıdır (kanal onu zayıf tutar).
  static func kur(_ kayit: FlutterPluginRegistry) -> AppleGirisKoprusu? {
    guard let kayitci = kayit.registrar(forPlugin: "TayfamAppleGiris") else { return nil }
    let kopru = AppleGirisKoprusu()
    let kanal = FlutterMethodChannel(name: kanalAdi, binaryMessenger: kayitci.messenger())
    kanal.setMethodCallHandler { [weak kopru] call, result in
      guard let kopru = kopru else {
        result(FlutterMethodNotImplemented)
        return
      }
      kopru.cagri(call, result)
    }
    return kopru
  }

  private func cagri(_ call: FlutterMethodCall, _ result: @escaping FlutterResult) {
    guard call.method == "girisYap" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard let girdiler = call.arguments as? [String: Any],
      let nonce = girdiler["nonce"] as? String, !nonce.isEmpty, bekleyen == nil
    else {
      result(FlutterError(code: "basarisiz", message: nil, details: nil))
      return
    }
    bekleyen = result
    let istek = ASAuthorizationAppleIDProvider().createRequest()
    istek.requestedScopes = [.fullName, .email]
    // Nonce kimlik token'ına olduğu gibi yazılır; sunucu aynı değerle
    // karşılaştırır (Google ile aynı kural, Tayfam-Api ADR-0045 §2).
    istek.nonce = nonce
    let yeni = ASAuthorizationController(authorizationRequests: [istek])
    yeni.delegate = self
    yeni.presentationContextProvider = self
    denetleyici = yeni
    yeni.performRequests()
  }

  private func bitir(_ sonuc: Any?) {
    let cevap = bekleyen
    bekleyen = nil
    denetleyici = nil
    cevap?(sonuc)
  }

  func authorizationController(
    controller: ASAuthorizationController,
    didCompleteWithAuthorization authorization: ASAuthorization
  ) {
    guard let kimlik = authorization.credential as? ASAuthorizationAppleIDCredential,
      let tokenVerisi = kimlik.identityToken,
      let idToken = String(data: tokenVerisi, encoding: .utf8), !idToken.isEmpty,
      let kodVerisi = kimlik.authorizationCode,
      let kod = String(data: kodVerisi, encoding: .utf8), !kod.isEmpty
    else {
      bitir(FlutterError(code: "basarisiz", message: nil, details: nil))
      return
    }
    var yanit: [String: Any] = ["idToken": idToken, "yetkilendirmeKodu": kod]
    if let adParcalari = kimlik.fullName {
      let ad = PersonNameComponentsFormatter().string(from: adParcalari)
      if !ad.isEmpty { yanit["ad"] = ad }
    }
    bitir(yanit)
  }

  func authorizationController(
    controller: ASAuthorizationController, didCompleteWithError error: Error
  ) {
    if let hata = error as? ASAuthorizationError, hata.code == .canceled {
      bitir(FlutterError(code: "iptal", message: nil, details: nil))
    } else {
      bitir(FlutterError(code: "basarisiz", message: nil, details: nil))
    }
  }

  func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
    let sahneler = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let pencereler = sahneler.flatMap { $0.windows }
    return pencereler.first { $0.isKeyWindow } ?? pencereler.first ?? ASPresentationAnchor()
  }
}
