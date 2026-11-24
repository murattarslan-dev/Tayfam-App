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
    // Apple'ın kendi düğmesi (Design: Giriş iOS) bir platform görünümüdür.
    kayitci.register(
      AppleDugmeFabrikasi(mesajci: kayitci.messenger()), withId: AppleDugmeFabrikasi.gorunumTuru)
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

/// `tayfam/apple-giris-dugmesi` platform görünümü: Apple'ın kendi düğmesi
/// (`ASAuthorizationAppleIDButton`, "Apple ile Devam Et"; metni sistem
/// cihazın diline göre yazar). Dart tarafı `AppleIleDevamDugmesi`'dir.
///
/// Düğme yalnızca basıldığını bildirir (`tayfam/apple-giris-dugmesi/<kimlik>`
/// kanalında `basildi`); girişi Dart başlatır.
final class AppleDugmeFabrikasi: NSObject, FlutterPlatformViewFactory {
  static let gorunumTuru = "tayfam/apple-giris-dugmesi"

  private let mesajci: FlutterBinaryMessenger

  init(mesajci: FlutterBinaryMessenger) {
    self.mesajci = mesajci
    super.init()
  }

  func create(withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?)
    -> FlutterPlatformView
  {
    let girdiler = args as? [String: Any]
    return AppleDugmeGorunumu(
      frame: frame,
      kanal: FlutterMethodChannel(
        name: "\(AppleDugmeFabrikasi.gorunumTuru)/\(viewId)", binaryMessenger: mesajci),
      koyuTema: (girdiler?["koyuTema"] as? Bool) ?? false,
      koseYaricapi: (girdiler?["koseYaricapi"] as? Double) ?? 0)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    return FlutterStandardMessageCodec.sharedInstance()
  }
}

final class AppleDugmeGorunumu: NSObject, FlutterPlatformView {
  private let dugme: ASAuthorizationAppleIDButton
  private let kanal: FlutterMethodChannel

  init(frame: CGRect, kanal: FlutterMethodChannel, koyuTema: Bool, koseYaricapi: Double) {
    // Açık temada siyah, koyu temada beyaz biçim (Design: Giriş iOS).
    dugme = ASAuthorizationAppleIDButton(
      authorizationButtonType: .continue,
      authorizationButtonStyle: koyuTema ? .white : .black)
    dugme.frame = frame
    if koseYaricapi > 0 { dugme.cornerRadius = CGFloat(koseYaricapi) }
    self.kanal = kanal
    super.init()
    dugme.addTarget(self, action: #selector(basildi), for: .touchUpInside)
  }

  func view() -> UIView {
    return dugme
  }

  @objc private func basildi() {
    kanal.invokeMethod("basildi", arguments: nil)
  }
}
