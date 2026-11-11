import 'package:flutter/foundation.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/features/etkinlik/application/tekrar_kurali.dart';
import 'package:tayfam/features/etkinlik/data/dis_uygulamalar.dart';

/// Sihirbazın adım sayısı (ADR-0015 §3): tür; başlık ve zaman; yer;
/// türe özel alanlar, kontenjan ve tekrar.
const int etkinlikAdimSayisi = 4;

/// Sözleşmedeki uzunluk ve sayı sınırları (`EventCreateRequest`,
/// `*DetailsInput`).
const int etkinlikBaslikEnCok = 120;
const int etkinlikAciklamaEnCok = 5000;
const int etkinlikYerAdiEnCok = 120;
const int etkinlikIlEnCok = 50;
const int etkinlikBaglantiEnCok = 2048;
const int etkinlikKontenjanEnCok = 10000;
const int etkinlikOyunEnCok = 60;
const int etkinlikSahaEnCok = 120;
const int etkinlikKampYeriEnCok = 120;
const int etkinlikKampNotuEnCok = 1000;
const int etkinlikZorlukEnCok = 5;
const double etkinlikMesafeEnCok = 1000;
const int etkinlikYukseltiEnCok = 9000;
const int etkinlikToleransEnCok = 1440;

/// Sihirbazda seçilebilen türler, sözleşmenin sırasıyla.
const List<EventType> secilebilirEtkinlikTurleri = [
  EventType.convoy,
  EventType.camp,
  EventType.hike,
  EventType.fishing,
  EventType.gaming,
  EventType.sports,
  EventType.general,
];

/// Seçilebilen oyun platformları (sözleşme sırasıyla).
const List<GamingDetailsPlatform> secilebilirPlatformlar = [
  GamingDetailsPlatform.pc,
  GamingDetailsPlatform.playstation,
  GamingDetailsPlatform.xbox,
  GamingDetailsPlatform.switch_,
  GamingDetailsPlatform.mobile,
  GamingDetailsPlatform.other,
];

/// Seçilebilen spor dalları (sözleşme sırasıyla).
const List<SportsDetailsSport> secilebilirSporlar = [
  SportsDetailsSport.football,
  SportsDetailsSport.tableFootball,
  SportsDetailsSport.basketball,
  SportsDetailsSport.volleyball,
  SportsDetailsSport.tennis,
  SportsDetailsSport.tableTennis,
  SportsDetailsSport.other,
];

/// Sihirbazdaki bir alanın hatası.
enum TaslakHatasi {
  tur,
  baslik,
  aciklama,
  baslangicYok,
  baslangicGecmis,
  bitis,
  nokta,
  noktaAdi,
  il,
  ilce,
  baglanti,
  kontenjan,
  oyun,
  platform,
  spor,
  sahaAdi,
  kampYeri,
  kampNotu,
  mesafe,
  yukselti,
  donus,
  tolerans,
  tekrarAralik,
  tekrarSayi,
  tekrarTarih,
}

const Object _ayni = Object();

/// Yer adımı: yüz yüze ise buluşma noktası, il ve ilçe; çevrimiçi ise
/// bağlantı. Buluşma noktası kullanıcının bilerek paylaştığı içeriktir
/// (kesin kural 3); log'a yazılmaz.
@immutable
final class YerBilgisi {
  const YerBilgisi({
    this.mod = EventMode.inPerson,
    this.nokta,
    this.noktaAdi = '',
    this.il = '',
    this.ilce = '',
    this.baglanti = '',
  });

  final EventMode mod;
  final LatLng? nokta;
  final String noktaAdi;
  final String il;
  final String ilce;
  final String baglanti;

  YerBilgisi kopya({
    EventMode? mod,
    LatLng? nokta,
    String? noktaAdi,
    String? il,
    String? ilce,
    String? baglanti,
  }) => YerBilgisi(
    mod: mod ?? this.mod,
    nokta: nokta ?? this.nokta,
    noktaAdi: noktaAdi ?? this.noktaAdi,
    il: il ?? this.il,
    ilce: ilce ?? this.ilce,
    baglanti: baglanti ?? this.baglanti,
  );

