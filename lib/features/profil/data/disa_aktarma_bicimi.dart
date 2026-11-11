import 'dart:convert';
import 'dart:typed_data';

import 'package:tayfam/core/dogrulama/kimlik.dart';

/// Veri dışa aktarmanın indirme ve çözme adımındaki hata türü (ADR-0022).
enum DisaAktarmaHataTuru {
  /// Sunucunun verdiği bilgi ya da indirilen dosya beklenen biçimde değil
  /// (bilinmeyen biçim, yanlış uzunlukta anahtar, bozuk başlık, kısa ya da
  /// büyük dosya, çözülen içerik zip değil).
  bicim,

  /// Dosya indirilemedi (bağlantı, süre, link süresi doldu).
  indirilemedi,

  /// Etiket doğrulanamadı: dosya bu anahtar ve talep için değil ya da
  /// bozulmuş. Doğrulanmamış içerik hiçbir zaman kullanılmaz.
  cozulemedi,

  /// Bu derlemede indirme yok (web geliştirme derlemesi, ADR-0011).
  desteklenmiyor,
}

/// Veri dışa aktarma indirmesi başarısız. Mesajda link, anahtar ya da
/// içerik yoktur (CLAUDE.md kesin kural 3).
final class DisaAktarmaHatasi implements Exception {
  const DisaAktarmaHatasi(this.tur);

  final DisaAktarmaHataTuru tur;

  @override
  bool operator ==(Object other) =>
      other is DisaAktarmaHatasi && other.tur == tur;

  @override
  int get hashCode => tur.hashCode;

  @override
  String toString() => 'DisaAktarmaHatasi(${tur.name})';
}

/// Şifreli dışa aktarma dosyasının parçaları.
final class SifreliDisaAktarma {
  const SifreliDisaAktarma({
    required this.nonce,
    required this.sifreliVeEtiket,
  });

  /// 12 baytlık nonce.
  final Uint8List nonce;

  /// AES-256-GCM şifreli metin ve sondaki 16 baytlık etiket.
  final Uint8List sifreliVeEtiket;
}

/// Tayfam-Api `docs/data-export-format.md` "Şifreli dosya
/// (`aes-256-gcm-v1`)":
///
/// ```
/// bayt 0     : 0x01 (biçim sürümü)
/// bayt 1..12 : nonce (12 bayt)
/// bayt 13..  : AES-256-GCM şifreli metin + 16 baytlık etiket
/// AAD        : "tayfam/data-export/v1/" (ASCII) + talep UUID'sinin 16 baytı
/// ```
///
/// Bu dosya yalnızca biçimi ayrıştırır; kriptografi yoktur (çözme Signal
/// köprüsündedir, CLAUDE.md kesin kural 4).
abstract final class DisaAktarmaBicimi {
  /// Biçim sürümü baytı.
  static const int surum = 0x01;

  /// Nonce uzunluğu.
  static const int nonceUzunlugu = 12;

  /// GCM etiketinin uzunluğu.
  static const int etiketUzunlugu = 16;

  /// AES-256 anahtar uzunluğu.
  static const int anahtarUzunlugu = 32;

  /// Başlık ve etiket: boş düz metinli dosyanın boyutu.
  static const int ekBoyut = 1 + nonceUzunlugu + etiketUzunlugu;

  /// Sıkıştırılmış zip'in sunucudaki üst sınırı (16 MiB).
  static const int zipEnCok = 16 * 1024 * 1024;

  /// Şifreli dosyanın üst sınırı (16 MiB + 29 bayt).
  static const int dosyaEnCok = zipEnCok + ekBoyut;

  /// AAD'nin ASCII öneki (22 bayt).
  static const String aadOneki = 'tayfam/data-export/v1/';

  /// [dosya]'yı parçalarına ayırır. Sürüm baytı yanlışsa, dosya
  /// başlık + etiketten kısaysa ya da üst sınırı aşıyorsa
  /// [DisaAktarmaHataTuru.bicim].
  static SifreliDisaAktarma ayristir(Uint8List dosya) {
    if (dosya.length <= ekBoyut ||
        dosya.length > dosyaEnCok ||
        dosya[0] != surum) {
      throw const DisaAktarmaHatasi(DisaAktarmaHataTuru.bicim);
    }
    return SifreliDisaAktarma(
      nonce: Uint8List.sublistView(dosya, 1, 1 + nonceUzunlugu),
      sifreliVeEtiket: Uint8List.sublistView(dosya, 1 + nonceUzunlugu),
    );
  }

  /// [talepId] için AAD: önek + UUID'nin 16 baytı (ağ sırası). UUID
  /// biçiminde değilse [DisaAktarmaHataTuru.bicim].
  static Uint8List aad(String talepId) {
    if (!uuidBicimindeMi(talepId)) {
      throw const DisaAktarmaHatasi(DisaAktarmaHataTuru.bicim);
    }
    final hex = talepId.replaceAll('-', '');
    return Uint8List.fromList([
      ...ascii.encode(aadOneki),
      for (var i = 0; i < 32; i += 2)
        int.parse(hex.substring(i, i + 2), radix: 16),
    ]);
  }

  /// Sunucunun verdiği base64 anahtarı çözer; 32 bayt değilse
  /// [DisaAktarmaHataTuru.bicim].
  static Uint8List anahtar(String base64Anahtar) {
    final Uint8List baytlar;
    try {
      baytlar = base64.decode(base64Anahtar);
    } on FormatException {
      throw const DisaAktarmaHatasi(DisaAktarmaHataTuru.bicim);
    }
    if (baytlar.length != anahtarUzunlugu) {
      throw const DisaAktarmaHatasi(DisaAktarmaHataTuru.bicim);
    }
    return baytlar;
  }

  /// Çözülen içerik bir zip mi (yerel dosya başlığı `PK\x03\x04` ya da boş
  /// arşivin `PK\x05\x06` imzası).
  static bool zipMi(Uint8List icerik) =>
      icerik.length >= 22 &&
      icerik[0] == 0x50 &&
      icerik[1] == 0x4b &&
      ((icerik[2] == 0x03 && icerik[3] == 0x04) ||
          (icerik[2] == 0x05 && icerik[3] == 0x06));
}
