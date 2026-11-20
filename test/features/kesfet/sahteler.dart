import 'package:flutter_riverpod/misc.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/features/kesfet/data/kesfet_deposu.dart';

import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';

/// Testlerde kullanılan, biçimi geçerli örnek kimlikler (gerçek veri
/// değil).
const String kesfetTayfaId = '7b6a5c4d-3e2f-4a1b-8c0d-9e8f7a6b5c4d';
const String kesfetEtkinlikId = '1a2b3c4d-5e6f-4a7b-8c9d-0e1f2a3b4c5d';
const String ayseId = '00000000-0000-4000-8000-0000000000a1';
const String mehmetId = '00000000-0000-4000-8000-0000000000a2';
const String elifId = '00000000-0000-4000-8000-0000000000a3';

/// Uç yolları (sahte taşımanın anahtarları).
const String akisYolu = '/v1/discover/events';
const String kesfetKatilYolu = '/v1/discover/tayfas/{tayfa_id}/join';
const String tayfaKesfetYolu = '/v1/tayfas/{tayfa_id}/discover';
const String geriBildirimYolu =
    '/v1/tayfas/{tayfa_id}/events/{event_id}/feedback';
const String guvenlikYolu =
    '/v1/tayfas/{tayfa_id}/events/{event_id}/safety-contact';
const String dondumYolu =
    '/v1/tayfas/{tayfa_id}/events/{event_id}/safety-contact/return';
const String paylasimlarYolu = '/v1/me/safety-shares';
const String arkadaslarYolu = '/v1/me/friends';

/// Sunucunun "özellik kapalı" cevabı (`404 feature-disabled`).
const ApiProblem ozellikKapaliHatasi = ApiProblem(
  type: ProblemType.featureDisabled,
  status: 404,
);

/// [tur] kodlu sunucu hatası.
ApiProblem problem(ProblemType tur, {int status = 409}) =>
    ApiProblem(type: tur, status: status);

/// `DiscoverPerson` JSON'u.
Map<String, Object?> kisiJson(String id, String ad) => {
  'user_id': id,
  'display_name': ad,
};

/// `DiscoverItem` JSON'u.
Map<String, Object?> kesfetOgesiJson({
  String tayfaId = kesfetTayfaId,
  String etkinlikId = kesfetEtkinlikId,
  int arkadasSayisi = 3,
  String? aciklama = 'Her pazar sabahı kolay ve orta parkurlar.',
  int etkinlikSayisi = 42,
  int katilimSayisi = 318,
}) => {
  'event': {
    'id': etkinlikId,
    'type': 'hiking',
    'title': 'Belgrad Ormanı sabah yürüyüşü',
    'starts_at': '2026-11-16T05:30:00Z',
    'ends_at': '2026-11-16T09:00:00Z',
    'city': 'İstanbul',
    'district': 'Sarıyer',
  },
  'tayfa': {
    'id': tayfaId,
    'name': 'Pazar Yürüyüşçüleri',
    'description': ?aciklama,
    'city': 'İstanbul',
    'created_at': '2024-03-10T10:00:00Z',
    'event_count': etkinlikSayisi,
    'attendance_count': katilimSayisi,
  },
  'friends': [
    if (arkadasSayisi > 0) kisiJson(ayseId, 'Ayşe'),
    if (arkadasSayisi > 1) kisiJson(mehmetId, 'Mehmet'),
    if (arkadasSayisi > 2) kisiJson(elifId, 'Elif'),
  ],
  'friend_count': arkadasSayisi,
};

/// `SafetyContact` JSON'u; [kisi] yoksa seçilmemiştir.
Map<String, Object?> guvenlikJson({
  bool kisi = true,
  int tolerans = 60,
  String? donus,
  String? alarm,
}) => {
  if (kisi) 'contact': kisiJson(ayseId, 'Ayşe'),
  'grace_minutes': kisi ? tolerans : 0,
  'returned_at': ?donus,
  'alert_sent_at': ?alarm,
};

