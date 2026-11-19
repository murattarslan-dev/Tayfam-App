import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';

/// Türe özel aracı olan bir etkinlik türü (ADR-0002): katalogdaki bir
/// türün anahtarı (`camp`, `hike`, `fishing`). Konvoyun araçları `vehicles`
/// bileşenine taşındı (#228).
///
/// Türün adı, ikonu ve alanları katalogdan gelir (ADR-0024); burada
/// yalnızca Faz 1'den kalan türe özel araç bölümü vardır. Araçlar bileşen
/// kaydına taşınınca bu arayüz kalkar (ADR-0024 §3, ADR-0033 §1).
///
/// Her tür `features/etkinlik/turler/<tür>/` altında bu arayüzü uygular ve
/// kayıt listesine (`shell/kayitlar.dart`) bir satırla eklenir; etkinlik
/// çekirdeğine dokunulmaz.
abstract interface class EtkinlikTuru {
  /// Türün katalog anahtarı (ör. `camp`).
  String get sunucuDegeri;

  /// Etkinlik detay ekranındaki türe özel araç bölümü (araç listesi,
  /// malzeme listesi, yoklama, av günlüğü…); yoksa `null`. [etkinlik] tek
  /// etkinlik yanıtıdır (türe özel ayrıntı yalnızca orada gelir).
  Widget? aracBolumu(BuildContext context, Event etkinlik);
}

/// Anahtarını kurucuda alan tür tabanı; alt sınıf yalnızca [aracBolumu]'nu
/// yazar.
abstract class KayitliEtkinlikTuru implements EtkinlikTuru {
  const KayitliEtkinlikTuru(this.sunucuDegeri);

  @override
  final String sunucuDegeri;
}

/// Bilinmeyen türlerin gösterildiği sade tür.
const String genelEtkinlikTuruDegeri = 'general';

/// [kayit]'ta [sunucuDegeri]'ne karşılık gelen tür; yoksa `null`.
///
/// `null` hata değildir: bilinmeyen tür `general` gibi sade etkinlik olarak
/// gösterilir (ADR-0002).
EtkinlikTuru? etkinlikTuruBul(List<EtkinlikTuru> kayit, String sunucuDegeri) {
  for (final tur in kayit) {
    if (tur.sunucuDegeri == sunucuDegeri) {
      return tur;
    }
  }
  return null;
}

/// Uygulamaya kayıtlı etkinlik türleri.
///
/// Liste `shell/kayitlar.dart`'ta tutulur ve uygulamanın kökünde bu
/// provider'a verilir; özellikler `shell/`'i import edemediği için
/// varsayılan değer boş listedir.
final etkinlikTurleriProvider = Provider<List<EtkinlikTuru>>(
  (ref) => const [],
  name: 'etkinlikTurleriProvider',
);
