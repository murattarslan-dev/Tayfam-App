// Mağaza görsellerinin demo verisi (T-22, T-11).
//
// Tayfam-Api'deki kapalı demo setiyle aynı ruhtadır
// (`internal/identity/app/demo/data.go`, docs/runbooks/demo-verisi.md,
// ADR-0023): "Ege Klasikleri Demo" ve "Kazdağı Kampçıları Demo" tayfaları,
// Bozdağ konvoyu, Kazdağı kampı, rota anketi, karbüratör sorusu. Kişi adları
// sıradan bir ad ve soyadının baş harfidir; gerçek bir kişiyi taklit etmez.
// Hiçbiri kişisel veri değildir; araçlarda plaka yoktur.

import 'package:flutter_riverpod/misc.dart';

import 'package:tayfam/core/degerlendirme/magaza_degerlendirmesi.dart';
import 'package:tayfam/core/harita/osm_harita.dart';
import 'package:tayfam/core/api/yer_arama.dart';
import 'package:tayfam/core/konum/konum_servisi.dart';
import 'package:tayfam/core/kullanici/kendi_kimligim.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/moduller/tayfa_module.dart';
import 'package:tayfam/core/moduller/tayfa_ust_menusu.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';
import 'package:tayfam/features/anket/anket.dart';
import 'package:tayfam/features/anket/application/anket_formu_notifier.dart';
import 'package:tayfam/features/anket/application/anket_kurallari.dart';
import 'package:tayfam/features/anket/data/anket_deposu.dart';
import 'package:tayfam/features/birebir/application/konusma_listesi_notifier.dart';
import 'package:tayfam/features/birebir/application/konusma_sessizlik_notifier.dart';
import 'package:tayfam/features/duyuru/data/duyuru_deposu.dart';
import 'package:tayfam/features/duyuru/duyuru.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_sihirbazi.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_zamani.dart';
import 'package:tayfam/features/etkinlik/bilesenler/sozluk/sozluk_deposu.dart';
import 'package:tayfam/features/etkinlik/data/dis_uygulamalar.dart';
import 'package:tayfam/features/etkinlik/etkinlik.dart';
import 'package:tayfam/features/sikayet/data/sikayet_deposu.dart';
import 'package:tayfam/features/sohbet/data/kanal_deposu.dart';
import 'package:tayfam/features/sohbet/presentation/sohbet_ekrani.dart';
import 'package:tayfam/features/soru_cevap/soru_cevap.dart';
import 'package:tayfam/features/tayfa/application/kurulum.dart';
import 'package:tayfam/features/tayfa_yonetim/tayfa_yonetim.dart'
    show tayfaUstMenusu, tayfayaDavetEt;
import 'package:tayfam/shell/kayitlar.dart' show etkinlikBilesenKaydi;

import '../features/bildirim/sahteler.dart' show bildirimOverridelari;
import '../features/birebir/sahteler.dart'
    show birebirOverridelari, konusmaJson, konusmaListesiJson, konusmalarYolu;
import '../features/duyuru/sahteler.dart' show duyuruJson, duyuruListesiJson;
import '../features/etkinlik/sahteler.dart'
    show
        SahteBaglantiAcici,
        SahteKonumServisi,
        SahteMagazaDegerlendirmesi,
        SahteTakvimPaylasici,
        SahteYerArayici,
        bilesenYolu,
        etkinlikJson,
        etkinlikListesiJson,
        etkinlikTasimasi,
        etkinlikYolu,
        etkinliklerYolu,
        hesapJson,
        hesapYolu,
        katilimcilarJson,
        katilimcilarYolu,
        kontrolListesiJson,
        listeYolu,
        profilJson,
        profilYolu;
import '../features/soru_cevap/sahteler.dart'
    show cevapJson, cevapListesiJson, etiketJson, soruJson, soruListesiJson;
import '../features/sohbet/sahteler.dart' show kanalJson, sohbetUyeJson;
import '../features/tayfa/sahteler.dart';
import '../yardimcilar.dart' show ornekTayfaId;

// --- Saat ---------------------------------------------------------------------

