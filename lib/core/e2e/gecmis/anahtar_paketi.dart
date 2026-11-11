import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:tayfam/core/dogrulama/kimlik.dart';
import 'package:tayfam/core/e2e/gecmis/arsiv_bicimi.dart';
import 'package:tayfam/core/e2e/gecmis/bagimliliklar.dart';
import 'package:tayfam/core/e2e/mesaj/dolgu.dart';
import 'package:tayfam/core/e2e/signal/signal_motoru.dart';

// Kendi cihazlar arası opak paketler (eşleştirme cevabı ve anahtar
// paylaşımı): `tür(1) ‖ Signal şifreli metni` (ADR-0020). Düz metinler
// UTF-8 JSON ve 160 bayt dolgulu; anahtarlar standart base64, doğrulama
// kodu dolgusuz base64url.

/// Sunucunun kabul ettiği en büyük cevap/paylaşım (16 KiB).
const int anahtarPaketiEnFazla = 16 * 1024;

/// [s]'yi tek bayt türle birlikte paketler.
Uint8List kendiCihazPaketi(KendiCihazSifreli s) =>
    Uint8List.fromList([s.tur, ...s.sifreli]);

/// [kendiCihazPaketi]'nin tersi; tür 2 ya da 3 değilse ya da boşsa `null`.
KendiCihazSifreli? kendiCihazPaketiniAc(Uint8List paket) {
  if (paket.length < 2 || paket.length > anahtarPaketiEnFazla) return null;
  final tur = paket[0];
  if (tur != SignalMesajTuru.signal && tur != SignalMesajTuru.onAnahtar) {
    return null;
  }
  return KendiCihazSifreli(
    tur: tur,
    sifreli: Uint8List.fromList(Uint8List.sublistView(paket, 1)),
  );
}

/// Dolgusuz base64url.
String b64urlKodla(Uint8List veri) =>
    base64Url.encode(veri).replaceAll('=', '');

final RegExp _b64url = RegExp(r'^[A-Za-z0-9_-]*$');

/// Dolgusuz base64url'i çözer; başka karakter ya da geçersiz uzunlukta
/// `null`.
Uint8List? b64urlCoz(String metin) {
  if (!_b64url.hasMatch(metin) || metin.length % 4 == 1) return null;
  try {
    return base64Url.decode(base64Url.normalize(metin));
  } on FormatException {
    return null;
  }
}

/// İki bayt dizisini uzunluğa bağlı, içeriğe bağlı olmayan sürede
/// karşılaştırır (doğrulama kodu ve kimlik anahtarı).
bool sabitZamanliEsit(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  var fark = 0;
  for (var i = 0; i < a.length; i++) {
    fark |= a[i] ^ b[i];
  }
  return fark == 0;
}

List<Map<String, Object?>> _anahtarListesi(Map<int, Uint8List> anahtarlar) => [
  for (final MapEntry(:key, :value) in anahtarlar.entries)
    {'surum': key, 'anahtar': base64.encode(value)},
];

Map<int, Uint8List>? _anahtarListesiOku(Object? liste) {
  if (liste is! List<Object?> || liste.isEmpty) return null;
  final sonuc = <int, Uint8List>{};
  for (final o in liste) {
    if (o is! Map<String, Object?>) return null;
    final surum = o['surum'];
    final anahtar = o['anahtar'];
    if (surum is! int || !gecerliGecmisSurumu(surum) || anahtar is! String) {
      return null;
    }
    final Uint8List bayt;
    try {
      bayt = base64.decode(anahtar);
    } on FormatException {
      return null;
    }
    if (bayt.length != gecmisAnahtariUzunlugu || sonuc.containsKey(surum)) {
      return null;
    }
    sonuc[surum] = bayt;
  }
  return sonuc;
}

Uint8List _jsonDolgula(Map<String, Object?> json) =>
    dolguEkle(Uint8List.fromList(utf8.encode(jsonEncode(json))));

Map<String, Object?>? _jsonDolgusuzOku(Uint8List dolgulu) {
  final veri = dolguKaldir(dolgulu);
  if (veri == null) return null;
  try {
    final json = jsonDecode(utf8.decode(veri));
    return json is Map<String, Object?> ? json : null;
  } on FormatException {
    return null;
  }
}

/// Anahtar yenileme paylaşımının düz metni: `{anahtarlar: [{surum,
/// anahtar}]}`.
Uint8List paylasimDuzMetni(Map<int, Uint8List> anahtarlar) =>
    _jsonDolgula({'anahtarlar': _anahtarListesi(anahtarlar)});

/// [paylasimDuzMetni]'nin tersi; bozuksa `null`.
Map<int, Uint8List>? paylasimDuzMetniniCoz(Uint8List dolgulu) {
  final json = _jsonDolgusuzOku(dolgulu);
  if (json == null) return null;
  return _anahtarListesiOku(json['anahtarlar']);
}

/// QR eşleştirme cevabının çözülmüş hali.
@immutable
final class EslemeCevabi {
  const EslemeCevabi({
    required this.kod,
    required this.istekId,
    required this.anahtarlar,
  });

  /// QR'daki 16 baytlık doğrulama kodu.
  final Uint8List kod;

  /// `link_request_id`.
  final String istekId;

  /// Geçmiş anahtarlarının bütün sürümleri.
  final Map<int, Uint8List> anahtarlar;

  /// Düz metin: `{kod, link_request_id, anahtarlar: [{surum, anahtar}]}`.
  Uint8List kodla() => _jsonDolgula({
    'kod': b64urlKodla(kod),
    'link_request_id': istekId,
    'anahtarlar': _anahtarListesi(anahtarlar),
  });

  /// [kodla]'nın tersi; bozuksa `null`.
  static EslemeCevabi? coz(Uint8List dolgulu) {
    final json = _jsonDolgusuzOku(dolgulu);
    if (json == null) return null;
    final kod = json['kod'];
    final istek = json['link_request_id'];
    if (kod is! String || istek is! String || !uuidBicimindeMi(istek)) {
      return null;
    }
    final kodBayt = b64urlCoz(kod);
    final anahtarlar = _anahtarListesiOku(json['anahtarlar']);
    if (kodBayt == null || anahtarlar == null) return null;
    return EslemeCevabi(kod: kodBayt, istekId: istek, anahtarlar: anahtarlar);
  }

  @override
  String toString() => 'EslemeCevabi(…)';
}
