import 'dart:ui';

import 'package:flutter_riverpod/misc.dart';

import 'package:tayfam/core/api/gen/apis/users_api.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/api/yer_arama.dart';
import 'package:tayfam/core/degerlendirme/degerlendirme_deposu.dart';
import 'package:tayfam/core/degerlendirme/magaza_degerlendirmesi.dart';
import 'package:tayfam/core/moduller/tayfa_module.dart';
import 'package:tayfam/core/tayfa/son_tayfa_deposu.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_sihirbazi.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_zamani.dart';
import 'package:tayfam/features/etkinlik/data/dis_uygulamalar.dart';
import 'package:tayfam/features/etkinlik/data/konum_servisi.dart';
import 'package:tayfam/features/etkinlik/etkinlik.dart';
import 'package:tayfam/features/etkinlik/presentation/osm_harita.dart';

import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';

/// Testlerde kullanılan, biçimi geçerli etkinlik kimlikleri.
const String ornekEtkinlikId = '3f6c2b1a-8d4e-4a7b-9c10-2e5d6f7a8b9c';
const String ikinciEtkinlikId = '9a8b7c6d-5e4f-4a3b-8c2d-1e0f9a8b7c6d';

/// Testlerde kullanılan organizatör ve katılımcı kimlikleri.
const String organizatorId = '5d4c3b2a-1f0e-4d9c-8b7a-6f5e4d3c2b1a';
const String katilimciId = '6e5d4c3b-2a1f-4e0d-9c8b-7a6f5e4d3c2b';

/// Testlerin sabit "şimdi"si (UTC).
final DateTime sabitSimdi = DateTime.utc(2026, 11, 11, 9);

/// Örnek etkinliğin başlangıcı: 14 Kasım 2026 Cumartesi 09:00 (Türkiye).
final DateTime ornekBaslangic = DateTime.utc(2026, 11, 14, 6);

/// Etkinlik uçları.
const String etkinliklerYolu = '/v1/tayfas/{tayfa_id}/events';
const String etkinlikYolu = '/v1/tayfas/{tayfa_id}/events/{event_id}';
const String katilimYolu = '/v1/tayfas/{tayfa_id}/events/{event_id}/rsvp';
const String katilimcilarYolu =
    '/v1/tayfas/{tayfa_id}/events/{event_id}/attendees';
const String takvimYolu = '/v1/tayfas/{tayfa_id}/events/{event_id}/calendar';
const String iptalYolu = '/v1/tayfas/{tayfa_id}/events/{event_id}/cancellation';
const String profilYolu = '/v1/users/{user_id}/profile';
const String varisYolu = '/v1/tayfas/{tayfa_id}/events/{event_id}/check-in';
const String cikisYolu = '/v1/tayfas/{tayfa_id}/events/{event_id}/hike-start';
const String donusYolu = '/v1/tayfas/{tayfa_id}/events/{event_id}/hike-return';
const String malzemelerYolu =
    '/v1/tayfas/{tayfa_id}/events/{event_id}/camp-items';
const String malzemeYolu =
    '/v1/tayfas/{tayfa_id}/events/{event_id}/camp-items/{item_id}';
const String araclarYolu =
    '/v1/tayfas/{tayfa_id}/events/{event_id}/convoy-vehicles';
const String aracYolu =
    '/v1/tayfas/{tayfa_id}/events/{event_id}/convoy-vehicles/{vehicle_id}';
const String avlarYolu =
    '/v1/tayfas/{tayfa_id}/events/{event_id}/fishing-catches';
const String avYolu =
    '/v1/tayfas/{tayfa_id}/events/{event_id}/fishing-catches/{catch_id}';
const String duzeltmeYolu =
    '/v1/tayfas/{tayfa_id}/events/{event_id}/attendees/{user_id}/attendance';

/// Varış penceresi açık bir etkinliğin başlangıcı: [sabitSimdi]'den 10
/// dakika sonra.
final DateTime yakinBaslangic = sabitSimdi.add(const Duration(minutes: 10));

/// Bitmiş (iki gün önce başlamış, üç saat sürmüş) bir etkinliğin
/// başlangıcı; organizatör düzeltmesi ve av ekleme süresi içinde.
final DateTime gecmisBaslangic = sabitSimdi.subtract(const Duration(days: 2));