/// `SafetyShare` JSON'u.
Map<String, Object?> paylasimJson(
  String durum, {
  String id = ayseId,
  String ad = 'Ayşe',
}) => {
  'participant': kisiJson(id, ad),
  'starts_at': '2026-11-15T16:00:00Z',
  'ends_at': '2026-11-15T19:00:00Z',
  'grace_minutes': 60,
  if (durum == 'returned') 'returned_at': '2026-11-15T19:50:00Z',
  if (durum == 'alert_sent') 'alert_sent_at': '2026-11-15T20:00:00Z',
  'state': durum,
};

/// `Friend` JSON'u.
Map<String, Object?> arkadasJson(String id, String ad, {String? durum}) => {
  'user_id': id,
  'display_name': ad,
  'state': durum ?? 'friends',
  'requested_at': '2026-11-10T09:00:00Z',
};

/// `TayfaDiscover` JSON'u.
Map<String, Object?> kesfetAyariJson({
  String durum = 'off',
  bool acik = false,
  bool vitrin = true,
}) => {'state': durum, 'enabled': acik, 'stats_showcase': vitrin};

/// Her istekte [deger]'i döndüren yanıt.
TayfaYaniti yanit(Object? deger) =>
    (_) => deger;

/// Varsayılan yanıtlarla sahte taşıma: dolu akış, seçilmemiş güvenlik
/// kişisi, cevapsız geri bildirim, boş paylaşımlar, üç arkadaş, kapalı
/// Keşfet ayarı.
SahteTayfaTasima kesfetTasimasi([Map<String, TayfaYaniti>? yanitlar]) {
  final tasima = SahteTayfaTasima(yanitlar);
  tasima.yanitlar
    ..putIfAbsent(
      'GET $akisYolu',
      () => yanit({
        'items': [kesfetOgesiJson()],
      }),
    )
    ..putIfAbsent('GET $guvenlikYolu', () => yanit(guvenlikJson(kisi: false)))
    ..putIfAbsent('GET $geriBildirimYolu', () => yanit(<String, Object?>{}))
    ..putIfAbsent('GET $paylasimlarYolu', () => yanit({'shares': <Object?>[]}))
    ..putIfAbsent(
      'GET $arkadaslarYolu',
      () => yanit({
        'friends': [
          arkadasJson(ayseId, 'Ayşe'),
          arkadasJson(mehmetId, 'Mehmet'),
          arkadasJson(elifId, 'Elif', durum: 'outgoing'),
        ],
      }),
    )
    ..putIfAbsent(
      'GET $tayfaKesfetYolu',
      () => yanit(kesfetAyariJson()),
    );
  return tasima;
}

/// Keşfet uçlarını [tasima]'ya bağlayan override'lar; oturum açık. Gerçek
/// ağ yok.
List<Override> kesfetOverridelari(SahteTayfaTasima tasima) => [
  ...tayfaOverridelari(tasima: tasima),
  kesfetDeposuProvider.overrideWithValue(KesfetDeposu(tasima)),
  oturumDurumuProvider.overrideWith(() => SabitOturumDurumu(OturumDurumu.acik)),
];

/// Testteki etkinlik: [mod], cevap, katılım ve zaman verilebilir.
Event kesfetEtkinligi({
  DateTime? baslangic,
  Duration sure = const Duration(hours: 3),
  String mod = 'in_person',
  String? cevap = 'going',
  String? katilim,
  bool halkaAcik = false,
  bool iptal = false,
}) {
  final bas = baslangic ?? DateTime.utc(2026, 11, 16, 6);
  return Event.fromJson({
    'id': kesfetEtkinlikId,
    'tayfa_id': kesfetTayfaId,
    'type': 'hiking',
    'type_version': 1,
    'mode': mod,
    'title': 'Yürüyüş',
    'description': '',
    'starts_at': bas.toIso8601String(),
    'ends_at': bas.add(sure).toIso8601String(),
    'open_ended': false,
    'capacity': 0,
    'status': iptal ? 'cancelled' : 'scheduled',
    'discoverable': halkaAcik,
    'going_count': 3,
    'maybe_count': 0,
    'waitlist_count': 0,
    'caller_rsvp': ?cevap,
    'caller_attendance': ?katilim,
    'caller_can_manage': false,
    'series_override': false,
    'created_at': '2026-11-01T10:00:00Z',
    'updated_at': '2026-11-01T10:00:00Z',
  });
}
