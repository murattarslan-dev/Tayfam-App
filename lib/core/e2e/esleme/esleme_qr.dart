import 'package:flutter/foundation.dart';

import 'package:tayfam/core/dogrulama/kimlik.dart';
import 'package:tayfam/core/e2e/esleme/esleme_hatasi.dart';
import 'package:tayfam/core/e2e/gecmis/anahtar_paketi.dart';

/// QR içeriğinin öneki ve biçim sürümü.
const String eslemeQrOneki = 'tayfam-esle:v1:';

/// Signal kimlik açık anahtarı uzunluğu (tür baytı 0x05 + 32).
const int kimlikAnahtariUzunlugu = 33;

/// Doğrulama kodu uzunluğu.
const int dogrulamaKoduUzunlugu = 16;

/// Kabul edilen en uzun QR metni (geçerli içerik ~160 karakter).
const int eslemeQrEnUzun = 256;

/// QR eşleştirme içeriği (ADR-0020):
/// `tayfam-esle:v1:<link_request_id>:<device_id>:<kimlik>:<kod>`.
///
/// - `link_request_id`, `device_id`: yeni cihazın eşleştirme isteği ve
///   sunucudaki cihaz kimliği (UUID).
/// - `kimlik`: yeni cihazın Signal kimlik açık anahtarı (33 bayt, dolgusuz
///   base64url).
/// - `kod`: `Random.secure()` ile 16 bayt tek kullanımlık doğrulama kodu
///   (dolgusuz base64url). Sunucuya hiç gitmez; yalnızca şifreli cevabın
///   içinde döner.
///
/// `toString` içerik yazmaz.
@immutable
final class EslemeQr {
  EslemeQr({
    required this.istekId,
    required this.cihazId,
    required Uint8List kimlikAnahtari,
    required Uint8List kod,
  }) : kimlikAnahtari = Uint8List.fromList(kimlikAnahtari),
       kod = Uint8List.fromList(kod) {
    if (!uuidBicimindeMi(istekId) ||
        !uuidBicimindeMi(cihazId) ||
        !_gecerliKimlik(kimlikAnahtari) ||
        kod.length != dogrulamaKoduUzunlugu) {
      throw const EslemeHatasi(EslemeHataTuru.qrGecersiz);
    }
  }

  final String istekId;
  final String cihazId;
  final Uint8List kimlikAnahtari;
  final Uint8List kod;

  static bool _gecerliKimlik(Uint8List k) =>
      k.length == kimlikAnahtariUzunlugu && k[0] == 0x05;

  /// QR'a yazılan metin.
  String kodla() =>
      '$eslemeQrOneki$istekId:$cihazId:'
      '${b64urlKodla(kimlikAnahtari)}:${b64urlKodla(kod)}';

  /// Taranan [metin]'i ayrıştırır ve biçimini doğrular (önek, alan sayısı,
  /// UUID'ler, uzunluklar). Geçersizse [EslemeHataTuru.qrGecersiz].
  /// Kimlik anahtarının sunucudaki cihazla eşleşmesi ayrıca denetlenir.
  static EslemeQr ayristir(String metin) {
    const hata = EslemeHatasi(EslemeHataTuru.qrGecersiz);
    if (metin.length > eslemeQrEnUzun || !metin.startsWith(eslemeQrOneki)) {
      throw hata;
    }
    final alanlar = metin.substring(eslemeQrOneki.length).split(':');
    if (alanlar.length != 4) throw hata;
    final kimlik = b64urlCoz(alanlar[2]);
    final kod = b64urlCoz(alanlar[3]);
    if (kimlik == null || kod == null) throw hata;
    return EslemeQr(
      istekId: alanlar[0],
      cihazId: alanlar[1],
      kimlikAnahtari: kimlik,
      kod: kod,
    );
  }

  @override
  String toString() => 'EslemeQr(…)';
}