/// Görsellerin "şimdi"si: 28 Kasım 2026 Cumartesi, 09:41 (Türkiye, UTC+3).
final DateTime demoSimdi = DateTime.utc(2026, 11, 28, 6, 41);

// --- Kişiler -----------------------------------------------------------------

String _kisi(int no) =>
    '0d0e0000-0000-4000-8000-${no.toRadixString(16).padLeft(12, '0')}';

/// Görsellerde oturumdaki kullanıcı: Elif K. (Ege Klasikleri'nin kurucusu).
final String benId = _kisi(1);
final String burakId = _kisi(2);
final String selinId = _kisi(5);
final String canId = _kisi(6);
final String denizId = _kisi(7);
final String mertId = _kisi(8);
final String eceId = _kisi(9);
final String kaanId = _kisi(10);
final String gizemId = _kisi(11);
final String onurId = _kisi(12);
final String damlaId = _kisi(13);
final String barisId = _kisi(14);
final String tolgaId = _kisi(16);
final String serkanId = _kisi(18);

/// Demo kişilerinin görünen adları (Tayfam-Api demo setiyle aynı).
final Map<String, String> demoAdlari = {
  benId: 'Elif K.',
  burakId: 'Burak T.',
  selinId: 'Selin D.',
  canId: 'Can Ö.',
  denizId: 'Deniz Ç.',
  mertId: 'Mert S.',
  eceId: 'Ece B.',
  kaanId: 'Kaan E.',
  gizemId: 'Gizem Ş.',
  onurId: 'Onur G.',
  damlaId: 'Damla U.',
  barisId: 'Barış H.',
  tolgaId: 'Tolga M.',
  serkanId: 'Serkan V.',
};

// --- Kimlikler ---------------------------------------------------------------

String _kimlik(int grup, int no) =>
    '0d0${grup}0000-0000-4000-8000-${no.toRadixString(16).padLeft(12, '0')}';

/// Ege Klasikleri Demo (konvoy). Ortak test yardımcıları tayfa kimliğini
/// bu değerle yazdığı için ana tayfa [ornekTayfaId]'dir.
const String egeId = ornekTayfaId;

/// Kazdağı Kampçıları Demo (kamp, balık).
final String kazdagiId = _kimlik(1, 2);

final String konvoyId = _kimlik(2, 1);
final String restorasyonId = _kimlik(2, 2);
final String kampId = _kimlik(2, 3);
final String balikId = _kimlik(2, 4);

final String kurallarDuyuruId = _kimlik(3, 1);
final String hosgeldinDuyuruId = _kimlik(3, 2);
final String izDuyuruId = _kimlik(3, 3);

final String rotaAnketiId = _kimlik(4, 1);
final String aidatAnketiId = _kimlik(4, 2);

final String karburatorSoruId = _kimlik(5, 1);
final String contaSoruId = _kimlik(5, 2);
final String jikleSoruId = _kimlik(5, 3);
final String antifrizSoruId = _kimlik(5, 4);

final String genelKanalId = _kimlik(6, 1);
final String yonetimKanalId = _kimlik(6, 2);
final String konvoyKanalId = _kimlik(6, 3);
final String bakimKanalId = _kimlik(6, 4);
final String parcaKanalId = _kimlik(6, 5);

// --- Tayfalar ----------------------------------------------------------------

Map<String, Object?> _gorunum(String id) {
  final ege = id == egeId;
  final gorunum = gorunumJson(
    id,
    ad: ege ? 'Ege Klasikleri Demo' : 'Kazdağı Kampçıları Demo',
    uyeSayisi: ege ? 9 : 8,
    rol: ege ? 'admin' : 'member',
    kod: ege ? sahteKod : null,
  );
  final tayfa = gorunum['tayfa']! as Map<String, Object?>;
  tayfa['description'] = ege
      ? 'Klasik otomobil tutkunlarının Ege turları, bakım sohbetleri ve '
            'buluşmaları.'
      : 'Kazdağları eteklerinde kamp, doğa ve kıyıda akşam balığı.';
  if (!ege) tayfa['interests'] = ['nature', 'water'];
  return gorunum;
}

