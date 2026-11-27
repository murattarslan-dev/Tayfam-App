import AudioToolbox
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  /// QR ekranı açılmadan önceki parlaklık; ekran kapanınca geri verilir.
  private var oncekiParlaklik: CGFloat?
  /// `tayfam/apple-giris` köprüsü; kanal onu zayıf tuttuğu için burada durur.
  private var appleGiris: AppleGirisKoprusu?
  /// `tayfam/e2e/signal` köprüsü (birebir mesaj şifrelemesi, ADR-0034 §7).
  private var signal: SignalKoprusu?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    kronometreKanaliniKur(engineBridge.pluginRegistry)
    bildirimKanaliniKur(engineBridge.pluginRegistry)
    appleGiris = AppleGirisKoprusu.kur(engineBridge.pluginRegistry)
    signal = SignalKoprusu.kur(engineBridge.pluginRegistry)
  }

  /// `tayfam/kronometre` (istemci ADR-0031 §3): kronometre ekranı açıkken
  /// ekranın kapanmasını engeller ve süre dolunca kısa bir sistem sesi çalar.
  /// QR ile katılım ekranı (istemci ADR-0032 §3) aynı kanalla ekranı açık
  /// tutar ve `parlaklik` ile parlaklığı en yükseğe çıkarıp sonra eski
  /// değerine döndürür.
  private func kronometreKanaliniKur(_ kayit: FlutterPluginRegistry) {
    guard let kayitci = kayit.registrar(forPlugin: "TayfamKronometre") else { return }
    let kanal = FlutterMethodChannel(
      name: "tayfam/kronometre", binaryMessenger: kayitci.messenger())
    kanal.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "ekraniAcikTut":
        UIApplication.shared.isIdleTimerDisabled = (call.arguments as? Bool) ?? false
        result(nil)
      case "uyar":
        AudioServicesPlaySystemSound(1005)
        result(nil)
      case "parlaklik":
        self?.parlaklik(artir: (call.arguments as? Bool) ?? false)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  /// `tayfam/bildirim` (istemci ADR-0019, iOS notu): yalnızca `ayarlariAc`.
  /// İzin reddedildikten sonra iOS izin penceresini bir daha göstermez;
  /// Profil → Bildirimler uygulamanın sistem bildirim ayarını açar. Kanal
  /// kurulumu (`kanallariKur`) Android'e özgüdür, Dart iOS'ta çağırmaz.
  private func bildirimKanaliniKur(_ kayit: FlutterPluginRegistry) {
    guard let kayitci = kayit.registrar(forPlugin: "TayfamBildirim") else { return }
    let kanal = FlutterMethodChannel(
      name: "tayfam/bildirim", binaryMessenger: kayitci.messenger())
    kanal.setMethodCallHandler { call, result in
      guard call.method == "ayarlariAc" else {
        result(FlutterMethodNotImplemented)
        return
      }
      let adres: String
      if #available(iOS 16.0, *) {
        adres = UIApplication.openNotificationSettingsURLString
      } else {
        adres = UIApplication.openSettingsURLString
      }
      guard let url = URL(string: adres) else {
        result(false)
        return
      }
      UIApplication.shared.open(url) { acildi in result(acildi) }
    }
  }

  private func parlaklik(artir: Bool) {
    if artir {
      if oncekiParlaklik == nil { oncekiParlaklik = UIScreen.main.brightness }
      UIScreen.main.brightness = 1.0
    } else if let onceki = oncekiParlaklik {
      UIScreen.main.brightness = onceki
      oncekiParlaklik = nil
    }
  }
}
