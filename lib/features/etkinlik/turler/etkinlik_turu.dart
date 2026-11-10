import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Bir etkinlik türü (ADR-0002): sözleşmedeki `EventType` değerlerinden
/// biri (`convoy`, `camp`, `hike`, `fishing`, `gaming`, `sports`,
/// `general`).
///
/// Her tür `features/etkinlik/turler/<tür>/` altında bu arayüzü uygular ve
/// kayıt listesine (`shell/kayitlar.dart`) bir satırla eklenir; etkinlik
/// çekirdeğine dokunulmaz.
abstract interface class EtkinlikTuru {
  /// Sözleşmedeki `EventType` değeri (ör. `convoy`).
  String get sunucuDegeri;

  /// Türün ikonu; yanında her zaman [etiket] gösterilir.
  IconData get ikon;

  /// Türün çeviri dosyasından gelen adı.
  String etiket(BuildContext context);

  /// Oluşturma ve düzenleme formuna eklenen türe özel alanlar.
  Widget formAlanlari(BuildContext context);

  /// Etkinlik detay ekranındaki türe özel araç bölümü (rota, malzeme
  /// listesi, yoklama, av günlüğü…); yoksa `null`.
  Widget? aracBolumu(BuildContext context, String etkinlikId);
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
