import 'package:flutter_riverpod/misc.dart';

import 'package:tayfam/core/kullanici/kullanici_adlari.dart';
import 'package:tayfam/features/bildirim/data/bildirim_deposu.dart';

import '../tayfa/sahteler.dart';

/// Bildirim uçlarının yol şablonları (sahte taşımanın anahtarları).
const String bildirimlerYolu = '/v1/notifications';
const String okunmamisYolu = '/v1/notifications/unread-count';
const String hepsiOkunduYolu = '/v1/notifications/read-all';
const String okunduYolu = '/v1/notifications/{notification_id}/read';

/// Testlerde kullanılan, biçimi geçerli örnek kimlikler.
const String bildirimId1 = '3c4d5e6f-0000-4000-8000-000000000001';
const String bildirimId2 = '3c4d5e6f-0000-4000-8000-000000000002';
const String bildirimId3 = '3c4d5e6f-0000-4000-8000-000000000003';
const String hedefId = '4d5e6f70-0000-4000-8000-000000000001';
const String kisiId = '5e6f7081-0000-4000-8000-000000000001';
const String bildirimTayfaId = '0b8f6a52-3c1d-4e7a-9f20-6d5b4c3a2e10';

/// Örnek bildirim (`Notification`) JSON'u.
Map<String, Object?> bildirimJson(
  String id, {
  String tur = 'event_created',
  String? tayfaId = bildirimTayfaId,
  String? aktor,
  String hedefTuru = 'event',
  String hedef = hedefId,
  String? soru,
  String? yuruyuscu,
  String? uyari,
  int? sayi,
  bool okundu = false,
  String zaman = '2026-11-10T10:00:00Z',
}) => {
  'id': id,
  'type': tur,
  'tayfa_id': ?tayfaId,
  'actor_id': ?aktor,
  'target_type': hedefTuru,
  'target_id': hedef,
  'question_id': ?soru,
  'subject_user_id': ?yuruyuscu,
  'warning_reason': ?uyari,
  'unread_count': ?sayi,
  'read': okundu,
  'created_at': zaman,
};

/// `GET /v1/notifications` yanıtı.
Map<String, Object?> bildirimListesiJson(
  List<Map<String, Object?>> bildirimler, {
  String? sonraki,
}) => {'notifications': bildirimler, 'next_page_token': ?sonraki};

/// `GET /v1/notifications/unread-count` yanıtı.
Map<String, Object?> okunmamisJson(int sayi) => {'unread_count': sayi};

/// Bildirim deposunun sahte taşımalı override'ı. Yanıt verilmezse liste
/// boş, okunmamış sayısı 0 ve okundu işaretleme uçları başarılıdır.
List<Override> bildirimOverridelari({SahteTayfaTasima? tasima}) {
  final t = tasima ?? SahteTayfaTasima();
  t.yanitlar
    ..putIfAbsent(
      'GET $bildirimlerYolu',
      () =>
          (_) => bildirimListesiJson(const []),
    )
    ..putIfAbsent(
      'GET $okunmamisYolu',
      () =>
          (_) => okunmamisJson(0),
    )
    ..putIfAbsent(
      'PUT $okunduYolu',
      () =>
          (_) => null,
    )
    ..putIfAbsent(
      'POST $hepsiOkunduYolu',
      () =>
          (_) => null,
    );
  return [bildirimDeposuProvider.overrideWithValue(BildirimDeposu(t))];
}

/// Profil ucunun sahtesi: [adlar]'daki kimlikler için ad döner; istenen
/// kimlikleri [istenen]'e yazar.
Override profilSahtesi(Map<String, String> adlar, {List<String>? istenen}) =>
    profilOkuyucuProvider.overrideWithValue((id) async {
      istenen?.add(id);
      final ad = adlar[id];
      if (ad == null) return const KullaniciAdi.silinmis();
      return KullaniciAdi(ad);
    });
