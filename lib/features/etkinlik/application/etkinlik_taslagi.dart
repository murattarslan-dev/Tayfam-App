import 'package:flutter/foundation.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/katalog/alanlar.dart';
import 'package:tayfam/features/etkinlik/application/tekrar_kurali.dart';
import 'package:tayfam/features/etkinlik/data/dis_uygulamalar.dart';

/// Sihirbazın adım sayısı (ADR-0015 §3 ve Notlar 2026-11-13): tür;
/// başlık ve zaman; yer; türe özel alanlar, kontenjan ve tekrar; önizleme.
const int etkinlikAdimSayisi = 5;

/// Sihirbazın adımları, sırasıyla.
abstract final class SihirbazAdimi {
  static const int tur = 0;
  static const int bilgi = 1;
  static const int yer = 2;
  static const int ayrinti = 3;

  /// "Her şey doğru mu?": doğrulanacak alanı yoktur; gönderim buradadır.
  static const int onizleme = 4;

  /// Anlık etkinlikte (ADR-0026) ayrıntıdan sonra "Kimleri çağıralım?":
  /// arkadaş seçimi; doğrulanacak alanı yoktur (en çok sayı arayüzde).
  static const int davet = 4;

  /// Anlık etkinlikte önizleme.
  static const int anlikOnizleme = 5;
}

/// Anlık etkinlik sihirbazının adım sayısı (ADR-0026): tür, bilgi, yer,
/// ayrıntı, davet, önizleme.
const int anlikAdimSayisi = 6;

/// Anlık etkinlikte doğrudan davet edilebilecek en çok arkadaş
/// (`InstantEventCreateRequest.invitee_user_ids`, `maxItems: 10`).
const int anlikDavetliEnCok = 10;

/// Sözleşmedeki uzunluk ve sayı sınırları (`EventCreateRequest`,
/// `*DetailsInput`).
const int etkinlikBaslikEnCok = 120;
const int etkinlikAciklamaEnCok = 5000;
const int etkinlikYerAdiEnCok = 120;
const int etkinlikIlEnCok = 50;
const int etkinlikBaglantiEnCok = 2048;
const int etkinlikKontenjanEnCok = 10000;
const int etkinlikKampYeriEnCok = 120;
const int etkinlikKampNotuEnCok = 1000;
const int etkinlikZorlukEnCok = 5;
const double etkinlikMesafeEnCok = 1000;
const int etkinlikYukseltiEnCok = 9000;
const int etkinlikToleransEnCok = 1440;

/// Konvoy rotası: boş ya da en az 2, en çok 500 nokta
/// (`ConvoyDetailsInput.route`).
const int rotaEnAzNokta = 2;
const int rotaEnCokNokta = 500;

/// Faz 1'den kalan, türe özel ayrıntısı sözleşmede ayrı nesne olan türlerin
/// katalog anahtarları (`Event.convoy`, `camp`, `hike`, `fishing`);
/// bileşenlere taşınana kadar sihirbazda kendi alanlarıyla çizilirler.
abstract final class EskiTur {
  static const String konvoy = 'convoy';
  static const String kamp = 'camp';
  static const String yuruyus = 'hike';
  static const String balik = 'fishing';
}

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

  /// Katalogdaki tür alanlarından en az biri geçersiz; alan başına hata
  /// [alanHatalari] ile hesaplanır.
  alanlar,
  kampYeri,
  kampNotu,
  mesafe,
  yukselti,
  donus,
  tolerans,
  tekrarAralik,
  tekrarSayi,
  tekrarTarih,
  rota,
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
    this.halkaAcik = false,
  });

  final EventMode mod;
  final LatLng? nokta;
  final String noktaAdi;
  final String il;
  final String ilce;
  final String baglanti;

  /// "Halka açık yerde buluşur" (`discoverable`; Tayfam-Api ADR-0033 §2):
  /// organizatörün işareti. Yalnızca yüz yüze etkinlikte gönderilir;
  /// varsayılan kapalı (30-kesfet-ve-guvenlik, karar 25).
  final bool halkaAcik;

  YerBilgisi kopya({
    EventMode? mod,
    LatLng? nokta,
    String? noktaAdi,
    String? il,
    String? ilce,
    String? baglanti,
    bool? halkaAcik,
  }) => YerBilgisi(
    mod: mod ?? this.mod,
    nokta: nokta ?? this.nokta,
    noktaAdi: noktaAdi ?? this.noktaAdi,
    il: il ?? this.il,
    ilce: ilce ?? this.ilce,
    baglanti: baglanti ?? this.baglanti,
    halkaAcik: halkaAcik ?? this.halkaAcik,
  );

  @override
  bool operator ==(Object other) =>
      other is YerBilgisi &&
      other.mod == mod &&
      other.nokta == nokta &&
      other.noktaAdi == noktaAdi &&
      other.il == il &&
      other.ilce == ilce &&
      other.baglanti == baglanti &&
      other.halkaAcik == halkaAcik;

  @override
  int get hashCode =>
      Object.hash(mod, nokta, noktaAdi, il, ilce, baglanti, halkaAcik);
}

