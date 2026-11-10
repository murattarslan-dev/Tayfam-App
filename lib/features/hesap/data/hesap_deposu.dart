import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_ayarlari.dart';
import 'package:tayfam/core/api/api_client.dart';
import 'package:tayfam/core/api/gen/apis/auth_api.dart';
import 'package:tayfam/core/api/gen/apis/me_api.dart';
import 'package:tayfam/core/api/gen/apis/registration_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/transport.dart';
import 'package:tayfam/features/hesap/data/google_kimligi.dart';
import 'package:tayfam/features/hesap/data/hukuki_metinler.dart';

/// Kayıt formunun gönderilecek değerleri (ADR-0012 §3). `toString`
/// içerik yazmaz (doğum tarihi kişisel veridir).
@immutable
final class KayitBilgisi {
  const KayitBilgisi({
    required this.dogumTarihi,
    required this.surumler,
    this.ad,
    this.referansKodu,
  });

  /// Yalnızca gün, ay, yıl kullanılır (`YYYY-AA-GG`).
  final DateTime dogumTarihi;

  /// Kullanıcının gördüğü ve onayladığı metin sürümleri.
  final OnaySurumleri surumler;

  /// Google adından farklıysa yeni görünen ad; aynıysa `null` (gönderilmez).
  final String? ad;

  /// İsteğe bağlı referans kodu.
  final String? referansKodu;

  @override
  String toString() => 'KayitBilgisi(…)';
}

/// `YYYY-AA-GG` (saat dilimsiz tarih; sözleşme: `birth_date`).
String tarihMetni(DateTime tarih) {
  String iki(int sayi) => sayi.toString().padLeft(2, '0');
  return '${tarih.year.toString().padLeft(4, '0')}-${iki(tarih.month)}-'
      '${iki(tarih.day)}';
}

/// Giriş, kayıt ve yeniden onay uçları (ADR-0012). Yalnızca üretilmiş uç
/// sınıflarını kullanır; arayüze ham API modeli yerine [OnaySurumleri]
/// verir.
final class HesapDeposu {
  HesapDeposu(ApiTransport istemci)
    : _auth = AuthApi(istemci),
      _kayit = RegistrationApi(istemci),
      _me = MeApi(istemci);

  final AuthApi _auth;
  final RegistrationApi _kayit;
  final MeApi _me;

  /// `POST /v1/auth/sign-in`. ID token ve nonce yalnızca gövdeye gider.
  Future<Session> girisYap(GoogleKimligi kimlik, {required String platform}) {
    return _auth.signIn(
      body: SignInRequest(
        provider: SignInRequestProvider.google,
        idToken: kimlik.idToken,
        nonce: kimlik.nonce,
        platform: SignInRequestPlatform.fromWire(platform),
      ),
    );
  }

  /// `GET /v1/registration/requirements`. Sürümler geçersizse
  /// [FormatException].
  Future<OnaySurumleri> kayitGereksinimleri() async {
    final gereksinim = await _kayit.getRegistrationRequirements();
    return OnaySurumleri.olustur(
      aydinlatma: gereksinim.privacyNoticeVersion,
      kosullar: gereksinim.termsVersion,
    );
  }

  /// `POST /v1/registration` (204).
  Future<void> kayitOl(KayitBilgisi bilgi) {
    return _kayit.completeRegistration(
      body: RegistrationRequest(
        birthDate: tarihMetni(bilgi.dogumTarihi),
        displayName: bilgi.ad,
        acceptedPrivacyNoticeVersion: bilgi.surumler.aydinlatma,
        acceptedTermsVersion: bilgi.surumler.kosullar,
        referralCode: bilgi.referansKodu,
      ),
    );
  }

  /// `GET /v1/me/consents`: güncel sürümler. Geçersizse [FormatException].
  Future<OnaySurumleri> onaySurumleri() async {
    final durum = await _me.getConsents();
    return OnaySurumleri.olustur(
      aydinlatma: durum.privacyNoticeVersion,
      kosullar: durum.termsVersion,
    );
  }

  /// `POST /v1/me/consents`: gösterilen sürümleri onaylar (204).
  Future<void> onayla(OnaySurumleri surumler) {
    return _me.acceptConsents(
      body: ConsentRequest(
        privacyNoticeVersion: surumler.aydinlatma,
        termsVersion: surumler.kosullar,
      ),
    );
  }
}

/// Hesap uçlarının deposu; bütün istekler tek `ApiClient`'tan geçer.
final hesapDeposuProvider = Provider<HesapDeposu>(
  (ref) => HesapDeposu(ref.watch(apiClientProvider)),
  name: 'hesapDeposuProvider',
);

/// Giriş isteğindeki `platform` (ve `X-Tayfam-Client`) değeri.
final hesapPlatformuProvider = Provider<String>(
  (ref) => istemciAdi(web: kIsWeb, platform: defaultTargetPlatform),
  name: 'hesapPlatformuProvider',
);
