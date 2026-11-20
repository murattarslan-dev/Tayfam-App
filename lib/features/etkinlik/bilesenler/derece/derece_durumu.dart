import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/katalog/alan_cizici.dart';
import 'package:tayfam/core/metin/sure.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/application/katilimcilar.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/olcum/olcum_durumu.dart';
import 'package:tayfam/features/etkinlik/data/etkinlik_deposu.dart';
import 'package:tayfam/l10n/app_localizations.dart';

export 'package:tayfam/core/metin/sure.dart' show sureMetni, sureOkunusu;

/// Bir etkinliğin bir derece bileşeni: bileşen uçlarındaki
/// `{component_key}` ([anahtar]) ve tanımdaki kaynak ölçümün anahtarı
/// ([kaynak], `source` parametresi). Ölçümden hesaplanan derecede ölçüm
/// değişince canlı olay ölçümün anahtarıyla gelir; derece onunla da
/// yeniden okunur.
typedef DereceKimligi = ({
  String tayfaId,
  String etkinlikId,
  String anahtar,
  String? kaynak,
});

/// Sözleşmedeki süre üst sınırı (`EventRankingValueRequest.value`, saniye).
const double dereceSureEnCok = 1000000;

/// Sözleşmedeki elle girilen sıranın sınırları (`rank` ölçütü).
const int dereceSiraEnAz = 1;
const int dereceSiraEnCok = 10000;

/// Sürenin ondalık basamağı (`duration` ölçütü: saniye, iki basamak).
const int dereceSureBasamagi = 2;

/// Süre girdisinin bir parçasındaki en çok rakam (taşmayı önler; sınırı
/// [dereceSureEnCok] denetler).
const int _parcaRakamiEnCok = 9;

/// Saniyedeki santisaniye.
const int _santi = 100;

/// Formdaki derece girdisinin hatası.
enum DereceHatasi {
  /// Boş.
  zorunlu,

  /// Süre `s:dd:ss,cc` ya da sıra tam sayı biçiminde değil.
  bicim,

  /// Sınırların dışında.
  aralik,

  /// Saniyede iki basamaktan fazla.
  basamak,
}

/// Okunan girdi: değer ya da hata.
typedef DereceGirdisi = ({double? deger, DereceHatasi? hata});

/// Süre girdisini saniyeye çevirir. Kabul edilen biçimler: `1:02:03,45`
/// (saat:dakika:saniye), `62:03,4` (dakika:saniye), `45,5` ya da `3723`
/// (saniye). Ondalık ayracı virgül ya da nokta; saniyede en çok iki
/// basamak. Baştaki parça sınırsız, sonrakiler 60'tan küçüktür. Değer
/// sıfırdan büyük ve en çok [dereceSureEnCok] saniyedir. Hesap tam sayı
/// santisaniyeyle yapılır (kayan nokta hatası olmasın).
DereceGirdisi sureGirdisiniOku(String metin) {
  final temiz = metin.trim();
  if (temiz.isEmpty) return (deger: null, hata: DereceHatasi.zorunlu);
  final parcalar = temiz.split(':');
  if (parcalar.length > 3) return (deger: null, hata: DereceHatasi.bicim);
  final son = RegExp(r'^(\d+)(?:[.,](\d*))?$').firstMatch(parcalar.last);
  if (son == null) return (deger: null, hata: DereceHatasi.bicim);
  final tamKisim = son.group(1)!;
  final kesir = son.group(2) ?? '';
  if (kesir.length > dereceSureBasamagi) {
    return (deger: null, hata: DereceHatasi.basamak);
  }
  var toplam = 0;
  for (var i = 0; i < parcalar.length - 1; i++) {
    final parca = parcalar[i];
    if (!RegExp(r'^\d+$').hasMatch(parca)) {
      return (deger: null, hata: DereceHatasi.bicim);
    }
    if (parca.length > _parcaRakamiEnCok) {
      return (deger: null, hata: DereceHatasi.aralik);
    }
    final sayi = int.parse(parca);
    if (i > 0 && sayi >= 60) return (deger: null, hata: DereceHatasi.bicim);
    toplam = toplam * 60 + sayi;
  }
  if (tamKisim.length > _parcaRakamiEnCok) {
    return (deger: null, hata: DereceHatasi.aralik);
  }
  final saniye = int.parse(tamKisim);
  if (parcalar.length > 1 && saniye >= 60) {
    return (deger: null, hata: DereceHatasi.bicim);
  }
  toplam = toplam * 60 + saniye;
  final santi =
      toplam * _santi +
      (kesir.isEmpty ? 0 : int.parse(kesir.padRight(dereceSureBasamagi, '0')));
  if (santi <= 0 || santi > dereceSureEnCok * _santi) {
    return (deger: null, hata: DereceHatasi.aralik);
  }
  return (deger: santi / _santi, hata: null);
}

