import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/gen/models.dart' as api;
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/features/bildirim/application/bildirim_hedefi.dart';
import 'package:tayfam/features/bildirim/application/push_hedefi.dart';
import 'package:tayfam/features/bildirim/presentation/bildirim_satiri.dart';
import 'package:tayfam/l10n/app_localizations.dart';

import 'sahteler.dart';

/// `now_started` bildirimi (Tayfam-Api ADR-0038 §4): organizatör
/// `actor_id`, hedef etkinlik, tayfa var.
api.Notification _simdi({String? tayfaId = bildirimTayfaId}) =>
    api.Notification.fromJson(
      bildirimJson(
        bildirimId1,
        tur: 'now_started',
        tayfaId: tayfaId,
        aktor: kisiId,
      ),
    );

api.MyTayfa _uyelik(String id, {String durum = 'active'}) =>
    api.MyTayfa.fromJson({
      'tayfa_id': id,
      'name': 'Tayfa',
      'kind': 'club',
      'role': 'member',
      'status': durum,
    });

void main() {
  final tr = lookupAppLocalizations(const Locale('tr'));
  final uye = etkinUyelik([_uyelik(bildirimTayfaId)])!;
  final uyeDegil = etkinUyelik(const [])!;
  final bekleyen = etkinUyelik([_uyelik(bildirimTayfaId, durum: 'pending')])!;

  group('now_started hedefi', () {
    test('üyesi olunan tayfada etkinliğin detayı açılır', () {
      expect(
        bildirimAdresi(_simdi(), etkinUyeMi: uye),
        Adresler.etkinlik(bildirimTayfaId, hedefId),
      );
      expect(satirIciIslem(_simdi(), etkinUyeMi: uye), isNull);
    });

    test('üyelik bilinmiyorsa etkinlik açılır, satır içi işlem yok', () {
      expect(
        bildirimAdresi(_simdi()),
        Adresler.etkinlik(bildirimTayfaId, hedefId),
      );
      expect(satirIciIslem(_simdi()), isNull);
      expect(etkinUyelik(null), isNull);
    });

    test('anlık etkinlik daveti: üye değilse davetler açılır ve "Katıl"', () {
      for (final sorgu in [uyeDegil, bekleyen]) {
        expect(
          bildirimAdresi(_simdi(), etkinUyeMi: sorgu),
          Adresler.tayfaDavetleri,
        );
        expect(simdiDavetiMi(_simdi(), etkinUyeMi: sorgu), isTrue);
        expect(satirIciIslem(_simdi(), etkinUyeMi: sorgu), SatirIciIslem.davet);
      }
      expect(davetTayfasi(_simdi()), bildirimTayfaId);
    });

    test('tayfası olmayan ya da biçimsiz bildirim davet sayılmaz', () {
      for (final b in [_simdi(tayfaId: null), _simdi(tayfaId: 'kotu')]) {
        expect(simdiDavetiMi(b, etkinUyeMi: uyeDegil), isFalse);
        expect(satirIciIslem(b, etkinUyeMi: uyeDegil), isNull);
        expect(davetTayfasi(b), isNull);
      }
    });

    test('push: üye değilse davetler, üyeyse etkinlik', () {
      expect(
        pushAdresi(_simdi(), etkinUyeMi: uyeDegil),
        Adresler.tayfaDavetleri,
      );
      expect(
        pushAdresi(_simdi(), etkinUyeMi: uye),
        Adresler.etkinlik(bildirimTayfaId, hedefId),
      );
    });
  });

  group('now_started metni', () {
    test('organizatörün adı; başlık, tür ve yer yok', () {
      expect(bildirimKisisi(_simdi()), kisiId);
      final metin = bildirimMetni(tr, _simdi(), kisi: 'Ayşe');
      expect(metin, tr.simdi_bildirim_satir('Ayşe'));
      expect(
        bildirimKategorisi(api.NotificationType.nowStarted),
        BildirimKategorisi.etkinlik,
      );
    });

    test('push metinleri içeriksiz ve argümansız', () {
      expect(tr.push_now_started_title, isNot(contains('{')));
      expect(tr.push_now_started_body, isNot(contains('{')));
    });
  });
}
