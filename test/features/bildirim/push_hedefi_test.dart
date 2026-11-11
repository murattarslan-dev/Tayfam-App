import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/features/bildirim/application/push_hedefi.dart';

import '../../../tool/kurallar/kurallar.dart';

const String _bildirim = '6f1d2c3b-4a59-4e68-9d7c-8b6a5f4e3d21';
const String _tayfa = '0b8f6a52-3c1d-4e7a-9f20-6d5b4c3a2e10';
const String _hedef = 'c4d3e2f1-0a9b-4c8d-8e7f-6a5b4c3d2e1f';

void main() {
  final simdi = DateTime.utc(2026, 11, 11, 18);

  group('pushBildirimi (data doğrulama)', () {
    test('etkinlik: alanlar okunur, hedefi etkinlik ekranıdır', () {
      final b = pushBildirimi({
        'notification_id': _bildirim,
        'type': 'event_created',
        'target_type': 'event',
        'target_id': _hedef,
        'tayfa_id': _tayfa,
      }, simdi: simdi);
      expect(b, isNotNull);
      expect(b!.id, _bildirim);
      expect(b.type, NotificationType.eventCreated);
      expect(b.read, isFalse);
      expect(pushAdresi(b), Adresler.etkinlik(_tayfa, _hedef));
    });

    test('birebir mesaj: konuşma açılır (tayfa ve gönderen yok)', () {
      final b = pushBildirimi({
        'notification_id': _bildirim,
        'type': 'dm_message',
        'target_type': 'dm_conversation',
        'target_id': _hedef,
      }, simdi: simdi);
      expect(pushAdresi(b), Adresler.birebirKonusma(_hedef));
    });

    test('tayfa uyarısı: neden okunur, tayfa açılır', () {
      final b = pushBildirimi({
        'notification_id': _bildirim,
        'type': 'tayfa_warned',
        'target_type': 'tayfa',
        'target_id': _tayfa,
        'tayfa_id': _tayfa,
        'reason': 'inactive',
      }, simdi: simdi);
      expect(b!.warningReason, NotificationWarningReason.inactive);
      expect(pushAdresi(b), Adresler.tayfa(_tayfa));
    });

    test('hedefin ekranı yoksa Bildirimler sekmesi', () {
      final b = pushBildirimi({
        'notification_id': _bildirim,
        'type': 'data_export_ready',
        'target_type': 'data_export',
        'target_id': _hedef,
      }, simdi: simdi);
      expect(b, isNotNull);
      expect(pushAdresi(b), Adresler.bildirimler);
    });

    final gecersizler = <String, Map<String, String>>{
      'kimlik UUID değil': {
        'notification_id': '../../profil',
        'type': 'announcement',
        'target_type': 'announcement',
        'target_id': _hedef,
        'tayfa_id': _tayfa,
      },
      'hedef kimliği yok': {
        'notification_id': _bildirim,
        'type': 'announcement',
        'target_type': 'announcement',
        'tayfa_id': _tayfa,
      },
      'bilinmeyen tür': {
        'notification_id': _bildirim,
        'type': 'yeni_tur',
        'target_type': 'event',
        'target_id': _hedef,
      },
      'bilinmeyen hedef türü': {
        'notification_id': _bildirim,
        'type': 'event_created',
        'target_type': 'baska',
        'target_id': _hedef,
      },
      'tayfa kimliği biçimsiz': {
        'notification_id': _bildirim,
        'type': 'event_created',
        'target_type': 'event',
        'target_id': _hedef,
        'tayfa_id': 'https://kotu.example/t',
      },
    };
    for (final MapEntry(key: ad, value: veri) in gecersizler.entries) {
      test('geçersiz veri ($ad): null, Bildirimler sekmesi açılır', () {
        final b = pushBildirimi(veri, simdi: simdi);
        expect(b, isNull);
        expect(pushAdresi(b), Adresler.bildirimler);
      });
    }
  });

  group('push metinleri', () {
    final arb =
        jsonDecode(File('lib/l10n/app_tr.arb').readAsStringSync())
            as Map<String, Object?>;

    test('her bildirim türünün başlığı ve gövdesi ARB\'de', () {
      for (final tur in NotificationType.values) {
        if (tur == NotificationType.unknown) continue;
        expect(arb['push_${tur.wire}_title'], isA<String>(), reason: tur.wire);
        expect(arb['push_${tur.wire}_body'], isA<String>(), reason: tur.wire);
      }
    });

    test('birebir mesaj metinleri içeriksiz ve genel', () {
      expect(arb['push_dm_message_title'], 'Yeni mesaj');
      expect(arb['push_dm_request_title'], 'Yeni mesaj isteği');
      for (final anahtar in arb.keys) {
        if (!androidMetinAnahtari.hasMatch(anahtar)) continue;
        // Çeviri argümanı yoktur (Tayfam-Api ADR-0019 §4).
        expect(arb[anahtar], isNot(contains('{')), reason: anahtar);
      }
    });

    test('strings.xml ARB\'den üretilenle aynı', () {
      final arbMetni = File('lib/l10n/app_tr.arb').readAsStringSync();
      final mevcut = File(androidMetinDosyasi).readAsStringSync();
      expect(mevcut, androidMetinleriniUret(arbMetni));
    });

    test('Android kaçırması', () {
      expect(
        androidKacir("Ali'nin \"x\" & <y>"),
        'Ali\\\'nin \\"x\\" &amp; &lt;y&gt;',
      );
      expect(androidKacir('@ad ?'), r'\@ad ?');
    });
  });
}
