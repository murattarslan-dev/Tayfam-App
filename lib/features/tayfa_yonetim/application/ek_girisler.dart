import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bir ek girişin bekleyen iş sayısı (ör. açık şikâyet): okunan ilk
/// sayfadaki adet ve devamı olup olmadığı. Toplam sözleşmede yoksa
/// "N+" gösterilir; sayı uydurulmaz.
typedef EkGirisSayisi = ({int sayi, bool devami});

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
    this.sayi,
    this.ozet,
    this.bekleyenMetni,
    this.bekleyenEtiketi,
  });

  /// Girişin ikonu.
  final IconData ikon;

  /// Girişin çeviri dosyasından gelen etiketi.
  final String Function(BuildContext context) etiket;

  /// Girişin [tayfaId] tayfasındaki tam adresi (ör.
  /// `/t/<tayfaId>/ayarlar/moderasyon`).
  final String Function(String tayfaId) adres;

  /// Bekleyen iş sayısı; ayarlar ekranının `build`'inde çağrılır ve [ref]
  /// ile izleyebilir. Veri yalnızca bellektedir. Henüz bilinmiyorsa `null`.
  final EkGirisSayisi? Function(WidgetRef ref, String tayfaId)? sayi;

  /// Satırın altındaki özet ("2 açık şikâyet", "20+ açık şikâyet").
  final String Function(BuildContext context, EkGirisSayisi sayi)? ozet;

  /// "Seni bekleyenler" kartındaki satırın metni (sayı rozetin içindedir).
  final String Function(BuildContext context)? bekleyenMetni;

  /// "Seni bekleyenler" satırının ekran okuyucu etiketi.
  final String Function(BuildContext context, EkGirisSayisi sayi)?
  bekleyenEtiketi;
}

/// Ayarlar ekranındaki ek girişler. Varsayılanı boştur; giriş ekleyen
/// paket `shell/kayitlar.dart`'ta bu provider'ı override eder ve
/// rotalarını kendisi kaydeder.
final yonetimEkGirisleriProvider = Provider<List<YonetimEkGirisi>>(
  (ref) => const [],
  name: 'yonetimEkGirisleriProvider',
);