/// Türe özel alanlar (sözleşmedeki `*DetailsInput`). Sayılar metin olarak
/// tutulur; gönderilirken okunur. Konvoy rotası, haritada sırayla
/// işaretlenen noktalardır (ADR-0015 Notlar 4, paket 3); kullanıcının
/// bilerek paylaştığı içeriktir, log'a yazılmaz.
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
    this.rota = const [],
  });

  /// Konvoy: rota noktaları, sırasıyla.
  final List<LatLng> rota;

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
    List<LatLng>? rota,
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
    rota: rota == null ? this.rota : List.unmodifiable(rota),
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
      listEquals(other.rota, rota);

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
    Object.hashAll(rota),
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
    this.turTanimi,
    this.alanlar = const {},
    this.alanlarDegisti = false,
    this.baslik = '',
    this.aciklama = '',
    this.baslangic,
    this.bitis,
    this.yer = const YerBilgisi(),
    this.kontenjan = '',
    this.tekrar,
    this.ayrinti = const TurAyrintisi(),
    this.ayrintiDegisti = false,
    this.kapak,
    this.onizlemeyeDon = false,
    this.hatalar = const {},
    this.gonderiliyor = false,
    this.hata,
    this.sonuc,
    this.davetliler = const [],
    this.anlikSonuc,
  });

  /// Sihirbaz açılınca bir kez üretilen `client_request_id`; aynı
  /// oluşturma tekrar gönderilirken aynı id kullanılır (ADR-0005).
  final String istekKimligi;

  /// Gösterilen adım (0–4; [SihirbazAdimi]).
  final int adim;

  /// Seçilen türün katalog anahtarı (`EventCreateRequest.type`).
  final String? tur;

  /// Seçilen türün tanımı: oluşturmada katalogdaki güncel sürüm,
  /// düzenlemede etkinliğin kendi tür sürümü (`type_version`). Düzenlemede
  /// tanım henüz okunmadıysa `null`'dır; o zaman katalog alanları
  /// çizilmez ve gönderilmez.
  final CatalogEventType? turTanimi;

  /// Türün katalogdaki alanlarının formdaki değerleri ([AlanDegerleri]).
  final AlanDegerleri alanlar;

  /// Katalog alanlarından biri değişti (düzenlemede `fields` yalnızca o
  /// zaman gönderilir; sunucu değerlerin tamamını değiştirir).
  final bool alanlarDegisti;

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

  /// Kapak fotoğrafının yüklemesi (`null`: kapak yok; ADR-0021 §6).
  /// Düzenlemede etkinliğin kapağıyla başlar.
  final String? kapak;

  /// Adıma önizlemedeki "Değiştir"le gelindi: "İleri" önizlemeye döner.
  final bool onizlemeyeDon;

  /// Gösterilen adımın hataları ("İleri"ye ya da gönder'e basılınca).
  final Set<TaslakHatasi> hatalar;

  final bool gonderiliyor;

  /// Son gönderimin hatası; metni ortak eşlemeden gelir.
  final Object? hata;

  /// Başarıda oluşturulan ya da düzenlenen etkinliğin kimliği.
  final String? sonuc;

  /// Anlık etkinlikte doğrudan davet edilecek arkadaşların kimlikleri,
  /// seçim sırasıyla (en çok [anlikDavetliEnCok]). Yalnızca bellektedir ve
  /// yalnızca istek gövdesine gider; log'a yazılmaz.
  final List<String> davetliler;

  /// Anlık etkinliğin oluşturma yanıtı (tayfa ve etkinlik); "Etkinlik
  /// açıldı" ekranı yalnızca bununla çizilir. Yalnızca bellektedir.
  final InstantEvent? anlikSonuc;

  EtkinlikTaslagi kopya({
    int? adim,
    String? tur,
    Object? turTanimi = _ayni,
    AlanDegerleri? alanlar,
    bool? alanlarDegisti,
    String? baslik,
    String? aciklama,
    DateTime? baslangic,
    DateTime? bitis,
    YerBilgisi? yer,
    String? kontenjan,
    Object? tekrar = _ayni,
    TurAyrintisi? ayrinti,
    bool? ayrintiDegisti,
    Object? kapak = _ayni,
    bool? onizlemeyeDon,
    Set<TaslakHatasi>? hatalar,
    bool gonderiliyor = false,
    Object? hata,
    String? sonuc,
    List<String>? davetliler,
    InstantEvent? anlikSonuc,
  }) => EtkinlikTaslagi(
    istekKimligi: istekKimligi,
    adim: adim ?? this.adim,
    tur: tur ?? this.tur,
    turTanimi: identical(turTanimi, _ayni)
        ? this.turTanimi
        : turTanimi as CatalogEventType?,
    alanlar: alanlar ?? this.alanlar,
    alanlarDegisti: alanlarDegisti ?? this.alanlarDegisti,
    baslik: baslik ?? this.baslik,
    aciklama: aciklama ?? this.aciklama,
    baslangic: baslangic ?? this.baslangic,
    bitis: bitis ?? this.bitis,
    yer: yer ?? this.yer,
    kontenjan: kontenjan ?? this.kontenjan,
    tekrar: identical(tekrar, _ayni) ? this.tekrar : tekrar as TekrarSecimi?,
    ayrinti: ayrinti ?? this.ayrinti,
    ayrintiDegisti: ayrintiDegisti ?? this.ayrintiDegisti,
    kapak: identical(kapak, _ayni) ? this.kapak : kapak as String?,
    onizlemeyeDon: onizlemeyeDon ?? this.onizlemeyeDon,
    hatalar: hatalar ?? this.hatalar,
    gonderiliyor: gonderiliyor,
    hata: hata,
    sonuc: sonuc ?? this.sonuc,
    davetliler: davetliler ?? this.davetliler,
    anlikSonuc: anlikSonuc ?? this.anlikSonuc,
  );
}

