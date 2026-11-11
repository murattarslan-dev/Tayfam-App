import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import 'package:tayfam/core/api/api_ayarlari.dart';
import 'package:tayfam/core/surum/uygulama_surumu.dart';

/// Ad aramasının bir sonucu: OpenStreetMap'teki yerin adı ve koordinatı;
/// adres ayrıntısı varsa il ve ilçe önerisi.
@immutable
final class YerSonucu {
  const YerSonucu({
    required this.ad,
    required this.enlem,
    required this.boylam,
    this.il,
    this.ilce,
  });

  /// Nominatim'in gösterim adı (`display_name`).
  final String ad;

  final double enlem;
  final double boylam;

  /// İl önerisi; adres ayrıntısında yoksa `null`.
  final String? il;

  /// İlçe önerisi; adres ayrıntısında yoksa `null`.
  final String? ilce;

  @override
  bool operator ==(Object other) =>
      other is YerSonucu &&
      other.ad == ad &&
      other.enlem == enlem &&
      other.boylam == boylam &&
      other.il == il &&
      other.ilce == ilce;

  @override
  int get hashCode => Object.hash(ad, enlem, boylam, il, ilce);
}

/// Ad araması yapılamadı (ağ, zaman aşımı, beklenmeyen yanıt). Ayrıntı
/// taşımaz: aranan metin ve yanıt hiçbir yere yazılmaz.
final class YerAramaHatasi implements Exception {
  const YerAramaHatasi();

  @override
  String toString() => 'YerAramaHatasi';
}

/// Buluşma noktası seçicisinin ad araması (ADR-0015 §4). Testlerde sahtesi
/// verilir.
abstract interface class YerArayici {
  /// [metin]'i arar. Boş metin için istek gönderilmez, boş liste döner.
  /// Hata durumunda [YerAramaHatasi] fırlatır.
  Future<List<YerSonucu>> ara(String metin);
}

/// OpenStreetMap Nominatim ile ad araması (ADR-0015 §4).
///
/// - API istemcisinden (`ApiClient`) ayrıdır: Tayfam sunucusuna değil
///   OSM'ye gider; `Authorization` ve Tayfam başlıkları gönderilmez.
/// - Nominatim kullanım kuralı: uygulamayı tanıtan [kullaniciAjani]
///   gönderilir, saniyede en çok bir istek ([enAzAralik]; istekler sıraya
///   alınır) ve otomatik tamamlama yoktur (arama yalnızca kullanıcı "Ara"ya
///   basınca çağrılır).
/// - Aranan metin, adres ve yanıt log'a yazılmaz; sonuçlar yalnızca
///   bellektedir.
final class NominatimArayici implements YerArayici {
  NominatimArayici({
    required http.Client istemci,
    DateTime Function()? saat,
    Future<void> Function(Duration sure)? bekle,
    this.ulkeKodlari = varsayilanUlkeKodlari,
    this.zamanAsimi = const Duration(seconds: 15),
  }) : _istemci = istemci,
       _saat = saat ?? DateTime.now,
       _bekle = bekle ?? Future<void>.delayed;

  final http.Client _istemci;
  final DateTime Function() _saat;
  final Future<void> Function(Duration sure) _bekle;

  /// `countrycodes` değeri; boşsa gönderilmez.
  final String ulkeKodlari;

  /// Bir isteğin en uzun süresi.
  final Duration zamanAsimi;

  /// Varsayılan ülke kısıtı: Türkiye.
  static const String varsayilanUlkeKodlari = 'tr';

  /// İki istek arasındaki en kısa süre (Nominatim: saniyede en çok bir).
  static const Duration enAzAralik = Duration(seconds: 1);

  /// İstenen en çok sonuç.
  static const int enCokSonuc = 10;

  /// Nominatim arama adresi.
  static final Uri aramaAdresi = Uri.https(
    'nominatim.openstreetmap.org',
    '/search',
  );

  /// Uygulamayı tanıtan `User-Agent` (Nominatim kullanım kuralı).
  static final String kullaniciAjani =
      'Tayfam/${uygulamaSurumu.isEmpty ? '0' : uygulamaSurumu} '
      '(+https://tayfam.app)';

  DateTime? _sonIstek;
  Future<void> _sira = Future<void>.value();