  @override
  bool operator ==(Object other) =>
      other is YerBilgisi &&
      other.mod == mod &&
      other.nokta == nokta &&
      other.noktaAdi == noktaAdi &&
      other.il == il &&
      other.ilce == ilce &&
      other.baglanti == baglanti;

  @override
  int get hashCode => Object.hash(mod, nokta, noktaAdi, il, ilce, baglanti);
}

/// Türe özel alanlar (sözleşmedeki `*DetailsInput`). Sayılar metin olarak
/// tutulur; gönderilirken okunur. Konvoy rotası türe özel araçlarla gelir
/// (ADR-0015 §7, paket 3); burada girilmez.
@immutable
final class TurAyrintisi {
  const TurAyrintisi({
    this.kampYeri = '',
    this.su,
    this.tuvalet,
    this.kampNotu = '',
    this.zorluk = 0,
    this.mesafe = '',
    this.yukselti = '',
    this.donus,
    this.tolerans = '',
    this.balikGizliligi = FishingDetailsSpotVisibility.tayfa,
    this.oyun = '',
    this.platform,
    this.spor,
    this.sahaAdi = '',
  });

  /// Kamp: yer adı, su ve tuvalet (bilinmiyorsa `null`), not.
  final String kampYeri;
  final bool? su;
  final bool? tuvalet;
  final String kampNotu;

  /// Yürüyüş: zorluk (0: verilmemiş, 1–5), mesafe (km), yükselti (m),
  /// beklenen dönüş ve dönüş toleransı (dakika).
  final int zorluk;
  final String mesafe;
  final String yukselti;
  final DateTime? donus;
  final String tolerans;

  /// Balık: buluşma noktasını kimin göreceği.
  final FishingDetailsSpotVisibility balikGizliligi;

  /// Oyun: oyunun adı ve platform (ikisi de zorunlu).
  final String oyun;
  final GamingDetailsPlatform? platform;

  /// Spor: dal (zorunlu) ve saha adı.
  final SportsDetailsSport? spor;
  final String sahaAdi;

  TurAyrintisi kopya({
    String? kampYeri,
    Object? su = _ayni,
    Object? tuvalet = _ayni,
    String? kampNotu,
    int? zorluk,
    String? mesafe,
    String? yukselti,
    Object? donus = _ayni,
    String? tolerans,
    FishingDetailsSpotVisibility? balikGizliligi,
    String? oyun,
    GamingDetailsPlatform? platform,
    SportsDetailsSport? spor,
    String? sahaAdi,
  }) => TurAyrintisi(
    kampYeri: kampYeri ?? this.kampYeri,
    su: identical(su, _ayni) ? this.su : su as bool?,
    tuvalet: identical(tuvalet, _ayni) ? this.tuvalet : tuvalet as bool?,
    kampNotu: kampNotu ?? this.kampNotu,
    zorluk: zorluk ?? this.zorluk,
    mesafe: mesafe ?? this.mesafe,
    yukselti: yukselti ?? this.yukselti,
    donus: identical(donus, _ayni) ? this.donus : donus as DateTime?,
    tolerans: tolerans ?? this.tolerans,
    balikGizliligi: balikGizliligi ?? this.balikGizliligi,
    oyun: oyun ?? this.oyun,
    platform: platform ?? this.platform,
    spor: spor ?? this.spor,
    sahaAdi: sahaAdi ?? this.sahaAdi,
  );

  @override
  bool operator ==(Object other) =>
      other is TurAyrintisi &&
      other.kampYeri == kampYeri &&
      other.su == su &&
      other.tuvalet == tuvalet &&
      other.kampNotu == kampNotu &&
      other.zorluk == zorluk &&
      other.mesafe == mesafe &&
      other.yukselti == yukselti &&
      other.donus == donus &&
      other.tolerans == tolerans &&
      other.balikGizliligi == balikGizliligi &&
      other.oyun == oyun &&
      other.platform == platform &&
      other.spor == spor &&
      other.sahaAdi == sahaAdi;

