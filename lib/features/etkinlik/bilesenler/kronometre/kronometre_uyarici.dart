import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Kronometrenin cihazla işleri (ADR-0031 §3): süre dolunca uyarı ve
/// kronometre ekranı açıkken ekranın kapanmasını engelleme. Testlerde
/// sahtesi verilir.
abstract interface class KronometreUyarici {
  /// Süre doldu: kısa titreşim ve kısa bir uyarı sesi. İzin istemez.
  Future<void> uyar();

  /// [acik] ise ekran kendiliğinden kapanmaz; yalnızca kronometre ekranı
  /// açıkken `true` verilir.
  Future<void> ekraniAcikTut({required bool acik});
}

/// [KronometreUyarici]'nın uygulaması: titreşim Flutter'ın
/// `HapticFeedback`'iyle, ses ve ekranı açık tutma `tayfam/kronometre`
/// platform kanalıyla (Android: `MainActivity.kt`, iOS: `AppDelegate.swift`).
/// Yeni paket gerekmez. Köprü yoksa (test, web geliştirme derlemesi)
/// sessizce hiçbir şey yapmaz.
final class KanalKronometreUyarici implements KronometreUyarici {
  const KanalKronometreUyarici([
    this._kanal = const MethodChannel(KanalKronometreUyarici.kanalAdi),
  ]);

  /// Platform kanalının adı (Kotlin ve Swift tarafıyla aynı).
  static const String kanalAdi = 'tayfam/kronometre';

  final MethodChannel _kanal;

  @override
  Future<void> uyar() async {
    await HapticFeedback.vibrate();
    await _cagir('uyar', null);
  }

  @override
  Future<void> ekraniAcikTut({required bool acik}) =>
      _cagir('ekraniAcikTut', acik);

  Future<void> _cagir(String yontem, Object? arguman) async {
    try {
      await _kanal.invokeMethod<void>(yontem, arguman);
    } on PlatformException {
      // Uyarı ve ekran kilidi kolaylıktır; kronometre onlarsız da çalışır.
    } on MissingPluginException {
      // Köprü yok.
    }
  }
}

/// Kronometrenin cihaz işleri.
final kronometreUyariciProvider = Provider<KronometreUyarici>(
  (ref) => const KanalKronometreUyarici(),
  name: 'kronometreUyariciProvider',
);
