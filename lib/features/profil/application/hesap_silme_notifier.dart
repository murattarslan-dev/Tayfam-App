import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/features/hesap/hesap.dart';
import 'package:tayfam/features/profil/data/profil_deposu.dart';

/// Yeniden girişte başka bir Google hesabı seçildi: o hesap bu oturumun
/// hesabı değil. Hiçbir hesap silinmez, oturum değişmez.
final class FarkliHesapHatasi implements Exception {
  const FarkliHesapHatasi();

  @override
  String toString() => 'FarkliHesapHatasi';
}

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
/// 1. Google'dan ID token alınır (`POST /v1/auth/sign-in`; kullanıcı
///    pencereyi kapatırsa akış sessizce biter).
/// 2. Gelen oturumun kullanıcısının bu oturumun kullanıcısı olduğu, eski
///    oturumla `GET /v1/users/{user_id}/profile` `self` alanından
///    doğrulanır. Başka bir hesap seçildiyse ([FarkliHesapHatasi]) ya da
///    yeni bir (kaydı bekleyen) hesap açıldıysa yeni oturum kullanılmaz,
///    hiçbir hesap silinmez.
/// 3. Yeni oturum `SessionStore`'a verilir ve `DELETE /v1/me` çağrılır.
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
    final google = ref.read(googleKimlikSaglayiciProvider);
    final hesap = ref.read(hesapDeposuProvider);
    final platform = ref.read(hesapPlatformuProvider);
    final profil = ref.read(profilDeposuProvider);
    final oturum = ref.read(sessionStoreProvider);
    final durum = ref.read(oturumDurumuProvider.notifier);
    try {
      final kimlik = await google.girisYap();
      if (kimlik == null) {
        // Kullanıcı Google penceresini kapattı: hata gösterilmez.
        _bitir(const HesapSilmeDurumu());
        return;
      }
      final yeni = await hesap.girisYap(kimlik, platform: platform);
      if (yeni.registrationPending || !await _kendisiMi(profil, yeni.userId)) {
        _bitir(const HesapSilmeDurumu(hata: FarkliHesapHatasi()));
        return;
      }
      await oturum.oturumAc(yeni);
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

  /// [kullaniciId] bu oturumun kullanıcısı mı. Profil bulunamazsa (yeni ya
  /// da erişilemeyen hesap) `false`.
  Future<bool> _kendisiMi(ProfilDeposu profil, String kullaniciId) async {
    try {
      return await profil.kendisiMi(kullaniciId);
    } on ApiProblem catch (problem) {
      if (problem.type == ProblemType.userNotFound ||
          problem.type == ProblemType.notFound ||
          problem.type == ProblemType.invalidRequest) {
        return false;
      }
      rethrow;
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