  @override
  int get hashCode => Object.hash(
    kampYeri,
    su,
    tuvalet,
    kampNotu,
    zorluk,
    mesafe,
    yukselti,
    donus,
    tolerans,
    balikGizliligi,
    oyun,
    platform,
    spor,
    sahaAdi,
  );
}

/// Oluşturma ya da düzenleme sihirbazının durumu. Girilenler adımlar
/// arasında korunur (ADR-0014 §4, ADR-0015 §3). Zamanlar UTC'dir.
@immutable
final class EtkinlikTaslagi {
  const EtkinlikTaslagi({
    required this.istekKimligi,
    this.adim = 0,
    this.tur,
    this.baslik = '',
    this.aciklama = '',
    this.baslangic,
    this.bitis,
    this.yer = const YerBilgisi(),
    this.kontenjan = '',
    this.tekrar,
    this.ayrinti = const TurAyrintisi(),
    this.ayrintiDegisti = false,
    this.hatalar = const {},
    this.gonderiliyor = false,
    this.hata,
    this.sonuc,
  });

  /// Sihirbaz açılınca bir kez üretilen `client_request_id`; aynı
  /// oluşturma tekrar gönderilirken aynı id kullanılır (ADR-0005).
  final String istekKimligi;

  /// Gösterilen adım (0–3).
  final int adim;

  final EventType? tur;
  final String baslik;
  final String aciklama;
  final DateTime? baslangic;
  final DateTime? bitis;
  final YerBilgisi yer;

  /// Kontenjan metni; boş ya da 0: sınırsız.
  final String kontenjan;

  /// Tekrar; `null` ise tek seferlik. Yalnızca oluşturmada.
  final TekrarSecimi? tekrar;

  final TurAyrintisi ayrinti;

  /// Türe özel alanlardan biri değişti (düzenlemede ayrıntı yalnızca o
  /// zaman gönderilir; sunucu ayrıntıyı tamamen değiştirir).
  final bool ayrintiDegisti;

  /// Gösterilen adımın hataları ("İleri"ye ya da gönder'e basılınca).
  final Set<TaslakHatasi> hatalar;

  final bool gonderiliyor;

  /// Son gönderimin hatası; metni ortak eşlemeden gelir.
  final Object? hata;

  /// Başarıda oluşturulan ya da düzenlenen etkinliğin kimliği.
  final String? sonuc;

  EtkinlikTaslagi kopya({
    int? adim,
    EventType? tur,
    String? baslik,
    String? aciklama,
    DateTime? baslangic,
    DateTime? bitis,
    YerBilgisi? yer,
    String? kontenjan,
    Object? tekrar = _ayni,
    TurAyrintisi? ayrinti,
    bool? ayrintiDegisti,
    Set<TaslakHatasi>? hatalar,
    bool gonderiliyor = false,
    Object? hata,
    String? sonuc,
  }) => EtkinlikTaslagi(
    istekKimligi: istekKimligi,
    adim: adim ?? this.adim,
    tur: tur ?? this.tur,
    baslik: baslik ?? this.baslik,
    aciklama: aciklama ?? this.aciklama,
    baslangic: baslangic ?? this.baslangic,
    bitis: bitis ?? this.bitis,
    yer: yer ?? this.yer,
    kontenjan: kontenjan ?? this.kontenjan,
    tekrar: identical(tekrar, _ayni) ? this.tekrar : tekrar as TekrarSecimi?,
    ayrinti: ayrinti ?? this.ayrinti,
    ayrintiDegisti: ayrintiDegisti ?? this.ayrintiDegisti,
    hatalar: hatalar ?? this.hatalar,
    gonderiliyor: gonderiliyor,
    hata: hata,
    sonuc: sonuc ?? this.sonuc,
  );
}

