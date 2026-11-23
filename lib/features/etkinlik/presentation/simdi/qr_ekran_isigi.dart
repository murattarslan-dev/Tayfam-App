import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/features/etkinlik/bilesenler/kronometre/kronometre_uyarici.dart';

/// QR ekranı açıkken ekranın parlaklığı ve kapanması (App ADR-0032 §3):
/// QR uzaktan ve güneşte okunabilsin diye parlaklık en yükseğe çıkar,
/// ekran kendiliğinden kapanmaz. Ekrandan çıkınca (ya da uygulama arka
/// plana geçince) ikisi de bırakılır. Testlerde sahtesi verilir.
abstract interface class QrEkranIsigi {
  /// [acik] ise parlaklık artar ve ekran açık kalır; değilse sistem
  /// ayarına dönülür.
  Future<void> ayarla({required bool acik});
}

/// [QrEkranIsigi]'nın uygulaması: kronometrenin `tayfam/kronometre`
/// platform kanalı (`ekraniAcikTut`, `parlaklik`; Android
/// `MainActivity.kt`, iOS `AppDelegate.swift`). Ayrı kanal ya da paket
/// yoktur, izin gerekmez. Köprü yoksa (test, web geliştirme derlemesi)
/// sessizce hiçbir şey yapmaz.
final class KanalQrEkranIsigi implements QrEkranIsigi {
  const KanalQrEkranIsigi([
    this._kanal = const MethodChannel(KanalKronometreUyarici.kanalAdi),
  ]);

  final MethodChannel _kanal;

  @override
  Future<void> ayarla({required bool acik}) async {
    await _cagir('ekraniAcikTut', acik);
    await _cagir('parlaklik', acik);
  }

  Future<void> _cagir(String yontem, bool arguman) async {
    try {
      await _kanal.invokeMethod<void>(yontem, arguman);
    } on PlatformException {
      // Parlaklık ve ekran kilidi kolaylıktır; QR onlarsız da okunur.
    } on MissingPluginException {
      // Köprü yok.
    }
  }
}

/// QR ekranının cihaz işleri.
final qrEkranIsigiProvider = Provider<QrEkranIsigi>(
  (ref) => const KanalQrEkranIsigi(),
  name: 'qrEkranIsigiProvider',
);
