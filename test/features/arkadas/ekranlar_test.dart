import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/features/arkadas/arkadas.dart';
import 'package:tayfam/features/arkadas/presentation/arkadas_bul_ekrani.dart';
import 'package:tayfam/features/arkadas/presentation/arkadas_istekleri_ekrani.dart';
import 'package:tayfam/features/arkadas/presentation/arkadaslar_ekrani.dart';
import 'package:tayfam/features/arkadas/presentation/engellenenler_ekrani.dart';
import 'package:tayfam/features/arkadas/presentation/kisi_profili_ekrani.dart';
import 'package:tayfam/features/arkadas/presentation/tayfa_davetleri_ekrani.dart';

import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';
import 'sahteler.dart';

Future<void> _ac(
  WidgetTester tester,
  Widget ekran,
  SahteTayfaTasima tasima, {
  ThemeMode themeMode = ThemeMode.light,
  List<Override> ek = const [],
}) => widgetAc(
  tester,
  ekran,
  themeMode: themeMode,
  tayfa: [...arkadasOverridelari(tasima), ...ek],
);

Future<void> _dokun(WidgetTester tester, Finder hedef) async {
  await tester.ensureVisible(hedef);
  await tester.pumpAndSettle();
  await tester.tap(hedef);
  await tester.pumpAndSettle();
}

/// Dolu yanıtlarla sahte taşıma: her listede kayıt var.
SahteTayfaTasima _doluTasima() => arkadasTasimasi({
  'GET $arkadaslarYolu': yanit(
    arkadasListesiJson([arkadasJson(kisiId1), arkadasJson(kisiId2)]),
  ),
  'GET $isteklerYolu': yanit(
    arkadasListesiJson([arkadasJson(kisiId1, durum: 'incoming')]),
  ),
  'GET $engellerYolu': yanit({
    'users': [engelJson(kisiId1, ad: 'Kişi 1'), engelJson(kisiId2)],
  }),
  'GET $davetlerimYolu': yanit({
    'invitations': [davetJson(ornekTayfaId)],
  }),
  'GET $profilYolu': (i) => kisiProfiliJson(
    i.yolParametreleri['user_id']!,
    durum: i.yolParametreleri['user_id'] == benimId ? null : 'friends',
    gecmisGorunur: true,
    ortak: [
      {'id': ornekTayfaId, 'name': 'Klasikçiler'},
    ],
  ),
  'GET $gecmisYolu': yanit({
    'records': [kayitJson(), kayitJson(uye: false, mod: 'online')],
  }),
});

final Map<String, Widget Function()> _ekranlar = {
  'arkadaşlar': () => const ArkadaslarEkrani(),
  'bul': () => const ArkadasBulEkrani(),
  'istekler': () => const ArkadasIstekleriEkrani(),
  'engellenenler': () => const EngellenenlerEkrani(),
  'tayfa davetleri': () => const TayfaDavetleriEkrani(),
  'kişi profili': () => const KisiProfiliEkrani(kullaniciId: kisiId1),
  'profil girişleri': () => const Scaffold(body: ArkadaslikGirisleri()),
};

