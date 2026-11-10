import 'package:flutter/material.dart';

/// Etkinlik türlerinin renk anahtarı (ADR-0004 Notlar, 2026-11-10). Her
/// tür kendi rengini taşır; yeni bir tür yeni bir anahtar ve iki temada
/// birer dolgu/metin çifti ister. Türün hangi anahtarı kullandığına
/// etkinlik türü kaydı (`core/moduller/etkinlik_turu_kaydi.dart`) karar
/// verir.
enum TurRengi { konvoy, kamp, yuruyus, balik, oyun, spor, genel }

/// Bir türün dolgu rengi ve üzerindeki metin/ikon rengi.
@immutable
final class TurRenkCifti {
  const TurRenkCifti({required this.dolgu, required this.ustu});

  /// Çip, hap ve etiket zemini.
  final Color dolgu;

  /// [dolgu] üzerindeki metin ve ikon (en az 4.5:1).
  final Color ustu;

  TurRenkCifti _lerp(TurRenkCifti diger, double t) => TurRenkCifti(
    dolgu: Color.lerp(dolgu, diger.dolgu, t)!,
    ustu: Color.lerp(ustu, diger.ustu, t)!,
  );

  @override
  bool operator ==(Object other) =>
      other is TurRenkCifti && other.dolgu == dolgu && other.ustu == ustu;

  @override
  int get hashCode => Object.hash(dolgu, ustu);
}

/// Etkinlik türü renkleri (Notion: Tasarım Standartları; ADR-0004 Notlar,
/// 2026-11-10). Ekranlar rengi yalnızca bu uzantıdan alır
/// (`context.turRenkleri`); ham hex yalnızca bu dosyadadır.
///
/// Renk tek başına bilgi taşımaz: tür her zaman ikon ve adla gösterilir.
@immutable
class TayfamTurRenkleri extends ThemeExtension<TayfamTurRenkleri> {
  const TayfamTurRenkleri(this._ciftler);

  final Map<TurRengi, TurRenkCifti> _ciftler;

  /// [renk] anahtarının dolgu/metin çifti.
  TurRenkCifti cift(TurRengi renk) => _ciftler[renk]!;

  /// Açık tema.
  static const TayfamTurRenkleri acik = TayfamTurRenkleri({
    TurRengi.konvoy: TurRenkCifti(dolgu: _Palet.mango, ustu: _Palet.ink),
    TurRengi.kamp: TurRenkCifti(dolgu: _Palet.orman, ustu: _Palet.ink),
    TurRengi.yuruyus: TurRenkCifti(dolgu: _Palet.teal, ustu: _Palet.ink),
    TurRengi.balik: TurRenkCifti(dolgu: _Palet.deniz, ustu: _Palet.ink),
    TurRengi.oyun: TurRenkCifti(dolgu: _Palet.brand, ustu: _Palet.beyaz),
    TurRengi.spor: TurRenkCifti(dolgu: _Palet.nar, ustu: _Palet.ink),
    TurRengi.genel: TurRenkCifti(dolgu: _Palet.lavanta, ustu: _Palet.ink),
  });

  /// Koyu tema: yalnızca oyun değişir (brand ink zeminde zayıf kaldığı
  /// için brand-dark + ink).
  static const TayfamTurRenkleri koyu = TayfamTurRenkleri({
    TurRengi.konvoy: TurRenkCifti(dolgu: _Palet.mango, ustu: _Palet.ink),
    TurRengi.kamp: TurRenkCifti(dolgu: _Palet.orman, ustu: _Palet.ink),
    TurRengi.yuruyus: TurRenkCifti(dolgu: _Palet.teal, ustu: _Palet.ink),
    TurRengi.balik: TurRenkCifti(dolgu: _Palet.deniz, ustu: _Palet.ink),
    TurRengi.oyun: TurRenkCifti(dolgu: _Palet.brandDark, ustu: _Palet.ink),
    TurRengi.spor: TurRenkCifti(dolgu: _Palet.nar, ustu: _Palet.ink),
    TurRengi.genel: TurRenkCifti(dolgu: _Palet.lavanta, ustu: _Palet.ink),
  });

  @override
  TayfamTurRenkleri copyWith({Map<TurRengi, TurRenkCifti>? ciftler}) =>
      TayfamTurRenkleri(ciftler ?? _ciftler);

  @override
  TayfamTurRenkleri lerp(covariant TayfamTurRenkleri? other, double t) {
    if (other == null) {
      return this;
    }
    return TayfamTurRenkleri({
      for (final renk in TurRengi.values)
        renk: cift(renk)._lerp(other.cift(renk), t),
    });
  }
}

/// Ham palet. Yalnızca bu dosyada kullanılır.
abstract final class _Palet {
  static const Color mango = Color(0xFFFFB000);
  static const Color orman = Color(0xFF2F9E5B);
  static const Color teal = Color(0xFF00C2A8);
  static const Color deniz = Color(0xFF3D8BEA);
  static const Color brand = Color(0xFF5B2BE0);
  static const Color brandDark = Color(0xFFA98BFF);
  static const Color nar = Color(0xFFFF3D68);
  static const Color lavanta = Color(0xFF8A7FA8);
  static const Color ink = Color(0xFF1B1036);
  static const Color beyaz = Color(0xFFFFFFFF);
}
