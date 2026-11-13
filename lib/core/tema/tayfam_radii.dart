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

  /// Seçili satır, menü satırı ve seçim kartı (tayfa menüsü, tayfa
  /// değiştirme paneli; 16 px).
  static const double secim = 16;

  /// Giriş ekranının mor üst alanının alt köşeleri (Design: Giriş).
  static const double ustPanel = 32;

  /// Sohbet balonu.
  static const double balon = 18;

  /// Sohbet balonunun gönderen tarafındaki köşesi.
  static const double balonKuyruk = 6;

  /// "Bu cihazı bağla" ekranındaki QR kartı (28 px; tasarım: Cihaz-QR).
  static const double qrKarti = 28;

  /// Kamera izni ekranındaki büyük ikon kutusu (30 px; tasarım:
  /// Cihaz-Kamera-Izni).
  static const double sonucKutusu = 30;

  /// Tarayıcı çerçevesinin köşe kavisi (22 px; tasarım: Cihaz-Tara).
  static const double taramaKosesi = 22;

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
  static const BorderRadius secimKoseleri = BorderRadius.all(
    Radius.circular(secim),
  );
  static const BorderRadius qrKartiKoseleri = BorderRadius.all(
    Radius.circular(qrKarti),
  );
  static const BorderRadius sonucKutusuKoseleri = BorderRadius.all(
    Radius.circular(sonucKutusu),
  );

  /// Yalnızca alt köşeleri [ustPanel] kadar yuvarlak (giriş ekranının mor
  /// üst alanı).
  static const BorderRadius ustPanelKoseleri = BorderRadius.vertical(
    bottom: Radius.circular(ustPanel),
  );
}
