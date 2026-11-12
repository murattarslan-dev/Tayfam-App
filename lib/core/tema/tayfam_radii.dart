import 'package:flutter/painting.dart';

/// Köşe yarıçapları (Notion: Tasarım Standartları; ADR-0004).
abstract final class TayfamRadii {
  /// Hap (tam yuvarlak): birincil eylem, rozet, etiket, çip.
  static const double hap = 999;

  /// Kart.
  static const double kart = 22;

  /// Önizleme (görsel, bağlantı önizlemesi).
  static const double onizleme = 14;

  /// Düğme ve giriş alanı (ikincil eylem dahil).
  static const double dugme = 12;

  /// Giriş ekranının mor üst alanının alt köşeleri (Design: Giriş).
  static const double ustPanel = 32;

  /// Sohbet balonu.
  static const double balon = 18;

  /// Sohbet balonunun gönderen tarafındaki köşesi.
  static const double balonKuyruk = 6;

  static const BorderRadius hapKoseleri = BorderRadius.all(
    Radius.circular(hap),
  );
  static const BorderRadius kartKoseleri = BorderRadius.all(
    Radius.circular(kart),
  );
  static const BorderRadius onizlemeKoseleri = BorderRadius.all(
    Radius.circular(onizleme),
  );
  static const BorderRadius dugmeKoseleri = BorderRadius.all(
    Radius.circular(dugme),
  );

  /// Yalnızca alt köşeleri [ustPanel] kadar yuvarlak (giriş ekranının mor
  /// üst alanı).
  static const BorderRadius ustPanelKoseleri = BorderRadius.vertical(
    bottom: Radius.circular(ustPanel),
  );
}
