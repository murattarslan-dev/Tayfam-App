import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/katalog/katalog.dart';
import 'package:tayfam/core/katalog/katalog_deposu.dart';
import 'package:tayfam/core/katalog/katalog_notifier.dart';

/// Test kataloğunun (`test/fixtures/katalog.json`; ADR-0024 §7) JSON'u:
/// Faz 1'in yedi türü, bütün alan türlerini kullanan `ornek_alanlar`,
/// bütün bileşenleri kullanan `ornek_bilesenler`, alan türü tanınmayan
/// `gelecek_tur` ve emekli `eski_tur`.
Map<String, Object?> testKataloguJson() =>
    jsonDecode(File('test/fixtures/katalog.json').readAsStringSync())
        as Map<String, Object?>;

/// Test kataloğunun sözleşme modeli.
Catalog testKataloguModeli() => Catalog.fromJson(testKataloguJson());

/// Test kataloğu.
Katalog testKatalogu() => Katalog(testKataloguModeli());

/// Test kataloğundaki [anahtar] türü.
CatalogEventType testTuru(String anahtar) => testKatalogu().tur(anahtar)!;

/// Eğitim türlerindeki gibi ders/konu alanı (`study_tags`, Tayfam-Api
/// ADR-0043 §6); katalog fikstüründe bu türde alan yoktur.
CatalogField dersAlani(
  String anahtar, {
  bool zorunlu = false,
  String? enSig,
  String? enDerin,
  int? enCok,
}) => CatalogField.fromJson({
  'key': anahtar,
  'kind': 'study_tags',
  'required': zorunlu,
  'labels': {'tr': anahtar},
  'min_depth': ?enSig,
  'max_depth': ?enDerin,
  'max_selected': ?enCok,
});

/// Sunucuya gitmeyen, sabit kataloglu notifier: ekran testlerinde katalog
/// hazır gelir. [katalog] `null` ise katalog hiç gelmemiş gibidir.
class SabitKatalogNotifier extends KatalogNotifier {
  SabitKatalogNotifier(this._durum);

  final AsyncValue<Katalog?> _durum;

  /// [KatalogNotifier.yenile] çağrılarının sayısı.
  int yenileme = 0;

  /// [KatalogNotifier.bilinmeyenTur] ile bildirilen anahtarlar.
  final List<String> bilinmeyenler = [];

  @override
  AsyncValue<Katalog?> build() => _durum;

  @override
  Future<void> gerekli() async {}

  @override
  Future<void> yenile() async {
    yenileme++;
  }

  @override
  Future<void> onPlanaDondu() async {}

  @override
  Future<void> bilinmeyenTur(String anahtar) async {
    bilinmeyenler.add(anahtar);
  }
}

/// Ekran testleri için: katalog test kataloğuyla hazır gelir.
Override katalogOverride([Katalog? katalog]) => katalogProvider.overrideWith(
  () => SabitKatalogNotifier(AsyncData(katalog ?? testKatalogu())),
);

/// Ekran testleri için: katalog verilen durumda (yükleniyor, hata, boş).
Override katalogDurumuOverride(AsyncValue<Katalog?> durum) =>
    katalogProvider.overrideWith(() => SabitKatalogNotifier(durum));

/// Sahte katalog uçları: istekleri kaydeder, sıradaki yanıtı döndürür.
final class SahteKatalogDeposu implements KatalogDeposu {
  SahteKatalogDeposu({
    Catalog? katalog,
    Map<String, CatalogEventType>? surumler,
  }) : katalog = katalog ?? testKataloguModeli(),
       surumler = surumler ?? {};

  /// Sunucudaki katalog; `null` ise okuma [hata] fırlatır.
  Catalog? katalog;

  /// `anahtar@sürüm` → tür sürümü.
  final Map<String, CatalogEventType> surumler;

  /// Verilirse bir sonraki istek bununla başarısız olur.
  Exception? hata;

  /// `oku` çağrılarında gönderilen `If-None-Match` değerleri.
  final List<String?> etagler = [];

  /// `surumOku` çağrıları (`anahtar@sürüm`).
  final List<String> surumIstekleri = [];

  @override
  Future<Catalog?> oku({String? etag}) async {
    etagler.add(etag);
    final hata = this.hata;
    if (hata != null) throw hata;
    final katalog = this.katalog!;
    // Sözleşme: ETag `"<catalog_version>"`; değişmediyse 304 (null).
    return etag == '"${katalog.catalogVersion}"' ? null : katalog;
  }

  @override
  Future<CatalogEventType> surumOku(String anahtar, int surum) async {
    surumIstekleri.add('$anahtar@$surum');
    final hata = this.hata;
    if (hata != null) throw hata;
    final bulunan = surumler['$anahtar@$surum'];
    if (bulunan == null) throw StateError('test: sürüm yok');
    return bulunan;
  }
}
