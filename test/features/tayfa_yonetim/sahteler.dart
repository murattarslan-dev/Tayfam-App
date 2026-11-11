import 'package:flutter_riverpod/misc.dart';

import 'package:tayfam/core/api/gen/apis/users_api.dart';
import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/core/moduller/tayfa_ust_menusu.dart';
import 'package:tayfam/core/oturum/oturum_durumu.dart';
import 'package:tayfam/features/tayfa_yonetim/application/uyeler_notifier.dart';
import 'package:tayfam/features/tayfa_yonetim/data/yonetim_deposu.dart';
import 'package:tayfam/features/tayfa_yonetim/tayfa_yonetim.dart';

import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';

/// Testlerde kullanılan, biçimi geçerli örnek kullanıcı kimlikleri.
const String benimId = '00000000-0000-4000-8000-0000000000aa';
const String uyeId1 = '00000000-0000-4000-8000-000000000001';
const String uyeId2 = '00000000-0000-4000-8000-000000000002';
const String uyeId3 = '00000000-0000-4000-8000-000000000003';
const String davetId1 = '3c4d5e6f-0000-4000-8000-000000000001';

/// Sahte davet token'ı (43 karakter base64url biçiminde; gerçek değil).
const String sahteDavetTokeni = 'ornekTokenOrnekTokenOrnekTokenOrnekToken-_0';

/// Testlerin sabit "şimdi"si.
final DateTime sabitSimdi = DateTime.utc(2026, 11, 11, 12);

/// Uç yolları (sahte taşımanın anahtarları).
const String tayfaYolu = '/v1/tayfas/{tayfa_id}';
const String uyelerYolu = '/v1/tayfas/{tayfa_id}/members';
const String uyeYolu = '/v1/tayfas/{tayfa_id}/members/{user_id}';
const String susturmaYolu = '/v1/tayfas/{tayfa_id}/members/{user_id}/mute';
const String banYolu = '/v1/tayfas/{tayfa_id}/members/{user_id}/ban';
const String isteklerYolu = '/v1/tayfas/{tayfa_id}/join-requests';
const String istekYolu = '/v1/tayfas/{tayfa_id}/join-requests/{user_id}';
const String onayYolu =
    '/v1/tayfas/{tayfa_id}/join-requests/{user_id}/approval';
const String davetlerYolu = '/v1/tayfas/{tayfa_id}/invites';
const String davetYolu = '/v1/tayfas/{tayfa_id}/invites/{invite_id}';
const String modulYolu = '/v1/tayfas/{tayfa_id}/modules/{module}';
const String kodYolu = '/v1/tayfas/{tayfa_id}/join-code';
const String silmeYolu = '/v1/tayfas/{tayfa_id}/deletion';
const String uyelikYolu = '/v1/tayfas/{tayfa_id}/membership';
const String tercihlerYolu = '/v1/notification-preferences';
const String tercihYolu = '/v1/notification-preferences/tayfas/{tayfa_id}';
const String profilYolu = '/v1/users/{user_id}/profile';

/// `Membership` JSON'u.
Map<String, Object?> uyeJson(
  String kullanici, {
  String rol = 'member',
  String durum = 'active',
  String? susturma,
}) => {
  'tayfa_id': ornekTayfaId,
  'user_id': kullanici,
  'role': rol,
  'status': durum,
  'joined_at': '2026-11-01T10:00:00Z',
  'muted_until': ?susturma,
};

/// `GET …/members` yanıtı.
Map<String, Object?> uyeListesiJson(
  List<Map<String, Object?>> uyeler, {
  String? sonraki,
}) => {'members': uyeler, 'next_page_token': ?sonraki};

/// `JoinRequest` JSON'u.
Map<String, Object?> istekJson(
  String kullanici, {
  String kaynak = 'code',
  String? davetEden,
}) => {
  'user_id': kullanici,
  'requested_at': '2026-11-10T09:00:00Z',
  'source': kaynak,
  'inviter_user_id': ?davetEden,
};