/// Elle girilen sırayı okur: [dereceSiraEnAz]–[dereceSiraEnCok] arası tam
/// sayı.
DereceGirdisi siraGirdisiniOku(String metin) {
  final temiz = metin.trim();
  if (temiz.isEmpty) return (deger: null, hata: DereceHatasi.zorunlu);
  if (!RegExp(r'^\d+$').hasMatch(temiz)) {
    return (deger: null, hata: DereceHatasi.bicim);
  }
  if (temiz.length > _parcaRakamiEnCok) {
    return (deger: null, hata: DereceHatasi.aralik);
  }
  final sira = int.parse(temiz);
  if (sira < dereceSiraEnAz || sira > dereceSiraEnCok) {
    return (deger: null, hata: DereceHatasi.aralik);
  }
  return (deger: sira.toDouble(), hata: null);
}

/// Derece elle mi giriliyor (kaynak ölçüm yok).
bool dereceElle(EventRanking derece) => derece.source == null;

/// Elle girilen derecenin ölçütü uygulamanın bu sürümünce tanınıyor mu.
bool dereceOlcutuTanindi(EventRanking derece) =>
    !dereceElle(derece) ||
    derece.metric == EventRankingMetric.duration ||
    derece.metric == EventRankingMetric.rank;

/// Satırdaki değerin yazımı: süre `1:02:03,45`, ölçümden hesaplanan derece
/// birimiyle (`12,4 km`). Elle girilen sırada değer sıranın kendisidir;
/// ayrıca yazılmaz (`null`).
String? dereceDegeriMetni(AppLocalizations m, EventRanking derece, double v) {
  if (dereceElle(derece)) {
    return switch (derece.metric) {
      EventRankingMetric.duration => sureMetni(m, v),
      _ => null,
    };
  }
  final sayi = olcumSayisi(m, v, derece.decimals.clamp(0, olcumBasamakEnCok));
  final birim = katalogBirimAdi(m, derece.unit);
  return birim == null ? sayi : m.katalog_birimli_deger(sayi, birim);
}

/// Satırdaki değerin ekran okuyucu metni (yalnızca sürede yazımından
/// farklıdır); `null`: görünen metin okunur.
String? dereceDegeriOkunusu(
  AppLocalizations m,
  EventRanking derece,
  double v,
) => dereceElle(derece) && derece.metric == EventRankingMetric.duration
    ? sureOkunusu(m, v)
    : null;

/// Formdaki [metin]'i derecenin ölçütüne göre okur.
DereceGirdisi dereceGirdisiniOku(EventRanking derece, String metin) =>
    derece.metric == EventRankingMetric.rank
    ? siraGirdisiniOku(metin)
    : sureGirdisiniOku(metin);

/// Düzeltmede formun ilk metni.
String dereceGirdisi(AppLocalizations m, EventRanking derece, double? v) {
  if (v == null) return '';
  return derece.metric == EventRankingMetric.rank
      ? v.round().toString()
      : sureMetni(m, v);
}

/// Formdaki hatanın metni.
String dereceHataMetni(
  AppLocalizations m,
  EventRanking derece,
  DereceHatasi hata,
) {
  final sira = derece.metric == EventRankingMetric.rank;
  return switch (hata) {
    DereceHatasi.zorunlu => m.katalog_alan_zorunlu,
    DereceHatasi.basamak => m.katalog_alan_basamak(dereceSureBasamagi),
    DereceHatasi.bicim =>
      sira ? m.katalog_alan_sayi : m.bilesen_ranking_sure_bicim,
    DereceHatasi.aralik =>
      sira
          ? m.katalog_alan_aralik('$dereceSiraEnAz', '$dereceSiraEnCok')
          : m.bilesen_ranking_sure_aralik(sureMetni(m, dereceSureEnCok)),
  };
}