Map<String, Object?> _tayfaListesi() => listeJson([
  etkinJson(egeId, ad: 'Ege Klasikleri Demo', rol: 'admin', kod: sahteKod),
  etkinJson(kazdagiId, ad: 'Kazdağı Kampçıları Demo'),
]);

// --- Etkinlikler -------------------------------------------------------------

/// Türkiye saatiyle (UTC+3) [gun] Aralık 2026, [saat]:[dakika].
DateTime _aralik(int gun, int saat, [int dakika = 0]) =>
    DateTime.utc(2026, 12, gun, saat - 3, dakika);

Map<String, Object?> _etkinlik(String id) {
  if (id == konvoyId) {
    return etkinlikJson(
      id: konvoyId,
      tur: 'convoy',
      baslik: 'Bozdağ sonbahar konvoyu',
      aciklama:
          "Kemalpaşa'dan Bozdağ'a sakin tempoda bir tur. Öğle yemeği "
          'yaylada, dönüş gün batımından önce.',
      baslangic: _aralik(5, 8, 30),
      sure: const Duration(hours: 9),
      gelen: 5,
      belki: 1,
      cevap: 'going',
      yonetebilir: true,
      ayrinti: {'vehicles': const <Object?>[]},
    )..addAll({
      'tayfa_id': egeId,
      'created_by_user_id': benId,
      'meeting_point_name': 'Kemalpaşa çıkışı dinlenme tesisi',
      'meeting_point': {'lat': 38.4262, 'lng': 27.4171},
      'city': 'İzmir',
      'district': 'Kemalpaşa',
    });
  }
  if (id == restorasyonId) {
    return etkinlikJson(
      id: restorasyonId,
      tur: 'general',
      mod: 'online',
      baslik: 'Restorasyon sohbeti',
      aciklama:
          'Kış bakımı öncesi parça tedariki ve usta önerileri üzerine bir '
          'saatlik sohbet.',
      baslangic: _aralik(9, 21),
      sure: const Duration(hours: 1),
      gelen: 3,
      belki: 1,
    )..addAll({'tayfa_id': egeId, 'created_by_user_id': benId});
  }
  if (id == kampId) {
    return etkinlikJson(
      id: kampId,
      tur: 'camp',
      baslik: 'Kazdağı hafta sonu kampı',
      aciklama:
          'Cuma akşamı kurulum, cumartesi kısa yürüyüş ve şelale, pazar '
          'öğlen toplanma.',
      baslangic: _aralik(11, 18),
      sure: const Duration(hours: 42),
      gelen: 6,
      belki: 1,
      cevap: 'going',
    )..addAll({
      'tayfa_id': kazdagiId,
      'created_by_user_id': burakId,
      'meeting_point_name': 'Milli park girişine yakın kamp alanı',
      'meeting_point': {'lat': 39.7031, 'lng': 26.8542},
      'city': 'Balıkesir',
      'district': 'Edremit',
    });
  }
  return etkinlikJson(
    id: balikId,
    tur: 'fishing',
    baslik: 'Akçay sahilinde akşam balığı',
    aciklama: 'Gün batımına doğru kıyıdan olta.',
    baslangic: _aralik(3, 17, 30),
    sure: const Duration(hours: 4),
    gelen: 3,
    belki: 1,
  )..addAll({
    'tayfa_id': kazdagiId,
    'created_by_user_id': burakId,
    'meeting_point_name': 'Akçay sahil yolu',
    'meeting_point': {'lat': 39.5838, 'lng': 26.9265},
    'city': 'Balıkesir',
    'district': 'Edremit',
  });
}

List<String> _gelenler(String etkinlikId) {
  if (etkinlikId == konvoyId) {
    return [benId, canId, kaanId, onurId, serkanId];
  }
  if (etkinlikId == kampId) {
    return [burakId, denizId, mertId, eceId, damlaId, benId];
  }
  if (etkinlikId == restorasyonId) return [benId, selinId, barisId];
  return [burakId, mertId, kaanId];
}

Map<String, Object?> _rota() => {
  'points': const [
    {'lat': 38.4262, 'lng': 27.4171},
    {'lat': 38.3790, 'lng': 27.6400},
    {'lat': 38.3369, 'lng': 27.8915},
    {'lat': 38.3427, 'lng': 28.1079},
  ],
  'updated_at': '2026-11-20T10:00:00Z',
  'caller_can_edit': true,
};