/// [a] ile [b]'de kullanıcının girdiği alanlar aynı mı (adım, hata ve
/// gönderim durumu sayılmaz). Sihirbaz kapatılırken "Vazgeçilsin mi?"
/// sorusu bununla verilir.
bool ayniGirdi(EtkinlikTaslagi a, EtkinlikTaslagi b) =>
    a.tur == b.tur &&
    ayniAlanDegerleri(a.alanlar, b.alanlar) &&
    a.baslik == b.baslik &&
    a.aciklama == b.aciklama &&
    a.baslangic == b.baslangic &&
    a.bitis == b.bitis &&
    a.yer == b.yer &&
    a.kontenjan == b.kontenjan &&
    a.tekrar == b.tekrar &&
    a.ayrinti == b.ayrinti &&
    a.kapak == b.kapak &&
    listEquals(a.davetliler, b.davetliler);

/// Düzenlenecek [etkinlik]'ten taslak: tür değişmez, ilk adım başlık ve
/// zamandır; tekrar düzenlenmez. [tanim] etkinliğin tür sürümünün
/// tanımıdır (biliniyorsa); katalog alanlarının değerleri ona göre okunur.
EtkinlikTaslagi duzenlemeTaslagi(
  Event etkinlik,
  String istekKimligi, {
  CatalogEventType? tanim,
}) {
  final hike = etkinlik.hike;
  final camp = etkinlik.camp;
  return EtkinlikTaslagi(
    istekKimligi: istekKimligi,
    adim: 1,
    tur: etkinlik.type,
    turTanimi: tanim,
    alanlar: tanim == null
        ? const {}
        : alanDegerleriOku(turAlanlari(tanim), etkinlik.fields),
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
      halkaAcik: etkinlik.discoverable,
    ),
    kontenjan: etkinlik.capacity > 0 ? '${etkinlik.capacity}' : '',
    kapak: etkinlik.coverUploadId,
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
      rota: List.unmodifiable(etkinlik.convoy?.route ?? const <LatLng>[]),
    ),
  );
}

