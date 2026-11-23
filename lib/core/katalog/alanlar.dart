import 'package:flutter/foundation.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/katalog/ders_konu.dart';
import 'package:tayfam/core/katalog/katalog.dart';

/// Katalogdaki alan türleri (sözleşme: `CatalogField.kind`, kapalı liste;
/// ADR-0024 §3, `study_tags` Tayfam-Api ADR-0043).
enum AlanTuru {
  metin('text'),
  uzunMetin('long_text'),
  tamSayi('integer'),
  ondalik('decimal'),
  secim('choice'),
  cokluSecim('multi_choice'),
  evetHayir('boolean'),
  tarih('date'),
  sure('duration'),

  /// Ders/konu listesinden (`Catalog.study_tags`) seçim; değer seçilen en
  /// derin etiketlerin anahtarlarıdır.
  dersKonu('study_tags');

  const AlanTuru(this.sunucuDegeri);

  /// Sözleşmedeki `kind` değeri.
  final String sunucuDegeri;

  /// [kind]'in alan türü; tanınmıyorsa `null` (alan çizilmez).
  static AlanTuru? coz(String kind) {
    for (final tur in values) {
      if (tur.sunucuDegeri == kind) return tur;
    }
    return null;
  }
}

/// Sözleşmedeki varsayılan sınırlar (`CatalogField` tablosu).
const int alanMetinEnCok = 120;
const int alanUzunMetinEnCok = 1000;
const int alanOndalikBasamak = 2;
const int alanOndalikBasamakEnCok = 3;
const int alanSecenekEnCok = 50;

/// `study_tags` alanında en çok seçim (sözleşme: 1–10, yoksa 1).
const int alanDersKonuEnCok = 10;

/// Sayı alanlarının üst sınırı tanımda yoksa kabul edilen en büyük değer
/// (JSON'da güvenle taşınan tam sayı sınırının içinde).
const double alanSayiEnCok = 1000000000;

/// [alanlar]'ın hepsinin türü tanınıyor mu. Tanınmayan alan türü içeren
/// türde etkinlik oluşturma kapatılır (ADR-0024 §3); detayda o alan
/// atlanır.
bool alanlarTaniniyor(Iterable<CatalogField> alanlar) =>
    alanlar.every(alanTaniniyor);

/// [alan]'ın türü (ve `study_tags` ise derinlik ayarları) tanınıyor mu.
/// Tanınmayan alan çizilmez.
bool alanTaniniyor(CatalogField alan) => switch (AlanTuru.coz(alan.kind)) {
  null => false,
  AlanTuru.dersKonu =>
    alan.minDepth != CatalogFieldMinDepth.unknown &&
        alan.maxDepth != CatalogFieldMaxDepth.unknown,
  _ => true,
};

/// `log` bileşeninin kayıt alanları tanınıyor mu. `study_tags` yalnızca
/// tür alanıdır (Tayfam-Api ADR-0043 §1); kayıt alanında gelirse
/// tanınmayan alan sayılır ve ekleme kapanır.
bool kayitAlanlariTaniniyor(Iterable<CatalogField> alanlar) => alanlar.every(
  (a) => alanTaniniyor(a) && AlanTuru.coz(a.kind) != AlanTuru.dersKonu,
);

/// `study_tags` alanında seçilebilecek en sığ seviye (`min_depth`; yoksa
/// ders).
DersKonuSeviyesi alanEnSigSeviye(CatalogField alan) =>
    alan.minDepth == CatalogFieldMinDepth.level
    ? DersKonuSeviyesi.duzey
    : DersKonuSeviyesi.ders;

/// `study_tags` alanında seçilebilecek en derin seviye (`max_depth`; yoksa
/// konu). Tanım tutarsızsa (en sığdan sığ) en sığ seviyeye çekilir; son
/// söz sunucunundur.
DersKonuSeviyesi alanEnDerinSeviye(CatalogField alan) {
  final enDerin = switch (alan.maxDepth) {
    CatalogFieldMaxDepth.level => DersKonuSeviyesi.duzey,
    CatalogFieldMaxDepth.subject => DersKonuSeviyesi.ders,
    _ => DersKonuSeviyesi.konu,
  };
  final enSig = alanEnSigSeviye(alan);
  return enDerin.index < enSig.index ? enSig : enDerin;
}

/// Bir alanın formdaki hatası; metni çeviri dosyasındadır.
enum AlanHatasi {
  /// Zorunlu alan boş.
  zorunlu,

  /// Metin en çok uzunluğu aşıyor.
  uzunluk,