/// Düzenlenecek [etkinlik]'ten taslak: tür değişmez, ilk adım başlık ve
/// zamandır; tekrar düzenlenmez.
EtkinlikTaslagi duzenlemeTaslagi(Event etkinlik, String istekKimligi) {
  final hike = etkinlik.hike;
  final camp = etkinlik.camp;
  return EtkinlikTaslagi(
    istekKimligi: istekKimligi,
    adim: 1,
    tur: etkinlik.type == EventType.unknown ? EventType.general : etkinlik.type,
    baslik: etkinlik.title,
    aciklama: etkinlik.description,
    baslangic: etkinlik.startsAt.toUtc(),
    bitis: etkinlik.endsAt.toUtc(),
    yer: YerBilgisi(
      mod: etkinlik.mode == EventMode.online
          ? EventMode.online
          : EventMode.inPerson,
      nokta: etkinlik.meetingPoint,
      noktaAdi: etkinlik.meetingPointName ?? '',
      il: etkinlik.city ?? '',
      ilce: etkinlik.district ?? '',
      baglanti: etkinlik.onlineUrl ?? '',
    ),
    kontenjan: etkinlik.capacity > 0 ? '${etkinlik.capacity}' : '',
    ayrinti: TurAyrintisi(
      kampYeri: camp?.siteName ?? '',
      su: camp?.hasWater,
      tuvalet: camp?.hasToilet,
      kampNotu: camp?.notes ?? '',
      zorluk: hike?.difficulty ?? 0,
      mesafe: _sayiMetni(hike?.distanceKm),
      yukselti: _sayiMetni(hike?.elevationM),
      donus: hike?.expectedReturnAt?.toUtc(),
      tolerans: _sayiMetni(hike?.returnGraceMinutes),
      balikGizliligi:
          etkinlik.fishing?.spotVisibility ==
              FishingDetailsSpotVisibility.participants
          ? FishingDetailsSpotVisibility.participants
          : FishingDetailsSpotVisibility.tayfa,
      oyun: etkinlik.gaming?.game ?? '',
      platform: switch (etkinlik.gaming?.platform) {
        null || GamingDetailsPlatform.unknown => null,
        final p => p,
      },
      spor: switch (etkinlik.sports?.sport) {
        null || SportsDetailsSport.unknown => null,
        final s => s,
      },
      sahaAdi: etkinlik.sports?.venueName ?? '',
    ),
  );
}

String _sayiMetni(num? sayi) {
  if (sayi == null || sayi == 0) return '';
  if (sayi is double && sayi == sayi.roundToDouble()) {
    return sayi.toInt().toString();
  }
  return sayi.toString();
}

int _uzunluk(String metin) => metin.runes.length;

/// Boş ya da yalnızca boşluksa `null`, değilse kırpılmış metin.
String? _doluysa(String metin) {
  final kirpik = metin.trim();
  return kirpik.isEmpty ? null : kirpik;
}

/// Ondalık sayı; Türkçe virgül de kabul edilir. Boşsa `null`; geçersizse
/// `double.nan`.
double? _ondalik(String metin) {
  final kirpik = metin.trim();
  if (kirpik.isEmpty) return null;
  return double.tryParse(kirpik.replaceAll(',', '.')) ?? double.nan;
}

/// Tam sayı. Boşsa `null`; geçersizse `-1`.
int? _tamSayi(String metin) {
  final kirpik = metin.trim();
  if (kirpik.isEmpty) return null;
  return int.tryParse(kirpik) ?? -1;
}

bool _aralikta(num? sayi, num enCok) =>
    sayi == null || (!sayi.isNaN && sayi >= 0 && sayi <= enCok);

/// Kontenjan sayısı; boşsa `null` (sunucu varsayılanı: sınırsız).
int? kontenjanSayisi(String metin) => _tamSayi(metin);