/// [tanim]'daki tür alanları (yoksa boş).
List<CatalogField> turAlanlari(CatalogEventType? tanim) =>
    tanim?.definition.fields ?? const <CatalogField>[];

/// [tanim] türünün izin verdiği modlar; tanım yoksa ya da tanınan mod
/// taşımıyorsa ikisi de.
List<EventMode> turModlari(CatalogEventType? tanim) {
  final modlar = [
    for (final mod in const [EventMode.inPerson, EventMode.online])
      if (tanim?.modes.contains(mod) ?? true) mod,
  ];
  return modlar.isEmpty ? const [EventMode.inPerson, EventMode.online] : modlar;
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
      // Oluşturmada tür katalogdan, tanımıyla seçilir; alan türü
      // tanınmayan türde etkinlik oluşturulmaz (ADR-0024 §3).
      final tanim = t.turTanimi;
      if (t.tur == null ||
          (eski == null &&
              (tanim == null || !alanlarTaniniyor(turAlanlari(tanim))))) {
        hatalar.add(TaslakHatasi.tur);
      }
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
      if (alanHatalari(turAlanlari(t.turTanimi), t.alanlar).isNotEmpty) {
        hatalar.add(TaslakHatasi.alanlar);
      }
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
    case EskiTur.kamp:
      if (_uzunluk(a.kampYeri.trim()) > etkinlikKampYeriEnCok) {
        hatalar.add(TaslakHatasi.kampYeri);
      }
      if (_uzunluk(a.kampNotu.trim()) > etkinlikKampNotuEnCok) {
        hatalar.add(TaslakHatasi.kampNotu);
      }
    case EskiTur.yuruyus:
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
    case EskiTur.konvoy:
      if (rotaHatali(a.rota)) hatalar.add(TaslakHatasi.rota);
  }
  return hatalar;
}

/// Rotanın nokta sayısı geçersiz mi (boş ya da 2–500 olmalı).
bool rotaHatali(List<LatLng> rota) =>
    rota.isNotEmpty &&
    (rota.length < rotaEnAzNokta || rota.length > rotaEnCokNokta);

/// Faz 1'den kalan türe özel ayrıntı (sözleşme: yalnızca kendi türünde, en
/// fazla bir tane). Boş kalan isteğe bağlı ayrıntı gönderilmez.
({
  ConvoyDetailsInput? convoy,
  CampDetailsInput? camp,
  HikeDetails? hike,
  FishingDetails? fishing,
})
turAyrintisi(String? tur, TurAyrintisi a) {
  ConvoyDetailsInput? convoy;
  CampDetailsInput? camp;
  HikeDetails? hike;
  FishingDetails? fishing;
  switch (tur) {
    case EskiTur.kamp:
      final girdi = CampDetailsInput(
        siteName: _doluysa(a.kampYeri),
        hasWater: a.su,
        hasToilet: a.tuvalet,
        notes: _doluysa(a.kampNotu),
      );
      if (girdi.toJson().isNotEmpty) camp = girdi;
    case EskiTur.yuruyus:
      final mesafe = _ondalik(a.mesafe);
      final girdi = HikeDetails(
        difficulty: a.zorluk == 0 ? null : a.zorluk,
        distanceKm: mesafe == null ? null : (mesafe * 100).round() / 100,
        elevationM: _tamSayi(a.yukselti),
        expectedReturnAt: a.donus,
        returnGraceMinutes: _tamSayi(a.tolerans),
      );
      if (girdi.toJson().isNotEmpty) hike = girdi;
    case EskiTur.balik:
      fishing = FishingDetails(spotVisibility: a.balikGizliligi);
    case EskiTur.konvoy:
      if (a.rota.isNotEmpty) convoy = ConvoyDetailsInput(route: a.rota);
  }
  return (convoy: convoy, camp: camp, hike: hike, fishing: fishing);
}

/// Taslaktaki katalog alanlarının `fields` gövdesi; türün alanı yoksa ya
/// da hiçbir değer girilmediyse `null` (alan gönderilmez).
Map<String, Object?>? _alanGovdesi(EtkinlikTaslagi t) {
  final govde = alanGovdesi(turAlanlari(t.turTanimi), t.alanlar);
  return govde.isEmpty ? null : govde;
}

