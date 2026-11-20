import 'package:flutter/foundation.dart';

import 'package:tayfam/core/api/gen/models.dart';

/// Ders seçiminin sunucu doğrulama hatasındaki alan adı (Tayfam-Api #302).
const String dersAlanAdi = 'subject_key';

/// Konu seçiminin sunucu doğrulama hatasındaki alan adı (Tayfam-Api #302).
const String konuAlanAdi = 'topic_key';

/// Ders ve konu etiket listesinin en çok derinliği (sözleşme:
/// `CatalogStudyTag`): düzey → ders → konu.
const int dersKonuEnCokSeviye = 3;

/// Etiketin listedeki seviyesi.
enum DersKonuSeviyesi {
  /// Sınav ya da düzey (LGS, YKS); `parent_key` yoktur.
  duzey,

  /// Ders; içerikte zorunlu seçimdir (`subject_key`).
  ders,

  /// Konu; isteğe bağlıdır ve seçilen dersin altındandır (`topic_key`).
  konu,
}

/// Eğitim içeriğinin (soru havuzu, materyal) ders/konu seçimi: sunucuya
/// giden yalnızca bu iki anahtardır. Düzey saklanmaz, dersin üstünden
/// bulunur.
@immutable
final class DersKonuSecimi {
  const DersKonuSecimi({required this.ders, this.konu});

  /// Ders anahtarı (`subject_key`).
  final String ders;

  /// Konu anahtarı (`topic_key`); seçilmediyse `null`.
  final String? konu;

  @override
  bool operator ==(Object other) =>
      other is DersKonuSecimi && other.ders == ders && other.konu == konu;

  @override
  int get hashCode => Object.hash(ders, konu);

  @override
  String toString() => 'DersKonuSecimi($ders, $konu)';
}

/// Katalogdaki `study_tags`'in ağaç hali (ADR-0033 §2, Tayfam-Api #302).
///
/// Sunucu listeyi düz ve emekliler dahil döndürür; burada `parent_key`'e
/// göre gruplanır, aynı üstün altındakiler `position`'a (eşitlikte
/// anahtara) göre sıralanır. Liste sunucudan gelen girdidir: yinelenen
/// anahtarın ilki kalır, üstü listede olmayan kayıt ve üç seviyeden
/// derindeki kayıt atlanır (biçimi geçersiz anahtarı `Katalog` ayıklar).
///
/// Emekli (`retired`) etiket ve emekli etiketin altındakiler yeni seçimde
/// sunulmaz ([secilebilir]); mevcut bir değer olarak geldiğinde adıyla
/// gösterilmeye devam eder.
@immutable
final class DersKonuAgaci {
  factory DersKonuAgaci(Iterable<CatalogStudyTag> etiketler) {
    final kayitlar = <String, CatalogStudyTag>{};
    for (final e in etiketler) {
      kayitlar.putIfAbsent(e.key, () => e);
    }
    final seviyeler = <String, DersKonuSeviyesi>{};
    for (final anahtar in kayitlar.keys) {
      final s = _seviyeBul(anahtar, kayitlar);
      if (s != null) seviyeler[anahtar] = s;
    }
    final altlar = <String?, List<CatalogStudyTag>>{};
    for (final anahtar in seviyeler.keys) {
      final e = kayitlar[anahtar]!;
      (altlar[e.parentKey] ??= []).add(e);
    }
    for (final liste in altlar.values) {
      liste.sort(
        (a, b) => a.position != b.position
            ? a.position.compareTo(b.position)
            : a.key.compareTo(b.key),
      );
    }
    return DersKonuAgaci._(
      <String, CatalogStudyTag>{
        for (final a in seviyeler.keys) a: kayitlar[a]!,
      },
      seviyeler,
      <String?, List<CatalogStudyTag>>{
        for (final g in altlar.entries)
          g.key: List<CatalogStudyTag>.unmodifiable(g.value),
      },
    );
  }

  DersKonuAgaci._(this._kayitlar, this._seviyeler, this._altlar);

  final Map<String, CatalogStudyTag> _kayitlar;
  final Map<String, DersKonuSeviyesi> _seviyeler;
  final Map<String?, List<CatalogStudyTag>> _altlar;

  /// Listede hiç (geçerli) etiket yok.
  bool get bos => _kayitlar.isEmpty;

  /// Yeni seçimde sunulabilecek ders var mı: yoksa seçici boş durumu
  /// gösterir.
  bool get secilebilirDersVar => duzeyler().any(
    (d) => altlar(d.key).any((e) => seviye(e.key) == DersKonuSeviyesi.ders),
  );

  /// [anahtar]'lı etiket; listede yoksa `null`.
  CatalogStudyTag? etiket(String anahtar) => _kayitlar[anahtar];

  /// [anahtar]'ın seviyesi; listede yoksa `null`.
  DersKonuSeviyesi? seviye(String anahtar) => _seviyeler[anahtar];

  /// [anahtar]'ın üstünün anahtarı; düzeyde ya da listede yoksa `null`.
  String? ust(String anahtar) => _kayitlar[anahtar]?.parentKey;

  /// [anahtar] yeni seçimde sunulabilir mi: kendisi ve bütün üstleri
  /// aktif.
  bool secilebilir(String anahtar) {
    String? a = anahtar;
    for (var i = 0; a != null && i < dersKonuEnCokSeviye; i++) {
      final e = _kayitlar[a];
      if (e == null || e.status != CatalogStatus.active) return false;
      a = e.parentKey;
    }
    return a == null;
  }

  /// Düzeyler, sırasıyla: seçilebilenler ve [mevcut] (seçili değerin
  /// düzeyi; emekli olsa da gösterilir).
  List<CatalogStudyTag> duzeyler({String? mevcut}) => _secenekler(null, mevcut);

  /// [ust]'ün altındakiler, sırasıyla: seçilebilenler ve [mevcut].
  List<CatalogStudyTag> altlar(String ust, {String? mevcut}) =>
      _secenekler(ust, mevcut);

  List<CatalogStudyTag> _secenekler(String? ust, String? mevcut) => [
    for (final e in _altlar[ust] ?? const <CatalogStudyTag>[])
      if (e.key == mevcut || secilebilir(e.key)) e,
  ];

  /// [secim]'in dersinin düzeyi; ders listede yoksa `null`.
  String? duzeyi(DersKonuSecimi secim) =>
      seviye(secim.ders) == DersKonuSeviyesi.ders ? ust(secim.ders) : null;

  /// [secim] yeni içerikte gönderilebilir mi: ders seçilebilir bir ders,
  /// konu varsa o dersin altında seçilebilir bir konu. Son söz sunucunundur
  /// (`subject_key` / `topic_key` hataları).
  bool gecerli(DersKonuSecimi secim) {
    if (seviye(secim.ders) != DersKonuSeviyesi.ders) return false;
    if (!secilebilir(secim.ders)) return false;
    final konu = secim.konu;
    if (konu == null) return true;
    return ust(konu) == secim.ders && secilebilir(konu);
  }
}

/// [anahtar]'ın seviyesi; üst zinciri listede kopuksa ya da üç seviyeden
/// derinse `null`.
DersKonuSeviyesi? _seviyeBul(
  String anahtar,
  Map<String, CatalogStudyTag> kayitlar,
) {
  var derinlik = 0;
  String? a = anahtar;
  while (a != null) {
    final e = kayitlar[a];
    if (e == null || derinlik >= dersKonuEnCokSeviye) return null;
    derinlik++;
    a = e.parentKey;
  }
  return DersKonuSeviyesi.values[derinlik - 1];
}
