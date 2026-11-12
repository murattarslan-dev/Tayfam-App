import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/tayfa/aktif_tayfa.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/features/tayfa_yonetim/presentation/ayarlar_ekrani.dart';
import 'package:tayfam/features/tayfa_yonetim/presentation/bilgiler_ekrani.dart';
import 'package:tayfam/features/tayfa_yonetim/presentation/davetler_ekrani.dart';
import 'package:tayfam/features/tayfa_yonetim/presentation/katilim_istekleri_ekrani.dart';
import 'package:tayfam/features/tayfa_yonetim/presentation/uyeler_ekrani.dart';
import 'package:tayfam/features/tayfa_yonetim/presentation/yonetim_menusu.dart';

import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';
import 'sahteler.dart';

Future<void> _ac(
  WidgetTester tester,
  Widget ekran,
  SahteTayfaTasima tasima, {
  ThemeMode themeMode = ThemeMode.light,
  SahtePaylasici? paylasici,
}) => widgetAc(
  tester,
  ekran,
  themeMode: themeMode,
  tayfa: yonetimOverridelari(tasima, paylasici: paylasici),
);

/// Bütün uygulamayı [rol]'deki kullanıcının tek tayfasıyla açar.
Future<void> _uygulamayiAc(WidgetTester tester, SahteTayfaTasima tasima) async {
  await uygulamayiAc(tester, oturum: null, tayfa: yonetimOverridelari(tasima));
  tester.container().read(aktifTayfaIdProvider.notifier).sec(ornekTayfaId);
  await tester.pumpAndSettle();
}

SahteTayfaTasima _uygulamaTasimasi(
  String rol, [
  Map<String, TayfaYaniti>? yanitlar,
]) => yonetimTasimasi(
  rol: rol,
  yanitlar: {
    'GET /v1/tayfas': yanit(listeJson([etkinJson(ornekTayfaId, rol: rol)])),
    ...?yanitlar,
  },
);

final Finder _menu = find.byType(TayfaYonetimMenusu);

Future<void> _dokun(WidgetTester tester, Finder hedef) async {
  await tester.ensureVisible(hedef);
  await tester.pumpAndSettle();
  await tester.tap(hedef);
  await tester.pumpAndSettle();
}

bool _rozetGorunur(WidgetTester tester) => tester
    .widget<Badge>(find.descendant(of: _menu, matching: find.byType(Badge)))
    .isLabelVisible;

