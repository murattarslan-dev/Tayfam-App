import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/gen/models.dart' as api;
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/features/bildirim/application/bildirim_hedefi.dart';
import 'package:tayfam/features/bildirim/presentation/bildirim_satiri.dart';
import 'package:tayfam/l10n/app_localizations.dart';

import 'sahteler.dart';

api.Notification _bildirim({
  String tur = 'event_created',
  String? tayfaId = bildirimTayfaId,
  String hedefTuru = 'event',
  String hedef = hedefId,
  String? aktor,
  String? yuruyuscu,
  String? cozum,
}) => api.Notification.fromJson(
  bildirimJson(
    bildirimId1,
    tur: tur,
    tayfaId: tayfaId,
    hedefTuru: hedefTuru,
    hedef: hedef,
    aktor: aktor,
    yuruyuscu: yuruyuscu,
    cozum: cozum,
  ),
);

api.Notification _oneri({String? cozum = 'pending', String hedef = kisiId}) =>
    _bildirim(
      tur: 'friend_suggestion',
      tayfaId: null,
      hedefTuru: 'user',
      hedef: hedef,
      cozum: cozum,
    );

void main() {
  group('bildirimAdresi', () {
    test('etkinlik hedefi etkinliğin detayını açıyor', () {
      expect(
        bildirimAdresi(_bildirim()),
        Adresler.etkinlik(bildirimTayfaId, hedefId),
      );
      expect(
        bildirimAdresi(_bildirim(tur: 'event_cancelled')),
        Adresler.etkinlik(bildirimTayfaId, hedefId),
      );
    });

    test('duyuru hedefi duyurunun ekranını açıyor', () {
      expect(
        bildirimAdresi(
          _bildirim(tur: 'announcement', hedefTuru: 'announcement'),
        ),
        Adresler.duyuru(bildirimTayfaId, hedefId),
      );
    });

    test('ekranı olmayan hedef tayfanın ana sayfasını açıyor', () {
      for (final (tur, hedefTuru) in [
        ('answer_received', 'answer'),
        ('join_request', 'membership'),
        ('tayfa_archived', 'tayfa'),
        ('gelecekte_eklenecek_tur', 'gelecekte_eklenecek_hedef'),
      ]) {
        expect(
          bildirimAdresi(_bildirim(tur: tur, hedefTuru: hedefTuru)),
          Adresler.tayfa(bildirimTayfaId),
          reason: tur,
        );
      }
    });

    test('tayfaya bağlı olmayan bildirimde adres yok', () {
      expect(
        bildirimAdresi(
          _bildirim(tur: 'dm_message', tayfaId: null, hedefTuru: 'user'),
        ),
        isNull,
      );
    });

    test('birebir mesaj bildirimi konuşmayı açıyor', () {
      expect(
        bildirimAdresi(
          _bildirim(
            tur: 'dm_message',
            tayfaId: null,
            hedefTuru: 'dm_conversation',
          ),
        ),
        Adresler.birebirKonusma(hedefId),
      );
    });

    test('arkadaşlık bildirimi kişinin profilini açıyor', () {
      for (final tur in ['friend_request', 'friend_accepted']) {
        expect(
          bildirimAdresi(_bildirim(tur: tur, tayfaId: null, hedefTuru: 'user')),
          Adresler.kisi(hedefId),
          reason: tur,
        );
      }
      expect(
        bildirimAdresi(
          _bildirim(
            tur: 'friend_request',
            tayfaId: null,
            hedefTuru: 'user',
            hedef: '../me',
          ),
        ),
        isNull,
      );
    });

    test('tayfa daveti gelen davetleri açıyor', () {
      expect(
        bildirimAdresi(_bildirim(tur: 'tayfa_invitation', hedefTuru: 'tayfa')),
        Adresler.tayfaDavetleri,
      );
    });

    test('biçimi bozuk kimlik kullanılmıyor', () {
      expect(
        bildirimAdresi(_bildirim(hedef: '../../profil')),
        Adresler.tayfa(bildirimTayfaId),
      );
      expect(bildirimAdresi(_bildirim(tayfaId: 'gecersiz/../x')), isNull);
    });
  });

  group('bildirimKisisi', () {
    test('kişi adı yalnızca ilgili türlerde', () {
      expect(
        bildirimKisisi(
          _bildirim(
            tur: 'join_request',
            hedefTuru: 'membership',
            hedef: kisiId,
          ),
        ),
        kisiId,
      );
      expect(
        bildirimKisisi(
          _bildirim(
            tur: 'friend_request',
            tayfaId: null,
            hedefTuru: 'user',
            hedef: kisiId,
          ),
        ),
        kisiId,
      );
      expect(
        bildirimKisisi(_bildirim(tur: 'hike_overdue', yuruyuscu: kisiId)),
        kisiId,
      );
      expect(
        bildirimKisisi(
          _bildirim(tur: 'tayfa_invitation', hedefTuru: 'tayfa', aktor: kisiId),
        ),
        kisiId,
      );
      expect(bildirimKisisi(_bildirim(aktor: kisiId)), isNull);
    });

    test('birebir mesajda gönderen hiçbir zaman kullanılmıyor', () {
      for (final tur in ['dm_request', 'dm_message']) {
        expect(
          bildirimKisisi(
            _bildirim(
              tur: tur,
              tayfaId: null,
              hedefTuru: 'dm_conversation',
              aktor: kisiId,
            ),
          ),
          isNull,
          reason: tur,
        );
      }
    });
  });

  group('arkadaş önerisi (friend_suggestion)', () {
    test('önerilen kişinin profilini açıyor; kişi target_id', () {
      expect(bildirimAdresi(_oneri()), Adresler.kisi(kisiId));
      expect(bildirimKisisi(_oneri()), kisiId);
    });

    test('yalnızca pending iken görünür ve satır içi işlemi var', () {
      expect(bildirimGorunurMu(_oneri()), isTrue);
      expect(satirIciIslem(_oneri()), SatirIciIslem.oneri);
      for (final cozum in [
        'accepted',
        'declined',
        'withdrawn',
        'expired',
        'gelecekte_eklenecek',
        null,
      ]) {
        final bildirim = _oneri(cozum: cozum);
        expect(bildirimGorunurMu(bildirim), isFalse, reason: '$cozum');
        expect(satirIciIslem(bildirim), isNull, reason: '$cozum');
      }
    });

    test('biçimsiz kimlikte işlem ve adres yok', () {
      final bildirim = _oneri(hedef: 'kimlik-degil');
      expect(bildirimKisisi(bildirim), isNull);
      expect(satirIciIslem(bildirim), isNull);
      expect(bildirimAdresi(bildirim), isNull);
    });

    test('öteki türler durumdan bağımsız görünür', () {
      expect(bildirimGorunurMu(_bildirim()), isTrue);
      expect(
        bildirimGorunurMu(
          _bildirim(
            tur: 'friend_request',
            tayfaId: null,
            hedefTuru: 'user',
            hedef: kisiId,
            cozum: 'accepted',
          ),
        ),
        isTrue,
      );
    });
  });

  group('güvenlik kişisi alarmı (safety_alert)', () {
    api.Notification alarm({bool okundu = false}) => api.Notification.fromJson(
      bildirimJson(
        bildirimId1,
        tur: 'safety_alert',
        tayfaId: null,
        hedefTuru: 'user',
        hedef: kisiId,
        okundu: okundu,
      ),
    );

    test('paylaşımlar ekranını açıyor; kişi target_id', () {
      expect(bildirimAdresi(alarm()), Adresler.guvenlikPaylasimlari);
      expect(bildirimKisisi(alarm()), kisiId);
    });

    test('okunmamışken sabit uyarı; okununca listedeki yerine döner', () {
      expect(sabitUyariMi(alarm()), isTrue);
      expect(sabitUyariMi(alarm(okundu: true)), isFalse);
      // Etkinlik bilgisi yoktur (güvenlik kişisi etkinliği görmez).
      expect(uyariEtkinligi(alarm()), isNull);
    });
  });

  group('rozet (badge_earned)', () {
    final kisisel = _bildirim(
      tur: 'badge_earned',
      tayfaId: null,
      hedefTuru: 'user',
      hedef: kisiId,
    );
    final tayfaRozeti = _bildirim(
      tur: 'badge_earned',
      hedefTuru: 'tayfa',
      hedef: bildirimTayfaId,
    );

    test('kişisel rozet profili, tayfa rozeti tayfayı açıyor', () {
      expect(kisisel.type, api.NotificationType.badgeEarned);
      expect(bildirimAdresi(kisisel), Adresler.kisi(kisiId));
      expect(bildirimAdresi(tayfaRozeti), Adresler.tayfa(bildirimTayfaId));
      expect(bildirimKisisi(kisisel), isNull);
    });

    test('biçimsiz hedef kimliği kullanılmıyor', () {
      expect(
        bildirimAdresi(
          _bildirim(
            tur: 'badge_earned',
            tayfaId: null,
            hedefTuru: 'user',
            hedef: '../v1/me',
          ),
        ),
        isNull,
      );
    });

    test('metin rozeti ve içeriği adlandırmıyor', () {
      final m = lookupAppLocalizations(const Locale('tr'));
      expect(bildirimMetni(m, kisisel, kisi: 'Ayşe'), m.rozet_bildirim);
      expect(bildirimMetni(m, tayfaRozeti, kisi: 'Ayşe'), m.rozet_bildirim_tayfa);
      expect(bildirimKategorisi(kisisel.type), BildirimKategorisi.etkinlik);
      expect(bildirimIkonu(kisisel.type), Icons.military_tech_outlined);
    });
  });

  group('kutlama (celebration)', () {
    final kutlama = _bildirim(tur: 'celebration', aktor: kisiId);

    test('etkinliğin detayını açıyor; kişi adı kullanılmıyor', () {
      expect(kutlama.type, api.NotificationType.celebration);
      expect(
        bildirimAdresi(kutlama),
        Adresler.etkinlik(bildirimTayfaId, hedefId),
      );
      expect(bildirimKisisi(kutlama), isNull);
    });

    test('metin kazananı ve içeriği adlandırmıyor', () {
      final m = lookupAppLocalizations(const Locale('tr'));
      expect(
        bildirimMetni(m, kutlama, kisi: 'Ayşe'),
        m.bilesen_celebration_bildirim,
      );
      expect(bildirimKategorisi(kutlama.type), BildirimKategorisi.etkinlik);
    });
  });
}