void main() {
  group('iki tema, 2× yazı, 320 dp', () {
    for (final MapEntry(key: ad, value: ekran) in _ekranlar.entries) {
      for (final tema in [ThemeMode.light, ThemeMode.dark]) {
        testWidgets('$ad (${tema.name}) taşmaz', (tester) async {
          ekranBoyutu(tester, genislik: 320);
          ikiKatYazi(tester);
          await _ac(tester, ekran(), _doluTasima(), themeMode: tema);
          expect(tester.takeException(), isNull);
        });
      }
    }
  });

  group('arkadaşlar', () {
    testWidgets('liste ve girişler', (tester) async {
      ekranBoyutu(tester);
      await _ac(tester, const ArkadaslarEkrani(), _doluTasima());
      expect(find.text(kisiAdi(kisiId1)), findsOneWidget);
      expect(find.text(kisiAdi(kisiId2)), findsOneWidget);
      expect(find.text(arbMetni('arkadas_istekler')), findsOneWidget);
      expect(find.text(arbMetni('arkadas_engellenenler')), findsOneWidget);
    });

    testWidgets('boş liste metni', (tester) async {
      ekranBoyutu(tester);
      await _ac(tester, const ArkadaslarEkrani(), arkadasTasimasi());
      expect(find.text(arbMetni('arkadas_liste_bos')), findsOneWidget);
    });

    testWidgets('hata satırı ve tekrar dene', (tester) async {
      ekranBoyutu(tester);
      await _ac(
        tester,
        const ArkadaslarEkrani(),
        arkadasTasimasi({'GET $arkadaslarYolu': yanit(Exception('x'))}),
      );
      expect(find.text(arbMetni('yonetim_tekrar_dene')), findsOneWidget);
    });
  });

  group('arkadaş bulma', () {
    testWidgets('kodla bulur ve istek gönderir', (tester) async {
      ekranBoyutu(tester);
      final tasima = arkadasTasimasi({
        'POST $referansYolu': yanit({
          'user_id': kisiId1,
          'display_name': kisiAdi(kisiId1),
        }),
        'POST $isteklerYolu': yanit(arkadasJson(kisiId1, durum: 'outgoing')),
      });
      await _ac(tester, const ArkadasBulEkrani(), tasima);

      await tester.enterText(find.byType(TextField), sahteReferansKodu);
      await _dokun(tester, find.text(arbMetni('arkadas_bul_ara')));
      expect(find.text(kisiAdi(kisiId1)), findsOneWidget);

      await _dokun(tester, find.text(arbMetni('arkadas_istek_gonder')));
      expect(tasima.giden('POST', isteklerYolu), hasLength(1));
      expect(find.text(arbMetni('arkadas_istek_gonderildi')), findsOneWidget);
      expect(find.text(arbMetni('arkadas_durum_giden')), findsOneWidget);
    });

    testWidgets('kendi kodunda istek düğmesi yok', (tester) async {
      ekranBoyutu(tester);
      final tasima = arkadasTasimasi({
        'POST $referansYolu': yanit({
          'user_id': benimId,
          'display_name': kisiAdi(benimId),
        }),
      });
      await _ac(tester, const ArkadasBulEkrani(), tasima);
      await tester.enterText(find.byType(TextField), sahteReferansKodu);
      await _dokun(tester, find.text(arbMetni('arkadas_bul_ara')));

      expect(find.text(arbMetni('arkadas_bul_kendi_kodun')), findsOneWidget);
      expect(find.text(arbMetni('arkadas_istek_gonder')), findsNothing);
    });

    testWidgets('bulunamayan kodda hata metni', (tester) async {
      ekranBoyutu(tester);
      final tasima = arkadasTasimasi({
        'POST $referansYolu': yanit(Exception('bulunamadı')),
      });
      await _ac(tester, const ArkadasBulEkrani(), tasima);
      await tester.enterText(find.byType(TextField), sahteReferansKodu);
      await _dokun(tester, find.text(arbMetni('arkadas_bul_ara')));
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });
  });

  group('istekler', () {
    testWidgets('gelen isteği kabul eder', (tester) async {
      ekranBoyutu(tester);
      final tasima = _doluTasima()
        ..yanitlar['POST $kabulYolu'] = yanit(arkadasJson(kisiId1));
      await _ac(tester, const ArkadasIstekleriEkrani(), tasima);

      await _dokun(tester, find.text(arbMetni('arkadas_kabul_et')));
      expect(tasima.giden('POST', kabulYolu), hasLength(1));
      expect(find.text(arbMetni('arkadas_artik_arkadassiniz')), findsOneWidget);
    });

    testWidgets('gönderilenlerde geri çekme', (tester) async {
      ekranBoyutu(tester);
      final tasima = arkadasTasimasi({
        'GET $isteklerYolu': (i) => arkadasListesiJson([
          if (i.sorgu['direction'] == 'outgoing')
            arkadasJson(kisiId2, durum: 'outgoing'),
        ]),
        'DELETE $arkadasYolu': yanit(null),
      });
      await _ac(tester, const ArkadasIstekleriEkrani(), tasima);
      expect(find.text(arbMetni('arkadas_istekler_gelen_bos')), findsOneWidget);

      await _dokun(tester, find.text(arbMetni('arkadas_istekler_giden')));
      await _dokun(tester, find.text(arbMetni('arkadas_geri_cek')));
      expect(
        tasima.giden('DELETE', arkadasYolu).single.yolParametreleri['user_id'],
        kisiId2,
      );
      expect(find.text(arbMetni('arkadas_istek_geri_cekildi')), findsOneWidget);
    });
  });

  group('engellenenler', () {
    testWidgets('silinmiş hesap adı ve onaylı engel kaldırma', (tester) async {
      ekranBoyutu(tester);
      final tasima = _doluTasima()..yanitlar['DELETE $engelYolu'] = yanit(null);
      await _ac(tester, const EngellenenlerEkrani(), tasima);
      expect(find.text(arbMetni('kullanici_silinmis')), findsOneWidget);

      await _dokun(tester, find.text(arbMetni('arkadas_engel_kaldir')).first);
      expect(
        find.text(arbMetni('arkadas_engel_kaldir_baslik')),
        findsOneWidget,
      );
      await _dokun(
        tester,
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(arbMetni('arkadas_engel_kaldir')),
        ),
      );
      expect(tasima.giden('DELETE', engelYolu), hasLength(1));
      expect(find.text(arbMetni('arkadas_engel_kaldirildi')), findsOneWidget);
    });
  });

  group('tayfa davetleri', () {
    testWidgets('kabul ve onay bekleyen üyelik', (tester) async {
      ekranBoyutu(tester);
      final tasima = _doluTasima()
        ..yanitlar['POST $davetKabulYolu'] = yanit(
          uyelikJson(ornekTayfaId, durum: 'pending'),
        );
      await _ac(tester, const TayfaDavetleriEkrani(), tasima);
      expect(find.text('Kampçılar'), findsOneWidget);
      expect(find.text(kisiAdi(kisiId1)), findsOneWidget);

      await _dokun(tester, find.text(arbMetni('arkadas_davet_kabul')));
      expect(tasima.giden('POST', davetKabulYolu), hasLength(1));
      expect(
        find.text(arbMetni('arkadas_davet_onay_bekliyor')),
        findsOneWidget,
      );
      expect(find.text(arbMetni('arkadas_davetler_bos')), findsOneWidget);
    });

    testWidgets('ret', (tester) async {
      ekranBoyutu(tester);
      final tasima = _doluTasima()
        ..yanitlar['DELETE $davetimYolu'] = yanit(null);
      await _ac(tester, const TayfaDavetleriEkrani(), tasima);
      await _dokun(tester, find.text(arbMetni('arkadas_reddet')));
      expect(tasima.giden('DELETE', davetimYolu), hasLength(1));
      expect(find.text(arbMetni('arkadas_davet_reddedildi')), findsOneWidget);
    });
  });

  group('kişi profili', () {
    testWidgets('geçersiz kimlikte istek yapılmaz', (tester) async {
      ekranBoyutu(tester);
      final tasima = arkadasTasimasi();
      await _ac(
        tester,
        const KisiProfiliEkrani(kullaniciId: '../v1/me'),
        tasima,
      );
      expect(find.text(arbMetni('hata_user_not_found')), findsOneWidget);
      expect(tasima.giden('GET', profilYolu), isEmpty);
    });

    testWidgets('ilişki yok: istek gönder; geçmiş gizli', (tester) async {
      ekranBoyutu(tester);
      String? durum;
      final tasima = arkadasTasimasi({
        'GET $profilYolu': (_) => kisiProfiliJson(kisiId1, durum: durum),
        'POST $isteklerYolu': (_) {
          durum = 'outgoing';
          return arkadasJson(kisiId1, durum: 'outgoing');
        },
      });
      await _ac(tester, const KisiProfiliEkrani(kullaniciId: kisiId1), tasima);
      expect(find.text(arbMetni('arkadas_gecmis_gizli')), findsOneWidget);
      expect(find.text(arbMetni('arkadas_ortak_tayfa_yok')), findsOneWidget);
      expect(tasima.giden('GET', gecmisYolu), isEmpty);

      await _dokun(tester, find.text(arbMetni('arkadas_istek_gonder')));
      expect(tasima.giden('POST', isteklerYolu), hasLength(1));
      expect(find.text(arbMetni('arkadas_geri_cek')), findsOneWidget);
    });

    testWidgets('arkadaş: ortak tayfa, geçmiş, davet ve çıkarma', (
      tester,
    ) async {
      ekranBoyutu(tester);
      await _ac(
        tester,
        const KisiProfiliEkrani(kullaniciId: kisiId1),
        _doluTasima(),
      );
      expect(find.text(arbMetni('arkadas_durum_arkadas')), findsOneWidget);
      expect(find.text(arbMetni('arkadas_tayfaya_davet')), findsOneWidget);
      expect(find.text(arbMetni('arkadas_cikar')), findsOneWidget);
      expect(find.text('Uludağ yürüyüşü'), findsOneWidget);
      expect(find.text(arbMetni('arkadas_gecmis_etkinlik')), findsOneWidget);
      expect(find.text(arbMetni('arkadas_gecmis_cevrimici')), findsOneWidget);
    });

    testWidgets('tayfaya davet: ortak tayfa seçenekte yok', (tester) async {
      ekranBoyutu(tester);
      const ikinciAd = 'Kampçılar';
      final tasima = _doluTasima()
        ..yanitlar['GET /v1/tayfas'] = yanit(
          listeJson([
            etkinJson(ornekTayfaId),
            etkinJson(ikinciTayfaId, ad: ikinciAd),
          ]),
        )
        ..yanitlar['POST $tayfaDavetiYolu'] = yanit({
          'tayfa_id': ikinciTayfaId,
          'tayfa_name': ikinciAd,
          'user_id': kisiId1,
          'invited_at': '2026-11-11T09:00:00Z',
        });
      await _ac(tester, const KisiProfiliEkrani(kullaniciId: kisiId1), tasima);

      await _dokun(tester, find.text(arbMetni('arkadas_tayfaya_davet')));
      final secim = find.byType(BottomSheet);
      expect(
        find.descendant(of: secim, matching: find.text('Klasikçiler')),
        findsNothing,
      );
      await _dokun(
        tester,
        find.descendant(of: secim, matching: find.text(ikinciAd)),
      );
      final istek = tasima.giden('POST', tayfaDavetiYolu).single;
      expect(istek.yolParametreleri['tayfa_id'], ikinciTayfaId);
      expect(find.text(arbMetni('arkadas_davet_gonderildi')), findsOneWidget);
    });

    testWidgets('engelleme onaylı', (tester) async {
      ekranBoyutu(tester);
      final tasima = _doluTasima()..yanitlar['PUT $engelYolu'] = yanit(null);
      await _ac(tester, const KisiProfiliEkrani(kullaniciId: kisiId1), tasima);

      await _dokun(tester, find.byType(PopupMenuButton<void>));
      await _dokun(tester, find.text(arbMetni('arkadas_engelle')));
      expect(find.byType(AlertDialog), findsOneWidget);
      await _dokun(
        tester,
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(arbMetni('arkadas_engelle')),
        ),
      );
      expect(tasima.giden('PUT', engelYolu), hasLength(1));
      expect(find.text(arbMetni('arkadas_engellendi')), findsOneWidget);
    });

    testWidgets('kendi profilinde eylem ve menü yok', (tester) async {
      ekranBoyutu(tester);
      await _ac(
        tester,
        const KisiProfiliEkrani(kullaniciId: benimId),
        _doluTasima(),
      );
      expect(find.text(arbMetni('arkadas_profil_sen')), findsOneWidget);
      expect(find.byType(PopupMenuButton<void>), findsNothing);
      expect(find.text(arbMetni('arkadas_ortak_tayfalar')), findsNothing);
    });

    testWidgets('kanca: başka paketin eylemi görünür', (tester) async {
      ekranBoyutu(tester);
      KisiProfiliBilgisi? gelen;
      await _ac(
        tester,
        const KisiProfiliEkrani(kullaniciId: kisiId1),
        _doluTasima(),
        ek: [
          kisiProfiliEylemleriProvider.overrideWithValue([
            (context, kisi) {
              gelen = kisi;
              return const Icon(Icons.chat_bubble_outline);
            },
            (context, kisi) => null,
          ]),
        ],
      );
      expect(find.byIcon(Icons.chat_bubble_outline), findsOneWidget);
      expect(gelen?.kullaniciId, kisiId1);
      expect(gelen?.arkadas, isTrue);
      expect(gelen?.ortakTayfaVar, isTrue);
    });
  });

  group('profil girişleri', () {
    testWidgets('bekleyen istek ve davet rozetleri', (tester) async {
      ekranBoyutu(tester);
      await _ac(
        tester,
        const Scaffold(body: ArkadaslikGirisleri()),
        _doluTasima(),
      );
      final rozetler = tester.widgetList<Badge>(find.byType(Badge));
      expect(rozetler.where((r) => r.isLabelVisible), hasLength(2));
    });
  });

  group('yönlendirici', () {
    testWidgets('kişi profili ve arkadaşlar adresleri açılır', (tester) async {
      ekranBoyutu(tester);
      await uygulamayiAc(
        tester,
        oturum: null,
        tayfa: arkadasOverridelari(_doluTasima()),
      );
      final yonlendirici = yonlendiriciyiAl(tester);

      yonlendirici.go(Adresler.arkadaslar);
      await tester.pumpAndSettle();
      expect(find.byType(ArkadaslarEkrani), findsOneWidget);

      yonlendirici.go(Adresler.tayfaDavetleri);
      await tester.pumpAndSettle();
      expect(find.byType(TayfaDavetleriEkrani), findsOneWidget);

      yonlendirici.go(Adresler.kisi(kisiId1));
      await tester.pumpAndSettle();
      expect(find.byType(KisiProfiliEkrani), findsOneWidget);
    });
  });
}
