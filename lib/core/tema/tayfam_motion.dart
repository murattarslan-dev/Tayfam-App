import 'package:flutter/animation.dart';

/// Hareket süreleri ve eğrileri (ADR-0004: geçişler 150–250 ms).
///
/// "Hareketi azalt" açıkken (`MediaQuery.disableAnimationsOf`) bileşenler
/// süs animasyonlarını kapatır ve geçişleri anında yapar.
abstract final class TayfamMotion {
  /// Küçük durum değişimleri (renk, saydamlık).
  static const Duration kisa = Duration(milliseconds: 150);

  /// Varsayılan geçiş.
  static const Duration orta = Duration(milliseconds: 200);

  /// Daha büyük yer değişimleri (anket çubuğu dolumu).
  static const Duration uzun = Duration(milliseconds: 250);

  /// "Çok yakında" rozetindeki noktanın bir nabız turu. Geçiş değil, durum
  /// göstergesidir; "hareketi azalt" açıkken çalışmaz.
  static const Duration nabiz = Duration(milliseconds: 1600);

  /// Varsayılan eğri.
  static const Curve egri = Curves.easeOutCubic;

  // --- Açılış logosu (Design: Splash animasyonu; issue #100) -------------
  //
  // Önce L yerine oturur, sonra mango, nar ve turkuaz bloklar dışarıdan
  // hafif taşarak gelir; yazı en son yükselir. Toplam ~820 ms. Süs
  // animasyonudur: "hareketi azalt" açıkken oynamaz, logo doğrudan
  // görünür.

  /// Her bloğun giriş süresi.
  static const Duration acilisBlok = Duration(milliseconds: 420);

  /// L parçasının başlama gecikmesi.
  static const Duration acilisL = Duration.zero;

  /// Mango bloğun başlama gecikmesi.
  static const Duration acilisMango = Duration(milliseconds: 80);

  /// Nar bloğun başlama gecikmesi.
  static const Duration acilisNar = Duration(milliseconds: 140);

  /// Turkuaz bloğun başlama gecikmesi.
  static const Duration acilisTurkuaz = Duration(milliseconds: 200);

  /// "tayfam" yazısının başlama gecikmesi.
  static const Duration acilisYaziGecikmesi = Duration(milliseconds: 520);

  /// "tayfam" yazısının yükselme süresi.
  static const Duration acilisYazi = Duration(milliseconds: 300);

  /// Açılış animasyonunun toplam süresi (yazının bitişi).
  static const Duration acilisToplam = Duration(milliseconds: 820);

  /// Blokların eğrisi: CSS `cubic-bezier(.2, .9, .3, 1.25)`; sonda hafif
  /// taşar.
  static const Curve acilisEgrisi = Cubic(.2, .9, .3, 1.25);

  /// Yazının eğrisi: CSS `ease-out`.
  static const Curve acilisYaziEgrisi = Curves.easeOut;
}
