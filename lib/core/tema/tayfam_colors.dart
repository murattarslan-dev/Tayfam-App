import 'package:flutter/material.dart';

/// Tayfam renk token'ları (ADR-0004, Notion: Tasarım Standartları).
///
/// Açık ve koyu temada aynı adlar kullanılır; değerler [acik] ve [koyu]
/// örneklerindedir. Ekranlar ve bileşenler rengi yalnızca bu sınıftan
/// alır (`context.renkler`); `Color(0x…)` ve `Colors.*` yalnızca
/// `core/tema/` içinde yazılır.
///
/// Kontrast kuralları: metin yalnızca [metin], [metinGovde],
/// [metinIkincil] ile ve her zeminin kendi "üstü" token'ıyla yazılır;
/// vurgu renkleri ([teal], [mango], [nar]) metin rengi olmaz.
@immutable
class TayfamColors extends ThemeExtension<TayfamColors> {
  const TayfamColors({
    required this.zemin,
    required this.kart,
    required this.cizgi,
    required this.metin,
    required this.metinGovde,
    required this.metinIkincil,
    required this.girisKenari,
    required this.marka,
    required this.markaUstu,
    required this.markaYuzey,
    required this.markaYuzeyUstu,
    required this.birincilEylem,
    required this.birincilEylemUstu,
    required this.tintMarka,
    required this.tintMarkaUstu,
    required this.tintMango,
    required this.tintMangoUstu,
    required this.gelenBalon,
    required this.gelenBalonUstu,
    required this.teal,
    required this.mango,
    required this.nar,
    required this.vurguUstu,
    required this.pasif,
    required this.pasifUstu,
    required this.odak,
    required this.markaYuzeyOdak,
    required this.golge,
  });

  /// Sayfa zemini (açık: surface, koyu: ink).
  final Color zemin;

  /// Kart yüzeyi (açık: card, koyu: card-dark).
  final Color kart;

  /// Ayırıcı ve kart kenarı; yalnızca süs (açık: line, koyu: line-dark).
  final Color cizgi;

  /// Ana metin (açık: ink, koyu: beyaz).
  final Color metin;

  /// Uzun gövde metni (açık: ink-body, koyu: text-body-dark).
  final Color metinGovde;

  /// İkincil metin (açık: ink-muted, koyu: text-muted-dark).
  final Color metinIkincil;

  /// Etkileşimli öğe sınırı, örneğin giriş alanı kenarı (en az 3:1).
  final Color girisKenari;

  /// Seçili durum, bağlantı, etkin sekme (açık: brand, koyu: brand-dark).
  final Color marka;

  /// [marka] üzerindeki metin (açık: beyaz, koyu: ink).
  final Color markaUstu;

  /// Tam yüzey mor (tayfa ana sayfası üst bölümü, giden sohbet balonu);
  /// iki temada da brand.
  final Color markaYuzey;

  /// [markaYuzey] üzerindeki metin; iki temada da beyaz.
  final Color markaYuzeyUstu;

  /// Birincil eylem zemini: açık zeminde brand, koyu zeminde mango.
  final Color birincilEylem;

  /// [birincilEylem] üzerindeki metin: açıkta beyaz, koyuda ink.
  final Color birincilEylemUstu;

  /// Etiket zemini (açık: tint-brand, koyu: tint-brand-dark).
  final Color tintMarka;

  /// [tintMarka] üzerindeki metin (açık: brand, koyu: #CDBBFF).
  final Color tintMarkaUstu;

  /// Vurgulu sayaç zemini (açık: tint-mango, koyu: tint-mango-dark).
  final Color tintMango;

  /// [tintMango] üzerindeki metin (açık: honey, koyu: #FFD27A).
  final Color tintMangoUstu;

  /// Gelen sohbet balonu (açık: tint-brand, koyu: bubble-in-dark).
  final Color gelenBalon;

  /// [gelenBalon] üzerindeki metin (açık: ink, koyu: beyaz).
  final Color gelenBalonUstu;

  /// Vurgu: teal. Metin rengi olmaz.
  final Color teal;

  /// Vurgu: mango. Metin rengi olmaz.
  final Color mango;

  /// Vurgu: nar. Metin rengi olmaz; üzerinde beyaz kullanılmaz.
  final Color nar;

  /// Vurgu renkleri üzerindeki metin; iki temada da ink.
  final Color vurguUstu;

  /// Devre dışı eylem zemini.
  final Color pasif;

  /// [pasif] üzerindeki metin.
  final Color pasifUstu;

  /// Odak çerçevesi, açık ve koyu zeminde (zemin, kart, tint'ler): açık
  /// temada brand, koyu temada mango (ADR-0004 Notlar, 2026-11-10). Mango
  /// açık zeminde 3:1'i geçmediği için açık temada brand kullanılır.
  final Color odak;

