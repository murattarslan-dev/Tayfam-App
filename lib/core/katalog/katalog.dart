import 'package:flutter/foundation.dart';

import 'package:tayfam/core/api/gen/models.dart';

/// Katalog anahtarının biçimi (sözleşme: `EventTypeKey`, `InterestKey`).
/// Sunucudan, adresten ya da başka bir yerden gelen anahtar girdi kabul
/// edilir ve bununla doğrulanır.
final RegExp _anahtarBicimi = RegExp(r'^[a-z][a-z0-9_]{1,39}$');

/// [anahtar] katalog anahtarı biçiminde mi.
bool katalogAnahtariMi(String anahtar) => _anahtarBicimi.hasMatch(anahtar);

/// Katalogdaki "Genel" türünün ve ilgi alanının anahtarı: alanı ve
/// bileşeni olmayan sade etkinlik.
const String genelTurAnahtari = 'general';

/// Sunucudan okunan katalog (ADR-0024 §1): ilgi alanları ve aktif türlerin
/// güncel sürümleri. Yalnızca bellektedir (ADR-0006).
///
/// Katalog herkese aynıdır ve kişisel veri taşımaz; yine de sunucudan
/// gelen girdidir: biçimi geçersiz anahtar taşıyan kayıt atlanır, türler
/// ve ilgi alanları anahtara göre tekilleştirilir.
@immutable
final class Katalog {
  Katalog(Catalog ham)
    : surum = ham.catalogVersion,
      ilgiAlanlari = List.unmodifiable(_tekil(ham.interests, (i) => i.key)),
      turler = List.unmodifiable(
        _tekil(ham.eventTypes.where((t) => t.version >= 1), (t) => t.key),
      );

  /// Kataloğun bütününün sürümü (`catalog_version`).
  final int surum;

  /// Bütün ilgi alanları (emekliler dahil), sunucunun sırasıyla.
  final List<CatalogInterest> ilgiAlanlari;

  /// Sunucunun döndürdüğü türler (güncel sürümleri), sunucunun sırasıyla.
  final List<CatalogEventType> turler;

  late final Map<String, CatalogEventType> _turler = {
    for (final t in turler) t.key: t,
  };

  late final Map<String, CatalogInterest> _ilgiAlanlari = {
    for (final i in ilgiAlanlari) i.key: i,
  };

  /// `If-None-Match` değeri: sözleşmede `ETag`, tırnak içinde sürümdür.
  String get etag => '"$surum"';

  /// [anahtar] türünün güncel sürümü; katalogda yoksa `null`.
  CatalogEventType? tur(String anahtar) => _turler[anahtar];

  /// [anahtar] ilgi alanı; katalogda yoksa `null`.
  CatalogInterest? ilgiAlani(String anahtar) => _ilgiAlanlari[anahtar];

  /// Yeni etkinlikte seçilebilen türler: emekli (`retired`) ya da durumu
  /// tanınmayan tür listelenmez (ADR-0024 §4).
  late final List<CatalogEventType> secilebilirTurler = List.unmodifiable(
    turler.where((t) => t.status == CatalogStatus.active),
  );

  /// Yeni seçimde (tayfa, profil) sunulan ilgi alanları: emekliler yok.
  late final List<CatalogInterest> secilebilirIlgiAlanlari = List.unmodifiable(
    ilgiAlanlari.where((i) => i.status == CatalogStatus.active),
  );

  /// [ilgiAlani]'nda listelenen seçilebilir türler (tür birden fazla ilgi
  /// alanında yer alabilir; `interest_keys`).
  List<CatalogEventType> ilgiAlanininTurleri(String ilgiAlani) => [
    for (final t in secilebilirTurler)
      if (t.interestKeys.contains(ilgiAlani)) t,
  ];
}

List<T> _tekil<T>(Iterable<T> ogeler, String Function(T) anahtar) {
  final gorulen = <String>{};
  return [
    for (final oge in ogeler)
      if (katalogAnahtariMi(anahtar(oge)) && gorulen.add(anahtar(oge))) oge,
  ];
}
