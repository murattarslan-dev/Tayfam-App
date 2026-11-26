import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/features/hesap/hesap.dart';
import 'package:tayfam/features/profil/data/profil_deposu.dart';

/// Yeniden girişte başka bir hesap seçildi: o hesap bu oturumun hesabı
/// değil. Yeni oturum kullanılmaz, oturum değişmez.
final class FarkliHesapHatasi implements Exception {
  const FarkliHesapHatasi();

  @override
  String toString() => 'FarkliHesapHatasi';
}

/// Tamamlanan bir yeniden girişin sonucu. `toString` içerik yazmaz.
final class YenidenGirisSonucu {
  const YenidenGirisSonucu({this.appleKodu});

  /// Apple ile yeniden girişte Apple'ın verdiği tek kullanımlık
  /// yetkilendirme kodu; Google'da `null`. Yalnızca hesap silmede
  /// `DELETE /v1/me` gövdesine gider (Tayfam-Api ADR-0045 §4); saklanmaz,
  /// loglanmaz.
  final String? appleKodu;

  @override
  String toString() => 'YenidenGirisSonucu(…)';
}

/// Son 10 dakikada sağlayıcıyla giriş isteyen işlemlerden önceki yeniden
/// giriş (`reauthentication-required`; CLAUDE.md "Hesap silme", Tayfam-Api
/// ADR-0021 §6). Hesap silme ve veri dışa aktarma indirmesi aynı akışı
/// kullanır.
///
/// 1. Bu cihazdaki son girişin sağlayıcısıyla ([GirisSaglayicisiHafizasi];
///    ADR-0034 §5) ID token alınır ve giriş yapılır
///    (`POST /v1/auth/sign-in`). Kayıt yoksa Google.
/// 2. Gelen oturumun kullanıcısının bu oturumun kullanıcısı olduğu, eski
///    oturumla `GET /v1/me/account`'un `user_id` alanından doğrulanır.
///    Başka bir hesap seçildiyse ya da yeni (kaydı bekleyen) bir hesap
///    açıldıysa [FarkliHesapHatasi]; yeni oturum kullanılmaz.
/// 3. Yeni oturum `SessionStore`'a verilir.
///
/// ID token, nonce, yetkilendirme kodu ve kullanıcı kimliği saklanmaz,
/// loglanmaz.
final class YenidenGiris {
  YenidenGiris({
    required this._google,
    required this._apple,
    required this._hafiza,
    required this._hesap,
    required this._platform,
    required this._profil,
    required this._oturum,
  });

  final GoogleKimlikSaglayici _google;
  final AppleKimlikSaglayici _apple;
  final GirisSaglayicisiHafizasi _hafiza;
  final HesapDeposu _hesap;
  final String _platform;
  final ProfilDeposu _profil;
  final SessionStore _oturum;

  /// Akışı yürütür. Yeni oturum açıldıysa sonucu; kullanıcı sağlayıcının
  /// penceresini kapattıysa `null` (hiçbir istek gönderilmez).
  Future<YenidenGirisSonucu?> yap() async {
    final Session yeni;
    String? appleKodu;
    switch (await _hafiza.oku()) {
      case GirisSaglayicisi.google:
        final kimlik = await _google.girisYap();
        if (kimlik == null) return null;
        yeni = await _hesap.girisYap(kimlik, platform: _platform);
      case GirisSaglayicisi.apple:
        final kimlik = await _apple.girisYap();
        if (kimlik == null) return null;
        yeni = await _hesap.appleIleGirisYap(kimlik, platform: _platform);
        appleKodu = kimlik.yetkilendirmeKodu;
    }
    if (yeni.registrationPending || !await _profil.kendisiMi(yeni.userId)) {
      throw const FarkliHesapHatasi();
    }
    await _oturum.oturumAc(yeni);
    return YenidenGirisSonucu(appleKodu: appleKodu);
  }
}

/// Yeniden giriş akışı.
final yenidenGirisProvider = Provider<YenidenGiris>(
  (ref) => YenidenGiris(
    google: ref.watch(googleKimlikSaglayiciProvider),
    apple: ref.watch(appleKimlikSaglayiciProvider),
    hafiza: ref.watch(girisSaglayicisiHafizasiProvider),
    hesap: ref.watch(hesapDeposuProvider),
    platform: ref.watch(hesapPlatformuProvider),
    profil: ref.watch(profilDeposuProvider),
    oturum: ref.watch(sessionStoreProvider),
  ),
  name: 'yenidenGirisProvider',
);