  /// Mor marka yüzeyindeki ([markaYuzey]) odak çerçevesi; iki temada da
  /// mango (ADR-0004 Notlar, 2026-11-10). `MarkaYuzeyi` bileşeni altındaki
  /// öğelerde [odak] bu değeri alır.
  final Color markaYuzeyOdak;

  /// Öne çıkan kartın tek gölgesinin rengi.
  final Color golge;

  /// Öne çıkan kartın tek gölgesi: `0 18 40 -24` (ADR-0004).
  List<BoxShadow> get oneCikanGolge => [
    BoxShadow(
      color: golge,
      offset: const Offset(0, 18),
      blurRadius: 40,
      spreadRadius: -24,
    ),
  ];

  /// Mor marka yüzeyinin altında geçerli token'lar: [odak] yerine
  /// [markaYuzeyOdak]. Diğer token'lar değişmez.
  TayfamColors markaYuzeyIcin() => copyWith(odak: markaYuzeyOdak);

  /// Açık tema (Notion: Tasarım Standartları).
  static const TayfamColors acik = TayfamColors(
    zemin: _Palet.surface,
    kart: _Palet.card,
    cizgi: _Palet.line,
    metin: _Palet.ink,
    metinGovde: _Palet.inkBody,
    metinIkincil: _Palet.inkMuted,
    girisKenari: _Palet.inkMuted,
    marka: _Palet.brand,
    markaUstu: _Palet.beyaz,
    markaYuzey: _Palet.brand,
    markaYuzeyUstu: _Palet.beyaz,
    birincilEylem: _Palet.brand,
    birincilEylemUstu: _Palet.beyaz,
    tintMarka: _Palet.tintBrand,
    tintMarkaUstu: _Palet.brand,
    tintMango: _Palet.tintMango,
    tintMangoUstu: _Palet.honey,
    gelenBalon: _Palet.tintBrand,
    gelenBalonUstu: _Palet.ink,
    teal: _Palet.teal,
    mango: _Palet.mango,
    nar: _Palet.nar,
    vurguUstu: _Palet.ink,
    pasif: _Palet.line,
    pasifUstu: _Palet.inkMuted,
    odak: _Palet.brand,
    markaYuzeyOdak: _Palet.mango,
    golge: _Palet.golge,
  );

  /// Koyu tema (ADR-0004 §2 tablosu; platform sahibi onayladı).
  static const TayfamColors koyu = TayfamColors(
    zemin: _Palet.ink,
    kart: _Palet.cardDark,
    cizgi: _Palet.lineDark,
    metin: _Palet.beyaz,
    metinGovde: _Palet.textBodyDark,
    metinIkincil: _Palet.textMutedDark,
    girisKenari: _Palet.textMutedDark,
    marka: _Palet.brandDark,
    markaUstu: _Palet.ink,
    markaYuzey: _Palet.brand,
    markaYuzeyUstu: _Palet.beyaz,
    birincilEylem: _Palet.mango,
    birincilEylemUstu: _Palet.ink,
    tintMarka: _Palet.tintBrandDark,
    tintMarkaUstu: _Palet.tintBrandDarkMetin,
    tintMango: _Palet.tintMangoDark,
    tintMangoUstu: _Palet.tintMangoDarkMetin,
    gelenBalon: _Palet.bubbleInDark,
    gelenBalonUstu: _Palet.beyaz,
    teal: _Palet.teal,
    mango: _Palet.mango,
    nar: _Palet.nar,
    vurguUstu: _Palet.ink,
    pasif: _Palet.lineDark,
    pasifUstu: _Palet.textMutedDark,
    odak: _Palet.mango,
    markaYuzeyOdak: _Palet.mango,
    golge: _Palet.golge,
  );

  @override
  TayfamColors copyWith({
    Color? zemin,
    Color? kart,
    Color? cizgi,
    Color? metin,
    Color? metinGovde,
    Color? metinIkincil,
    Color? girisKenari,
    Color? marka,
    Color? markaUstu,
    Color? markaYuzey,
    Color? markaYuzeyUstu,
    Color? birincilEylem,
    Color? birincilEylemUstu,
    Color? tintMarka,
    Color? tintMarkaUstu,
    Color? tintMango,
    Color? tintMangoUstu,
    Color? gelenBalon,
    Color? gelenBalonUstu,
    Color? teal,
    Color? mango,
    Color? nar,
    Color? vurguUstu,
    Color? pasif,
    Color? pasifUstu,
    Color? odak,
    Color? markaYuzeyOdak,
    Color? golge,
  }) {
    return TayfamColors(
      zemin: zemin ?? this.zemin,
      kart: kart ?? this.kart,
      cizgi: cizgi ?? this.cizgi,
      metin: metin ?? this.metin,
      metinGovde: metinGovde ?? this.metinGovde,
      metinIkincil: metinIkincil ?? this.metinIkincil,
      girisKenari: girisKenari ?? this.girisKenari,
      marka: marka ?? this.marka,
      markaUstu: markaUstu ?? this.markaUstu,
      markaYuzey: markaYuzey ?? this.markaYuzey,
      markaYuzeyUstu: markaYuzeyUstu ?? this.markaYuzeyUstu,
      birincilEylem: birincilEylem ?? this.birincilEylem,
      birincilEylemUstu: birincilEylemUstu ?? this.birincilEylemUstu,
      tintMarka: tintMarka ?? this.tintMarka,
      tintMarkaUstu: tintMarkaUstu ?? this.tintMarkaUstu,
      tintMango: tintMango ?? this.tintMango,
      tintMangoUstu: tintMangoUstu ?? this.tintMangoUstu,
      gelenBalon: gelenBalon ?? this.gelenBalon,
      gelenBalonUstu: gelenBalonUstu ?? this.gelenBalonUstu,
      teal: teal ?? this.teal,
      mango: mango ?? this.mango,
      nar: nar ?? this.nar,
      vurguUstu: vurguUstu ?? this.vurguUstu,
      pasif: pasif ?? this.pasif,
      pasifUstu: pasifUstu ?? this.pasifUstu,
      odak: odak ?? this.odak,
      markaYuzeyOdak: markaYuzeyOdak ?? this.markaYuzeyOdak,
      golge: golge ?? this.golge,
    );
  }

