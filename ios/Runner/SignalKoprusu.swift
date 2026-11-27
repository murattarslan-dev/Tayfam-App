import Flutter
import Foundation
import TayfamSignal

/// `tayfam/e2e/signal` platform kanalı: Android'deki `SignalKoprusu.kt`'nin
/// iOS karşılığı (istemci ADR-0010, ADR-0034 §7).
///
/// İnce ve durumsuz: her çağrı `SignalIslemleri`'ne gider. Çağrılar
/// Flutter'ın arka plan görev kuyruğunda çalışır; ana iş parçacığı
/// bloklanmaz. Hiçbir şey log'lanmaz; hata yalnızca türünü taşır
/// (kod = `SignalHatasiTuru` adı, mesaj ve ayrıntı yok).
///
/// Bu katmanın tek işi Flutter'ın `StandardMessageCodec` türlerini
/// (`FlutterStandardTypedData`, `NSNumber`, `NSNull`) saf Swift türlerine
/// (`Data`, `Int`) ve geri çevirmektir.
final class SignalKoprusu {
  static let kanalAdi = "tayfam/e2e/signal"

  private let kanal: FlutterMethodChannel

  private init(kanal: FlutterMethodChannel) {
    self.kanal = kanal
  }

  /// Kanalı kurar. Dönen köprüyü çağıran tutmalıdır.
  static func kur(_ kayit: FlutterPluginRegistry) -> SignalKoprusu? {
    guard let kayitci = kayit.registrar(forPlugin: "TayfamSignal") else { return nil }
    let mesajci = kayitci.messenger()
    let kanal = FlutterMethodChannel(
      name: kanalAdi,
      binaryMessenger: mesajci,
      codec: FlutterStandardMethodCodec.sharedInstance(),
      taskQueue: mesajci.makeBackgroundTaskQueue?())
    kanal.setMethodCallHandler { call, result in
      result(SignalKoprusu.cagri(call.method, call.arguments))
    }
    return SignalKoprusu(kanal: kanal)
  }

  /// Kanal çağrısını çalıştırır; sonuç ya harita ya `FlutterError`'dır.
  static func cagri(_ yontem: String, _ hamArg: Any?) -> Any {
    guard let arg = argumanlar(hamArg) else {
      return FlutterError(code: SignalHatasiTuru.bilinmeyen.rawValue, message: nil, details: nil)
    }
    do {
      return disari(try SignalIslemleri.calistir(yontem, arg))
    } catch let hata as SignalHatasi {
      return FlutterError(code: hata.tur.rawValue, message: nil, details: nil)
    } catch {
      return FlutterError(code: SignalHatasiTuru.bilinmeyen.rawValue, message: nil, details: nil)
    }
  }

  /// Kanaldan gelen değer → saf Swift. Anahtarı metin olmayan harita
  /// biçim hatasıdır (`nil`).
  private static func argumanlar(_ ham: Any?) -> [String: Any]? {
    guard let ham = ham, !(ham is NSNull) else { return [:] }
    guard let harita = ham as? [AnyHashable: Any] else { return nil }
    return iceri(harita) as? [String: Any]
  }

  private static func iceri(_ deger: Any) -> Any? {
    switch deger {
    case let b as FlutterStandardTypedData:
      return b.data
    case let h as [AnyHashable: Any]:
      var sonuc: [String: Any] = [:]
      sonuc.reserveCapacity(h.count)
      for (k, v) in h {
        guard let ad = k as? String, let d = iceri(v) else { return nil }
        sonuc[ad] = d
      }
      return sonuc
    case let l as [Any]:
      var sonuc: [Any] = []
      sonuc.reserveCapacity(l.count)
      for v in l {
        guard let d = iceri(v) else { return nil }
        sonuc.append(d)
      }
      return sonuc
    default:
      return deger
    }
  }

  /// Saf Swift → kanal. `Data` bayt dizisi olarak gider.
  private static func disari(_ deger: Any) -> Any {
    switch deger {
    case let d as Data:
      return FlutterStandardTypedData(bytes: d)
    case let h as [String: Any]:
      return h.mapValues { disari($0) }
    case let l as [Any]:
      return l.map { disari($0) }
    default:
      return deger
    }
  }
}
