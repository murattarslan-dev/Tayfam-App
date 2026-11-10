import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:http/http.dart' as http;

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/api/gen/transport.dart';
import 'package:tayfam/core/surum/uygulama_surumu.dart';

/// Tek satırlık API günlüğü yazıcısı.
///
/// Satırda yalnızca yöntem, yol şablonu, durum kodu ve problem türü
/// bulunur; token, gövde, gerçek kimlik veya tam adres bulunmaz (CLAUDE.md
/// kesin kural 3).
typedef ApiGunlugu = void Function(String satir);

/// Varsayılan günlük: `dart:developer` (yalnızca hata ayıklama araçlarında
/// görünür; analitiğe veya hata raporuna gitmez).
void varsayilanApiGunlugu(String satir) =>
    developer.log(satir, name: 'tayfam.api');

/// Ham HTTP katmanı (ADR-0005): adres, ortak başlıklar, zaman aşımı,
/// problem ayrıştırma ve günlük.
///
/// Token'ı kendisi bilmez; `Authorization` başlığını yalnızca `ApiClient`
/// [gonder]'e verdiği erişim token'ıyla ekler. [ApiTransport] olarak
/// yalnızca kimlik doğrulamasız (`security: []`) uçları gönderir; bu sayede
/// `SessionStore` yenileme ve yoklama isteklerini döngüye girmeden bununla
/// yapar.
final class HttpTasima implements ApiTransport {
  HttpTasima({
    required this._istemci,
    required Uri tabanAdres,
    required String istemciAdi,
    String? surumBasligi,
    this._zamanAsimi = const Duration(seconds: 30),
    this._gunluk = varsayilanApiGunlugu,
  }) : _taban = _tabanDogrula(tabanAdres),
       _istemciAdi = _istemciAdiDogrula(istemciAdi),
       _surumBasligi = _surumBasligiDogrula(surumBasligi);

  final http.Client _istemci;
  final Uri _taban;
  final String _istemciAdi;

  /// `X-Tayfam-Client-Version` değeri; `null` ise başlık gönderilmez.
  final String? _surumBasligi;

  final StreamController<void> _eskiSurum = StreamController<void>.broadcast();

  /// Herhangi bir istek `client-outdated` (426) aldıkça bir olay; arayüz
  /// "Güncelleme gerekli" ekranına geçer (ADR-0012 §1).
  Stream<void> get eskiSurumOlaylari => _eskiSurum.stream;

  /// Olay akışını kapatır (provider bırakılınca).
  Future<void> dispose() => _eskiSurum.close();
  final Duration _zamanAsimi;
  final ApiGunlugu _gunluk;

  static final RegExp _yerTutucu = RegExp(r'\{([^}]+)\}');

  /// Sözleşmedeki `X-Tayfam-Client` değerleri (`web` yalnızca prod dışı,
  /// ADR-0011).
  static const Set<String> istemciAdlari = {'android', 'ios', 'web'};

  static Uri _tabanDogrula(Uri adres) {
    if (adres.scheme != 'https' ||
        adres.host.isEmpty ||
        adres.userInfo.isNotEmpty ||
        adres.hasQuery ||
        adres.hasFragment) {
      throw ArgumentError('API taban adresi yalnızca https olabilir');
    }
    return adres;
  }

  static String? _surumBasligiDogrula(String? baslik) {
    if (baslik != null && !surumBasligiBicimi.hasMatch(baslik)) {
      throw ArgumentError('Geçersiz X-Tayfam-Client-Version değeri');
    }
    return baslik;
  }

  static String _istemciAdiDogrula(String ad) {
    if (!istemciAdlari.contains(ad)) {
      throw ArgumentError('Geçersiz X-Tayfam-Client değeri');
    }
    return ad;
  }

  @override
  Future<Object?> send({
    required String method,
    required String pathTemplate,
    required bool authenticated,
    Map<String, String> pathParams = const {},
    Map<String, String> query = const {},
    Object? body,
    ResponseKind expect = ResponseKind.json,
  }) {
    if (authenticated) {
      // Kimlikli uçlar yalnızca ApiClient'tan geçer (token ve yenileme).
      throw StateError('$pathTemplate kimlik doğrulaması ister; ApiClient');
    }
    return gonder(
      method: method,
      pathTemplate: pathTemplate,
      pathParams: pathParams,
      query: query,
      body: body,
      expect: expect,
    );
  }