  @override
  Future<List<YerSonucu>> ara(String metin) {
    final sonuc = _sira.then((_) => _ara(metin));
    _sira = sonuc.then<void>((_) {}, onError: (Object _) {});
    return sonuc;
  }

  Future<List<YerSonucu>> _ara(String metin) async {
    final sorgu = metin.trim();
    if (sorgu.isEmpty) return const [];
    final son = _sonIstek;
    if (son != null) {
      final gecen = _saat().difference(son);
      if (gecen < enAzAralik) await _bekle(enAzAralik - gecen);
    }
    _sonIstek = _saat();
    final adres = aramaAdresi.replace(
      queryParameters: {
        'q': sorgu,
        'format': 'jsonv2',
        'accept-language': 'tr',
        if (ulkeKodlari.isNotEmpty) 'countrycodes': ulkeKodlari,
        'addressdetails': '1',
        'limit': '$enCokSonuc',
      },
    );
    final http.Response yanit;
    try {
      yanit = await _istemci
          .get(
            adres,
            headers: {
              'User-Agent': kullaniciAjani,
              'Accept': 'application/json',
            },
          )
          .timeout(zamanAsimi);
    } on Exception {
      throw const YerAramaHatasi();
    }
    if (yanit.statusCode != 200) throw const YerAramaHatasi();
    return yerSonuclariniOku(yanit.bodyBytes);
  }
}

/// Nominatim `jsonv2` yanıtını okur. Koordinatı ya da adı geçersiz olan
/// satır atlanır; yanıt liste değilse [YerAramaHatasi].
@visibleForTesting
List<YerSonucu> yerSonuclariniOku(List<int> govde) {
  final Object? belge;
  try {
    belge = jsonDecode(utf8.decode(govde));
  } on FormatException {
    throw const YerAramaHatasi();
  }
  if (belge is! List<Object?>) throw const YerAramaHatasi();
  final sonuc = <YerSonucu>[];
  for (final oge in belge) {
    if (sonuc.length >= NominatimArayici.enCokSonuc) break;
    if (oge is! Map<String, Object?>) continue;
    final enlem = _sayi(oge['lat']);
    final boylam = _sayi(oge['lon']);
    final ad = oge['display_name'];
    if (enlem == null || boylam == null || ad is! String) continue;
    if (ad.trim().isEmpty) continue;
    if (enlem < -90 || enlem > 90 || boylam < -180 || boylam > 180) continue;
    final adres = oge['address'];
    final ayrinti = adres is Map<String, Object?>
        ? adres
        : const <String, Object?>{};
    sonuc.add(
      YerSonucu(
        ad: _kisalt(ad.trim(), _adEnCok),
        enlem: enlem,
        boylam: boylam,
        il: _ilkDolu(ayrinti, const ['province', 'state', 'city']),
        ilce: _ilkDolu(ayrinti, const [
          'town',
          'county',
          'city_district',
          'district',
          'suburb',
        ]),
      ),
    );
  }
  return List.unmodifiable(sonuc);
}

const int _adEnCok = 300;
const int _adresParcasiEnCok = 50;

double? _sayi(Object? deger) {
  final sayi = switch (deger) {
    final String s => double.tryParse(s),
    final num n => n.toDouble(),
    _ => null,
  };
  return sayi != null && sayi.isFinite ? sayi : null;
}

String? _ilkDolu(Map<String, Object?> ayrinti, List<String> anahtarlar) {
  for (final anahtar in anahtarlar) {
    final deger = ayrinti[anahtar];
    if (deger is String && deger.trim().isNotEmpty) {
      return _kisalt(deger.trim(), _adresParcasiEnCok);
    }
  }
  return null;
}

String _kisalt(String metin, int enCok) {
  final harfler = metin.runes;
  if (harfler.length <= enCok) return metin;
  return String.fromCharCodes(harfler.take(enCok));
}

/// Uygulamanın yer arayıcısı. Uygulama boyunca tektir; böylece saniyede
/// bir istek sınırı bütün seçiciler için geçerlidir.
final yerArayiciProvider = Provider<YerArayici>(
  (ref) => NominatimArayici(istemci: ref.watch(httpClientProvider)),
  name: 'yerArayiciProvider',
);
