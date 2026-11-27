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
  /// `tayfam/butunluk` köprüsü (App Attest, ADR-0034 §7).
  private var butunluk: ButunlukKoprusu?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    kronometreKanaliniKur(engineBridge.pluginRegistry)
    appleGiris = AppleGirisKoprusu.kur(engineBridge.pluginRegistry)
    signal = SignalKoprusu.kur(engineBridge.pluginRegistry)
    butunluk = ButunlukKoprusu.kur(engineBridge.pluginRegistry)
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
