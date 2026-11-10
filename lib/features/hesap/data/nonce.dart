import 'dart:convert';
import 'dart:math';

/// Google ID token'ına bağlanan nonce'un bayt uzunluğu (ADR-0012 §2).
const int nonceBaytSayisi = 32;

/// `Random.secure()` ile [nonceBaytSayisi] bayt üretir ve base64url
/// (dolgusuz, 43 karakter) döndürür (ADR-0012 §2; CLAUDE.md kesin kural 4).
///
/// Nonce loglanmaz ve diske yazılmaz. [ureteci] yalnızca testler içindir.
String nonceUret([Random? ureteci]) {
  final rastgele = ureteci ?? Random.secure();
  final baytlar = List<int>.generate(
    nonceBaytSayisi,
    (_) => rastgele.nextInt(256),
  );
  return base64Url.encode(baytlar).replaceAll('=', '');
}
