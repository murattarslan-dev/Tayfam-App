/// Boşluk adımları (Notion: Tasarım Standartları; ADR-0004).
///
/// Ekranlarda ve bileşenlerde sabit boşluk sayısı yazılmaz; yalnızca bu
/// adımlar kullanılır. Değerler temadan bağımsızdır.
abstract final class TayfamSpacing {
  static const double s4 = 4;
  static const double s8 = 8;
  static const double s12 = 12;
  static const double s16 = 16;
  static const double s20 = 20;
  static const double s24 = 24;
  static const double s32 = 32;
  static const double s40 = 40;
  static const double s56 = 56;
  static const double s64 = 64;

  /// Mobilde sayfa kenar boşluğu (ADR-0004 §5).
  static const double kenarMobil = s16;

  /// Geniş ekranda en fazla sayfa kenar boşluğu (ADR-0004 §5).
  static const double kenarGenis = 48;

  /// Kart iç boşluğu.
  static const double kartIci = s20;

  /// Bütün adımlar, küçükten büyüğe (testler için).
  static const List<double> adimlar = [
    s4,
    s8,
    s12,
    s16,
    s20,
    s24,
    s32,
    s40,
    s56,
    s64,
  ];
}
