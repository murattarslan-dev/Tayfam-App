import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/gen/models.dart' as api;
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/features/bildirim/application/bildirim_hedefi.dart';

import 'sahteler.dart';

api.Notification _bildirim({
  String tur = 'event_created',
  String? tayfaId = bildirimTayfaId,
  String hedefTuru = 'event',
  String hedef = hedefId,
  String? aktor,
  String? yuruyuscu,
}) => api.Notification.fromJson(
  bildirimJson(
    bildirimId1,
    tur: tur,
    tayfaId: tayfaId,
    hedefTuru: hedefTuru,
    hedef: hedef,
    aktor: aktor,
    yuruyuscu: yuruyuscu,
  ),
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
      expect(
        bildirimAdresi(
          _bildirim(
            tur: 'dm_message',
            tayfaId: null,
            hedefTuru: 'dm_conversation',
          ),
        ),
        isNull,
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
}