Map<String, Object?> _arac(
  int no,
  String sahip,
  String marka,
  String model,
  int yil,
  String renk,
) => {
  'id': _kimlik(7, no),
  'user_id': sahip,
  'make': marka,
  'model': model,
  'model_year': yil,
  'color': renk,
  'seats': 0,
  'rider_user_ids': const <String>[],
  'pending_user_ids': const <String>[],
};

Map<String, Object?> _araclar() => {
  'vehicles': [
    _arac(1, benId, 'Mercedes-Benz', '280 SE', 1972, 'Krem'),
    _arac(2, canId, 'Volkswagen', 'Kaplumbağa', 1968, 'Açık mavi'),
    _arac(3, kaanId, 'Ford', 'Mustang', 1967, 'Kırmızı'),
    _arac(4, onurId, 'Fiat', '124', 1974, 'Beyaz'),
    _arac(5, serkanId, 'Renault', '12', 1979, 'Bej'),
  ],
  'plate_enabled': false,
  'seats_enabled': false,
  'caller_can_participate': true,
  'caller_can_manage': true,
};

Map<String, Object?> _madde(int no, String ad, int adet, String? ustlenen) => {
  'id': _kimlik(8, no),
  'name': ad,
  'quantity': adet,
  'assigned_user_id': ?ustlenen,
};

Map<String, Object?> _malzemeListesi() => kontrolListesiJson(
  maddeler: [
    _madde(1, 'Çadır (4 kişilik)', 2, burakId),
    _madde(2, 'Kamp ocağı ve tüp', 1, denizId),
    _madde(3, 'Su bidonu (19 L)', 3, mertId),
    _madde(4, 'İlk yardım çantası', 1, eceId),
    _madde(5, 'Çöp poşetleri', 1, benId),
    _madde(6, 'Kahvaltılık', 1, null),
    _madde(7, 'Fener ve yedek pil', 4, null),
  ],
  ustlenebilir: true,
);

// --- Duyurular ---------------------------------------------------------------

Map<String, Object?> _duyurular(String tayfaId) => duyuruListesiJson(
  tayfaId == egeId
      ? [
          duyuruJson(
            kurallarDuyuruId,
            baslik: 'Konvoy kuralları',
            govde:
                'Konvoyda sıra bozulmaz, öndeki aracı gözden kaybetmeyin. '
                'Hız sınırlarına uyuyoruz, kimse yarışmıyor.',
            sabit: true,
            zaman: '2026-11-18T09:00:00Z',
            yazar: benId,
          ),
          duyuruJson(
            hosgeldinDuyuruId,
            baslik: 'Yeni üyelere hoş geldiniz',
            govde:
                'Aracınızı ve hikâyesini genel kanalda paylaşmayı '
                'unutmayın.',
            zaman: '2026-11-26T17:00:00Z',
            yazar: benId,
          ),
        ]
      : [
          duyuruJson(
            izDuyuruId,
            baslik: 'İz bırakmama ilkesi',
            govde: 'Getirdiğimiz her şeyi geri götürüyoruz.',
            sabit: true,
            yazar: burakId,
          ),
        ],
);

// --- Anketler ----------------------------------------------------------------

Map<String, Object?> _anket(String id) {
  final rota = id == rotaAnketiId;
  final secenekler = rota
      ? [('Şirince', 4), ('Alaçatı', 1), ('Bozdağ', 0), ('Kozak Yaylası', 2)]
      : [('Aidat olmasın', 1), ('500 TL', 4), ('1000 TL', 1)];
  return {
    'id': id,
    'tayfa_id': egeId,
    'created_by_user_id': rota ? benId : canId,
    'question': rota
        ? 'Bir sonraki konvoy rotası nereye olsun?'
        : 'Yıllık kulüp aidatı ne kadar olsun?',
    'anonymous': !rota,
    'multiple_choice': false,
    'closes_at': rota ? '2026-12-01T18:00:00Z' : null,
    'closed': false,
    'created_at': rota ? '2026-11-25T08:00:00Z' : '2026-11-24T19:00:00Z',
    'options': [
      for (final (sira, (metin, oy)) in secenekler.indexed)
        {
          'id': _kimlik(9, (rota ? 0 : 16) + sira + 1),
          'text': metin,
          'position': sira,
          'vote_count': oy,
        },
    ],
    'voter_count': rota ? 7 : 6,
    'own_option_ids': [_kimlik(9, rota ? 1 : 18)],
  }..removeWhere((_, deger) => deger == null);
}

