import 'package:flutter/widgets.dart' hide Notification;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/features/bildirim/application/bildirim_gruplari.dart';
import 'package:tayfam/features/bildirim/application/bildirim_hedefi.dart';
import 'package:tayfam/features/bildirim/presentation/bildirim_satiri.dart';
import 'package:tayfam/l10n/app_localizations.dart';

import 'sahteler.dart';

Notification _bildirim(
  String id, {
  String tur = 'event_created',
  String? tayfaId = bildirimTayfaId,
  String? aktor,
  String hedefTuru = 'event',
  String hedef = hedefId,
  String? yuruyuscu,
  bool okundu = false,
  DateTime? zaman,
}) => Notification.fromJson(
  bildirimJson(
    id,
    tur: tur,
    tayfaId: tayfaId,
    aktor: aktor,
    hedefTuru: hedefTuru,
    hedef: hedef,
    yuruyuscu: yuruyuscu,
    okundu: okundu,
    zaman: (zaman ?? DateTime.utc(2026, 11, 10, 10)).toUtc().toIso8601String(),
  ),
);

void main() {
  late AppLocalizations m;

  setUpAll(() async {
    await initializeDateFormatting('tr');
    m = await AppLocalizations.delegate.load(const Locale('tr', 'TR'));
  });

  // Yerel saatle kurulur: hesap cihazın saat diliminde, takvim gününe göre.
  // simdi: 13 Kasım 2026 Cuma, 15:00.
  final simdi = DateTime(2026, 11, 13, 15);

  group('bildirimGrubu', () {
    final ornekler = <String, (DateTime, BildirimGrubu)>{
      'bugün sabah': (DateTime(2026, 11, 13, 0, 5), BildirimGrubu.bugun),
      'gelecek (saat kayması)': (
        simdi.add(const Duration(minutes: 2)),
        BildirimGrubu.bugun,
      ),
      'dün gece yarısından hemen önce': (
        DateTime(2026, 11, 12, 23, 59),
        BildirimGrubu.dun,
      ),
      'dün sabah': (DateTime(2026, 11, 12, 0, 1), BildirimGrubu.dun),
      'iki gün önce': (DateTime(2026, 11, 11, 22), BildirimGrubu.buHafta),
      'altı gün önce': (DateTime(2026, 11, 7, 9), BildirimGrubu.buHafta),
      'yedi gün önce': (DateTime(2026, 11, 6, 23), BildirimGrubu.dahaEski),
      'geçen yıl': (DateTime(2025, 12, 30), BildirimGrubu.dahaEski),
    };
    for (final MapEntry(key: ad, value: (an, grup)) in ornekler.entries) {
      test(ad, () => expect(bildirimGrubu(an, simdi), grup));
    }
  });

  group('bildirimZamani', () {
    test('bugün ve dün saat', () {
      expect(bildirimZamani(m, DateTime(2026, 11, 13, 14, 32), simdi), '14:32');
      expect(bildirimZamani(m, DateTime(2026, 11, 12, 21, 40), simdi), '21:40');
    });

    test('bu hafta gün adı; büyük harfe çevrilmez', () {
      expect(bildirimZamani(m, DateTime(2026, 11, 10, 12), simdi), 'Salı');
      expect(bildirimZamani(m, DateTime(2026, 11, 9, 12), simdi), 'Pazartesi');
    });

    test('daha eskisi gün ve ay; başka yılsa yılla', () {
      expect(bildirimZamani(m, DateTime(2026, 11, 3, 10), simdi), '3 Kas');
      expect(
        bildirimZamani(m, DateTime(2025, 12, 30, 10), simdi),
        allOf(contains('2025'), contains('30')),
      );
    });

    test('grup başlıkları çeviri dosyasından', () {
      expect(bildirimGrubuBasligi(m, BildirimGrubu.bugun), 'Bugün');
      expect(bildirimGrubuBasligi(m, BildirimGrubu.dun), 'Dün');
      expect(bildirimGrubuBasligi(m, BildirimGrubu.buHafta), 'Bu hafta');
      expect(bildirimGrubuBasligi(m, BildirimGrubu.dahaEski), 'Daha eski');
    });
  });

  group('bildirimleriGrupla', () {
    test('gruplar sırayla, boş grup yok, grup içinde sıra korunur', () {
      final bildirimler = [
        _bildirim(bildirimId1, zaman: DateTime(2026, 11, 13, 14)),
        _bildirim(bildirimId2, zaman: DateTime(2026, 11, 13, 9)),
        _bildirim(bildirimId3, zaman: DateTime(2026, 11, 1, 9)),
      ];
      final gruplar = bildirimleriGrupla(bildirimler, simdi);
      expect(
        [for (final (grup, _) in gruplar) grup],
        [BildirimGrubu.bugun, BildirimGrubu.dahaEski],
      );
      expect(
        [for (final b in gruplar.first.$2) b.id],
        [bildirimId1, bildirimId2],
      );
      expect(gruplar.last.$2.single.id, bildirimId3);
    });

    test('sırasız gelse de gruplar Bugün → Daha eski', () {
      final gruplar = bildirimleriGrupla([
        _bildirim(bildirimId1, zaman: DateTime(2026, 11, 1, 9)),
        _bildirim(bildirimId2, zaman: DateTime(2026, 11, 12, 9)),
      ], simdi);
      expect(
        [for (final (grup, _) in gruplar) grup],
        [BildirimGrubu.dun, BildirimGrubu.dahaEski],
      );
    });

    test('boş liste boş grup', () {
      expect(bildirimleriGrupla(const [], simdi), isEmpty);
    });
  });

  group('satır içi işlem ve sabit uyarı', () {
    test('arkadaşlık isteği, davet ve katılım isteği', () {
      expect(
        satirIciIslem(
          _bildirim(
            bildirimId1,
            tur: 'friend_request',
            tayfaId: null,
            hedefTuru: 'user',
            hedef: kisiId,
          ),
        ),
        SatirIciIslem.arkadaslik,
      );
      final davet = _bildirim(
        bildirimId2,
        tur: 'tayfa_invitation',
        tayfaId: null,
        aktor: kisiId,
        hedefTuru: 'tayfa',
        hedef: bildirimTayfaId,
      );
      expect(satirIciIslem(davet), SatirIciIslem.davet);
      expect(davetTayfasi(davet), bildirimTayfaId);
      final katilim = _bildirim(
        bildirimId3,
        tur: 'join_request',
        hedefTuru: 'membership',
        hedef: kisiId,
      );
      expect(satirIciIslem(katilim), SatirIciIslem.katilimIstegi);
      expect(
        katilimIstekleriAdresi(katilim),
        '/t/$bildirimTayfaId/ayarlar/istekler',
      );
    });

    test('kimlik doğrulanamazsa işlem yok', () {
      expect(
        satirIciIslem(
          _bildirim(
            bildirimId1,
            tur: 'friend_request',
            tayfaId: null,
            hedefTuru: 'user',
            hedef: 'kimlik-degil',
          ),
        ),
        isNull,
      );
      expect(
        satirIciIslem(
          _bildirim(
            bildirimId2,
            tur: 'tayfa_invitation',
            tayfaId: null,
            hedefTuru: 'tayfa',
            hedef: '../../v1/me',
          ),
        ),
        isNull,
      );
      expect(satirIciIslem(_bildirim(bildirimId3)), isNull);
    });

    test('okunmamış hike_overdue sabit; okununca listeye döner', () {
      final uyari = _bildirim(
        bildirimId1,
        tur: 'hike_overdue',
        yuruyuscu: kisiId,
      );
      expect(sabitUyariMi(uyari), isTrue);
      expect(uyariEtkinligi(uyari), (
        tayfaId: bildirimTayfaId,
        etkinlikId: hedefId,
      ));
      final okunmus = _bildirim(
        bildirimId2,
        tur: 'hike_overdue',
        yuruyuscu: kisiId,
        okundu: true,
      );
      expect(sabitUyariMi(okunmus), isFalse);
      expect(sabitUyariMi(_bildirim(bildirimId3)), isFalse);
    });
  });

  group('kesin kural 7', () {
    test('DM bildiriminde gönderen yok: kişi istenmez, metin türden', () {
      for (final tur in ['dm_request', 'dm_message']) {
        final dm = _bildirim(
          bildirimId1,
          tur: tur,
          tayfaId: null,
          aktor: kisiId,
          hedefTuru: 'dm_conversation',
        );
        expect(bildirimKisisi(dm), isNull);
        final metin = bildirimMetni(m, dm, kisi: 'Ayşe');
        expect(metin, isNot(contains('Ayşe')));
        expect(satirIciIslem(dm), isNull);
      }
    });

    test('kategori renkleri: mesaj turkuaz, arkadaşlık mavi, uyarı nar', () {
      expect(
        bildirimKategorisi(NotificationType.dmMessage),
        BildirimKategorisi.mesaj,
      );
      expect(
        bildirimKategorisi(NotificationType.tayfaInvitation),
        BildirimKategorisi.arkadaslik,
      );
      expect(
        bildirimKategorisi(NotificationType.hikeOverdue),
        BildirimKategorisi.uyari,
      );
      expect(
        bildirimKategorisi(NotificationType.eventCreated),
        BildirimKategorisi.etkinlik,
      );
      expect(
        bildirimKategorisi(NotificationType.announcement),
        BildirimKategorisi.marka,
      );
    });
  });
}