/// [adim]'ın hataları; boşsa adım geçerlidir. Düzenlemede ([eski]) zaman
/// değişmediyse başlangıcın geçmişte olması hata değildir.
Set<TaslakHatasi> adimHatalari(
  int adim,
  EtkinlikTaslagi t, {
  required DateTime simdi,
  Event? eski,
}) {
  final hatalar = <TaslakHatasi>{};
  switch (adim) {
    case 0:
      if (t.tur == null) hatalar.add(TaslakHatasi.tur);
    case 1:
      final baslik = t.baslik.trim();
      if (baslik.isEmpty || _uzunluk(baslik) > etkinlikBaslikEnCok) {
        hatalar.add(TaslakHatasi.baslik);
      }
      if (_uzunluk(t.aciklama.trim()) > etkinlikAciklamaEnCok) {
        hatalar.add(TaslakHatasi.aciklama);
      }
      final baslangic = t.baslangic;
      final bitis = t.bitis;
      if (baslangic == null) {
        hatalar.add(TaslakHatasi.baslangicYok);
      } else {
        final degismedi =
            eski != null && eski.startsAt.isAtSameMomentAs(baslangic);
        if (!degismedi && !baslangic.isAfter(simdi)) {
          hatalar.add(TaslakHatasi.baslangicGecmis);
        }
      }
      if (bitis == null || (baslangic != null && !bitis.isAfter(baslangic))) {
        hatalar.add(TaslakHatasi.bitis);
      }
    case 2:
      final yer = t.yer;
      if (yer.mod == EventMode.online) {
        final adres = Uri.tryParse(yer.baglanti.trim());
        if (adres == null ||
            !guvenliBaglantiMi(adres) ||
            _uzunluk(yer.baglanti.trim()) > etkinlikBaglantiEnCok) {
          hatalar.add(TaslakHatasi.baglanti);
        }
      } else {
        if (yer.nokta == null) hatalar.add(TaslakHatasi.nokta);
        if (_uzunluk(yer.noktaAdi.trim()) > etkinlikYerAdiEnCok) {
          hatalar.add(TaslakHatasi.noktaAdi);
        }
        final il = yer.il.trim();
        if (il.isEmpty || _uzunluk(il) > etkinlikIlEnCok) {
          hatalar.add(TaslakHatasi.il);
        }
        final ilce = yer.ilce.trim();
        if (ilce.isEmpty || _uzunluk(ilce) > etkinlikIlEnCok) {
          hatalar.add(TaslakHatasi.ilce);
        }
      }
    case 3:
      if (!_aralikta(kontenjanSayisi(t.kontenjan), etkinlikKontenjanEnCok)) {
        hatalar.add(TaslakHatasi.kontenjan);
      }
      hatalar.addAll(_ayrintiHatalari(t));
      final tekrar = t.tekrar;
      final baslangic = t.baslangic;
      if (eski == null && tekrar != null && baslangic != null) {
        switch (tekrarHatasi(tekrar, baslangic)) {
          case TekrarHatasi.aralik:
            hatalar.add(TaslakHatasi.tekrarAralik);
          case TekrarHatasi.sayi:
            hatalar.add(TaslakHatasi.tekrarSayi);
          case TekrarHatasi.tarih:
            hatalar.add(TaslakHatasi.tekrarTarih);
          case null:
            break;
        }
      }
  }
  return Set.unmodifiable(hatalar);
}