Map<String, Object?> _anketOyVerenleri(String secenekId) {
  final kimler = switch (secenekId) {
    final s when s == _kimlik(9, 1) => [benId, canId, onurId, selinId],
    final s when s == _kimlik(9, 2) => [barisId],
    final s when s == _kimlik(9, 4) => [kaanId, serkanId],
    _ => <String>[],
  };
  return {
    'voters': [
      for (final id in kimler)
        {'user_id': id, 'voted_at': '2026-11-26T10:00:00Z'},
    ],
  };
}

// --- Soru-cevap --------------------------------------------------------------

final Map<String, Object?> _bakim = etiketJson(_kimlik(5, 101), 'bakım');
final Map<String, Object?> _karburator = etiketJson(
  _kimlik(5, 102),
  'karbüratör',
);
final Map<String, Object?> _parca = etiketJson(_kimlik(5, 103), 'parça');

Map<String, Object?> _soru(
  String id,
  String baslik,
  String govde,
  String yazar,
  List<Map<String, Object?>> etiketler,
  int cevap,
  String zaman,
) => soruJson(
  id,
  baslik: baslik,
  govde: govde,
  yazar: yazar,
  etiketler: etiketler,
  cevapSayisi: cevap,
  zaman: zaman,
)..['tayfa_id'] = egeId;

List<Map<String, Object?>> _karburatorSorulari() => [
  _soru(
    karburatorSoruId,
    'Çift gövdeli karbüratör ayarını kim yapıyor?',
    'Rölantide tekleme var, şamandıra seviyesi doğru görünüyor. Bornova '
        'civarında önerebileceğiniz bir usta var mı?',
    kaanId,
    [_bakim, _karburator],
    2,
    '2026-11-27T18:20:00Z',
  ),
  _soru(
    contaSoruId,
    'Weber karbüratör için conta takımı nereden bulunur?',
    'Orijinal takım bulamadım, muadili olan var mı?',
    serkanId,
    [_parca, _karburator],
    3,
    '2026-11-22T11:05:00Z',
  ),
  _soru(
    jikleSoruId,
    'Soğuk sabahlarda karbüratörlü motor zor çalışıyor',
    'Jikle tam açıkken bile birkaç denemede çalışıyor; sonra düzgün.',
    onurId,
    [_bakim, _karburator],
    1,
    '2026-11-14T07:40:00Z',
  ),
];

Map<String, Object?> _sorular(TayfaIstegi istek) {
  final arama = istek.sorgu['q'];
  if (arama != null && arama.isNotEmpty) {
    return soruListesiJson(_karburatorSorulari());
  }
  return soruListesiJson([
    ..._karburatorSorulari(),
    _soru(
      antifrizSoruId,
      'Kışa girerken antifriz oranı ne olmalı?',
      'Garajda duran araç için yarı yarıya yeterli mi?',
      barisId,
      [_bakim],
      2,
      '2026-11-10T09:00:00Z',
    ),
  ]);
}

Map<String, Object?> _cevaplar(String soruId) => cevapListesiJson([
  cevapJson(
    _kimlik(5, 201),
    soruId: soruId,
    govde:
        'Önce vakum kaçağına bak; hortumlar eskiyse rölanti hep oynar. '
        'Sonra senkron ayarı yapılır.',
    yazar: canId,
    oy: 3,
  )..['tayfa_id'] = egeId,
]);

// --- Sohbet ------------------------------------------------------------------