/// `GET …/join-requests` yanıtı.
Map<String, Object?> istekListesiJson(
  List<Map<String, Object?>> istekler, {
  String? sonraki,
}) => {'join_requests': istekler, 'next_page_token': ?sonraki};

/// `Invite` JSON'u.
Map<String, Object?> davetJson(String id, {int kullanilan = 2}) => {
  'id': id,
  'tayfa_id': ornekTayfaId,
  'created_by_user_id': uyeId1,
  'created_at': '2026-11-10T09:00:00Z',
  'expires_at': '2026-11-17T09:00:00Z',
  'max_uses': 10,
  'use_count': kullanilan,
};

/// `NotificationPreference` JSON'u.
Map<String, Object?> tercihJson({
  String seviye = 'none',
  String? bitis,
  String tayfa = ornekTayfaId,
}) => {
  'scope_type': 'tayfa',
  'scope_id': tayfa,
  'level': seviye,
  'mute_until': ?bitis,
  'updated_at': '2026-11-10T09:00:00Z',
};

/// Kullanıcı profili JSON'u; [benimId] kendisidir.
Map<String, Object?> profilJson(String id) => {
  'user_id': id,
  'display_name': id == benimId ? 'Ben' : 'Kişi ${id.substring(id.length - 1)}',
  'self': id == benimId,
  'mutual_tayfas': <Object?>[],
  'activity_visible': false,
};

/// [rol]'deki kullanıcı için tayfa görünümü; [kod] ve [silinme] verilebilir.
Map<String, Object?> yonetimGorunumu({
  String rol = 'admin',
  String? kod,
  String? silinme,
}) => gorunumJson(ornekTayfaId, rol: rol, kod: kod, silinme: silinme);

/// Varsayılan yanıtlarla sahte taşıma: [rol] görünümü, boş listeler, profil,
/// sessiz olmayan tercih.
SahteTayfaTasima yonetimTasimasi({
  String rol = 'admin',
  Map<String, TayfaYaniti>? yanitlar,
}) {
  final tasima = SahteTayfaTasima(yanitlar);
  tasima.yanitlar
    ..putIfAbsent('GET $tayfaYolu', () => yanit(yonetimGorunumu(rol: rol)))
    ..putIfAbsent('GET $uyelerYolu', () => yanit(uyeListesiJson([])))
    ..putIfAbsent('GET $isteklerYolu', () => yanit(istekListesiJson([])))
    ..putIfAbsent('GET $davetlerYolu', () => yanit({'invites': <Object?>[]}))
    ..putIfAbsent(
      'GET $tercihlerYolu',
      () => yanit({'preferences': <Object?>[]}),
    )
    ..putIfAbsent(
      'GET $profilYolu',
      () =>
          (i) => profilJson(i.yolParametreleri['user_id']!),
    );
  return tasima;
}

/// Her istekte [deger]'i döndüren yanıt.
TayfaYaniti yanit(Object? deger) =>
    (_) => deger;

/// Tayfa ve yönetim uçlarını [tasima]'ya bağlayan override'lar; oturum
/// açık, saat sabit, tayfa üst menüsü kayıtlı. Gerçek ağ yok.
List<Override> yonetimOverridelari(
  SahteTayfaTasima tasima, {
  SahtePaylasici? paylasici,
}) => [
  ...tayfaOverridelari(tasima: tasima, paylasici: paylasici),
  yonetimDeposuProvider.overrideWithValue(YonetimDeposu(tasima)),
  profilOkuyucuProvider.overrideWithValue((id) async {
    final profil = await UsersApi(tasima).getUserProfile(userId: id);
    return KullaniciAdi(profil.displayName, ben: profil.self);
  }),
  saatProvider.overrideWithValue(() => sabitSimdi),
  tayfaUstMenusuProvider.overrideWithValue(tayfaUstMenusu),
  oturumDurumuProvider.overrideWith(() => SabitOturumDurumu(OturumDurumu.acik)),
];