/// Örnek `Event` JSON'u (sözleşmedeki zorunlu alanlar dolu).
Map<String, Object?> etkinlikJson({
  String id = ornekEtkinlikId,
  String tur = 'camp',
  String mod = 'in_person',
  String baslik = 'Göl kampı',
  String aciklama = 'Çadırını getir.',
  DateTime? baslangic,
  Duration sure = const Duration(hours: 30),
  int kontenjan = 0,
  int gelen = 3,
  int belki = 1,
  int bekleyen = 0,
  String? cevap,
  bool yonetebilir = false,
  bool iptal = false,
  String? seri,
  String? katilim,
  Map<String, Object?>? ayrinti,
}) {
  final bas = baslangic ?? ornekBaslangic;
  final yuzYuze = mod == 'in_person';
  return {
    'id': id,
    'tayfa_id': ornekTayfaId,
    'type': tur,
    'mode': mod,
    'title': baslik,
    'description': aciklama,
    'starts_at': bas.toIso8601String(),
    'ends_at': bas.add(sure).toIso8601String(),
    if (yuzYuze) 'meeting_point_name': 'Abant Gölü',
    if (yuzYuze) 'meeting_point': {'lat': 40.6, 'lng': 31.28},
    if (yuzYuze) 'city': 'Bolu',
    if (yuzYuze) 'district': 'Merkez',
    if (!yuzYuze) 'online_url': 'https://ornek.tayfam.app/oda',
    'capacity': kontenjan,
    'status': iptal ? 'cancelled' : 'scheduled',
    if (iptal) 'cancelled_at': '2026-11-10T10:00:00Z',
    if (iptal) 'cancel_reason': 'Hava kötü',
    'discoverable': false,
    'created_by_user_id': organizatorId,
    'going_count': gelen,
    'maybe_count': belki,
    'waitlist_count': bekleyen,
    'caller_rsvp': ?cevap,
    'caller_can_manage': yonetebilir,
    'caller_attendance': ?katilim,
    'series_id': ?seri,
    'series_override': false,
    'created_at': '2026-11-01T10:00:00Z',
    'updated_at': '2026-11-01T10:00:00Z',
    tur: ?ayrinti,
  };
}

/// Örnek `Event` modeli.
Event ornekEtkinlik({
  String tur = 'camp',
  String mod = 'in_person',
  int kontenjan = 0,
  int gelen = 3,
  int belki = 1,
  int bekleyen = 0,
  String? cevap,
  bool yonetebilir = false,
  String? seri,
  Map<String, Object?>? ayrinti,
}) => Event.fromJson(
  etkinlikJson(
    tur: tur,
    mod: mod,
    kontenjan: kontenjan,
    gelen: gelen,
    belki: belki,
    bekleyen: bekleyen,
    cevap: cevap,
    yonetebilir: yonetebilir,
    seri: seri,
    ayrinti: ayrinti,
  ),
);

/// Etkinlik listesi JSON'u.
Map<String, Object?> etkinlikListesiJson(
  List<Map<String, Object?>> etkinlikler, {
  String? sonraki,
}) => {'events': etkinlikler, 'next_page_token': ?sonraki};

/// Katılımcı listesi JSON'u.
Map<String, Object?> katilimcilarJson(
  List<String> kimlikler, {
  String durum = 'going',
  String? sonraki,
}) => {
  'attendees': [
    for (final id in kimlikler)
      {'user_id': id, 'status': durum, 'updated_at': '2026-11-02T10:00:00Z'},
  ],
  'next_page_token': ?sonraki,
};

/// Kullanıcı profili JSON'u; [ben] oturumdaki kullanıcının kendisi.
Map<String, Object?> profilJson(String id, String ad, {bool ben = false}) => {
  'user_id': id,
  'display_name': ad,
  'self': ben,
  'mutual_tayfas': const <Object?>[],
  'activity_visible': false,
};

/// Detay ekranının okuduğu uçların varsayılan yanıtları; [yanitlar]
/// önce gelir.
SahteTayfaTasima etkinlikTasimasi([Map<String, TayfaYaniti>? yanitlar]) {
  final t = SahteTayfaTasima(yanitlar);
  t.yanitlar
    ..putIfAbsent(
      'GET /v1/tayfas',
      () =>
          (_) => listeJson([etkinJson(ornekTayfaId)]),
    )
    ..putIfAbsent(
      'GET $etkinliklerYolu',
      () =>
          (_) => etkinlikListesiJson([etkinlikJson()]),
    )
    ..putIfAbsent(
      'GET $etkinlikYolu',
      () =>
          (_) => etkinlikJson(),
    )
    ..putIfAbsent(
      'GET $katilimcilarYolu',
      () =>
          (_) => katilimcilarJson([katilimciId]),
    )
    ..putIfAbsent(
      'GET $avlarYolu',
      () =>
          (_) => {'catches': const <Object?>[]},
    )
    ..putIfAbsent(
      'GET $profilYolu',
      () =>
          (i) => profilJson(
            i.yolParametreleri['user_id']!,
            i.yolParametreleri['user_id'] == organizatorId ? 'Ayşe' : 'Mert',
          ),
    );
  return t;
}

/// Sahte takvim paylaşıcısı: paylaşılan metinleri tutar.
final class SahteTakvimPaylasici implements TakvimPaylasici {
  final List<String> paylasilan = [];

  @override
  Future<void> paylas(String icerik, {Rect? konum}) async {
    paylasilan.add(icerik);
  }
}

/// Sahte bağlantı açıcı: açılan noktaları ve adresleri tutar.
final class SahteBaglantiAcici implements EtkinlikBaglantiAcici {
  final List<(double, double)> noktalar = [];
  final List<Uri> adresler = [];

