import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Giriş kanıtının bağlama önekidir (Tayfam-Api ADR-0022 §2).
// kural-istisnası: elle-uc — API yolu değil, sunucuyla ortak bağlama öneki.
const String _girisOneki = 'tayfam-integrity/v1/sign-in\n';

/// Yenileme kanıtının bağlama önekidir (Tayfam-Api ADR-0022 §2).
// kural-istisnası: elle-uc — API yolu değil, sunucuyla ortak bağlama öneki.
const String _yenilemeOneki = 'tayfam-integrity/v1/refresh\n';

/// `POST /v1/auth/sign-in` kanıtının `requestHash`'i (istemci ADR-0023 §2):
/// base64url(SHA-256("tayfam-integrity/v1/sign-in\n" + nonce)), dolgusuz,
/// 43 karakter. Sonuç loglanmaz.
String girisBaglamasi(String nonce) =>
    _ozetMetni(utf8.encode('$_girisOneki$nonce'));

/// `POST /v1/auth/refresh` kanıtının `requestHash`'i (istemci ADR-0023 §2):
/// base64url(SHA-256("tayfam-integrity/v1/refresh\n" +
/// SHA-256(refresh_token))), dolgusuz; iç özet ham bayttır. Yenileme
/// token'ının kendisi bu fonksiyondan dışarı çıkmaz; Google'a yalnızca
/// özetinin özeti gider.
String yenilemeBaglamasi(String yenilemeTokeni) {
  final ic = sha256.convert(utf8.encode(yenilemeTokeni)).bytes;
  return _ozetMetni([...utf8.encode(_yenilemeOneki), ...ic]);
}

String _ozetMetni(List<int> girdi) =>
    base64Url.encode(sha256.convert(girdi).bytes).replaceAll('=', '');
