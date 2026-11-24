import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/features/hesap/data/nonce.dart';

/// Apple ile girişin sonucu (ADR-0034 §5, Tayfam-Api ADR-0045). Yalnızca
/// bellekte, giriş (ya da hesap silme) isteği gönderilene kadar yaşar;
/// `toString` içerik yazmaz.
@immutable
final class AppleKimligi {
  const AppleKimligi({
    required this.idToken,
    required this.nonce,
    required this.yetkilendirmeKodu,
    required this.ad,
  });

  /// Yalnızca `POST /v1/auth/sign-in` gövdesine gider; saklanmaz,
  /// loglanmaz.
  final String idToken;

  /// Apple'a verilen ve kimlik token'ına bağlanan nonce (aynı istekle
  /// gönderilir; Google ile aynı kural).
  final String nonce;

  /// Apple'ın bu yetkilendirme için verdiği tek kullanımlık kod (yaklaşık
  /// 5 dakika geçerli). Yalnızca hesap silmede `DELETE /v1/me` gövdesine
  /// gider: sunucu onunla kullanıcının Apple token'larını iptal eder
  /// (Tayfam-Api ADR-0045 §4). Saklanmaz, loglanmaz.
  final String yetkilendirmeKodu;

  /// Apple'ın yalnızca ilk yetkilendirmede verdiği ad; kimlik token'ında
  /// yoktur. Yalnızca kayıt formunu önceden doldurmak için.
  final String? ad;

  @override
  String toString() => 'AppleKimligi(…)';
}

/// Apple ile giriş başlatılamadı ya da yarıda kesildi (kullanıcının
/// pencereyi kapatması bu değildir; o durumda `null` döner).
final class AppleGirisHatasi implements Exception {
  const AppleGirisHatasi({this.desteklenmiyor = false});

  /// Bu platformda Apple ile giriş yok (Android, web geliştirme derlemesi
  /// ya da köprüsü olmayan derleme).
  final bool desteklenmiyor;

  @override
  String toString() => 'AppleGirisHatasi';
}

/// Apple'ın giriş penceresinin arkasındaki arayüz; testler sahtesini
/// kullanır.
abstract interface class AppleKimlikSaglayici {
  /// Apple'ın penceresini açıp kimlik token'ı ve yetkilendirme kodu alır.
  /// Kullanıcı pencereyi kapatırsa `null`; başka bir sorun varsa
  /// [AppleGirisHatasi].
  Future<AppleKimligi?> girisYap();
}

/// [AppleKimlikSaglayici]'nın iOS uygulaması: `tayfam/apple-giris` platform
/// kanalı üzerinden Swift köprüsü ve Apple'ın kendi çerçevesi
/// (AuthenticationServices). Yeni Flutter paketi yoktur (ADR-0034 §5).
///
/// Her deneme `Random.secure()` ile yeni bir nonce üretir. Kanal hata kodu
/// yalnızca [iptalKodu] için anlam taşır; mesaj ve ayrıntı okunmaz. Hiçbir
/// şey loglanmaz.
final class KanalAppleKimlikSaglayici implements AppleKimlikSaglayici {
  KanalAppleKimlikSaglayici({MethodChannel? kanal, String Function()? nonce})
    : _kanal = kanal ?? const MethodChannel(kanalAdi),
      _nonceUret = nonce ?? nonceUret;

  /// Platform kanalının adı (Swift tarafıyla aynı).
  static const String kanalAdi = 'tayfam/apple-giris';

  /// Kullanıcı Apple penceresini kapattığında köprünün verdiği hata kodu.
  static const String iptalKodu = 'iptal';

  /// Sözleşmedeki `apple_authorization_code` sınırı.
  static const int enUzunKod = 1024;

  final MethodChannel _kanal;
  final String Function() _nonceUret;

  @override
  Future<AppleKimligi?> girisYap() async {
    final nonce = _nonceUret();
    final Object? sonuc;
    try {
      sonuc = await _kanal.invokeMethod<Object?>('girisYap', {'nonce': nonce});
    } on PlatformException catch (hata) {
      if (hata.code == iptalKodu) return null;
      throw const AppleGirisHatasi();
    } on MissingPluginException {
      throw const AppleGirisHatasi(desteklenmiyor: true);
    }
    if (sonuc is! Map<Object?, Object?>) throw const AppleGirisHatasi();
    final idToken = sonuc['idToken'];
    final kod = sonuc['yetkilendirmeKodu'];
    final ad = sonuc['ad'];
    if (idToken is! String ||
        idToken.isEmpty ||
        kod is! String ||
        kod.isEmpty ||
        kod.length > enUzunKod) {
      throw const AppleGirisHatasi();
    }
    return AppleKimligi(
      idToken: idToken,
      nonce: nonce,
      yetkilendirmeKodu: kod,
      ad: ad is String && ad.trim().isNotEmpty ? ad.trim() : null,
    );
  }
}

/// Uygulamanın Apple kimlik sağlayıcısı (kalıcı; nonce her denemede
/// yenidir).
final appleKimlikSaglayiciProvider = Provider<AppleKimlikSaglayici>(
  (ref) => KanalAppleKimlikSaglayici(),
  name: 'appleKimlikSaglayiciProvider',
);