  /// Sayı olarak okunamıyor.
  sayi,

  /// Sayı tanımdaki aralığın dışında.
  aralik,

  /// Ondalık basamak sayısı fazla.
  basamak,

  /// Seçenek tanımda yok.
  secim,

  /// En çok seçim sayısı aşıldı.
  cokSecim,

  /// Geçerli bir takvim günü değil.
  tarih,
}

/// Bir sayı alanının tanımdaki sınırları.
@immutable
final class AlanAraligi {
  const AlanAraligi({required this.enAz, required this.enCok});

  final double enAz;
  final double enCok;
}

/// [alan]'ın sayı aralığı (sözleşme: `min` yoksa 0, `duration` için 1).
/// Tanım tutarsızsa (`max` < `min`) üst sınır alt sınıra çekilir; son söz
/// sunucunundur.
AlanAraligi alanAraligi(CatalogField alan) {
  final sure = AlanTuru.coz(alan.kind) == AlanTuru.sure;
  final enAz = _sonlu(alan.min) ?? (sure ? 1 : 0);
  final enCok = _sonlu(alan.max) ?? alanSayiEnCok;
  return AlanAraligi(enAz: enAz, enCok: enCok < enAz ? enAz : enCok);
}

double? _sonlu(double? sayi) => sayi == null || !sayi.isFinite ? null : sayi;

/// [alan]'ın metin uzunluğu sınırı (sözleşme: `text` ≤ 120, `long_text`
/// ≤ 1000). Tanımdaki değer bu sınırların içine çekilir.
int alanMetinSiniri(CatalogField alan) {
  final ust = AlanTuru.coz(alan.kind) == AlanTuru.uzunMetin
      ? alanUzunMetinEnCok
      : alanMetinEnCok;
  final tanim = alan.maxLength;
  return tanim == null || tanim < 1 || tanim > ust ? ust : tanim;
}

/// `decimal` alanının ondalık basamak sayısı (1–3; yoksa 2).
int alanBasamagi(CatalogField alan) {
  final tanim = alan.decimals;
  return tanim == null || tanim < 1 || tanim > alanOndalikBasamakEnCok
      ? alanOndalikBasamak
      : tanim;
}

/// [alan]'ın seçenekleri: biçimi geçerli, tekrarsız, en çok
/// [alanSecenekEnCok] anahtar.
List<String> alanSecenekleri(CatalogField alan) {
  final gorulen = <String>{};
  return [
    for (final secenek in alan.options ?? const <String>[])
      if (_secenekBicimi.hasMatch(secenek) && gorulen.add(secenek)) secenek,
  ].take(alanSecenekEnCok).toList(growable: false);
}

final RegExp _secenekBicimi = RegExp(r'^[a-z0-9][a-z0-9_]{0,39}$');

/// `multi_choice` alanında en çok seçim (yoksa seçenek sayısı);
/// `study_tags` alanında 1–[alanDersKonuEnCok] (yoksa 1).
int alanEnCokSecim(CatalogField alan) {
  final tanim = alan.maxSelected;
  if (AlanTuru.coz(alan.kind) == AlanTuru.dersKonu) {
    if (tanim == null || tanim < 1) return 1;
    return tanim > alanDersKonuEnCok ? alanDersKonuEnCok : tanim;
  }
  final secenekSayisi = alanSecenekleri(alan).length;
  return tanim == null || tanim < 1 || tanim > secenekSayisi
      ? secenekSayisi
      : tanim;
}

final RegExp _tamSayiBicimi = RegExp(r'^-?\d{1,15}$');
final RegExp _ondalikBicimi = RegExp(r'^-?\d{1,15}(?:[.,]\d{1,9})?$');
final RegExp _tarihBicimi = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// `YYYY-MM-DD` metni geçerli bir takvim günüyse o gün (UTC gece yarısı),
/// değilse `null`.
DateTime? alanTarihiCoz(String metin) {
  final eslesme = _tarihBicimi.firstMatch(metin);
  if (eslesme == null) return null;
  final yil = int.parse(eslesme.group(1)!);
  final ay = int.parse(eslesme.group(2)!);
  final gun = int.parse(eslesme.group(3)!);
  final tarih = DateTime.utc(yil, ay, gun);
  return tarih.year == yil && tarih.month == ay && tarih.day == gun
      ? tarih
      : null;
}

/// [tarih]'in `YYYY-MM-DD` yazımı (sözleşme: `date` alanı).
String alanTarihiYaz(DateTime tarih) {
  String iki(int sayi) => sayi.toString().padLeft(2, '0');
  final yil = tarih.year.toString().padLeft(4, '0');
  return '$yil-${iki(tarih.month)}-${iki(tarih.day)}';
}

