import 'package:flutter_riverpod/misc.dart';

import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/features/duyuru/data/duyuru_deposu.dart';
import 'package:tayfam/features/etkinlik/data/etkinlik_deposu.dart';
import 'package:tayfam/features/sikayet/data/sikayet_deposu.dart';

import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';

/// Testlerde kullanılan, biçimi geçerli örnek kimlikler.
const String duyuruId1 = '1a2b3c4d-0000-4000-8000-000000000001';
const String duyuruId2 = '1a2b3c4d-0000-4000-8000-000000000002';
const String duyuruId3 = '1a2b3c4d-0000-4000-8000-000000000003';
const String duyuruId4 = '1a2b3c4d-0000-4000-8000-000000000004';
const String duyuruId5 = '1a2b3c4d-0000-4000-8000-000000000005';
const String etkinlikId1 = '2b3c4d5e-0000-4000-8000-000000000001';
const String etkinlikId2 = '2b3c4d5e-0000-4000-8000-000000000002';
const String etkinlikId3 = '2b3c4d5e-0000-4000-8000-000000000003';
const String etkinlikId4 = '2b3c4d5e-0000-4000-8000-000000000004';

/// Duyuru uçlarının yol şablonları (sahte taşımanın anahtarları).
const String duyurularYolu = '/v1/tayfas/{tayfa_id}/announcements';
const String duyuruYolu =
    '/v1/tayfas/{tayfa_id}/announcements/{announcement_id}';
const String sabitlemeYolu =
    '/v1/tayfas/{tayfa_id}/announcements/{announcement_id}/pin';
const String etkinliklerYolu = '/v1/tayfas/{tayfa_id}/events';
const String sikayetlerYolu = '/v1/tayfas/{tayfa_id}/reports';

/// Örnek duyuruların yazarı; [benimId] oturumdaki kullanıcıdır.
const String yazarId = '00000000-0000-4000-8000-000000000001';
const String benimId = '00000000-0000-4000-8000-0000000000aa';

/// Örnek duyuru (`Announcement`) JSON'u.
Map<String, Object?> duyuruJson(
  String id, {
  String baslik = 'Pazar buluşması',
  String govde = 'Saat 9’da Moda’dayız.',
  bool sabit = false,
  String zaman = '2026-11-10T10:00:00Z',
  String yazar = yazarId,
}) => {
  'id': id,
  'tayfa_id': ornekTayfaId,
  'author_user_id': yazar,
  'title': baslik,
  'body': govde,
  'pinned': sabit,
  'created_at': zaman,
  'updated_at': zaman,
};

/// `GET …/announcements` yanıtı.
Map<String, Object?> duyuruListesiJson(
  List<Map<String, Object?>> duyurular, {
  String? sonraki,
}) => {'announcements': duyurular, 'next_page_token': ?sonraki};

/// Örnek etkinlik (`Event`) JSON'u.
Map<String, Object?> etkinlikJson(
  String id, {
  String tur = 'convoy',
  String mod = 'in_person',
  String baslik = 'Sabah konvoyu',
  String baslangic = '2026-11-14T06:00:00Z',
  String? yer = 'Moda Sahili',
  String? il,
  String? ilce,
  int kontenjan = 0,
  int gelen = 4,
  int bekleme = 0,
  String durum = 'scheduled',
  String? cevap,
}) => {
  'id': id,
  'tayfa_id': ornekTayfaId,
  'type': tur,
  'mode': mod,
  'title': baslik,
  'description': '',
  'starts_at': baslangic,
  'ends_at': '2026-11-14T12:00:00Z',
  'meeting_point_name': ?yer,
  'city': ?il,
  'district': ?ilce,
  'capacity': kontenjan,
  'status': durum,
  'discoverable': false,
  'going_count': gelen,
  'maybe_count': 0,
  'waitlist_count': bekleme,
  'caller_rsvp': ?cevap,
  'caller_can_manage': false,
  'series_override': false,
  'created_at': '2026-11-01T10:00:00Z',
  'updated_at': '2026-11-01T10:00:00Z',
};

/// `GET …/events` yanıtı.
Map<String, Object?> etkinlikListesiJson(
  List<Map<String, Object?>> etkinlikler, {
  String? sonraki,
}) => {'events': etkinlikler, 'next_page_token': ?sonraki};

/// `GET /v1/tayfas/{tayfa_id}` yanıtı; rol ve modüller verilebilir.
Map<String, Object?> modulluGorunum({
  String rol = 'member',
  bool duyurular = true,
  bool etkinlikler = true,
  bool uyeEtkinlikAcar = false,
}) {
  final gorunum = gorunumJson(ornekTayfaId, rol: rol);
  final tayfa = gorunum['tayfa']! as Map<String, Object?>;
  tayfa['modules'] = {
    'announcements': duyurular,
    'events': etkinlikler,
    'qa': true,
    'polls': true,
  };
  tayfa['members_can_create_events'] = uyeEtkinlikAcar;
  return gorunum;
}

/// Sahte taşımaya varsayılan yanıtları ekler: tayfa görünümü (üye, bütün
/// modüller açık), boş duyuru ve etkinlik listeleri.
SahteTayfaTasima modulTasimasi([Map<String, TayfaYaniti>? yanitlar]) {
  final tasima = SahteTayfaTasima(yanitlar);
  tasima.yanitlar
    ..putIfAbsent('GET /v1/tayfas/{tayfa_id}', () => yanit(modulluGorunum()))
    ..putIfAbsent('GET $duyurularYolu', () => yanit(duyuruListesiJson([])))
    ..putIfAbsent('GET $etkinliklerYolu', () => yanit(etkinlikListesiJson([])));
  return tasima;
}

/// Her istekte [deger]'i döndüren yanıt.
TayfaYaniti yanit(Object? deger) =>
    (_) => deger;

/// Tayfa, duyuru ve etkinlik uçlarını [tasima]'ya bağlayan override'lar;
/// oturum açık başlar. Gerçek ağ ve güvenli depo yok.
List<Override> modulOverridelari(SahteTayfaTasima tasima) => [
  ...tayfaOverridelari(tasima: tasima),
  duyuruDeposuProvider.overrideWithValue(DuyuruDeposu(tasima)),
  etkinlikDeposuProvider.overrideWithValue(EtkinlikDeposu(tasima)),
  sikayetDeposuProvider.overrideWithValue(SikayetDeposu(tasima)),
  profilOkuyucuProvider.overrideWithValue(
    (id) async => KullaniciAdi('Kişi', ben: id == benimId),
  ),
  oturumDurumuProvider.overrideWith(() => SabitOturumDurumu(OturumDurumu.acik)),
];