void main() {
  group('tayfa menüsü', () {
    testWidgets('üye: ayarlar yok; sessize al ve ayrıl var', (tester) async {
      ekranBoyutu(tester);
      await _uygulamayiAc(tester, _uygulamaTasimasi('member'));

      expect(_menu, findsOneWidget);
      expect(_rozetGorunur(tester), isFalse);
      await _dokun(tester, _menu);
      expect(find.text(arbMetni('yonetim_menu_ayarlar')), findsNothing);
      expect(find.text(arbMetni('yonetim_menu_sessize_al')), findsOneWidget);
      expect(find.text(arbMetni('yonetim_menu_ayril')), findsOneWidget);
      expect(find.text(arbMetni('sikayet_tayfa_menu')), findsOneWidget);
    });

    testWidgets('yönetici: bekleyen sayısı rozette, ayarlara gider', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = _uygulamaTasimasi('admin', {
        'GET $tayfaYolu': yanit(yonetimGorunumu(bekleyen: 3)),
      });
      await _uygulamayiAc(tester, tasima);

      expect(_rozetGorunur(tester), isTrue);
      expect(
        find.descendant(of: _menu, matching: find.text('3')),
        findsOneWidget,
      );
      // Sayı tayfa görünümünden gelir; istek listesi yoklanmaz.
      expect(tasima.giden('GET', isteklerYolu), isEmpty);
      await _dokun(tester, _menu);
      expect(find.text('3 bekleyen katılım isteği'), findsOneWidget);
      await _dokun(tester, find.text(arbMetni('yonetim_menu_ayarlar')));

      expect(find.byType(TayfaAyarlariEkrani), findsOneWidget);
    });

    testWidgets('yönetici: bekleyen 0 ise rozet yok', (tester) async {
      ekranBoyutu(tester);
      final tasima = _uygulamaTasimasi('admin', {
        'GET $tayfaYolu': yanit(yonetimGorunumu(bekleyen: 0)),
      });
      await _uygulamayiAc(tester, tasima);

      expect(_rozetGorunur(tester), isFalse);
      await _dokun(tester, _menu);
      expect(find.textContaining('bekleyen katılım isteği'), findsNothing);
    });

    testWidgets('üye bekleyen istekleri sormaz', (tester) async {
      ekranBoyutu(tester);
      final tasima = _uygulamaTasimasi('member');
      await _uygulamayiAc(tester, tasima);
      expect(tasima.giden('GET', isteklerYolu), isEmpty);
    });

    testWidgets('sessize al', (tester) async {
      ekranBoyutu(tester);
      final tasima = _uygulamaTasimasi('member', {
        'PUT $tercihYolu': yanit(tercihJson()),
      });
      await _uygulamayiAc(tester, tasima);

      await _dokun(tester, _menu);
      await _dokun(tester, find.text(arbMetni('yonetim_menu_sessize_al')));

      expect(tasima.giden('PUT', tercihYolu).single.govde, {'level': 'none'});
      expect(find.text(arbMetni('yonetim_sessize_alindi')), findsOneWidget);
      await _dokun(tester, _menu);
      expect(
        find.text(arbMetni('yonetim_menu_sessizden_cikar')),
        findsOneWidget,
      );
    });

    testWidgets('ayrıl: onaydan sonra üyelik silinir', (tester) async {
      ekranBoyutu(tester);
      var uye = true;
      final tasima = _uygulamaTasimasi('member', {
        'GET /v1/tayfas': (_) => listeJson([if (uye) etkinJson(ornekTayfaId)]),
        'DELETE $uyelikYolu': (_) {
          uye = false;
          return null;
        },
      });
      await _uygulamayiAc(tester, tasima);

      await _dokun(tester, _menu);
      await _dokun(tester, find.text(arbMetni('yonetim_menu_ayril')));
      expect(find.text(arbMetni('yonetim_ayril_baslik')), findsOneWidget);
      await _dokun(tester, find.text(arbMetni('yonetim_ayril_onayla')));

      expect(tasima.giden('DELETE', uyelikYolu), hasLength(1));
      expect(find.text(arbMetni('yonetim_ayrildin')), findsOneWidget);
      expect(find.byType(KarsilamaEkrani), findsOneWidget);
    });

    testWidgets('ayrılmaktan vazgeçince istek yok', (tester) async {
      ekranBoyutu(tester);
      final tasima = _uygulamaTasimasi('member');
      await _uygulamayiAc(tester, tasima);

      await _dokun(tester, _menu);
      await _dokun(tester, find.text(arbMetni('yonetim_menu_ayril')));
      await _dokun(tester, find.text(arbMetni('yonetim_vazgec')));

      expect(tasima.giden('DELETE', uyelikYolu), isEmpty);
    });
  });

  group('ayarlar', () {
    testWidgets('yönetici her bölümü görür', (tester) async {
      ekranBoyutu(tester, yukseklik: 2000);
      await _ac(
        tester,
        const TayfaAyarlariEkrani(tayfaId: ornekTayfaId),
        yonetimTasimasi(
          yanitlar: {'GET $tayfaYolu': yanit(yonetimGorunumu(kod: sahteKod))},
        ),
      );

      for (final anahtar in [
        'yonetim_istekler',
        'yonetim_uyeler',
        'yonetim_davetler',
        'yonetim_bilgiler',
        'yonetim_moduller',
        'yonetim_kod_baslik',
        'yonetim_silme_baslik',
      ]) {
        expect(find.text(arbMetni(anahtar)), findsWidgets, reason: anahtar);
      }
      expect(find.text('Tayfa kodu: $sahteKod'), findsOneWidget);
    });

    testWidgets('moderatör yalnızca istek, üye ve davetleri görür', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 2000);
      await _ac(
        tester,
        const TayfaAyarlariEkrani(tayfaId: ornekTayfaId),
        yonetimTasimasi(rol: 'moderator'),
      );

      expect(find.text(arbMetni('yonetim_istekler')), findsOneWidget);
      expect(find.text(arbMetni('yonetim_bilgiler')), findsNothing);
      expect(find.text(arbMetni('yonetim_moduller')), findsNothing);
      expect(find.text(arbMetni('yonetim_silme_baslik')), findsNothing);
    });

    testWidgets('modül kapatma', (tester) async {
      ekranBoyutu(tester, yukseklik: 2000);
      final tasima = yonetimTasimasi(yanitlar: {'PUT $modulYolu': yanit(null)});
      await _ac(
        tester,
        const TayfaAyarlariEkrani(tayfaId: ornekTayfaId),
        tasima,
      );

      await _dokun(
        tester,
        find.widgetWithText(SwitchListTile, arbMetni('yonetim_modul_anketler')),
      );

      final istek = tasima.giden('PUT', modulYolu).single;
      expect(istek.yolParametreleri['module'], 'polls');
      expect(istek.govde, {'enabled': false});
      expect(find.text(arbMetni('yonetim_modul_kapandi')), findsOneWidget);
      // Görünüm sunucudan yeniden okunur.
      expect(tasima.giden('GET', tayfaYolu), hasLength(2));
    });

    testWidgets('kod yenileme onaylıdır', (tester) async {
      ekranBoyutu(tester, yukseklik: 2000);
      final tasima = yonetimTasimasi(
        yanitlar: {
          'GET $tayfaYolu': yanit(yonetimGorunumu(kod: sahteKod)),
          'POST $kodYolu': yanit({'join_code': 'ABCD2345'}),
        },
      );
      await _ac(
        tester,
        const TayfaAyarlariEkrani(tayfaId: ornekTayfaId),
        tasima,
      );

      await _dokun(tester, find.text(arbMetni('yonetim_kod_yenile')));
      expect(
        find.text(arbMetni('yonetim_kod_yenile_aciklama')),
        findsOneWidget,
      );
      await _dokun(tester, find.text(arbMetni('yonetim_kod_yenile_onayla')));

      expect(tasima.giden('POST', kodYolu), hasLength(1));
      expect(find.text(arbMetni('yonetim_kod_yenilendi')), findsOneWidget);
    });

    testWidgets('silme başlatma ve iptal', (tester) async {
      ekranBoyutu(tester, yukseklik: 2000);
      String? silinme;
      final tasima = yonetimTasimasi(
        yanitlar: {
          'GET $tayfaYolu': (_) => yonetimGorunumu(silinme: silinme),
          'POST $silmeYolu': (_) {
            silinme = '2026-11-14T12:00:00Z';
            return {'deletion_at': silinme};
          },
          'DELETE $silmeYolu': (_) {
            silinme = null;
            return null;
          },
        },
      );
      await _ac(
        tester,
        const TayfaAyarlariEkrani(tayfaId: ornekTayfaId),
        tasima,
      );

      await _dokun(
        tester,
        find.widgetWithText(IkincilEylem, arbMetni('yonetim_sil')),
      );
      await _dokun(tester, find.text(arbMetni('yonetim_sil_onayla')));

      expect(tasima.giden('POST', silmeYolu), hasLength(1));
      expect(find.text(arbMetni('yonetim_silme_iptal')), findsOneWidget);

      await _dokun(tester, find.text(arbMetni('yonetim_silme_iptal')));
      expect(tasima.giden('DELETE', silmeYolu), hasLength(1));
      expect(find.text(arbMetni('yonetim_silme_iptal_edildi')), findsOneWidget);
    });
  });

  group('katılım istekleri', () {
    testWidgets('kaynak ve davet eden; onay', (tester) async {
      ekranBoyutu(tester, yukseklik: 1200);
      var bekleyen = true;
      final tasima = yonetimTasimasi(
        yanitlar: {
          'GET $isteklerYolu': (_) => istekListesiJson([
            if (bekleyen)
              istekJson(uyeId1, kaynak: 'invite_link', davetEden: uyeId2),
          ]),
          'POST $onayYolu': (_) {
            bekleyen = false;
            return uyeJson(uyeId1);
          },
        },
      );
      await _ac(
        tester,
        const KatilimIstekleriEkrani(tayfaId: ornekTayfaId),
        tasima,
      );

      expect(find.text('Kişi 1'), findsOneWidget);
      expect(find.text('Kişi 2'), findsOneWidget);
      expect(find.text(arbMetni('yonetim_istek_kaynak_link')), findsOneWidget);

      await _dokun(tester, find.text(arbMetni('yonetim_onayla')));

      expect(
        tasima.giden('POST', onayYolu).single.yolParametreleri['user_id'],
        uyeId1,
      );
      expect(find.text(arbMetni('yonetim_istek_onaylandi')), findsOneWidget);
      expect(find.text(arbMetni('yonetim_istekler_bos')), findsOneWidget);
    });

    testWidgets('ret', (tester) async {
      ekranBoyutu(tester, yukseklik: 1200);
      final tasima = yonetimTasimasi(
        yanitlar: {
          'GET $isteklerYolu': yanit(istekListesiJson([istekJson(uyeId1)])),
          'DELETE $istekYolu': yanit(null),
        },
      );
      await _ac(
        tester,
        const KatilimIstekleriEkrani(tayfaId: ornekTayfaId),
        tasima,
      );

      expect(find.text(arbMetni('yonetim_istek_kaynak_kod')), findsOneWidget);
      await _dokun(tester, find.text(arbMetni('yonetim_reddet')));

      expect(tasima.giden('DELETE', istekYolu), hasLength(1));
      expect(find.text(arbMetni('yonetim_istek_reddedildi')), findsOneWidget);
    });
  });

  group('üyeler', () {
    SahteTayfaTasima uyeTasimasi([Map<String, TayfaYaniti>? ek]) =>
        yonetimTasimasi(
          yanitlar: {
            'GET $uyelerYolu': (i) => i.sorgu['status'] == 'banned'
                ? uyeListesiJson([uyeJson(uyeId3, durum: 'banned')])
                : uyeListesiJson([
                    uyeJson(benimId, rol: 'admin'),
                    uyeJson(uyeId2, rol: 'moderator'),
                    uyeJson(uyeId1),
                  ]),
            ...?ek,
          },
        );

    final Finder islemDugmesi = find.byTooltip(
      arbMetni('yonetim_uye_islemleri'),
    );

    testWidgets('kendine işlem yok; filtreler', (tester) async {
      ekranBoyutu(tester, yukseklik: 1200);
      final tasima = uyeTasimasi();
      await _ac(tester, const UyelerEkrani(tayfaId: ornekTayfaId), tasima);

      expect(find.text('Ben'), findsOneWidget);
      expect(find.text('Kişi 2'), findsOneWidget);
      expect(find.text('Kişi 1'), findsOneWidget);
      // Yönetici kendine değil, iki alt seviyeye dokunabilir.
      expect(islemDugmesi, findsNWidgets(2));

      await _dokun(tester, find.text(arbMetni('yonetim_filtre_moderator')));
      expect(find.text('Kişi 2'), findsOneWidget);
      expect(find.text('Kişi 1'), findsNothing);

      await _dokun(tester, find.text(arbMetni('yonetim_filtre_banli')));
      expect(find.text('Kişi 3'), findsOneWidget);
      expect(find.text(arbMetni('yonetim_banli')), findsOneWidget);
      expect(islemDugmesi, findsNothing);
      expect(tasima.giden('GET', uyelerYolu).last.sorgu['status'], 'banned');
    });

    testWidgets('1 gün susturma', (tester) async {
      ekranBoyutu(tester, yukseklik: 1200);
      final tasima = uyeTasimasi({
        'PUT $susturmaYolu': yanit(
          uyeJson(uyeId1, susturma: '2026-11-12T12:00:00Z'),
        ),
      });
      await _ac(tester, const UyelerEkrani(tayfaId: ornekTayfaId), tasima);

      await _dokun(tester, islemDugmesi.last);
      expect(find.text(arbMetni('yonetim_rol_yap_moderator')), findsOneWidget);
      await _dokun(tester, find.text('1 gün sustur'));

      final istek = tasima.giden('PUT', susturmaYolu).single;
      expect(istek.yolParametreleri['user_id'], uyeId1);
      expect(istek.govde, {'muted_until': '2026-11-12T12:00:00.000Z'});
      expect(
        find.text(arbMetni('yonetim_susturuldu_bildirim')),
        findsOneWidget,
      );
      expect(
        find.text(
          '${arbMetni('yonetim_rol_member')} · '
          '${arbMetni('yonetim_susturuldu')}',
        ),
        findsOneWidget,
      );
    });

    testWidgets('banlama onaylıdır ve listeden çıkarır', (tester) async {
      ekranBoyutu(tester, yukseklik: 1200);
      final tasima = uyeTasimasi({'PUT $banYolu': yanit(null)});
      await _ac(tester, const UyelerEkrani(tayfaId: ornekTayfaId), tasima);

      await _dokun(tester, islemDugmesi.last);
      await _dokun(tester, find.text(arbMetni('yonetim_banla')));
      expect(find.text(arbMetni('yonetim_banla_aciklama')), findsOneWidget);
      await _dokun(tester, find.text(arbMetni('yonetim_banla_onayla')));

      final istek = tasima.giden('PUT', banYolu).single;
      expect(istek.yolParametreleri['user_id'], uyeId1);
      // Gerekçe seçilmediyse gövde yok.
      expect(istek.govde, isNull);
      expect(find.text('Kişi 1'), findsNothing);
      expect(find.text(arbMetni('yonetim_banlandi')), findsOneWidget);
    });

    testWidgets('banlarken gerekçe seçilebilir; staff_conduct yok', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 1200);
      final tasima = uyeTasimasi({'PUT $banYolu': yanit(null)});
      await _ac(tester, const UyelerEkrani(tayfaId: ornekTayfaId), tasima);

      await _dokun(tester, islemDugmesi.last);
      await _dokun(tester, find.text(arbMetni('yonetim_banla')));
      expect(find.text(arbMetni('yonetim_ban_gerekce_baslik')), findsOneWidget);
      expect(find.text(arbMetni('yonetim_ban_gerekce_yok')), findsOneWidget);
      // Yönetim davranışı gerekçesi ban için geçerli değil (sözleşme).
      expect(find.text(arbMetni('sikayet_gerekce_yonetim')), findsNothing);
      await _dokun(tester, find.text(arbMetni('sikayet_gerekce_spam')));
      await _dokun(tester, find.text(arbMetni('yonetim_banla_onayla')));

      expect(tasima.giden('PUT', banYolu).single.govde, {'reason': 'spam'});
      // Gerekçe istemcide hiçbir yerde gösterilmez.
      expect(find.text(arbMetni('sikayet_gerekce_spam')), findsNothing);
      expect(find.text(arbMetni('yonetim_banlandi')), findsOneWidget);
    });

    testWidgets('ban penceresinde vazgeçilirse istek yok', (tester) async {
      ekranBoyutu(tester, yukseklik: 1200);
      final tasima = uyeTasimasi({'PUT $banYolu': yanit(null)});
      await _ac(tester, const UyelerEkrani(tayfaId: ornekTayfaId), tasima);

      await _dokun(tester, islemDugmesi.last);
      await _dokun(tester, find.text(arbMetni('yonetim_banla')));
      await _dokun(tester, find.text(arbMetni('yonetim_vazgec')));

      expect(tasima.giden('PUT', banYolu), isEmpty);
      expect(find.text('Kişi 1'), findsOneWidget);
    });

    for (final mod in [ThemeMode.light, ThemeMode.dark]) {
      testWidgets('ban penceresi ${mod.name} temada 2× yazıda taşmıyor', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await _ac(
          tester,
          const UyelerEkrani(tayfaId: ornekTayfaId),
          uyeTasimasi(),
          themeMode: mod,
        );

        await _dokun(tester, islemDugmesi.last);
        await _dokun(tester, find.text(arbMetni('yonetim_banla')));
        expect(tester.takeException(), isNull);
        expect(find.text(arbMetni('yonetim_ban_gerekce_yok')), findsOneWidget);
      });
    }

    testWidgets('moderatör moderatöre dokunamaz, rol değiştiremez', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 1200);
      final tasima = yonetimTasimasi(
        rol: 'moderator',
        yanitlar: {
          'GET $uyelerYolu': yanit(
            uyeListesiJson([
              uyeJson(uyeId2, rol: 'moderator'),
              uyeJson(uyeId1),
            ]),
          ),
        },
      );
      await _ac(tester, const UyelerEkrani(tayfaId: ornekTayfaId), tasima);

      expect(islemDugmesi, findsOneWidget);
      await _dokun(tester, islemDugmesi);
      expect(find.text(arbMetni('yonetim_rol_yap_moderator')), findsNothing);
      expect(find.text(arbMetni('yonetim_cikar')), findsOneWidget);
    });
  });

  group('tayfa bilgileri', () {
    testWidgets('yalnızca değişen alan gönderilir', (tester) async {
      ekranBoyutu(tester, yukseklik: 1600);
      final tasima = yonetimTasimasi(
        yanitlar: {
          'PATCH $tayfaYolu': (i) => tayfaJson(id: ornekTayfaId, ad: 'Yeni ad'),
        },
      );
      await _ac(
        tester,
        const TayfaBilgileriEkrani(tayfaId: ornekTayfaId),
        tasima,
      );

      await tester.enterText(
        find.widgetWithText(TextField, arbMetni('yonetim_ad_etiketi')),
        'Yeni ad',
      );
      await _dokun(tester, find.text(arbMetni('yonetim_kaydet')));

      expect(tasima.giden('PATCH', tayfaYolu).single.govde, {
        'name': 'Yeni ad',
      });
      expect(find.text(arbMetni('yonetim_kaydedildi')), findsOneWidget);
    });

    testWidgets('kısa ad gönderilmez', (tester) async {
      ekranBoyutu(tester, yukseklik: 1600);
      final tasima = yonetimTasimasi();
      await _ac(
        tester,
        const TayfaBilgileriEkrani(tayfaId: ornekTayfaId),
        tasima,
      );

      await tester.enterText(
        find.widgetWithText(TextField, arbMetni('yonetim_ad_etiketi')),
        'ab',
      );
      await _dokun(tester, find.text(arbMetni('yonetim_kaydet')));

      expect(find.text(arbMetni('yonetim_ad_hata')), findsOneWidget);
      expect(tasima.giden('PATCH', tayfaYolu), isEmpty);
    });
  });

  group('davet linkleri', () {
    testWidgets('oluşturma: link yalnızca paylaşım panelinde', (tester) async {
      ekranBoyutu(tester, yukseklik: 1200);
      final paylasici = SahtePaylasici();
      final tasima = yonetimTasimasi(
        yanitlar: {
          'POST $davetlerYolu': yanit({
            'invite': davetJson(davetId1, kullanilan: 0),
            'token': sahteDavetTokeni,
          }),
        },
      );
      await _ac(
        tester,
        const DavetlerEkrani(tayfaId: ornekTayfaId),
        tasima,
        paylasici: paylasici,
      );
      expect(find.text(arbMetni('yonetim_davetler_bos')), findsOneWidget);

      await _dokun(tester, find.text(arbMetni('yonetim_davet_olustur')));
      await _dokun(tester, find.text('30 gün'));
      await _dokun(tester, find.text('1 kişi'));
      await _dokun(tester, find.text(arbMetni('yonetim_davet_olustur_onayla')));

      expect(tasima.giden('POST', davetlerYolu).single.govde, {
        'ttl_seconds': 2592000,
        'max_uses': 1,
      });
      const link = 'https://tayfam.app/davet#$sahteDavetTokeni';
      expect(find.text(link), findsOneWidget);

      await _dokun(tester, find.text(arbMetni('yonetim_davet_paylas')));
      expect(paylasici.paylasilan.single, contains(link));
      await _dokun(tester, find.text(arbMetni('yonetim_davet_kopyala')));
      expect(paylasici.kopyalanan.single, link);

      // Panel kapanınca link bir daha görünmez; listede token yok.
      Navigator.of(tester.element(find.text(link))).pop();
      await tester.pumpAndSettle();
      expect(find.text(link), findsNothing);
      expect(find.text('0/10 kişi katıldı'), findsOneWidget);
    });

    testWidgets('iptal onaylıdır', (tester) async {
      ekranBoyutu(tester, yukseklik: 1200);
      final tasima = yonetimTasimasi(
        yanitlar: {
          'GET $davetlerYolu': yanit({
            'invites': [davetJson(davetId1)],
          }),
          'DELETE $davetYolu': yanit(null),
        },
      );
      await _ac(tester, const DavetlerEkrani(tayfaId: ornekTayfaId), tasima);

      expect(find.text('2/10 kişi katıldı'), findsOneWidget);
      expect(find.text('Kişi 1'), findsOneWidget);
      await _dokun(tester, find.text(arbMetni('yonetim_davet_iptal')));
      await _dokun(tester, find.text(arbMetni('yonetim_davet_iptal_onayla')));

      expect(
        tasima.giden('DELETE', davetYolu).single.yolParametreleri['invite_id'],
        davetId1,
      );
      expect(find.text(arbMetni('yonetim_davetler_bos')), findsOneWidget);
    });
  });

  for (final mod in [ThemeMode.light, ThemeMode.dark]) {
    group('${mod.name} temada 2× yazıda 320 dp taşmıyor', () {
      final ekranlar = <String, Widget>{
        'ayarlar': const TayfaAyarlariEkrani(tayfaId: ornekTayfaId),
        'istekler': const KatilimIstekleriEkrani(tayfaId: ornekTayfaId),
        'üyeler': const UyelerEkrani(tayfaId: ornekTayfaId),
        'bilgiler': const TayfaBilgileriEkrani(tayfaId: ornekTayfaId),
        'davetler': const DavetlerEkrani(tayfaId: ornekTayfaId),
      };
      for (final MapEntry(key: ad, value: ekran) in ekranlar.entries) {
        testWidgets(ad, (tester) async {
          ekranBoyutu(tester, genislik: 320);
          ikiKatYazi(tester);
          await _ac(
            tester,
            ekran,
            yonetimTasimasi(
              yanitlar: {
                'GET $tayfaYolu': yanit(
                  yonetimGorunumu(
                    kod: sahteKod,
                    silinme: '2026-11-14T12:00:00Z',
                  ),
                ),
                'GET $uyelerYolu': yanit(
                  uyeListesiJson([
                    uyeJson(uyeId1, susturma: '2026-11-12T12:00:00Z'),
                  ], sonraki: 'opak-1'),
                ),
                'GET $isteklerYolu': yanit(
                  istekListesiJson([
                    istekJson(
                      uyeId1,
                      kaynak: 'direct_invite',
                      davetEden: uyeId2,
                    ),
                  ]),
                ),
                'GET $davetlerYolu': yanit({
                  'invites': [davetJson(davetId1)],
                }),
              },
            ),
            themeMode: mod,
          );
          expect(tester.takeException(), isNull);
        });
      }

      testWidgets('menü ve davet paneli', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await _ac(
          tester,
          const Scaffold(
            body: DavetLinkiPaylasimi(
              link: 'https://tayfam.app/davet#$sahteDavetTokeni',
              tayfaAdi: 'Çok uzun adlı klasik otomobil tayfası',
            ),
          ),
          yonetimTasimasi(),
          themeMode: mod,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('ana sayfa üst bölümü menüyle', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await _ac(
          tester,
          const TayfaAnaSayfa(tayfaId: ornekTayfaId),
          yonetimTasimasi(
            yanitlar: {
              'GET $tayfaYolu': yanit(
                gorunumJson(
                  ornekTayfaId,
                  rol: 'admin',
                  ad: 'Çok uzun adlı klasik otomobil tayfası',
                ),
              ),
              'GET $isteklerYolu': yanit(istekListesiJson([istekJson(uyeId1)])),
            },
          ),
          themeMode: mod,
        );
        expect(_menu, findsOneWidget);
        expect(tester.takeException(), isNull);
        await _dokun(tester, _menu);
        expect(tester.takeException(), isNull);
      });
    });
  }
}