Set<TaslakHatasi> _ayrintiHatalari(EtkinlikTaslagi t) {
  final a = t.ayrinti;
  final hatalar = <TaslakHatasi>{};
  switch (t.tur) {
    case EventType.camp:
      if (_uzunluk(a.kampYeri.trim()) > etkinlikKampYeriEnCok) {
        hatalar.add(TaslakHatasi.kampYeri);
      }
      if (_uzunluk(a.kampNotu.trim()) > etkinlikKampNotuEnCok) {
        hatalar.add(TaslakHatasi.kampNotu);
      }
    case EventType.hike:
      if (!_aralikta(_ondalik(a.mesafe), etkinlikMesafeEnCok)) {
        hatalar.add(TaslakHatasi.mesafe);
      }
      if (!_aralikta(_tamSayi(a.yukselti), etkinlikYukseltiEnCok)) {
        hatalar.add(TaslakHatasi.yukselti);
      }
      if (!_aralikta(_tamSayi(a.tolerans), etkinlikToleransEnCok)) {
        hatalar.add(TaslakHatasi.tolerans);
      }
      final donus = a.donus;
      final baslangic = t.baslangic;
      if (donus != null && baslangic != null && !donus.isAfter(baslangic)) {
        hatalar.add(TaslakHatasi.donus);
      }
    case EventType.gaming:
      final oyun = a.oyun.trim();
      if (oyun.isEmpty || _uzunluk(oyun) > etkinlikOyunEnCok) {
        hatalar.add(TaslakHatasi.oyun);
      }
      if (a.platform == null) hatalar.add(TaslakHatasi.platform);
    case EventType.sports:
      if (a.spor == null) hatalar.add(TaslakHatasi.spor);
      if (_uzunluk(a.sahaAdi.trim()) > etkinlikSahaEnCok) {
        hatalar.add(TaslakHatasi.sahaAdi);
      }
    case EventType.convoy ||
        EventType.fishing ||
        EventType.general ||
        EventType.unknown ||
        null:
      break;
  }
  return hatalar;
}

/// Türe özel ayrıntı (sözleşme: en fazla bir tane ve türle aynı; `gaming`
/// ve `sports` için zorunlu, `general` için yok). Boş kalan isteğe bağlı
/// ayrıntı gönderilmez.
({
  CampDetailsInput? camp,
  HikeDetails? hike,
  FishingDetails? fishing,
  GamingDetails? gaming,
  SportsDetails? sports,
})
turAyrintisi(EventType? tur, TurAyrintisi a) {
  CampDetailsInput? camp;
  HikeDetails? hike;
  FishingDetails? fishing;
  GamingDetails? gaming;
  SportsDetails? sports;
  switch (tur) {
    case EventType.camp:
      final girdi = CampDetailsInput(
        siteName: _doluysa(a.kampYeri),
        hasWater: a.su,
        hasToilet: a.tuvalet,
        notes: _doluysa(a.kampNotu),
      );
      if (girdi.toJson().isNotEmpty) camp = girdi;
    case EventType.hike:
      final mesafe = _ondalik(a.mesafe);
      final girdi = HikeDetails(
        difficulty: a.zorluk == 0 ? null : a.zorluk,
        distanceKm: mesafe == null ? null : (mesafe * 100).round() / 100,
        elevationM: _tamSayi(a.yukselti),
        expectedReturnAt: a.donus,
        returnGraceMinutes: _tamSayi(a.tolerans),
      );
      if (girdi.toJson().isNotEmpty) hike = girdi;
    case EventType.fishing:
      fishing = FishingDetails(spotVisibility: a.balikGizliligi);
    case EventType.gaming:
      final platform = a.platform;
      if (platform != null) {
        gaming = GamingDetails(game: a.oyun.trim(), platform: platform);
      }
    case EventType.sports:
      final spor = a.spor;
      if (spor != null) {
        sports = SportsDetails(sport: spor, venueName: _doluysa(a.sahaAdi));
      }
    case EventType.convoy || EventType.general || EventType.unknown || null:
      break;
  }
  return (
    camp: camp,
    hike: hike,
    fishing: fishing,
    gaming: gaming,
    sports: sports,
  );
}