/// Formdaki alan değerleri: alan anahtarı → ham girdi.
///
/// | Tür | Formdaki değer |
/// |-----|----------------|
/// | `text`, `long_text` | `String` |
/// | `integer`, `decimal`, `duration` | `String` (yazılan metin) |
/// | `choice` | `String` (seçenek anahtarı) |
/// | `multi_choice` | `List<String>` |
/// | `study_tags` | `List<String>` (en derin etiket anahtarları, sırayla) |
/// | `boolean` | `bool` |
/// | `date` | `String` (`YYYY-MM-DD`) |
///
/// Değeri olmayan alan haritada yer almaz.
typedef AlanDegerleri = Map<String, Object?>;

/// [deger] boş mu (alan verilmemiş sayılır).
bool _bos(Object? deger) => switch (deger) {
  null => true,
  final String metin => metin.trim().isEmpty,
  final List<Object?> liste => liste.isEmpty,
  _ => false,
};

/// [alanlar]'ın formdaki [degerler]'e göre hataları: alan anahtarı → hata.
/// Boş harita form geçerli demektir. Tanınmayan türdeki alan denetlenmez
/// (o türde etkinlik zaten oluşturulamaz). Sınır ve zorunluluk tanımdan
/// okunur; son söz sunucunundur (ADR-0024 §3).
Map<String, AlanHatasi> alanHatalari(
  Iterable<CatalogField> alanlar,
  AlanDegerleri degerler,
) {
  final hatalar = <String, AlanHatasi>{};
  for (final alan in alanlar) {
    final tur = AlanTuru.coz(alan.kind);
    if (tur == null) continue;
    final hata = _alanHatasi(alan, tur, degerler[alan.key]);
    if (hata != null) hatalar[alan.key] = hata;
  }
  return Map.unmodifiable(hatalar);
}

AlanHatasi? _alanHatasi(CatalogField alan, AlanTuru tur, Object? deger) {
  if (_bos(deger)) {
    return alan.required_ == true ? AlanHatasi.zorunlu : null;
  }
  switch (tur) {
    case AlanTuru.metin || AlanTuru.uzunMetin:
      if (deger is! String) return AlanHatasi.zorunlu;
      return deger.trim().runes.length > alanMetinSiniri(alan)
          ? AlanHatasi.uzunluk
          : null;
    case AlanTuru.tamSayi || AlanTuru.sure:
      if (deger is! String || !_tamSayiBicimi.hasMatch(deger.trim())) {
        return AlanHatasi.sayi;
      }
      return _aralikta(alan, double.parse(deger.trim()))
          ? null
          : AlanHatasi.aralik;
    case AlanTuru.ondalik:
      if (deger is! String) return AlanHatasi.sayi;
      final metin = deger.trim();
      if (!_ondalikBicimi.hasMatch(metin)) return AlanHatasi.sayi;
      final ayrac = metin.indexOf(RegExp('[.,]'));
      if (ayrac >= 0 && metin.length - ayrac - 1 > alanBasamagi(alan)) {
        return AlanHatasi.basamak;
      }
      return _aralikta(alan, double.parse(metin.replaceAll(',', '.')))
          ? null
          : AlanHatasi.aralik;
    case AlanTuru.secim:
      return deger is String && alanSecenekleri(alan).contains(deger)
          ? null
          : AlanHatasi.secim;
    case AlanTuru.cokluSecim:
      if (deger is! List<Object?>) return AlanHatasi.secim;
      final secenekler = alanSecenekleri(alan);
      if (!deger.every(secenekler.contains)) return AlanHatasi.secim;
      return deger.length > alanEnCokSecim(alan) ? AlanHatasi.cokSecim : null;
    case AlanTuru.dersKonu:
      // Yalnızca biçim (Tayfam-Api ADR-0043 §2.1): anahtar biçimi, tekrar
      // yok, en çok seçim. Etiketin listede ve seçilebilir olması seçicide
      // sağlanır; mevcut emekli seçim değişmeden geri gönderilebilsin diye
      // burada denetlenmez. Son söz sunucunundur.
      if (deger is! List<Object?>) return AlanHatasi.secim;
      final gorulen = <String>{};
      for (final anahtar in deger) {
        if (anahtar is! String ||
            !katalogAnahtariMi(anahtar) ||
            !gorulen.add(anahtar)) {
          return AlanHatasi.secim;
        }
      }
      return deger.length > alanEnCokSecim(alan) ? AlanHatasi.cokSecim : null;
    case AlanTuru.evetHayir:
      return deger is bool ? null : AlanHatasi.zorunlu;
    case AlanTuru.tarih:
      return deger is String && alanTarihiCoz(deger) != null
          ? null
          : AlanHatasi.tarih;
  }
}

