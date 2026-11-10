import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'package:tayfam/features/hesap/data/nonce.dart';

/// API'nin kabul ettiği Google OAuth (web) istemci kimliği: ID token'ın
/// `aud`'u budur (ADR-0012 §2). Public bir değerdir (CLAUDE.md kesin kural
/// 6); ortama göre `--dart-define=TAYFAM_GOOGLE_SUNUCU_ISTEMCI=...` ile
/// değişir, verilmezse dev değeri.
const String googleSunucuIstemciKimligi = String.fromEnvironment(
  'TAYFAM_GOOGLE_SUNUCU_ISTEMCI',
  defaultValue:
      '73439258394-uhd9m0b6mkc5k8eaoup6kgh57a49on4t'
      '.apps.googleusercontent.com',
);

/// Google girişinin sonucu. Yalnızca bellekte, giriş isteği gönderilene
/// kadar yaşar; `toString` içerik yazmaz.
@immutable
final class GoogleKimligi {
  const GoogleKimligi({
    required this.idToken,
    required this.nonce,
    required this.ad,
  });

  /// Yalnızca `POST /v1/auth/sign-in` gövdesine gider; saklanmaz,
  /// loglanmaz.
  final String idToken;

  /// ID token'a bağlanan nonce (aynı istekle gönderilir).
  final String nonce;

  /// Google hesabının görünen adı; yalnızca kayıt formunu önceden
  /// doldurmak için.
  final String? ad;

  @override
  String toString() => 'GoogleKimligi(…)';
}

/// Google girişi başlatılamadı ya da yarıda kesildi (kullanıcının pencereyi
/// kapatması bu değildir; o durumda `null` döner).
final class GoogleGirisHatasi implements Exception {
  const GoogleGirisHatasi({this.desteklenmiyor = false});

  /// Bu platformda (web geliştirme derlemesi) giriş penceresi açılamıyor.
  final bool desteklenmiyor;

  @override
  String toString() => 'GoogleGirisHatasi';
}

/// Google SDK'sının arkasındaki arayüz; testler sahtesini kullanır.
abstract interface class GoogleKimlikSaglayici {
  /// Google hesabı seçtirip ID token alır. Kullanıcı pencereyi kapatırsa
  /// `null`; başka bir sorun varsa [GoogleGirisHatasi].
  Future<GoogleKimligi?> girisYap();
}

/// `google_sign_in` ile Google girişi (Android; iOS kapsam dışı, ADR-0012).
///
/// `google_sign_in` nonce'u yalnızca `initialize` sırasında aldığı için
/// uygulama süreci başına bir nonce üretilir; Google'daki çıkış her
/// girişten önce yapılır ki hesap seçici açılsın.
final class GoogleSignInSaglayici implements GoogleKimlikSaglayici {
  GoogleSignInSaglayici({GoogleSignIn? google, String Function()? nonce})
    : _google = google ?? GoogleSignIn.instance,
      _nonceUret = nonce ?? nonceUret;

  final GoogleSignIn _google;
  final String Function() _nonceUret;

  Future<String>? _hazirlik;

  Future<String> _hazirla() => _hazirlik ??= _baslat();

  Future<String> _baslat() async {
    final nonce = _nonceUret();
    await _google.initialize(
      serverClientId: googleSunucuIstemciKimligi,
      nonce: nonce,
    );
    return nonce;
  }

  @override
  Future<GoogleKimligi?> girisYap() async {
    final String nonce;
    try {
      nonce = await _hazirla();
    } on GoogleSignInException {
      _hazirlik = null;
      throw const GoogleGirisHatasi();
    }
    if (!_google.supportsAuthenticate()) {
      throw const GoogleGirisHatasi(desteklenmiyor: true);
    }
    try {
      final hesap = await _google.authenticate();
      final idToken = hesap.authentication.idToken;
      // Uygulamanın kendi oturumu Tayfam token'larıdır; Google tarafındaki
      // oturum tutulmaz.
      await _google.signOut();
      if (idToken == null || idToken.isEmpty) {
        throw const GoogleGirisHatasi();
      }
      return GoogleKimligi(
        idToken: idToken,
        nonce: nonce,
        ad: hesap.displayName,
      );
    } on GoogleSignInException catch (hata) {
      if (hata.code == GoogleSignInExceptionCode.canceled) return null;
      throw const GoogleGirisHatasi();
    }
  }
}

/// Uygulamanın Google kimlik sağlayıcısı (kalıcı: nonce süreç boyunca
/// aynıdır).
final googleKimlikSaglayiciProvider = Provider<GoogleKimlikSaglayici>(
  (ref) => GoogleSignInSaglayici(),
  name: 'googleKimlikSaglayiciProvider',
);