  /// İsteği gönderir. [erisimTokeni] verilirse `Authorization: Bearer`
  /// eklenir; yalnızca `ApiClient` verir.
  ///
  /// Hata yanıtında [ApiProblem], bağlantı hatasında [ApiOffline], süre
  /// aşımında [ApiTimeout] fırlatır.
  Future<Object?> gonder({
    required String method,
    required String pathTemplate,
    Map<String, String> pathParams = const {},
    Map<String, String> query = const {},
    Object? body,
    ResponseKind expect = ResponseKind.json,
    String? erisimTokeni,
  }) async {
    final adres = _adres(pathTemplate, pathParams, query);
    final istek = http.Request(method, adres)
      ..followRedirects = false
      ..headers.addAll(_basliklar(method, expect, erisimTokeni));
    if (body != null) {
      istek
        ..headers['Content-Type'] = 'application/json'
        ..body = jsonEncode(body);
    }

    final http.Response yanit;
    try {
      yanit = await _istemci
          .send(istek)
          .then(http.Response.fromStream)
          .timeout(_zamanAsimi);
    } on TimeoutException {
      _gunluk('$method $pathTemplate → zaman aşımı');
      throw const ApiTimeout();
    } on http.ClientException {
      _gunluk('$method $pathTemplate → bağlantı yok');
      throw const ApiOffline();
    }

    final durum = yanit.statusCode;
    if (durum < 200 || durum > 299) {
      final problem = _problem(yanit);
      _gunluk('$method $pathTemplate → $durum ${problem.type.name}');
      if (problem.type == ProblemType.clientOutdated && !_eskiSurum.isClosed) {
        _eskiSurum.add(null);
      }
      throw problem;
    }
    _gunluk('$method $pathTemplate → $durum');

    switch (expect) {
      case ResponseKind.none:
        return null;
      case ResponseKind.text:
        return utf8.decode(yanit.bodyBytes);
      case ResponseKind.json:
        return jsonDecode(utf8.decode(yanit.bodyBytes));
    }
  }

  Map<String, String> _basliklar(
    String method,
    ResponseKind expect,
    String? erisimTokeni,
  ) => {
    'Accept': switch (expect) {
      ResponseKind.text => 'text/*, application/problem+json',
      _ => 'application/json, application/problem+json',
    },
    // Durum değiştiren her istekte zorunlu (sözleşme: ClientHeader).
    if (method != 'GET' && method != 'HEAD') 'X-Tayfam-Client': _istemciAdi,
    // Her istekte (sözleşme: ClientVersionHeader, Tayfam-Api ADR-0016).
    'X-Tayfam-Client-Version': ?_surumBasligi,
    if (erisimTokeni != null) 'Authorization': 'Bearer $erisimTokeni',
  };

  /// Şablondaki `{ad}` yer tutucularını [parametreler]'deki ham değerlerle
  /// doldurur; her parça ayrı ayrı yüzde kodlanır. Hata mesajında değer
  /// yoktur, yalnızca şablon ve ad vardır.
  Uri _adres(
    String sablon,
    Map<String, String> parametreler,
    Map<String, String> sorgu,
  ) {
    if (!sablon.startsWith('/')) {
      throw ArgumentError('$sablon: yol / ile başlamalı');
    }
    final kullanilan = <String>{};
    final parcalar = [
      ..._taban.pathSegments.where((p) => p.isNotEmpty),
      for (final parca in sablon.substring(1).split('/'))
        parca.replaceAllMapped(_yerTutucu, (eslesme) {
          final ad = eslesme[1]!;
          final deger = parametreler[ad];
          if (!_gecerliDeger(deger)) {
            throw ArgumentError('$sablon: {$ad} eksik ya da geçersiz');
          }
          kullanilan.add(ad);
          return deger!;
        }),
    ];
    if (kullanilan.length != parametreler.length) {
      throw ArgumentError('$sablon: şablonda olmayan yol parametresi');
    }
    return _taban.replace(
      pathSegments: parcalar,
      queryParameters: sorgu.isEmpty ? null : sorgu,
    );
  }

  /// Boş değer ve nokta parçaları (`.`, `..`) yolu değiştirebileceği için
  /// reddedilir.
  static bool _gecerliDeger(String? deger) =>
      deger != null && deger.isNotEmpty && deger != '.' && deger != '..';

  /// Hata yanıtını [ApiProblem]'e çevirir. `title` ve `detail` okunmaz.
  ApiProblem _problem(http.Response yanit) {
    var type = ProblemType.unknown;
    final tur = yanit.headers['content-type'] ?? '';
    if (tur.startsWith('application/problem+json')) {
      try {
        final json = jsonDecode(utf8.decode(yanit.bodyBytes));
        if (json is Map<String, Object?>) {
          type = problemTypeOku(json['type']);
        }
      } on FormatException {
        type = ProblemType.unknown;
      }
    }
    final bekle = int.tryParse(yanit.headers['retry-after']?.trim() ?? '');
    return ApiProblem(
      type: type,
      status: yanit.statusCode,
      retryAfter: bekle == null || bekle < 0 ? null : Duration(seconds: bekle),
    );
  }
}
