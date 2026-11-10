import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/core/gezinme/adresler.dart';

/// Tayfa başına açılıp kapanan bir modül (ADR-0002): `announcements`,
/// `events`, `qa`, `polls`. Sohbet ve tayfa yönetimi modül değildir.
///
/// Modülü görünür yapan sunucudan gelen `modules` alanıdır
/// ([gorunurModuller]); istemcinin gizlemesi yetki değildir ve
/// `module-disabled` cevabı her zaman ele alınır (CLAUDE.md, kesin kural 5).
abstract interface class TayfaModule {
  /// Sözleşmedeki `Module` değeri (ör. `events`).
  String get sunucuAnahtari;

  /// Modülün rotaları. Göreli yollardır ve `/t/:tayfaId` rotasının altına
  /// eklenir; böylece her modül adresi tayfa kimliğini taşır ve Tayfa
  /// sekmesinin geçmişinde kalır.
  List<RouteBase> get rotalar;

  /// Tayfa ana sayfasında gösterilen kart.
  Widget anaSayfaKarti(BuildContext context, String tayfaId);

  /// Tayfa sekmesinin alt gezinmesindeki giriş.
  TayfaModuluGirisi get gezinmeGirisi;
}

/// Bir modülün Tayfa sekmesindeki gezinme girişi.
@immutable
class TayfaModuluGirisi {
  const TayfaModuluGirisi({
    required this.ikon,
    required this.etiket,
    required this.altYol,
  });

  /// Girişin ikonu; yanında her zaman [etiket] gösterilir.
  final IconData ikon;

  /// Girişin çeviri dosyasından gelen etiketi.
  final String Function(BuildContext context) etiket;

  /// Modülün `/t/<tayfaId>/` altındaki yolu (ör. `etkinlikler`).
  final String altYol;

  /// Girişin [tayfaId] tayfasındaki tam adresi.
  String adres(String tayfaId) => '${Adresler.tayfa(tayfaId)}/$altYol';
}

/// [kayit]'taki modüllerden sunucunun açık dediği ([sunucuModulleri])
/// olanları kayıt sırasıyla döndürür.
///
/// Sunucunun bizim bilmediğimiz bir modül anahtarı göndermesi hata
/// değildir; o anahtar yok sayılır (ADR-0002).
List<TayfaModule> gorunurModuller(
  List<TayfaModule> kayit,
  Iterable<String> sunucuModulleri,
) {
  final acik = sunucuModulleri.toSet();
  return [
    for (final modul in kayit)
      if (acik.contains(modul.sunucuAnahtari)) modul,
  ];
}

/// Uygulamaya kayıtlı tayfa modülleri.
///
/// Liste `shell/kayitlar.dart`'ta tutulur ve uygulamanın kökünde bu
/// provider'a verilir; `core/` `shell/`'i import edemediği için
/// varsayılan değer boş listedir. Testler kendi modüllerini override ile
/// verir (ADR-0001, kural 7).
final tayfaModulleriProvider = Provider<List<TayfaModule>>(
  (ref) => const [],
  name: 'tayfaModulleriProvider',
);
