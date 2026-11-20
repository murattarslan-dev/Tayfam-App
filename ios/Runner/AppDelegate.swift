import AudioToolbox
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    kronometreKanaliniKur(engineBridge.pluginRegistry)
  }

  /// `tayfam/kronometre` (istemci ADR-0031 §3): kronometre ekranı açıkken
  /// ekranın kapanmasını engeller ve süre dolunca kısa bir sistem sesi çalar.
  private func kronometreKanaliniKur(_ kayit: FlutterPluginRegistry) {
    guard let kayitci = kayit.registrar(forPlugin: "TayfamKronometre") else { return }
    let kanal = FlutterMethodChannel(
      name: "tayfam/kronometre", binaryMessenger: kayitci.messenger())
    kanal.setMethodCallHandler { call, result in
      switch call.method {
      case "ekraniAcikTut":
        UIApplication.shared.isIdleTimerDisabled = (call.arguments as? Bool) ?? false
        result(nil)
      case "uyar":
        AudioServicesPlaySystemSound(1005)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
