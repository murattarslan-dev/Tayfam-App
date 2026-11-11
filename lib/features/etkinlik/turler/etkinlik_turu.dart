import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/moduller/etkinlik_turu_kaydi.dart';
import 'package:tayfam/l10n/app_localizations.dart';

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
  ///
  /// Şimdilik kullanılmaz: alanlar sihirbazda türe göre `switch` ile
  /// yazılır (ADR-0015 Notlar 3).
  Widget formAlanlari(BuildContext context);

  /// Etkinlik detay ekranındaki türe özel araç bölümü (araç listesi,
  /// malzeme listesi, yoklama, av günlüğü…); yoksa `null`. [etkinlik] tek
  /// etkinlik yanıtıdır (türe özel ayrıntı yalnızca orada gelir).
  Widget? aracBolumu(BuildContext context, Event etkinlik);
}

/// Kayıttaki görünümünü (ad, ikon) `core/moduller/etkinlik_turu_kaydi`'ndan
/// alan tür tabanı; alt sınıf yalnızca [aracBolumu]'nu yazar.
abstract class KayitliEtkinlikTuru implements EtkinlikTuru {
  const KayitliEtkinlikTuru(this.tur);

  /// Sözleşmedeki tür.
  final EventType tur;

  @override
  String get sunucuDegeri => tur.wire;

  @override
  IconData get ikon => etkinlikTuruGirdisi(tur).ikon;

  @override
  String etiket(BuildContext context) =>
      etkinlikTuruGirdisi(tur).ad(AppLocalizations.of(context));

  /// Alanlar sihirbazdadır (ADR-0015 Notlar 3).
  @override
  Widget formAlanlari(BuildContext context) => const SizedBox.shrink();
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