/// Geçerli [t]'den `POST .../events` gövdesi. Yalnızca seçilen moda ait
/// yer alanları gönderilir.
EventCreateRequest olusturmaIstegi(EtkinlikTaslagi t) {
  final yuzYuze = t.yer.mod != EventMode.online;
  final ayrinti = turAyrintisi(t.tur, t.ayrinti);
  final tekrar = t.tekrar;
  return EventCreateRequest(
    type: t.tur ?? EventType.general,
    mode: yuzYuze ? EventMode.inPerson : EventMode.online,
    title: t.baslik.trim(),
    description: _doluysa(t.aciklama),
    startsAt: t.baslangic!,
    endsAt: t.bitis!,
    meetingPointName: yuzYuze ? _doluysa(t.yer.noktaAdi) : null,
    meetingPoint: yuzYuze ? t.yer.nokta : null,
    city: yuzYuze ? t.yer.il.trim() : null,
    district: yuzYuze ? t.yer.ilce.trim() : null,
    onlineUrl: yuzYuze ? null : t.yer.baglanti.trim(),
    capacity: kontenjanSayisi(t.kontenjan),
    camp: ayrinti.camp,
    hike: ayrinti.hike,
    fishing: ayrinti.fishing,
    gaming: ayrinti.gaming,
    sports: ayrinti.sports,
    recurrence: tekrar == null ? null : tekrarKurali(tekrar),
    clientRequestId: t.istekKimligi,
  );
}

/// Geçerli [t]'den `PATCH .../events/{event_id}` gövdesi: yalnızca
/// [eski]'ye göre değişen alan grupları (sözleşme: zaman ikisi birlikte,
/// yer alanları mod ile birlikte). Değişiklik yoksa `null`.
///
/// Türe özel ayrıntı yalnızca alanlarına dokunulduysa gönderilir. Seriye
/// ait etkinlikte `apply_to_series` gönderilmez: yalnızca bu etkinlik
/// değişir (ADR-0015 §3).
EventUpdateRequest? duzenlemeIstegi(EtkinlikTaslagi t, Event eski) {
  final baslik = t.baslik.trim();
  final aciklama = t.aciklama.trim();
  final baslangic = t.baslangic!;
  final bitis = t.bitis!;
  final zamanDegisti =
      !eski.startsAt.isAtSameMomentAs(baslangic) ||
      !eski.endsAt.isAtSameMomentAs(bitis);
  final yuzYuze = t.yer.mod != EventMode.online;
  final mod = yuzYuze ? EventMode.inPerson : EventMode.online;
  final noktaAdi = yuzYuze ? _doluysa(t.yer.noktaAdi) : null;
  final nokta = yuzYuze ? t.yer.nokta : null;
  final il = yuzYuze ? t.yer.il.trim() : null;
  final ilce = yuzYuze ? t.yer.ilce.trim() : null;
  final baglanti = yuzYuze ? null : t.yer.baglanti.trim();
  final yerDegisti =
      mod != eski.mode ||
      noktaAdi != eski.meetingPointName ||
      nokta != eski.meetingPoint ||
      il != eski.city ||
      ilce != eski.district ||
      baglanti != eski.onlineUrl;
  final kontenjan = kontenjanSayisi(t.kontenjan) ?? 0;
  final ayrinti = t.ayrintiDegisti
      ? turAyrintisi(t.tur, t.ayrinti)
      : (camp: null, hike: null, fishing: null, gaming: null, sports: null);
  final istek = EventUpdateRequest(
    title: baslik == eski.title ? null : baslik,
    description: aciklama == eski.description ? null : aciklama,
    startsAt: zamanDegisti ? baslangic : null,
    endsAt: zamanDegisti ? bitis : null,
    mode: yerDegisti ? mod : null,
    meetingPointName: yerDegisti ? noktaAdi : null,
    meetingPoint: yerDegisti ? nokta : null,
    city: yerDegisti ? il : null,
    district: yerDegisti ? ilce : null,
    onlineUrl: yerDegisti ? baglanti : null,
    capacity: kontenjan == eski.capacity ? null : kontenjan,
    camp: ayrinti.camp,
    hike: ayrinti.hike,
    fishing: ayrinti.fishing,
    gaming: ayrinti.gaming,
    sports: ayrinti.sports,
  );
  return istek.toJson().isEmpty ? null : istek;
}