  @override
  Future<bool> haritadaAc(double enlem, double boylam) async {
    noktalar.add((enlem, boylam));
    return true;
  }

  @override
  Future<bool> baglantiAc(Uri adres) async {
    adresler.add(adres);
    return true;
  }
}

/// Sahte yer arayıcı: aramaları sayar, verilen sonuçları döndürür.
final class SahteYerArayici implements YerArayici {
  SahteYerArayici([this.sonuclar = const []]);

  final List<YerSonucu> sonuclar;
  final List<String> aramalar = [];

  @override
  Future<List<YerSonucu>> ara(String metin) async {
    aramalar.add(metin);
    return sonuclar;
  }
}

/// Testlerdeki cihaz konumu (buluşma noktasının yakını).
const LatLng sahteKonum = LatLng(lat: 40.600123, lng: 31.280456);

/// Sahte konum servisi: verilen sonucu döndürür, çağrıları sayar.
final class SahteKonumServisi implements KonumServisi {
  SahteKonumServisi([this.sonuc = const KonumAlindi(sahteKonum)]);

  KonumSonucu sonuc;
  int okuma = 0;
  int uygulamaAyarlari = 0;
  int konumAyarlari = 0;

  @override
  Future<KonumSonucu> tekSeferlikKonum() async {
    okuma++;
    return sonuc;
  }

  @override
  Future<bool> uygulamaAyarlariniAc() async {
    uygulamaAyarlari++;
    return true;
  }

  @override
  Future<bool> konumAyarlariniAc() async {
    konumAyarlari++;
    return true;
  }
}

/// Sahte mağaza değerlendirme penceresi: istekleri sayar (ADR-0016).
final class SahteMagazaDegerlendirmesi implements MagazaDegerlendirmesi {
  SahteMagazaDegerlendirmesi({this.kullanilabilir = true});

  final bool kullanilabilir;
  int istek = 0;

  @override
  Future<bool> kullanilabilirMi() async => kullanilabilir;

  @override
  Future<void> iste() async {
    istek++;
  }
}

/// Sahte istek kimliği (UUID v4 biçiminde).
const String sahteEtkinlikIstekKimligi = '2c9d8e7f-6a5b-4c3d-8e2f-1a0b9c8d7e6f';

/// Etkinlik özelliğinin sahte bağımlılıkları: uçlar [tasima]'dan, saat
/// [sabitSimdi], karolar verilmezse çizilmez (ağ yok), paylaşım ve dış
/// bağlantılar ve konum sahte, istek kimliği sabit. Etkinlik modülü ve
/// türe özel araçları olan türler kayıtlıdır. Değerlendirme bayrağı
/// bellekte; mağaza penceresi verilmezse kullanılamaz (istenmez).
List<Override> etkinlikOverridelari({
  required SahteTayfaTasima tasima,
  SahteTakvimPaylasici? takvim,
  SahteBaglantiAcici? baglanti,
  YerArayici? arayici,
  KaroSaglayiciUretici? karolar,
  KonumServisi? konum,
  SonTayfaDeposu? sonTayfa,
  DegerlendirmeDeposu? degerlendirme,
  MagazaDegerlendirmesi? magaza,
}) => [
  ...tayfaOverridelari(tasima: tasima, sonTayfa: sonTayfa),
  etkinlikDeposuProvider.overrideWithValue(EtkinlikDeposu(tasima)),
  profilOkuyucuProvider.overrideWithValue((id) async {
    final profil = await UsersApi(tasima).getUserProfile(userId: id);
    return KullaniciAdi(profil.displayName, ben: profil.self);
  }),
  etkinlikSaatiProvider.overrideWithValue(() => sabitSimdi),
  karoSaglayiciProvider.overrideWithValue(karolar ?? (() => null)),
  takvimPaylasiciProvider.overrideWithValue(takvim ?? SahteTakvimPaylasici()),
  etkinlikBaglantiAciciProvider.overrideWithValue(
    baglanti ?? SahteBaglantiAcici(),
  ),
  yerArayiciProvider.overrideWithValue(arayici ?? SahteYerArayici()),
  etkinlikIstekKimligiProvider.overrideWithValue(
    () => sahteEtkinlikIstekKimligi,
  ),
  tayfaModulleriProvider.overrideWithValue(const [EtkinlikModulu()]),
  konumServisiProvider.overrideWithValue(konum ?? SahteKonumServisi()),
  etkinlikTurleriProvider.overrideWithValue(const [
    KonvoyTuru(),
    KampTuru(),
    YuruyusTuru(),
    BalikTuru(),
  ]),
  degerlendirmeDeposuProvider.overrideWithValue(
    degerlendirme ?? BellekDegerlendirmeDeposu(),
  ),
  magazaDegerlendirmesiProvider.overrideWithValue(
    magaza ?? SahteMagazaDegerlendirmesi(kullanilabilir: false),
  ),
];
