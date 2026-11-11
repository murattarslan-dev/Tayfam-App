import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// İmzalı depolama linkinin hatası (ADR-0021 §4).
///
/// Linki, başlıkları ya da gövdeyi taşımaz; `toString` log'a yazılabilir
/// (CLAUDE.md kesin kural 3).
sealed class MedyaTasimaHatasi implements Exception {
  const MedyaTasimaHatasi();
}

/// Link beklenen biçimde değil (https değil, beklenen alan adında değil,
/// kullanıcı bilgisi ya da parça içeriyor) veya başlıklar tutmuyor.
final class GecersizMedyaLinki extends MedyaTasimaHatasi {
  const GecersizMedyaLinki();

  @override
  String toString() => 'GecersizMedyaLinki';
}

/// Depo 2xx dışında bir durum döndürdü (ör. süresi dolmuş link: 403).
final class MedyaDurumHatasi extends MedyaTasimaHatasi {
  const MedyaDurumHatasi(this.durum);

  final int durum;

  @override
  String toString() => 'MedyaDurumHatasi($durum)';
}

/// Bağlantı kurulamadı, koptu ya da süre aşıldı.
final class MedyaBaglantiHatasi extends MedyaTasimaHatasi {
  const MedyaBaglantiHatasi();

  @override
  String toString() => 'MedyaBaglantiHatasi';
}

/// İmzalı linklerin ait olabileceği alan adı soneki (Tayfam-Api ADR-0020
/// §7: `https://<hesap>.r2.cloudflarestorage.com`).
const String medyaAlanAdiSoneki = '.r2.cloudflarestorage.com';

/// [adres] sunucunun verdiği bir imzalı depolama linki olabilir mi:
/// yalnızca `https`, [medyaAlanAdiSoneki] ile biten bir alt alan adı,
/// kullanıcı bilgisi ve parça (`#`) yok. Sunucudan gelen veri girdidir
/// (CLAUDE.md: Doğrula).
bool medyaLinkiGecerli(Uri adres) =>
    adres.scheme == 'https' &&
    adres.userInfo.isEmpty &&
    !adres.hasFragment &&
    !adres.hasPort &&
    adres.host.length > medyaAlanAdiSoneki.length &&
    adres.host.endsWith(medyaAlanAdiSoneki);

/// İmzalı depolama linkleriyle konuşan ham HTTP katmanı (ADR-0021 §4).
///
/// [ApiClient]'tan bilerek ayrıdır: imzalı link kendisi yetkidir, bu
/// yüzden isteğe **hiçbir** Tayfam başlığı (`Authorization`,
/// `X-Tayfam-Client`, sürüm) eklenmez; erişim token'ı depolama sağlayıcısına
/// gitmez. Linkler taşıyıcı sırdır: günlüğe yalnızca yöntem ve durum kodu
/// yazılır, adres yazılmaz. Yönlendirme izlenmez.
final class MedyaTasima {
  MedyaTasima({
    required this._istemci,
    this._zamanAsimi = const Duration(seconds: 60),
    void Function(String satir)? gunluk,
  }) : _gunluk = gunluk ?? _varsayilanGunluk;

  final http.Client _istemci;
  final Duration _zamanAsimi;
  final void Function(String satir) _gunluk;

  static void _varsayilanGunluk(String satir) =>
      developer.log(satir, name: 'tayfam.medya');

  /// [govde]'yi [adres]'e `PUT` eder. [basliklar] sunucunun verdiği
  /// başlıklardır ve aynen gönderilir; `Content-Length` varsa gövdenin
  /// uzunluğuyla aynı olmalıdır (değilse istek gönderilmez).
  Future<void> yukle(
    Uri adres,
    Map<String, String> basliklar,
    Uint8List govde,
  ) async {
    if (!medyaLinkiGecerli(adres)) throw const GecersizMedyaLinki();
    final istek = http.Request('PUT', adres)..followRedirects = false;
    for (final MapEntry(:key, :value) in basliklar.entries) {
      final ad = key.trim();
      switch (_asciiKucuk(ad)) {
        case 'content-length':
          if (int.tryParse(value.trim()) != govde.length) {
            throw const GecersizMedyaLinki();
          }
        // http paketi uzunluğu gövdeden kendisi yazar.
        case 'host' || 'authorization' || 'cookie':
          // Sözleşmede yok; gelirse link güvenilmez sayılır.
          throw const GecersizMedyaLinki();
        default:
          istek.headers[ad] = value;
      }
    }
    istek.bodyBytes = govde;
    await _gonder(istek, 'PUT');
  }

  /// HTTP başlık adını (ASCII) küçük harfe çevirir; yalnızca A–Z değişir.
  static String _asciiKucuk(String ad) => String.fromCharCodes([
    for (final c in ad.codeUnits) c >= 0x41 && c <= 0x5A ? c + 0x20 : c,
  ]);

  /// [adres]'teki dosyayı indirir (yalnızca bellekte; ADR-0006).
  Future<Uint8List> indir(Uri adres) async {
    if (!medyaLinkiGecerli(adres)) throw const GecersizMedyaLinki();
    final istek = http.Request('GET', adres)..followRedirects = false;
    final yanit = await _gonder(istek, 'GET');
    return yanit.bodyBytes;
  }

  Future<http.Response> _gonder(http.Request istek, String yontem) async {
    final http.Response yanit;
    try {
      yanit = await _istemci
          .send(istek)
          .then(http.Response.fromStream)
          .timeout(_zamanAsimi);
    } on TimeoutException {
      _gunluk('$yontem medya → zaman aşımı');
      throw const MedyaBaglantiHatasi();
    } on http.ClientException {
      _gunluk('$yontem medya → bağlantı yok');
      throw const MedyaBaglantiHatasi();
    }
    _gunluk('$yontem medya → ${yanit.statusCode}');
    if (yanit.statusCode < 200 || yanit.statusCode > 299) {
      throw MedyaDurumHatasi(yanit.statusCode);
    }
    return yanit;
  }
}

/// İmzalı linkler için ayrı `http.Client` (API istemcisinden bağımsız);
/// provider bırakılınca kapanır.
final medyaHttpIstemcisiProvider = Provider<http.Client>((ref) {
  final istemci = http.Client();
  ref.onDispose(istemci.close);
  return istemci;
}, name: 'medyaHttpIstemcisiProvider');

/// İmzalı linklerle konuşan katman (yükleme `PUT`'u ve indirme).
final medyaTasimaProvider = Provider<MedyaTasima>(
  (ref) => MedyaTasima(istemci: ref.watch(medyaHttpIstemcisiProvider)),
  name: 'medyaTasimaProvider',
);