/// Derecenin yeniden okunmasını gerektiren hatalar: durumu etkinlikle ya
/// da tür tanımıyla değişmiş.
const Set<ProblemType> _bayatDereceHatalari = {
  ProblemType.eventCancelled,
  ProblemType.componentFrozen,
  ProblemType.componentDisabled,
  ProblemType.rankingNotStarted,
  ProblemType.rankingFromMeasure,
};

/// Derece bileşeni (`GET …/components/{component_key}/ranking`;
/// Tayfam-Api #253), çağıranın gördüğü haliyle. Bölüm açıkken canlıdır
/// (ADR-0024 §5): bileşen ya da kaynak ölçüm değişince REST'ten yeniden
/// okunur.
///
/// Değerler yalnızca bellekte tutulur ve loglanmaz (ADR-0006). Hassas
/// ölçümden hesaplanan derece yetkisi olmayana gizlidir (`hidden`, boş
/// liste). Yazan her uç derecenin güncel halini döner; durum onunla
/// değişir. Yetki sunucudadır; istemci yalnızca düğmeleri sadeleştirir
/// (kesin kural 5).
class DereceNotifier extends AsyncNotifier<EventRanking> {
  DereceNotifier(this.kimlik);

  final DereceKimligi kimlik;

  @override
  Future<EventRanking> build() {
    final etkinlik = (tayfaId: kimlik.tayfaId, etkinlikId: kimlik.etkinlikId);
    bilesenDegisiminiIzle(ref, etkinlik, kimlik.anahtar);
    final kaynak = kimlik.kaynak;
    if (kaynak != null && kaynak != kimlik.anahtar) {
      bilesenDegisiminiIzle(ref, etkinlik, kaynak);
    }
    ref.watch(etkinlikDetayProvider(etkinlik).select((d) => d.value?.status));
    return ref
        .read(etkinlikDeposuProvider)
        .derece(kimlik.tayfaId, kimlik.etkinlikId, kimlik.anahtar);
  }

  /// Baştan okur ("Tekrar dene").
  Future<void> yenile() async {
    ref.invalidateSelf();
    try {
      await future;
    } on Exception {
      // Hata durumu bölümde gösterilir.
    }
  }

  /// [kullaniciId]'nin derecesini [deger] yapar (süre saniye ya da sıra).
  Future<Object?> degeriYaz(String kullaniciId, double deger) => _yaz(
    (d) => d.dereceYaz(
      kimlik.tayfaId,
      kimlik.etkinlikId,
      kimlik.anahtar,
      kullaniciId,
      deger,
    ),
  );

  /// [kullaniciId]'nin derecesini kaldırır.
  Future<Object?> degeriKaldir(String kullaniciId) => _yaz(
    (d) => d.dereceyiKaldir(
      kimlik.tayfaId,
      kimlik.etkinlikId,
      kimlik.anahtar,
      kullaniciId,
    ),
  );

  /// Başarıda `null`, değilse hata döner; durum değişmez ve hata çağıranda
  /// gösterilir. Derece bayatlamışsa yeniden okunur.
  Future<Object?> _yaz(
    Future<EventRanking> Function(EtkinlikDeposu depo) islem,
  ) async {
    try {
      final derece = await islem(ref.read(etkinlikDeposuProvider));
      if (ref.mounted) state = AsyncData(derece);
      return null;
    } on Exception catch (hata) {
      if (hata is ApiProblem &&
          _bayatDereceHatalari.contains(hata.type) &&
          ref.mounted) {
        ref.invalidateSelf();
      }
      return hata;
    }
  }
}

/// Bir derece bileşeninin durumu. Hata otomatik yeniden denenmez.
final dereceProvider = AsyncNotifierProvider.autoDispose
    .family<DereceNotifier, EventRanking, DereceKimligi>(
      DereceNotifier.new,
      name: 'dereceProvider',
      retry: yenidenDenemeYok,
    );
