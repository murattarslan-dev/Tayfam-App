import 'package:flutter_riverpod/misc.dart';

import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/features/sikayet/data/sikayet_deposu.dart';

import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';

/// Testlerde kullanılan, biçimi geçerli örnek kimlikler.
const String sikayetId1 = '9a8b7c6d-0000-4000-8000-000000000001';
const String sikayetId2 = '9a8b7c6d-0000-4000-8000-000000000002';
const String duyuruId = '1a2b3c4d-0000-4000-8000-000000000001';
const String cevapId = '3c4d5e6f-0000-4000-8000-000000000001';
const String uyeId = '00000000-0000-4000-8000-000000000001';
const String moderatorId = '00000000-0000-4000-8000-000000000002';
const String mesajId = '4d5e6f70-0000-4000-8000-000000000001';

/// Uç yolları (sahte taşımanın anahtarları).
const String sikayetlerYolu = '/v1/tayfas/{tayfa_id}/reports';
const String cozumYolu =
    '/v1/tayfas/{tayfa_id}/reports/{report_id}/resolution';
const String benimSikayetlerimYolu = '/v1/me/reports';
const String duyuruYolu =
    '/v1/tayfas/{tayfa_id}/announcements/{announcement_id}';
const String duyuruGeriAlmaYolu =
    '/v1/tayfas/{tayfa_id}/announcements/{announcement_id}/restoration';
const String cevapYolu = '/v1/tayfas/{tayfa_id}/answers/{answer_id}';
const String cevapGeriAlmaYolu =
    '/v1/tayfas/{tayfa_id}/answers/{answer_id}/restoration';

/// `MyReport` JSON'u.
Map<String, Object?> benimSikayetimJson({
  String tur = 'announcement',
  String hedef = duyuruId,
  String gerekce = 'spam',
  String? tayfa = ornekTayfaId,
}) => {
  'id': sikayetId1,
  'tayfa_id': ?tayfa,
  'target_type': tur,
  'target_id': hedef,
  'reason': gerekce,
  'status': 'open',
  'created_at': '2026-11-11T10:00:00Z',
};

/// `ModerationReport` JSON'u.
Map<String, Object?> kuyrukSikayetiJson({
  String id = sikayetId1,
  String tur = 'announcement',
  String hedef = duyuruId,
  String gerekce = 'spam',
  String oncelik = 'normal',
  String durum = 'open',
  String? sonuc,
  String? not,
  String? konu = uyeId,
}) => {
  'id': id,
  'tayfa_id': ornekTayfaId,
  'target_type': tur,
  'target_id': hedef,
  'subject_user_id': ?konu,
  'reason': gerekce,
  'description': ?not,
  'priority': oncelik,
  'status': durum,
  'resolution': ?sonuc,
  'handled_by_user_id': ?(durum == 'resolved' ? moderatorId : null),
  'created_at': '2026-11-10T09:00:00Z',
  'resolved_at': ?(durum == 'resolved' ? '2026-11-11T09:00:00Z' : null),
};

/// `ModerationReportList` JSON'u.
Map<String, Object?> kuyrukJson(
  List<Map<String, Object?>> sikayetler, {
  String? sonraki,
}) => {'reports': sikayetler, 'next_page_token': ?sonraki};

/// `Announcement` JSON'u.
Map<String, Object?> duyuruJson({String baslik = 'Pazar buluşması'}) => {
  'id': duyuruId,
  'tayfa_id': ornekTayfaId,
  'author_user_id': uyeId,
  'title': baslik,
  'body': 'Saat 9’da.',
  'pinned': false,
  'created_at': '2026-11-10T10:00:00Z',
  'updated_at': '2026-11-10T10:00:00Z',
};

/// Her istekte [deger]'i döndüren yanıt.
TayfaYaniti yanit(Object? deger) =>
    (_) => deger;

/// Şikâyet ve tayfa uçlarını [tasima]'ya bağlayan override'lar; oturum
/// açık, adlar sabit. Gerçek ağ yok.
List<Override> sikayetOverridelari(SahteTayfaTasima tasima) => [
  ...tayfaOverridelari(tasima: tasima),
  sikayetDeposuProvider.overrideWithValue(SikayetDeposu(tasima)),
  profilOkuyucuProvider.overrideWithValue(
    (id) async => KullaniciAdi(id == moderatorId ? 'Moderatör' : 'Üye Kişi'),
  ),
  oturumDurumuProvider.overrideWith(() => SabitOturumDurumu(OturumDurumu.acik)),
];
