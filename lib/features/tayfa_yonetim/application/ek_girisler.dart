import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tayfa ayarları ekranına başka bir paketin eklediği giriş (ör. şikâyet
/// ve moderasyon kuyruğu, ADR-0018 §8; dalga 2).
///
/// Giriş moderatör ve yöneticiye görünür (ayarlar ekranı yalnızca onlara
/// açılır); yetkiyi yine sunucu verir (kesin kural 5).
@immutable
class YonetimEkGirisi {
  const YonetimEkGirisi({
    required this.ikon,
    required this.etiket,
    required this.adres,
  });

  /// Girişin ikonu.
  final IconData ikon;

  /// Girişin çeviri dosyasından gelen etiketi.
  final String Function(BuildContext context) etiket;

  /// Girişin [tayfaId] tayfasındaki tam adresi (ör.
  /// `/t/<tayfaId>/ayarlar/moderasyon`).
  final String Function(String tayfaId) adres;
}

/// Ayarlar ekranındaki ek girişler. Varsayılanı boştur; giriş ekleyen
/// paket `shell/kayitlar.dart`'ta bu provider'ı override eder ve
/// rotalarını kendisi kaydeder.
final yonetimEkGirisleriProvider = Provider<List<YonetimEkGirisi>>(
  (ref) => const [],
  name: 'yonetimEkGirisleriProvider',
);