bool _aralikta(CatalogField alan, double sayi) {
  final aralik = alanAraligi(alan);
  return sayi >= aralik.enAz && sayi <= aralik.enCok;
}

/// Geçerli [degerler]'den etkinliğin `fields` gövdesi (sözleşme:
/// `EventFieldValues`): alan anahtarı → JSON değeri. Değeri olmayan alan
/// nesnede yer almaz; `null` gönderilmez. Tanımda olmayan anahtar ve
/// tanınmayan türdeki alan gönderilmez.
///
/// Çağıran önce [alanHatalari]'nın boş olduğunu doğrular; geçersiz kalan
/// değer burada sessizce atlanır.
Map<String, Object?> alanGovdesi(
  Iterable<CatalogField> alanlar,
  AlanDegerleri degerler,
) {
  final govde = <String, Object?>{};
  for (final alan in alanlar) {
    final tur = AlanTuru.coz(alan.kind);
    final deger = degerler[alan.key];
    if (tur == null || _bos(deger) || _alanHatasi(alan, tur, deger) != null) {
      continue;
    }
    govde[alan.key] = switch (tur) {
      AlanTuru.metin || AlanTuru.uzunMetin => (deger as String).trim(),
      AlanTuru.tamSayi || AlanTuru.sure => int.parse((deger as String).trim()),
      AlanTuru.ondalik => double.parse(
        (deger as String).trim().replaceAll(',', '.'),
      ),
      AlanTuru.secim || AlanTuru.tarih => deger as String,
      AlanTuru.cokluSecim || AlanTuru.dersKonu => List<String>.unmodifiable(
        (deger as List<Object?>).cast<String>(),
      ),
      AlanTuru.evetHayir => deger as bool,
    };
  }
  return Map.unmodifiable(govde);
}

/// Sunucudan gelen `fields` nesnesinden formdaki değerler (düzenleme).
/// Sunucunun değeri girdidir: türüne uymayan ya da tanımda olmayan değer
/// atlanır.
AlanDegerleri alanDegerleriOku(
  Iterable<CatalogField> alanlar,
  Map<String, Object?>? govde,
) {
  final degerler = <String, Object?>{};
  if (govde == null) return degerler;
  for (final alan in alanlar) {
    final tur = AlanTuru.coz(alan.kind);
    final ham = govde[alan.key];
    if (tur == null || ham == null) continue;
    final Object? deger = switch (tur) {
      AlanTuru.metin ||
      AlanTuru.uzunMetin ||
      AlanTuru.secim ||
      AlanTuru.tarih => ham is String ? ham : null,
      AlanTuru.tamSayi || AlanTuru.sure => ham is int ? '$ham' : null,
      AlanTuru.ondalik => ham is num && ham.isFinite ? sayiMetni(ham) : null,
      AlanTuru.cokluSecim || AlanTuru.dersKonu =>
        ham is List<Object?> && ham.every((e) => e is String)
            ? List<String>.unmodifiable(ham.cast<String>())
            : null,
      AlanTuru.evetHayir => ham is bool ? ham : null,
    };
    if (deger != null) degerler[alan.key] = deger;
  }
  return degerler;
}

/// Sayının sade yazımı: tam sayıysa ondalıksız (`12.0` → `12`).
String sayiMetni(num sayi) =>
    sayi is int || sayi == sayi.roundToDouble() && sayi.abs() < 1e15
    ? sayi.toInt().toString()
    : sayi.toString();

/// İki alan değeri haritası aynı girdiyi mi taşıyor (boş değerler yok
/// sayılır).
bool ayniAlanDegerleri(AlanDegerleri a, AlanDegerleri b) {
  Map<String, Object?> dolu(AlanDegerleri m) => {
    for (final e in m.entries)
      if (!_bos(e.value)) e.key: e.value,
  };
  final x = dolu(a);
  final y = dolu(b);
  if (x.length != y.length) return false;
  for (final e in x.entries) {
    final diger = y[e.key];
    final deger = e.value;
    if (deger is List<Object?> && diger is List<Object?>) {
      if (!listEquals(deger, diger)) return false;
    } else if (deger != diger) {
      return false;
    }
  }
  return true;
}
