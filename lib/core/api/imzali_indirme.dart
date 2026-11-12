import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:tayfam/core/api/api_ayarlari.dart';

/// İmzalı depolama linkinden indirmenin hata türü.
enum ImzaliIndirmeHataTuru {
  /// Link `https` değil ya da biçimi bozuk.
  gecersizAdres,

  /// Bağlantı kurulamadı ya da koptu.
  baglanti,

  /// İndirme süresinde bitmedi.
  zamanAsimi,

  /// Sunucu 200 dışında bir durum döndü (ör. linkin süresi doldu).
  durum,

  /// Dosya beklenen boyutta değil ya da sınırı aşıyor.
  boyut,
}

/// İmzalı linkten indirme başarısız.
///
/// Mesajda link, sorgu (imza) ya da içerik yoktur; yalnızca tür vardır
/// (CLAUDE.md kesin kural 3).
final class ImzaliIndirmeHatasi implements Exception {
  const ImzaliIndirmeHatasi(this.tur);

  final ImzaliIndirmeHataTuru tur;

  @override
  String toString() => 'ImzaliIndirmeHatasi(${tur.name})';
}

/// Sunucunun verdiği kısa ömürlü, imzalı bir depolama linkinden (ör.
/// KVKK veri dışa aktarma dosyası; Tayfam-Api ADR-0021) dosyayı belleğe
/// indirir. Testlerde sahtesi verilir.
abstract interface class ImzaliIndirici {
  /// [adres]'teki dosyayı indirir. Dosya tam olarak [beklenenBoyut] bayt
  /// olmalıdır; [enCok]'tan büyük bir boyut hiç denenmez. Hata durumunda
  /// yalnızca [ImzaliIndirmeHatasi].
  Future<Uint8List> indir(
    Uri adres, {
    required int beklenenBoyut,
    required int enCok,
  });
}

/// `package:http` ile indirme (ADR-0022).
///
/// - İstek `ApiClient`'tan geçmez: link kendi imzasını taşır; erişim
///   token'ı, `X-Tayfam-*` başlıkları ya da çerez **gönderilmez**.
/// - Yalnızca `https`; yönlendirme izlenmez.
/// - Gövde akışla okunur; beklenen boyutu aşan yanıt kesilir.
/// - Link (imzalı sorgusuyla) hiçbir yere yazılmaz, log'lanmaz.
final class HttpImzaliIndirici implements ImzaliIndirici {
  HttpImzaliIndirici(
    this._istemci, {
    this._zamanAsimi = const Duration(minutes: 2),
  });

  final http.Client _istemci;
  final Duration _zamanAsimi;

  @override
  Future<Uint8List> indir(
    Uri adres, {
    required int beklenenBoyut,
    required int enCok,
  }) async {
    if (adres.scheme != 'https' ||
        adres.host.isEmpty ||
        adres.userInfo.isNotEmpty ||
        adres.hasFragment) {
      throw const ImzaliIndirmeHatasi(ImzaliIndirmeHataTuru.gecersizAdres);
    }
    if (beklenenBoyut <= 0 || beklenenBoyut > enCok) {
      throw const ImzaliIndirmeHatasi(ImzaliIndirmeHataTuru.boyut);
    }
    try {
      return await _indir(adres, beklenenBoyut).timeout(_zamanAsimi);
    } on TimeoutException {
      throw const ImzaliIndirmeHatasi(ImzaliIndirmeHataTuru.zamanAsimi);
    } on http.ClientException {
      throw const ImzaliIndirmeHatasi(ImzaliIndirmeHataTuru.baglanti);
    }
  }

  Future<Uint8List> _indir(Uri adres, int beklenenBoyut) async {
    final istek = http.Request('GET', adres)..followRedirects = false;
    final yanit = await _istemci.send(istek);
    if (yanit.statusCode != 200) {
      await yanit.stream.drain<void>();
      throw const ImzaliIndirmeHatasi(ImzaliIndirmeHataTuru.durum);
    }
    final uzunluk = yanit.contentLength;
    if (uzunluk != null && uzunluk != beklenenBoyut) {
      await yanit.stream.drain<void>();
      throw const ImzaliIndirmeHatasi(ImzaliIndirmeHataTuru.boyut);
    }
    final tampon = BytesBuilder(copy: false);
    await for (final parca in yanit.stream) {
      if (tampon.length + parca.length > beklenenBoyut) {
        // Döngüden çıkmak akışı iptal eder; fazlası okunmaz.
        throw const ImzaliIndirmeHatasi(ImzaliIndirmeHataTuru.boyut);
      }
      tampon.add(parca);
    }
    if (tampon.length != beklenenBoyut) {
      throw const ImzaliIndirmeHatasi(ImzaliIndirmeHataTuru.boyut);
    }
    return tampon.takeBytes();
  }
}

/// Uygulamanın imzalı link indiricisi.
final imzaliIndiriciProvider = Provider<ImzaliIndirici>(
  (ref) => HttpImzaliIndirici(ref.watch(httpClientProvider)),
  name: 'imzaliIndiriciProvider',
);
