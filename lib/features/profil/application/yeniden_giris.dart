import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/oturum/session_store.dart';
import 'package:tayfam/features/hesap/hesap.dart';
import 'package:tayfam/features/profil/data/profil_deposu.dart';

/// Yeniden girişte başka bir Google hesabı seçildi: o hesap bu oturumun
/// hesabı değil. Yeni oturum kullanılmaz, oturum değişmez.
final class FarkliHesapHatasi implements Exception {
  const FarkliHesapHatasi();

  @override
  String toString() => 'FarkliHesapHatasi';
}

/// Son 10 dakikada sağlayıcıyla giriş isteyen işlemlerden önceki yeniden
/// Google girişi (`reauthentication-required`; CLAUDE.md "Hesap silme",
/// Tayfam-Api ADR-0021 §6). Hesap silme ve veri dışa aktarma indirmesi
/// aynı akışı kullanır.
///
/// 1. Google'dan ID token alınır (`POST /v1/auth/sign-in`).
/// 2. Gelen oturumun kullanıcısının bu oturumun kullanıcısı olduğu, eski
///    oturumla `GET /v1/me/account`'un `user_id` alanından doğrulanır.
///    Başka bir hesap seçildiyse ya da yeni (kaydı bekleyen) bir hesap
///    açıldıysa [FarkliHesapHatasi]; yeni oturum kullanılmaz.
/// 3. Yeni oturum `SessionStore`'a verilir.
///
/// ID token, nonce ve kullanıcı kimliği saklanmaz, loglanmaz.
final class YenidenGiris {
  YenidenGiris({
    required this._google,
    required this._hesap,
    required this._platform,
    required this._profil,
    required this._oturum,
  });

  final GoogleKimlikSaglayici _google;
  final HesapDeposu _hesap;
  final String _platform;
  final ProfilDeposu _profil;
  final SessionStore _oturum;

  /// Akışı yürütür. Yeni oturum açıldıysa `true`; kullanıcı Google
  /// penceresini kapattıysa `false` (hiçbir istek gönderilmez).
  Future<bool> yap() async {
    final kimlik = await _google.girisYap();
    if (kimlik == null) return false;
    final yeni = await _hesap.girisYap(kimlik, platform: _platform);
    if (yeni.registrationPending || !await _profil.kendisiMi(yeni.userId)) {
      throw const FarkliHesapHatasi();
    }
    await _oturum.oturumAc(yeni);
    return true;
  }
}

/// Yeniden giriş akışı.
final yenidenGirisProvider = Provider<YenidenGiris>(
  (ref) => YenidenGiris(
    google: ref.watch(googleKimlikSaglayiciProvider),
    hesap: ref.watch(hesapDeposuProvider),
    platform: ref.watch(hesapPlatformuProvider),
    profil: ref.watch(profilDeposuProvider),
    oturum: ref.watch(sessionStoreProvider),
  ),
  name: 'yenidenGirisProvider',
);
