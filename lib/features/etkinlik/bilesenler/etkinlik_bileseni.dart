import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_parametreleri.dart';
import 'package:tayfam/l10n/app_localizations.dart';

/// Çağıranın etkinlikteki rolü (ADR-0024 §3). Yalnızca arayüzü
/// sadeleştirmek içindir: bir işlemin yapılıp yapılamayacağına sunucu karar
/// verir (kesin kural 5); bileşen sunucunun hatasını her durumda gösterir.
enum BilesenRolu {
  /// Etkinliği açan, moderatör ya da yönetici (`caller_can_manage`).
  organizator,

  /// Bu bileşene (ya da etkinliğin tamamına) atanmış hakem: organizatörle
  /// birlikte sonuç girer (Tayfam-Api ADR-0025 §5).
  hakem,

  /// "Geliyorum" diyen üye.
  katilimci,

  /// Diğer üyeler.
  uye,
}

/// Sihirbazdaki form bölümünün bağlantısı: bileşen, organizatöre bırakılan
/// parametrelerdeki seçimi bununla bildirir (ADR-0031 §1).
@immutable
final class BilesenFormu {
  const BilesenFormu({required this.onSecim});

  /// [param] parametresinde [deger] seçildi. `null`: seçimler salt
  /// okunurdur (etkinlik başladı ya da gönderim sürüyor).
  final void Function(String param, String deger)? onSecim;
}

/// Bir bileşenin çizileceği bağlam (ADR-0024 §3): etkinlik, bileşenin
/// tanımdaki anahtarı ve parametreleri, organizatörün seçimleri ve
/// çağıranın rolü.
@immutable
final class BilesenBaglami {
  const BilesenBaglami({
    required this.tanim,
    required this.rol,
    this.tayfaId,
    this.etkinlik,
    this.secimler = const {},
    this.kilitli = false,
    this.form,
  });

  /// Bileşenin tür tanımındaki kaydı.
  final CatalogComponent tanim;

  final BilesenRolu rol;

  /// Etkinliğin tayfası; anlık etkinlik sihirbazında (tayfa henüz yokken)
  /// `null`.
  final String? tayfaId;

  /// Etkinlik; oluşturma sihirbazında `null`.
  final Event? etkinlik;

  /// Organizatöre bırakılan parametrelerde geçerli seçenek (parametre adı
  /// → seçenek): organizatörün seçimi ya da tanımdaki varsayılan.
  final Map<String, String> secimler;

  /// Seçimler artık değişmez (`EventComponentList.locked`: etkinlik
  /// başladı ya da iptal edildi, ya da tayfa salt okunur).
  final bool kilitli;

  /// Yalnızca sihirbazdaki form bölümünde doludur.
  final BilesenFormu? form;

  /// Bileşenin anahtarı: bileşen uçlarındaki `{component_key}`.
  String get anahtar => bilesenAnahtari(tanim);

  /// Parametreler; seçimli parametre geçerli seçimiyle okunur.
  BilesenParametreleri get params =>
      BilesenParametreleri(tanim.params, secimler);

  /// Organizatöre bırakılan [param] parametresi; öyle bir parametre yoksa
  /// `null`.
  SecimliParametre? secimli(String param) {
    for (final p in secimliParametreler(tanim)) {
      if (p.ad == param) return p;
    }
    return null;
  }

  /// Organizatör, moderatör ya da yönetici mi.
  bool get yonetebilir => rol == BilesenRolu.organizator;

  /// Sonuç girebilir mi (organizatör ya da hakem).
  bool get sonucGirebilir =>
      rol == BilesenRolu.organizator || rol == BilesenRolu.hakem;
}

/// Bir etkinlik bileşeni (ADR-0024 §3): sözleşmedeki bir `component kind`'ın
/// istemcideki karşılığı. Tür tanımı veridir; istemci yalnızca bu kayıttaki
/// bileşenleri çizer.
///
/// Her bileşen `features/etkinlik/bilesenler/<bileşen>/` altında bu arayüzü
/// uygular ve kayıt listesine (`shell/kayitlar.dart`,
/// `etkinlikBilesenKaydi`) bir satırla eklenir; etkinlik çekirdeğine
/// dokunulmaz. Bölümü olmayan yer için `null` döner.
abstract interface class EtkinlikBileseni {
  /// Sözleşmedeki bileşen türü (`CatalogComponent.kind`; ör. `scoreboard`).
  String get tur;

  /// Bileşenin adı (çeviri dosyasından). Tanımda `labels` varsa o
  /// gösterilir (katalog metni, ADR-0024 §2); bu, yokken kullanılır.
  String ad(AppLocalizations m);

  /// Oluşturma ve düzenleme sihirbazının türe özel adımındaki bölüm:
  /// organizatöre bırakılan seçimler ([BilesenBaglami.form]) ve bileşenin
  /// oluşturma alanları.
  Widget? formBolumu(BilesenBaglami b);

  /// Etkinlik detayındaki bölüm (başlığıyla birlikte).
  Widget? detayBolumu(BilesenBaglami b);

  /// Etkinlik kartındaki tek satır (isteğe bağlı; ADR-0024 §3). Liste
  /// yanıtı bileşen verisi taşımadığı için henüz hiçbir kartta çizilmez
  /// (ADR-0024 Notlar, 2026-11-19).
  Widget? ozetSatiri(BilesenBaglami b);
}

/// Bölümü olmayan bileşenlerin tabanı: alt sınıf yalnızca çizdiği yeri
/// yazar.
abstract class KayitliBilesen implements EtkinlikBileseni {
  const KayitliBilesen(this.tur);

  @override
  final String tur;

  @override
  Widget? formBolumu(BilesenBaglami b) => null;

  @override
  Widget? detayBolumu(BilesenBaglami b) => null;

  @override
  Widget? ozetSatiri(BilesenBaglami b) => null;
}

/// Etkinliğin temel alanlarıyla karşılanan bileşen: kendi bölümü, ucu ve
/// seçimi yoktur. `meeting_point` böyledir (buluşma noktası etkinliğin
/// temel alanıdır ve detayda her etkinlikte çizilir; Tayfam-Api ADR-0025
/// §4). Kayıtta durur ki "Uygulamayı güncelle" kartı çıkmasın.
final class TemelBilesen extends KayitliBilesen {
  const TemelBilesen(super.tur);

  @override
  String ad(AppLocalizations m) => '';
}

/// [kayit]'ta [tur] türündeki bileşen; yoksa `null` (o bölümde "Uygulamayı
/// güncelle" kartı gösterilir).
EtkinlikBileseni? etkinlikBileseniBul(
  List<EtkinlikBileseni> kayit,
  String tur,
) {
  for (final bilesen in kayit) {
    if (bilesen.tur == tur) return bilesen;
  }
  return null;
}

/// Uygulamaya kayıtlı etkinlik bileşenleri.
///
/// Liste `shell/kayitlar.dart`'ta tutulur ve uygulamanın kökünde bu
/// provider'a verilir; özellikler `shell/`'i import edemediği için
/// varsayılan değer boş listedir.
final etkinlikBilesenKaydiProvider = Provider<List<EtkinlikBileseni>>(
  (ref) => const [],
  name: 'etkinlikBilesenKaydiProvider',
);