List<Map<String, Object?>> _kanallar() => [
  kanalJson(genelKanalId, ad: 'genel', okunmamis: 3, kisiSayisi: 9),
  kanalJson(
    konvoyKanalId,
    ad: 'Bozdağ sonbahar konvoyu',
    gorunurluk: 'event',
    etkinlik: konvoyId,
    okunmamis: 5,
    kisiSayisi: 6,
  ),
  kanalJson(bakimKanalId, ad: 'bakım-onarım', okunmamis: 1, kisiSayisi: 9),
  kanalJson(parcaKanalId, ad: 'parça-pazarı', kisiSayisi: 9, yavas: 60),
  kanalJson(yonetimKanalId, ad: 'yönetim', yonetim: true, kisiSayisi: 2),
];

// --- Taşıma ------------------------------------------------------------------

/// Demo verisinin sahte taşıması: bütün ekranların uçları tek yerde. Gerçek
/// ağ yoktur; tanımlı olmayan istek `StateError` fırlatır ve
/// [tanimsizIstekler]'de görünür.
SahteTayfaTasima demoTasimasi() {
  final t = etkinlikTasimasi({
    'GET /v1/tayfas': (_) => _tayfaListesi(),
    'GET /v1/tayfas/{tayfa_id}': (i) =>
        _gorunum(i.yolParametreleri['tayfa_id']!),
    'GET $etkinliklerYolu': (i) => etkinlikListesiJson(
      i.sorgu.containsKey('event_id')
          ? const []
          : i.yolParametreleri['tayfa_id'] == egeId
          ? [_etkinlik(konvoyId), _etkinlik(restorasyonId)]
          : [_etkinlik(balikId), _etkinlik(kampId)],
    ),
    'GET $etkinlikYolu': (i) => _etkinlik(i.yolParametreleri['event_id']!),
    'GET $katilimcilarYolu': (i) =>
        katilimcilarJson(_gelenler(i.yolParametreleri['event_id']!)),
    'GET $bilesenYolu/route': (_) => _rota(),
    'GET $bilesenYolu/vehicles': (_) => _araclar(),
    'GET $listeYolu': (_) => _malzemeListesi(),
    'GET $profilYolu': (i) {
      final id = i.yolParametreleri['user_id']!;
      return profilJson(id, demoAdlari[id] ?? 'Üye', ben: id == benId);
    },
    'GET $hesapYolu': (_) => hesapJson(benId)..['display_name'] = 'Elif K.',
    'GET /v1/tayfas/{tayfa_id}/announcements': (i) =>
        _duyurular(i.yolParametreleri['tayfa_id']!),
    'GET /v1/tayfas/{tayfa_id}/polls': (i) => {
      'polls': i.sorgu.containsKey('event_id')
          ? const <Object?>[]
          : [_anket(rotaAnketiId), _anket(aidatAnketiId)],
    },
    'GET /v1/tayfas/{tayfa_id}/polls/{poll_id}': (i) =>
        _anket(i.yolParametreleri['poll_id']!),
    'GET /v1/tayfas/{tayfa_id}/polls/{poll_id}/options/{option_id}/voters': (
      i,
    ) => _anketOyVerenleri(i.yolParametreleri['option_id']!),
    'GET /v1/tayfas/{tayfa_id}/questions': _sorular,
    'GET /v1/tayfas/{tayfa_id}/questions/{question_id}/answers': (i) =>
        _cevaplar(i.yolParametreleri['question_id']!),
    'GET /v1/tayfas/{tayfa_id}/tags': (_) => {
      'tags': [
        etiketJson(_kimlik(5, 101), 'bakım', sayi: 3),
        etiketJson(_kimlik(5, 102), 'karbüratör', sayi: 3),
        etiketJson(_kimlik(5, 103), 'parça', sayi: 1),
      ],
    },
    'GET /v1/tayfas/{tayfa_id}/channels': (_) => {'channels': _kanallar()},
    'GET /v1/tayfas/{tayfa_id}/members': (_) => {
      'members': [
        sohbetUyeJson(benId, rol: 'admin'),
        sohbetUyeJson(canId, rol: 'moderator'),
        for (final id in [kaanId, onurId, barisId, serkanId, tolgaId, selinId])
          sohbetUyeJson(id),
      ],
    },
    'GET $konusmalarYolu': (_) => konusmaListesiJson([
      konusmaJson(
        _kimlik(6, 101),
        karsi: canId,
        okunmamis: 2,
        zaman: '2026-11-28T06:20:00Z',
      ),
    ]),
    'GET /v1/notifications/unread-count': (_) => {'unread_count': 2},
  });
  return t;
}