/// Geçerli [t]'den `POST .../events` gövdesi. Yalnızca seçilen moda ait
/// yer alanları gönderilir.
EventCreateRequest olusturmaIstegi(EtkinlikTaslagi t) {
  final yuzYuze = t.yer.mod != EventMode.online;
  final ayrinti = turAyrintisi(t.tur, t.ayrinti);
  final tekrar = t.tekrar;
  return EventCreateRequest(
    type: t.tur!,
    fields: _alanGovdesi(t),
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
    // Yalnızca işaretliyse gönderilir; çevrim içinde anlamı yoktur.
    discoverable: yuzYuze && t.yer.halkaAcik ? true : null,
    capacity: kontenjanSayisi(t.kontenjan),
    convoy: ayrinti.convoy,
    camp: ayrinti.camp,
    hike: ayrinti.hike,
    fishing: ayrinti.fishing,
    recurrence: tekrar == null ? null : tekrarKurali(tekrar),
    coverUploadId: t.kapak,
    clientRequestId: t.istekKimligi,
  );
}

/// Geçerli [t]'den `POST /v1/instant-events` gövdesi (ADR-0026): etkinlik
/// alanları tayfa etkinliğiyle aynı; tekrar ve kapak sözleşme gereği
/// gönderilmez, `discoverable` hiç gönderilmez. Davetliler yinelenmeden,
/// en çok [anlikDavetliEnCok] kişi.
InstantEventCreateRequest anlikIstegi(EtkinlikTaslagi t) {
  final etkinlik = olusturmaIstegi(t);
  final davetliler = t.davetliler.toSet().take(anlikDavetliEnCok).toList();
  return InstantEventCreateRequest(
    event: EventCreateRequest(
      type: etkinlik.type,
      fields: etkinlik.fields,
      mode: etkinlik.mode,
      title: etkinlik.title,
      description: etkinlik.description,
      startsAt: etkinlik.startsAt,
      endsAt: etkinlik.endsAt,
      meetingPointName: etkinlik.meetingPointName,
      meetingPoint: etkinlik.meetingPoint,
      city: etkinlik.city,
      district: etkinlik.district,
      onlineUrl: etkinlik.onlineUrl,
      capacity: etkinlik.capacity,
      convoy: etkinlik.convoy,
      camp: etkinlik.camp,
      hike: etkinlik.hike,
      fishing: etkinlik.fishing,
      clientRequestId: etkinlik.clientRequestId,
    ),
    inviteeUserIds: davetliler.isEmpty ? null : davetliler,
  );
}

/// Geçerli [t]'den `PATCH .../events/{event_id}` gövdesi: yalnızca
/// [eski]'ye göre değişen alan grupları (sözleşme: zaman ikisi birlikte,
/// yer alanları mod ile birlikte). Değişiklik yoksa `null`.
///
/// Türe özel ayrıntı yalnızca alanlarına dokunulduysa gönderilir; konvoyda
/// silinen rota boş listeyle gönderilir. Seriye
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
  final halkaAcik = yuzYuze && t.yer.halkaAcik;
  final kontenjan = kontenjanSayisi(t.kontenjan) ?? 0;
  final ayrinti = t.ayrintiDegisti
      ? turAyrintisi(t.tur, t.ayrinti)
      : (convoy: null, camp: null, hike: null, fishing: null);
  // `fields` verilirse değerlerin tamamı yerine geçer; boş nesne bütün
  // değerleri kaldırır (sözleşme). Tanım bilinmiyorsa gönderilmez.
  final alanlar = t.alanlarDegisti && t.turTanimi != null
      ? alanGovdesi(turAlanlari(t.turTanimi), t.alanlar)
      : null;
  final rotaSilindi =
      t.ayrintiDegisti &&
      t.tur == EskiTur.konvoy &&
      t.ayrinti.rota.isEmpty &&
      (eski.convoy?.route?.isNotEmpty ?? false);
  final istek = EventUpdateRequest(
    fields: alanlar,
    // Kaldırılan kapak "" ile gönderilir (sözleşme).
    coverUploadId: t.kapak == eski.coverUploadId ? null : t.kapak ?? '',
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
    discoverable: halkaAcik == eski.discoverable ? null : halkaAcik,
    capacity: kontenjan == eski.capacity ? null : kontenjan,
    convoy: rotaSilindi ? const ConvoyDetailsInput(route: []) : ayrinti.convoy,
    camp: ayrinti.camp,
    hike: ayrinti.hike,
    fishing: ayrinti.fishing,
  );
  return istek.toJson().isEmpty ? null : istek;
}
