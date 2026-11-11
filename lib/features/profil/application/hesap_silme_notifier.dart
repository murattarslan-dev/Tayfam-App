import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/features/profil/application/yeniden_giris.dart';
import 'package:tayfam/features/profil/data/profil_deposu.dart';

export 'package:tayfam/features/profil/application/yeniden_giris.dart'
    show FarkliHesapHatasi;

/// Hesap silme akışının durumu.
@immutable
final class HesapSilmeDurumu {
  const HesapSilmeDurumu({this.suruyor = false, this.hata});

  /// Google penceresi açık ya da istekler sürüyor.
  final bool suruyor;

  /// Son denemenin hatası; yoksa `null`.
  final Object? hata;

  @override
  bool operator ==(Object other) =>
      other is HesapSilmeDurumu &&
      other.suruyor == suruyor &&
      other.hata == hata;

  @override
  int get hashCode => Object.hash(suruyor, hata);
}

/// Hesap silme (ADR-0018 §2; CLAUDE.md "Hesap silme"): açıklama ve onay
/// ekranda verildikten sonra yeniden Google girişi → `DELETE /v1/me`.
///
/// 1. Yeniden Google girişi ([YenidenGiris]; kullanıcı pencereyi kapatırsa
///    akış sessizce biter). Başka bir hesap seçildiyse
///    ([FarkliHesapHatasi]) ya da yeni bir (kaydı bekleyen) hesap açıldıysa
///    yeni oturum kullanılmaz, hiçbir hesap silinmez.
/// 2. Yeni oturumla `DELETE /v1/me` çağrılır.
///    Başarıda yerel oturum kapanır (giriş ekranına dönülür).
///    `reauthentication-required` gelirse kullanıcıdan yeniden giriş
///    istenir (akış tekrar başlatılır).
///
/// ID token, nonce ve kullanıcı kimliği saklanmaz, loglanmaz.
class HesapSilmeNotifier extends Notifier<HesapSilmeDurumu> {
  @override
  HesapSilmeDurumu build() => const HesapSilmeDurumu();

  /// Akışı başlatır. Sürerken ikinci çağrı yok sayılır.
  Future<void> sil() async {
    if (state.suruyor) return;
    state = const HesapSilmeDurumu(suruyor: true);
    final yenidenGiris = ref.read(yenidenGirisProvider);
    final profil = ref.read(profilDeposuProvider);
    final oturum = ref.read(sessionStoreProvider);
    final durum = ref.read(oturumDurumuProvider.notifier);
    try {
      if (!await yenidenGiris.yap()) {
        // Kullanıcı Google penceresini kapattı: hata gösterilmez.
        _bitir(const HesapSilmeDurumu());
        return;
      }
      await profil.hesabiSil();
      await oturum.kapat(OturumKapanisNedeni.hesapSilindi);
      _bitir(const HesapSilmeDurumu());
    } on OturumYok catch (hata) {
      durum.ayarla(OturumDurumu.girisYok);
      _bitir(HesapSilmeDurumu(hata: hata));
    } on Exception catch (hata) {
      _bitir(HesapSilmeDurumu(hata: hata));
    }
  }

  void _bitir(HesapSilmeDurumu yeni) {
    if (ref.mounted) state = yeni;
  }
}

/// Hesap silme ekranının notifier'ı; ekran kapanınca bırakılır.
final hesapSilmeProvider =
    NotifierProvider.autoDispose<HesapSilmeNotifier, HesapSilmeDurumu>(
      HesapSilmeNotifier.new,
      name: 'hesapSilmeProvider',
    );