/// [tasima]'ya yapılıp karşılığı tanımlı olmayan istekler (hata ayıklama
/// için; yalnızca yöntem ve yol şablonu, gövde ve sorgu yazılmaz).
List<String> tanimsizIstekler(SahteTayfaTasima tasima) => {
  for (final i in tasima.istekler)
    if (!tasima.yanitlar.containsKey('${i.method} ${i.yol}'))
      '${i.method} ${i.yol}',
}.toList();

// --- Override'lar ------------------------------------------------------------

/// `uygulamayiAc`'ın `tayfa` override'ları: demo taşımasına bağlı depolar,
/// sabit saat, demo adları, uygulamanın gerçek modül ve bileşen kayıtları.
List<Override> demoOverridelari(SahteTayfaTasima t) => [
  ...tayfaOverridelari(tasima: t),
  duyuruDeposuProvider.overrideWithValue(DuyuruDeposu(t)),
  etkinlikDeposuProvider.overrideWithValue(EtkinlikDeposu(t)),
  sozlukDeposuProvider.overrideWithValue(SozlukDeposu(t)),
  sikayetDeposuProvider.overrideWithValue(SikayetDeposu(t)),
  anketDeposuProvider.overrideWithValue(AnketDeposu(t)),
  soruCevapDeposuProvider.overrideWithValue(SoruCevapDeposu(t)),
  kanalDeposuProvider.overrideWithValue(KanalDeposu(t)),
  profilOkuyucuProvider.overrideWithValue(
    (id) async => switch (demoAdlari[id]) {
      final ad? => KullaniciAdi(ad),
      null => const KullaniciAdi.silinmis(),
    },
  ),
  kendiKimligiOkuyucuProvider.overrideWithValue(() async => benId),
  etkinlikSaatiProvider.overrideWithValue(() => demoSimdi),
  anketSaatiProvider.overrideWithValue(() => demoSimdi),
  tayfaSaatiProvider.overrideWithValue(() => demoSimdi),
  birebirSaatiProvider.overrideWithValue(() => demoSimdi),
  simdiProvider.overrideWithValue(() => demoSimdi),
  // Harita karoları çizilmez: testte ağ yok (OSM'den karo indirilmez).
  karoSaglayiciProvider.overrideWithValue(() => null),
  takvimPaylasiciProvider.overrideWithValue(SahteTakvimPaylasici()),
  etkinlikBaglantiAciciProvider.overrideWithValue(SahteBaglantiAcici()),
  yerArayiciProvider.overrideWithValue(SahteYerArayici()),
  konumServisiProvider.overrideWithValue(SahteKonumServisi()),
  magazaDegerlendirmesiProvider.overrideWithValue(
    SahteMagazaDegerlendirmesi(kullanilabilir: false),
  ),
  etkinlikIstekKimligiProvider.overrideWithValue(() => _kimlik(9, 99)),
  anketIstekKimligiProvider.overrideWithValue(() => _kimlik(9, 98)),
  tayfaModulleriProvider.overrideWithValue(const [
    EtkinlikModulu(),
    DuyuruModulu(),
    AnketModulu(),
    SoruCevapModulu(),
  ]),
  etkinlikBilesenKaydiProvider.overrideWithValue(etkinlikBilesenKaydi),
  tayfaUstMenusuProvider.overrideWithValue(tayfaUstMenusu),
  tayfaDavetiProvider.overrideWithValue(tayfayaDavetEt),
  birebirOkunmamisYuvasiProvider.overrideWith(
    (ref) => ref.watch(birebirOkunmamisBilinenProvider),
  ),
];

/// Bildirim ve birebir override'ları (aynı taşıma).
List<Override> demoBildirimOverridelari(SahteTayfaTasima t) =>
    bildirimOverridelari(tasima: t);

/// Birebir override'ları (aynı taşıma).
List<Override> demoBirebirOverridelari(SahteTayfaTasima t) =>
    birebirOverridelari(t);
