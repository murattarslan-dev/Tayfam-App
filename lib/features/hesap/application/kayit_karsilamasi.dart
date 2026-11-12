import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/oturum/oturum_durumu.dart';

/// Kayıt bitince gösterilecek hoş geldin ekranının bilgisi.
///
/// Yalnızca bellektedir (ADR-0006); `toString` içerik yazmaz.
@immutable
final class KayitKarsilamasi {
  const KayitKarsilamasi({required this.ad});

  /// "Hoş geldin, {ad}!" için kullanıcının görünen adı; bilinmiyorsa boş.
  final String ad;

  @override
  String toString() => 'KayitKarsilamasi(…)';
}

/// Kayıt yeni tamamlandıysa hoş geldin ekranının bilgisi; değilse `null`.
///
/// [KayitNotifier] kayıt başarılı olunca, `SessionStore.yenile()`'den
/// önce doldurur; yönlendirici oturum açılınca kullanıcıyı ana adres
/// yerine hoş geldin ekranına götürür. Hoş geldin ekranından çıkılırken
/// [bitir] çağrılır. Oturum kapanınca silinir.
class KayitKarsilamasiNotifier extends Notifier<KayitKarsilamasi?> {
  @override
  KayitKarsilamasi? build() {
    ref.listen(oturumDurumuProvider, (_, durum) {
      if (durum == OturumDurumu.girisYok) state = null;
    });
    return null;
  }

  /// Hoş geldin ekranını bekletir.
  void baslat(String ad) => state = KayitKarsilamasi(ad: ad);

  /// Hoş geldin ekranı bitti.
  void bitir() => state = null;
}

/// Kayıt sonrası hoş geldin ekranının bilgisi (uygulama boyunca, bellek).
final kayitKarsilamasiProvider =
    NotifierProvider<KayitKarsilamasiNotifier, KayitKarsilamasi?>(
      KayitKarsilamasiNotifier.new,
      name: 'kayitKarsilamasiProvider',
    );

/// Kayıtla birlikte işlenen davetin sonucu.
enum KayitDavetDurumu {
  /// Katılma isteği yöneticinin onayını bekliyor.
  bekliyor,

  /// Üyelik hemen etkin oldu (açık tayfa).
  etkin,

  /// Kullanıcı bu tayfada zaten üye ya da isteği zaten bekliyor.
  zatenUye,
}

/// Davetle gelen kullanıcının katılım sonucu (hoş geldin ekranı).
@immutable
final class KayitDavetSonucu {
  const KayitDavetSonucu({
    required this.durum,
    required this.tayfaAdi,
    this.tayfaId,
  });

  final KayitDavetDurumu durum;

  /// Davet önizlemesindeki tayfa adı (sözleşme: `InvitePreview.name`).
  final String tayfaAdi;

  /// Tayfanın kimliği; etkin üyelikte ana sayfasını açmak için.
  final String? tayfaId;
}

/// Kayıt sonrası bekleyen davetin işlenmesi (ADR-0018 §6 akışıyla).
///
/// Değer `null` ise bekleyen davet yoktur (linksiz gelen kullanıcı).
/// Hata, davetin işlenemediğini söyler; ayrıntıyı mevcut davet ekranı
/// gösterir.
///
/// Davet linkinin token'ı ve katılım akışı kabuktadır (`shell/derin_link/`);
/// özellik kabuğu import edemediği için (ADR-0002) varsayılan uygulama
/// "davet yok" der ve kabuk bu provider'ı kendi alt sınıfıyla override
/// eder (`shell/kayitlar.dart`).
class KayitDavetNotifier extends AsyncNotifier<KayitDavetSonucu?> {
  @override
  Future<KayitDavetSonucu?> build() async => null;
}

/// Hoş geldin ekranındaki davet işlemi; ekran kapanınca bırakılır. Hata
/// otomatik yeniden denenmez.
final kayitDavetProvider =
    AsyncNotifierProvider.autoDispose<KayitDavetNotifier, KayitDavetSonucu?>(
      KayitDavetNotifier.new,
      name: 'kayitDavetProvider',
      retry: _yenidenDenemeYok,
    );

Duration? _yenidenDenemeYok(int deneme, Object hata) => null;