  @override
  TayfamColors lerp(covariant TayfamColors? other, double t) {
    if (other == null) {
      return this;
    }
    Color l(Color a, Color b) => Color.lerp(a, b, t)!;
    return TayfamColors(
      zemin: l(zemin, other.zemin),
      kart: l(kart, other.kart),
      cizgi: l(cizgi, other.cizgi),
      metin: l(metin, other.metin),
      metinGovde: l(metinGovde, other.metinGovde),
      metinIkincil: l(metinIkincil, other.metinIkincil),
      girisKenari: l(girisKenari, other.girisKenari),
      marka: l(marka, other.marka),
      markaUstu: l(markaUstu, other.markaUstu),
      markaYuzey: l(markaYuzey, other.markaYuzey),
      markaYuzeyUstu: l(markaYuzeyUstu, other.markaYuzeyUstu),
      birincilEylem: l(birincilEylem, other.birincilEylem),
      birincilEylemUstu: l(birincilEylemUstu, other.birincilEylemUstu),
      tintMarka: l(tintMarka, other.tintMarka),
      tintMarkaUstu: l(tintMarkaUstu, other.tintMarkaUstu),
      tintMango: l(tintMango, other.tintMango),
      tintMangoUstu: l(tintMangoUstu, other.tintMangoUstu),
      gelenBalon: l(gelenBalon, other.gelenBalon),
      gelenBalonUstu: l(gelenBalonUstu, other.gelenBalonUstu),
      teal: l(teal, other.teal),
      mango: l(mango, other.mango),
      nar: l(nar, other.nar),
      vurguUstu: l(vurguUstu, other.vurguUstu),
      pasif: l(pasif, other.pasif),
      pasifUstu: l(pasifUstu, other.pasifUstu),
      odak: l(odak, other.odak),
      markaYuzeyOdak: l(markaYuzeyOdak, other.markaYuzeyOdak),
      golge: l(golge, other.golge),
    );
  }
}

/// Ham palet. Yalnızca bu dosyada kullanılır; dışarıya token adlarıyla
/// ([TayfamColors]) açılır.
abstract final class _Palet {
  // Açık tema (Notion: Tasarım Standartları).
  static const Color brand = Color(0xFF5B2BE0);
  static const Color teal = Color(0xFF00C2A8);
  static const Color mango = Color(0xFFFFB000);
  static const Color nar = Color(0xFFFF3D68);
  static const Color ink = Color(0xFF1B1036);
  static const Color inkMuted = Color(0xFF5A5275);
  static const Color inkBody = Color(0xFF3F3758);
  static const Color surface = Color(0xFFFAF8FF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color line = Color(0xFFE6E1F5);
  static const Color tintBrand = Color(0xFFECE4FF);
  static const Color tintMango = Color(0xFFFFF0CC);
  static const Color honey = Color(0xFF7A5A1E);
  static const Color beyaz = Color(0xFFFFFFFF);

  // Koyu tema (ADR-0004 §2).
  static const Color cardDark = Color(0xFF261A47);
  static const Color lineDark = Color(0xFF3A2D60);
  static const Color textBodyDark = Color(0xFFDCD6EE);
  static const Color textMutedDark = Color(0xFFB4ABD1);
  static const Color brandDark = Color(0xFFA98BFF);
  static const Color tintBrandDark = Color(0xFF3B2A70);
  static const Color tintBrandDarkMetin = Color(0xFFCDBBFF);
  static const Color tintMangoDark = Color(0xFF4A3A1A);
  static const Color tintMangoDarkMetin = Color(0xFFFFD27A);
  static const Color bubbleInDark = Color(0xFF33255C);

  // Tek gölge: rgba(91, 43, 224, .35).
  static const Color golge = Color.fromRGBO(91, 43, 224, .35);
}
