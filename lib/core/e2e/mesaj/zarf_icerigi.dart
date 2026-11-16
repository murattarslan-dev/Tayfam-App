import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'package:tayfam/core/dogrulama/kimlik.dart';
import 'package:tayfam/core/e2e/ek/ek_sifreleme.dart';
import 'package:tayfam/core/e2e/gecmis/anahtar_paketi.dart'
    show b64urlCoz, b64urlKodla;
import 'package:tayfam/core/sohbet/paylasilan_yer.dart';

/// Görüntünün en büyük kenarı (ADR-0021: `full` en çok 1600 piksel).
const int ekOlcuEnCok = 1600;

/// Uçtan uca şifreli bir birebir mesajın içeriği (ADR-0020, istemci
/// ADR-0028 §3). Zarfın ve geçmiş arşivi kaydının düz metnindedir; yalnızca
/// bellekte yaşar, hiçbir yere yazılmaz ve loglanmaz. `toString` içerik
/// yazmaz.
@immutable
sealed class BirebirIcerik {
  const BirebirIcerik();

  /// Metin mesajında metin; diğerlerinde `null`.
  String? get metin => null;

  /// Zarf/arşiv JSON'undaki alanlar (`t` ve türün alanları).
  Map<String, Object?> alanlar();

  /// [json]'daki `t` ve türün alanlarından içerik; tanınmayan tür, eksik
  /// ya da sınır dışı alan `null` (zarf "çözülemedi" sayılır).
  static BirebirIcerik? oku(Map<String, Object?> json) => switch (json['t']) {
    'metin' => switch (json['govde']) {
      final String govde => MetinIcerigi(govde),
      _ => null,
    },
    'foto' => switch (EkAnahtari._oku(json['ek'])) {
      final EkAnahtari ek => FotografIcerigi(ek),
      null => null,
    },
    'yer' => YerIcerigi._oku(json),
    _ => null,
  };
}

/// Metin mesajı: `{t:"metin", govde}`.
final class MetinIcerigi extends BirebirIcerik {
  const MetinIcerigi(this.govde);

  final String govde;

  @override
  String get metin => govde;

  @override
  Map<String, Object?> alanlar() => {'t': 'metin', 'govde': govde};

  @override
  bool operator ==(Object other) =>
      other is MetinIcerigi && other.govde == govde;

  @override
  int get hashCode => govde.hashCode;

  @override
  String toString() => 'MetinIcerigi(…)';
}

/// Şifreli fotoğraf eki: `{t:"foto", ek:{id, anahtar, ozet, boyut, en,
/// boy}}`.
final class FotografIcerigi extends BirebirIcerik {
  const FotografIcerigi(this.ek);

  final EkAnahtari ek;

  @override
  Map<String, Object?> alanlar() => {'t': 'foto', 'ek': ek._alanlar()};

  @override
  bool operator ==(Object other) => other is FotografIcerigi && other.ek == ek;

  @override
  int get hashCode => ek.hashCode;

  @override
  String toString() => 'FotografIcerigi(…)';
}

/// Paylaşılan yer: `{t:"yer", enlem, boylam, ad?}`.
final class YerIcerigi extends BirebirIcerik {
  const YerIcerigi(this.yer);

  final PaylasilanYer yer;

  @override
  Map<String, Object?> alanlar() => {
    't': 'yer',
    'enlem': yer.enlem,
    'boylam': yer.boylam,
    'ad': ?yer.ad,
  };

  static YerIcerigi? _oku(Map<String, Object?> json) {
    final enlem = json['enlem'];
    final boylam = json['boylam'];
    final ad = json['ad'];
    if (enlem is! num || boylam is! num || (ad != null && ad is! String)) {
      return null;
    }
    final yer = PaylasilanYer(
      enlem: enlem.toDouble(),
      boylam: boylam.toDouble(),
      ad: ad as String?,
    );
    return yer.gecerliMi ? YerIcerigi(yer) : null;
  }

  @override
  bool operator ==(Object other) => other is YerIcerigi && other.yer == yer;

  @override
  int get hashCode => yer.hashCode;

  @override
  String toString() => 'YerIcerigi(…)';
}

/// Bir şifreli ekin zarftaki bilgisi: dosya kimliği, anahtar, özet, blob
/// boyutu ve görüntü ölçüleri. Anahtar yalnızca bellekte yaşar; diske ve
/// log'a yazılmaz.
@immutable
final class EkAnahtari {
  const EkAnahtari({
    required this.uploadId,
    required this.anahtar,
    required this.ozet,
    required this.boyut,
    required this.genislik,
    required this.yukseklik,
  });

  /// `attachment_upload_id`.
  final String uploadId;

  /// 32 bayt AES-256 anahtarı.
  final Uint8List anahtar;

  /// SHA-256(blob), 32 bayt.
  final Uint8List ozet;

  /// Blob'un bayt sayısı (indirme tam bu boyutta beklenir).
  final int boyut;

  /// Görüntünün ölçüleri (yer tutucunun oranı).
  final int genislik;
  final int yukseklik;

  Map<String, Object?> _alanlar() => {
    'id': uploadId,
    'anahtar': b64urlKodla(anahtar),
    'ozet': b64urlKodla(ozet),
    'boyut': boyut,
    'en': genislik,
    'boy': yukseklik,
  };

  static EkAnahtari? _oku(Object? deger) {
    if (deger is! Map<String, Object?>) return null;
    final id = deger['id'];
    final anahtar = deger['anahtar'];
    final ozet = deger['ozet'];
    final boyut = deger['boyut'];
    final en = deger['en'];
    final boy = deger['boy'];
    if (id is! String ||
        !uuidBicimindeMi(id) ||
        anahtar is! String ||
        ozet is! String ||
        boyut is! int ||
        en is! int ||
        boy is! int) {
      return null;
    }
    final a = b64urlCoz(anahtar);
    final o = b64urlCoz(ozet);
    if (a == null ||
        a.length != ekAnahtarUzunlugu ||
        o == null ||
        o.length != ekOzetUzunlugu ||
        boyut <= ekEkBayt ||
        boyut > ekEnCokBayt ||
        en < 1 ||
        en > ekOlcuEnCok ||
        boy < 1 ||
        boy > ekOlcuEnCok) {
      return null;
    }
    return EkAnahtari(
      uploadId: id,
      anahtar: a,
      ozet: o,
      boyut: boyut,
      genislik: en,
      yukseklik: boy,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is EkAnahtari &&
      other.uploadId == uploadId &&
      listEquals(other.anahtar, anahtar) &&
      listEquals(other.ozet, ozet) &&
      other.boyut == boyut &&
      other.genislik == genislik &&
      other.yukseklik == yukseklik;

  @override
  int get hashCode =>
      Object.hash(uploadId, Object.hashAll(ozet), boyut, genislik, yukseklik);

  @override
  String toString() => 'EkAnahtari(…)';
}

/// [icerik]'in UTF-8 JSON kodu: `{v:1, …ekler, t, …alanlar}`.
Uint8List icerikJsonu(
  BirebirIcerik icerik, {
  Map<String, Object?> ekler = const {},
}) => Uint8List.fromList(
  utf8.encode(jsonEncode({'v': 1, ...ekler, ...icerik.alanlar()})),
);

/// UTF-8 JSON baytlarını sürüm 1 nesnesine çözer; değilse `null`.
Map<String, Object?>? icerikNesnesi(Uint8List ham) {
  try {
    final json = jsonDecode(utf8.decode(ham));
    if (json is! Map<String, Object?> || json['v'] != 1) return null;
    return json;
  } on FormatException {
    return null;
  }
}
