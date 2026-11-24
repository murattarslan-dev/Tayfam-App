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

/// iOS OAuth istemci kimliği (Google Cloud'da `com.murattarslan.tayfam`
/// için iOS türünde istemci; ADR-0034 §5). Public bir değerdir (CLAUDE.md
/// kesin kural 6). Dev ve prod aynı iOS uygulamasıdır; değer tektir.
/// `ios/Runner/Info.plist`'teki geri dönüş URL şeması bu kimliğin ters
/// yazılışıdır; ikisi birlikte değişir.
const String googleIosIstemciKimligi =
    '73439258394-bk26461t68cc7c2f7opa5ata0cv14h54'
    '.apps.googleusercontent.com';

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

  /// Google hesabından çıkar ki bir sonraki girişte hesap seçici kesin
  /// açılsın (ADR-0012 Notlar, issue #184). Yalnızca platformun çıkış
  /// çağrısını yapar; Tayfam sunucusuna istek gitmez. Hata fırlatmaz ve
  /// hiçbir şey loglamaz.
  Future<void> cikisYap();
}

/// `google_sign_in` ile Google girişi (Android ve iOS; ADR-0012, ADR-0034 §5).
///
/// iOS'ta istemci kimliği `initialize`'a açıkça verilir: eklenti
/// (`google_sign_in_ios`) `clientId` verilmezse `serverClientId`'yi de yok
/// sayar ve yalnızca `Info.plist`'e bakar; o zaman ortama göre değişen
/// sunucu istemci kimliği (ID token'ın `aud`'u) uygulanmazdı. Android'de
/// `clientId` verilmez.
///
/// Her giriş denemesi (yeniden giriş dahil) `Random.secure()` ile yeni bir
/// nonce üretir (ADR-0012 §2, istemci ADR-0023 §2): `google_sign_in` nonce'u
/// yalnızca `initialize` sırasında aldığı için `initialize` her denemede o
/// denemenin nonce'uyla yeniden çağrılır. Android uygulamasında
/// (`google_sign_in_android`) `init` yalnızca parametreleri saklar; olay
/// akışı olmadığı için tekrar çağrı abonelik çoğaltmaz. Google'daki çıkış her
/// girişten sonra yapılır ki hesap seçici yeniden açılsın. Nonce loglanmaz,
/// saklanmaz.
final class GoogleSignInSaglayici implements GoogleKimlikSaglayici {
  GoogleSignInSaglayici({
    GoogleSignIn? google,
    String Function()? nonce,
    TargetPlatform? platform,
  }) : _google = google ?? GoogleSignIn.instance,
       _nonceUret = nonce ?? nonceUret,
       _platform = platform;

  final GoogleSignIn _google;
  final String Function() _nonceUret;

  /// Yalnızca testler verir; verilmezse çalışılan platform.
  final TargetPlatform? _platform;

  String? get _istemciKimligi {
    if (kIsWeb) return null;
    return (_platform ?? defaultTargetPlatform) == TargetPlatform.iOS
        ? googleIosIstemciKimligi
        : null;
  }

  @override
  Future<GoogleKimligi?> girisYap() async {
    final nonce = _nonceUret();
    try {
      await _google.initialize(
        clientId: _istemciKimligi,
        serverClientId: googleSunucuIstemciKimligi,
        nonce: nonce,
      );
    } on GoogleSignInException {
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

  @override
  Future<void> cikisYap() async {
    try {
      await _google.signOut();
    } on Object {
      // Çıkış başarısızsa da giriş ekranına dönülür. Hata loglanmaz:
      // özellikler doğrudan log yazmaz ve ileti hesap bilgisi taşıyabilir.
    }
  }
}

/// Uygulamanın Google kimlik sağlayıcısı (kalıcı; nonce her denemede
/// yenidir).
final googleKimlikSaglayiciProvider = Provider<GoogleKimlikSaglayici>(
  (ref) => GoogleSignInSaglayici(),
  name: 'googleKimlikSaglayiciProvider',
);
