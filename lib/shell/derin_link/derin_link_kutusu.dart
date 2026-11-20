import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/shell/derin_link/derin_link.dart';

/// İşlenmeyi bekleyen derin link (ADR-0018 §6, ADR-0017 §1).
///
/// Link giriş, kayıt, yeniden onay ve hoş geldin tanıtımı boyunca
/// korunur ve sonra işlenir. **Yalnızca bellektedir:** diske, adrese,
/// gezinme geçmişine ya da log'a yazılmaz (kesin kural 3, 9; ADR-0006).
/// Uygulama süreci kapanınca kaybolur; soğuk açılışta link platformdan
/// yeniden gelir.
///
/// Riverpod durumu değildir: yönlendiricinin `redirect`'i çizim sırasında
/// çalışabildiği için orada provider değiştirmek yasaktır. Bu nesne düz
/// bir kutudur; değişince kimseye haber vermez. Yönlendirici onu her
/// yönlendirmede okur.
final class DerinLinkKutusu {
  String? _davetToken;
  String? _referansKodu;
  String? _qrToken;

  /// Bekleyen davetin token'ı; yoksa `null`. Yalnızca istek gövdesine
  /// konur.
  String? get davetToken => _davetToken;

  /// Bekleyen davet var mı.
  bool get davetBekliyor => _davetToken != null;

  /// QR ile katılım linki bekliyor mu (App ADR-0032 §3). Token'ın kendisi
  /// yalnızca [qrTokeniAl] ile, bir kez alınır.
  bool get qrBekliyor => _qrToken != null;

  /// Bekleyen QR token'ını verir ve kutudan bırakır (QR ekranı işler);
  /// yoksa `null`. Token yalnızca istek gövdesine konur.
  String? qrTokeniAl() {
    final token = _qrToken;
    _qrToken = null;
    return token;
  }

  /// Kayıt formunu dolduracak referans kodu; yoksa `null`.
  String? get referansKodu => _referansKodu;

  /// Gelen adresi ayrıştırır; derin linkse kutuya koyar ve yönlendirmenin
  /// devam edeceği adresi döndürür.
  ///
  /// - Uygulama içi adres olduğu gibi döner.
  /// - Davet linki saklanır (yenisi eskisinin yerine geçer); kök adres
  ///   döner, token adreste kalmaz.
  /// - QR ile katılım linki saklanır (yenisi eskisinin yerine geçer); kök
  ///   adres döner, token adreste kalmaz.
  /// - Referans linki yalnızca oturum açık değilken saklanır (açık
  ///   oturumda kayıt formu yoktur); kök adres döner.
  /// - Geçersiz link işlenmez; kök adres döner.
  Uri yakala(Uri konum, {required bool oturumAcik}) {
    switch (gelenAdresiAyristir(konum)) {
      case IcAdres():
        return konum;
      case DavetLinki(:final token):
        _davetToken = token;
      case QrKatilimLinki(:final token):
        _qrToken = token;
      case ReferansLinki(:final kod):
        if (!oturumAcik) _referansKodu = kod;
      case GecersizLink():
        break;
    }
    return Uri(path: Adresler.kok);
  }

  /// Daveti bırakır (katılındı, vazgeçildi ya da link kullanılamaz).
  void davetiBirak() => _davetToken = null;

  /// Referans kodunu bırakır (kayıt tamamlandı).
  void referansiBirak() => _referansKodu = null;
}

/// Uygulama boyunca yaşayan tek kutu.
final derinLinkKutusuProvider = Provider<DerinLinkKutusu>(
  (ref) => DerinLinkKutusu(),
  name: 'derinLinkKutusuProvider',
);
