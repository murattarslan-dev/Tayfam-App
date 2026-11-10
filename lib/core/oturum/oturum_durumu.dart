import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/oturum/session_store.dart';

/// Yönlendirme korumalarının baktığı oturum durumu (ADR-0003).
///
/// Bu durum yalnızca kullanıcıyı doğru ekrana götürmek içindir; yetki
/// kararı değildir, yetki sunucudadır (CLAUDE.md, kesin kural 5).
enum OturumDurumu {
  /// Açılışta güvenli depodaki kayıt henüz okunmadı; açılış ekranı.
  yukleniyor,

  /// Oturum yok; giriş ekranına gidilir.
  girisYok,

  /// Google girişi yapıldı, kayıt tamamlanmadı (`registration_pending`).
  kayitBekliyor,

  /// Onay sürümleri değişti, yeniden onay gerekiyor (`consent_required`).
  onayGerekli,

  /// Oturum açık; uygulama kullanılabilir.
  acik,
}

/// `SessionStore`'un olayını yönlendirme durumuna çevirir (ADR-0012 §1.2):
/// kayıt yok → giriş; `registration_pending` → kayıt; `consent_required` →
/// yeniden onay; aksi halde açık. Kayıt, onaydan önce gelir.
OturumDurumu oturumDurumunaCevir(OturumOlayi olay) => switch (olay) {
  OturumKapali() => OturumDurumu.girisYok,
  OturumAcik(kayitBekliyor: true) => OturumDurumu.kayitBekliyor,
  OturumAcik(onayGerekli: true) => OturumDurumu.onayGerekli,
  OturumAcik() => OturumDurumu.acik,
};

/// Oturum durumunu tutan notifier; `SessionStore`'dan beslenir.
///
/// İlk değer [OturumDurumu.yukleniyor]'dur; depodaki kayıt okununca
/// (`SessionStore.durum()`) gerçek duruma geçer. Sonraki her değişiklik
/// (giriş, kayıt/onay sonrası yenileme, çıkış, oturumun sunucuda ya da
/// yenilemede kapanması) `SessionStore.olaylar`'dan gelir. Token taşımaz.
///
/// Kullanıcıya bağlı provider'lar bu provider'ı izleyerek sıfırlanır
/// (ADR-0001, kural 8).
class OturumDurumuNotifier extends Notifier<OturumDurumu> {
  @override
  OturumDurumu build() {
    final oturum = ref.watch(sessionStoreProvider);
    final abonelik = oturum.olaylar.listen(
      (olay) => state = oturumDurumunaCevir(olay),
    );
    ref.onDispose(abonelik.cancel);
    unawaited(_ilkDurum(oturum));
    return OturumDurumu.yukleniyor;
  }

  Future<void> _ilkDurum(SessionStore oturum) async {
    OturumDurumu ilk;
    try {
      ilk = oturumDurumunaCevir(await oturum.durum());
    } on Exception {
      ilk = OturumDurumu.girisYok;
    }
    // Bu arada bir olay geldiyse o daha yenidir.
    if (ref.mounted && state == OturumDurumu.yukleniyor) state = ilk;
  }

  /// Oturum durumunu değiştirir. `SessionStore` dışında yalnızca bir
  /// istek `OturumYok` aldığında giriş ekranına dönmek için kullanılır.
  void ayarla(OturumDurumu yeni) => state = yeni;
}

/// Uygulama boyunca yaşayan oturum durumu (ADR-0001 kural 4: kalıcı;
/// Riverpod 3'te `autoDispose` olmayan provider kalıcıdır).
final oturumDurumuProvider =
    NotifierProvider<OturumDurumuNotifier, OturumDurumu>(
      OturumDurumuNotifier.new,
      name: 'oturumDurumuProvider',
    );
