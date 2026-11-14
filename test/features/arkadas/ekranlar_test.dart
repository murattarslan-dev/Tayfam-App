import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/bilesenler/bilesenler.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/medya/medya_gorseli.dart';
import 'package:tayfam/features/arkadas/arkadas.dart';
import 'package:tayfam/features/arkadas/presentation/arkadas_bul_ekrani.dart';
import 'package:tayfam/features/arkadas/presentation/arkadas_istekleri_ekrani.dart';
import 'package:tayfam/features/arkadas/presentation/arkadaslar_ekrani.dart';
import 'package:tayfam/features/arkadas/presentation/engellenenler_ekrani.dart';
import 'package:tayfam/features/arkadas/presentation/arkadas_ortak.dart';
import 'package:tayfam/features/arkadas/presentation/katilim_gecmisi.dart';
import 'package:tayfam/features/arkadas/presentation/kisi_profili_ekrani.dart';
import 'package:tayfam/features/arkadas/presentation/tayfa_davetleri_ekrani.dart';
import 'package:tayfam/features/sikayet/presentation/sikayet_sayfasi.dart';
import 'package:tayfam/l10n/app_localizations.dart';

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
  'kendi kişi profili': () => const KisiProfiliEkrani(kullaniciId: benimId),
  'katılımlarım': () => const KatilimlarimEkrani(),
  'profil girişleri': () =>
      const Scaffold(body: SingleChildScrollView(child: ArkadaslikGirisleri())),
  'katılım özeti': () => Scaffold(
    body: SingleChildScrollView(
      child: KatilimOzeti(
        kullaniciId: benimId,
        bosMetin: arbMetni('arkadas_gecmis_kendi_bos'),
        onTumu: () {},
      ),
    ),
  ),
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
    testWidgets('liste, bekleyen istek kartı ve engellenenler', (tester) async {
      ekranBoyutu(tester);
      await _ac(tester, const ArkadaslarEkrani(), _doluTasima());
      expect(find.text(kisiAdi(kisiId2)), findsOneWidget);
      // Kart: sayı gelen istek listesinden, adlar.
      expect(find.text('1 arkadaşlık isteği'), findsOneWidget);
      expect(find.text('Kişi 1 cevabını bekliyor'), findsOneWidget);
      expect(find.text(arbMetni('arkadas_engellenenler')), findsOneWidget);
      // Kanca verilmezse "Kodumu paylaş" yok.
      expect(find.text(arbMetni('arkadas_kodumu_paylas')), findsNothing);
    });

    testWidgets('istek yoksa kart görünmez', (tester) async {
      ekranBoyutu(tester);
      await _ac(tester, const ArkadaslarEkrani(), arkadasTasimasi());
      expect(find.textContaining('arkadaşlık isteği'), findsNothing);
    });

    testWidgets('ilk sayfa doluysa istek sayısı "N+"', (tester) async {
      ekranBoyutu(tester);
      final tasima = arkadasTasimasi({
        'GET $isteklerYolu': yanit(
          arkadasListesiJson([
            arkadasJson(kisiId1, durum: 'incoming'),
            arkadasJson(kisiId2, durum: 'incoming'),
          ], sonraki: 'sonraki-sayfa'),
        ),
      });
      await _ac(tester, const ArkadaslarEkrani(), tasima);
      expect(find.text('2+ arkadaşlık isteği'), findsOneWidget);
      expect(find.text('Kişi 1 ve Kişi 2 cevabını bekliyor'), findsOneWidget);
    });

    testWidgets('"Kodumu paylaş" kancayı çağırır', (tester) async {
      ekranBoyutu(tester);
      var cagri = 0;
      await _ac(
        tester,
        const ArkadaslarEkrani(),
        _doluTasima(),
        ek: [
          referansPaylasimiProvider.overrideWithValue((dugme, ref) async {
            cagri++;
          }),
        ],
      );
      await _dokun(tester, find.text(arbMetni('arkadas_kodumu_paylas')));
      expect(cagri, 1);
    });

    testWidgets('"Arkadaş ekle" alttan sayfayı açar', (tester) async {
      ekranBoyutu(tester);
      await _ac(tester, const ArkadaslarEkrani(), _doluTasima());
      await _dokun(tester, find.text(arbMetni('arkadas_ekle')));
      final sayfa = find.byType(BottomSheet);
      expect(sayfa, findsOneWidget);
      expect(
        find.descendant(of: sayfa, matching: find.byType(TextField)),
        findsOneWidget,
      );
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
      expect(
        find.textContaining('Davet eden: ${kisiAdi(kisiId1)} · '),
        findsOneWidget,
      );

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
      expect(
        find.textContaining(arbMetni('arkadas_durum_arkadas')),
        findsOneWidget,
      );
      expect(find.text(arbMetni('arkadas_tayfaya_davet')), findsOneWidget);
      expect(find.text('Klasikçiler'), findsOneWidget);
      expect(find.text('Uludağ yürüyüşü'), findsOneWidget);
      expect(find.text(arbMetni('arkadas_gecmis_etkinlik')), findsOneWidget);
      expect(
        find.textContaining(arbMetni('arkadas_gecmis_cevrimici')),
        findsOneWidget,
      );

      // ⋯ alttan sayfa: çıkar, şikâyet, engelle.
      await _dokun(tester, find.byIcon(Icons.more_horiz));
      final menu = find.byType(BottomSheet);
      for (final anahtar in const [
        'arkadas_cikar',
        'sikayet_et',
        'arkadas_engelle',
      ]) {
        expect(
          find.descendant(of: menu, matching: find.text(arbMetni(anahtar))),
          findsOneWidget,
        );
      }
    });

    testWidgets('arkadaşlıktan çıkarma yıkıcı onayla', (tester) async {
      ekranBoyutu(tester);
      final tasima = _doluTasima()
        ..yanitlar['DELETE $arkadasYolu'] = yanit(null);
      await _ac(tester, const KisiProfiliEkrani(kullaniciId: kisiId1), tasima);

      await _dokun(tester, find.byIcon(Icons.more_horiz));
      await _dokun(tester, find.text(arbMetni('arkadas_cikar')));
      expect(find.byType(AlertDialog), findsOneWidget);
      await _dokun(
        tester,
        find.descendant(
          of: find.byType(YikiciEylem),
          matching: find.text(arbMetni('arkadas_cikar')),
        ),
      );
      expect(tasima.giden('DELETE', arkadasYolu), hasLength(1));
      expect(find.text(arbMetni('arkadas_cikarildi')), findsOneWidget);
    });

    testWidgets('şikâyet: tek ortak tayfada kullanıcı hedefiyle açılır', (
      tester,
    ) async {
      ekranBoyutu(tester);
      await _ac(
        tester,
        const KisiProfiliEkrani(kullaniciId: kisiId1),
        _doluTasima(),
      );
      await _dokun(tester, find.byIcon(Icons.more_horiz));
      await _dokun(tester, find.text(arbMetni('sikayet_et')));

      final sayfa = tester.widget<SikayetSayfasi>(find.byType(SikayetSayfasi));
      expect(sayfa.hedef.tur, ReportTargetType.user);
      expect(sayfa.hedef.id, kisiId1);
      expect(sayfa.hedef.tayfaId, ornekTayfaId);
      expect(find.text(arbMetni('sikayet_soru_uye')), findsOneWidget);
    });

    testWidgets('şikâyet: birden çok ortak tayfada tayfa seçtirilir', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = _doluTasima()
        ..yanitlar['GET $profilYolu'] = (i) => kisiProfiliJson(
          kisiId1,
          durum: 'friends',
          ortak: [
            {'id': ornekTayfaId, 'name': 'Klasikçiler'},
            {'id': ikinciTayfaId, 'name': 'Kampçılar'},
          ],
        );
      await _ac(tester, const KisiProfiliEkrani(kullaniciId: kisiId1), tasima);
      await _dokun(tester, find.byIcon(Icons.more_horiz));
      await _dokun(tester, find.text(arbMetni('sikayet_et')));

      expect(
        find.text(arbMetni('arkadas_sikayet_tayfa_baslik')),
        findsOneWidget,
      );
      await _dokun(
        tester,
        find.descendant(
          of: find.byType(BottomSheet),
          matching: find.text('Kampçılar'),
        ),
      );
      final sayfa = tester.widget<SikayetSayfasi>(find.byType(SikayetSayfasi));
      expect(sayfa.hedef.tayfaId, ikinciTayfaId);
    });

    testWidgets('ortak tayfa yoksa şikâyet satırı yok', (tester) async {
      ekranBoyutu(tester);
      await _ac(
        tester,
        const KisiProfiliEkrani(kullaniciId: kisiId1),
        arkadasTasimasi(),
      );
      expect(find.text(arbMetni('arkadas_sikayet_baglanti')), findsNothing);
      await _dokun(tester, find.byIcon(Icons.more_horiz));
      expect(find.text(arbMetni('sikayet_et')), findsNothing);
      expect(find.text(arbMetni('arkadas_cikar')), findsNothing);
      expect(find.text(arbMetni('arkadas_engelle')), findsOneWidget);
    });

    testWidgets('profilin altındaki şikâyet bağlantısı şikâyeti açar', (
      tester,
    ) async {
      ekranBoyutu(tester);
      await _ac(
        tester,
        const KisiProfiliEkrani(kullaniciId: kisiId1),
        _doluTasima(),
      );
      final baglanti = find.text(arbMetni('arkadas_sikayet_baglanti'));
      await tester.ensureVisible(baglanti);
      await _dokun(tester, baglanti);

      final sayfa = tester.widget<SikayetSayfasi>(find.byType(SikayetSayfasi));
      expect(sayfa.hedef.tur, ReportTargetType.user);
      expect(sayfa.hedef.id, kisiId1);
      expect(sayfa.hedef.tayfaId, ornekTayfaId);
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

      await _dokun(tester, find.byIcon(Icons.more_horiz));
      await _dokun(tester, find.text(arbMetni('arkadas_engelle')));
      expect(find.byType(AlertDialog), findsOneWidget);
      await _dokun(
        tester,
        find.descendant(
          of: find.byType(YikiciEylem),
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
      expect(find.byIcon(Icons.more_horiz), findsNothing);
      expect(find.text(arbMetni('arkadas_istek_gonder')), findsNothing);
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
    testWidgets('bekleyen istek ve davet noktaları, arkadaş avatarları', (
      tester,
    ) async {
      ekranBoyutu(tester);
      await _ac(
        tester,
        const Scaffold(body: ArkadaslikGirisleri()),
        _doluTasima(),
      );
      expect(find.byType(BekleyenNoktasi), findsNWidgets(2));
      expect(find.text(arbMetni('arkadas_istek_bekliyor')), findsOneWidget);
      expect(find.text(arbMetni('arkadas_davet_bekliyor')), findsOneWidget);
      // İki arkadaşın avatarı; sayı yok.
      expect(
        find.descendant(
          of: find.byType(AvatarYigini),
          matching: find.byType(KullaniciAvatari),
        ),
        findsNWidgets(2),
      );
    });

    testWidgets('bekleyen yoksa nokta yok', (tester) async {
      ekranBoyutu(tester);
      await _ac(
        tester,
        const Scaffold(body: ArkadaslikGirisleri()),
        arkadasTasimasi(),
      );
      expect(find.byType(BekleyenNoktasi), findsNothing);
      expect(find.text(arbMetni('arkadas_istek_yok_kisa')), findsOneWidget);
      expect(find.text(arbMetni('arkadas_davet_yok_kisa')), findsOneWidget);
    });
  });

  group('liste ekranları (2026-11-13 tasarım)', () {
    testWidgets('boş durumlar mevcut metinlerle', (tester) async {
      ekranBoyutu(tester);
      for (final (ekran, anahtar) in const <(Widget, String)>[
        (ArkadasIstekleriEkrani(), 'arkadas_istekler_gelen_bos'),
        (TayfaDavetleriEkrani(), 'arkadas_davetler_bos'),
        (EngellenenlerEkrani(), 'arkadas_engellenenler_bos'),
        (KatilimlarimEkrani(), 'arkadas_gecmis_kendi_bos'),
      ]) {
        // Her ekran kendi kapsamında açılır.
        await tester.pumpWidget(const SizedBox.shrink());
        await _ac(tester, ekran, arkadasTasimasi());
        expect(find.text(arbMetni(anahtar)), findsOneWidget, reason: anahtar);
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await _ac(tester, const ArkadasIstekleriEkrani(), arkadasTasimasi());
      await _dokun(tester, find.text(arbMetni('arkadas_istekler_giden')));
      expect(find.text(arbMetni('arkadas_istekler_giden_bos')), findsOneWidget);
    });

    testWidgets('seçicide gelen sayısı; yoksa yalnızca "Gelen"', (
      tester,
    ) async {
      ekranBoyutu(tester);
      await _ac(tester, const ArkadasIstekleriEkrani(), _doluTasima());
      expect(find.text('Gelen · 1'), findsOneWidget);
      // Gelen satırında "Reddet" ve "Kabul et"; geri çekme yok.
      expect(find.text(arbMetni('arkadas_reddet')), findsOneWidget);
      expect(find.text(arbMetni('arkadas_geri_cek')), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      await _ac(tester, const ArkadasIstekleriEkrani(), arkadasTasimasi());
      expect(find.text(arbMetni('arkadas_istekler_gelen')), findsOneWidget);
    });

    testWidgets('ilk sayfa doluysa seçicide "Gelen · N+"', (tester) async {
      ekranBoyutu(tester);
      final tasima = arkadasTasimasi({
        'GET $isteklerYolu': yanit(
          arkadasListesiJson([
            arkadasJson(kisiId1, durum: 'incoming'),
          ], sonraki: 'sonraki-sayfa'),
        ),
      });
      await _ac(tester, const ArkadasIstekleriEkrani(), tasima);
      expect(find.text('Gelen · 1+'), findsOneWidget);
    });

    testWidgets('isteğin adı ve tarihi profil açan tek düğme', (tester) async {
      ekranBoyutu(tester);
      await _ac(tester, const ArkadasIstekleriEkrani(), _doluTasima());
      expect(
        find.ancestor(
          of: find.text(kisiAdi(kisiId1)),
          matching: find.byType(ListeKartiSatiri),
        ),
        findsOneWidget,
      );
    });

    testWidgets('engellenen satırı avatarlı, eylem çerçeveli', (tester) async {
      ekranBoyutu(tester);
      await _ac(tester, const EngellenenlerEkrani(), _doluTasima());
      expect(find.byType(EylemliSatir), findsNWidgets(2));
      expect(
        find.widgetWithText(
          CerceveliHapEylem,
          arbMetni('arkadas_engel_kaldir'),
        ),
        findsNWidgets(2),
      );
    });

    testWidgets('katılım geçmişin: görünürlük kancası ve ay grupları', (
      tester,
    ) async {
      ekranBoyutu(tester);
      const kanca = 'gorunurluk-kancasi';
      await _ac(
        tester,
        const KatilimlarimEkrani(),
        _doluTasima(),
        ek: [
          katilimGorunurlukSatiriProvider.overrideWithValue(
            (context) => const Text(kanca),
          ),
        ],
      );
      expect(find.text(kanca), findsOneWidget);
      // İki kayıt da aynı ayda: tek ay başlığı, tek kart.
      expect(find.byType(BolumEtiketi), findsOneWidget);
      expect(find.byType(KatilimSatiri), findsNWidgets(2));
    });

    testWidgets('kanca verilmezse görünürlük satırı yok', (tester) async {
      ekranBoyutu(tester);
      await _ac(tester, const KatilimlarimEkrani(), _doluTasima());
      expect(find.byType(KatilimSatiri), findsNWidgets(2));
    });

    testWidgets('katılımlar aya göre gruplanır; başlıkta yıl gerekirse', (
      tester,
    ) async {
      ekranBoyutu(tester);
      late AppLocalizations m;
      await _ac(
        tester,
        Builder(
          builder: (context) {
            m = AppLocalizations.of(context);
            return const SizedBox.shrink();
          },
        ),
        arkadasTasimasi(),
      );
      ActivityRecord kayit(DateTime yerel) => ActivityRecord.fromJson({
        ...kayitJson(),
        'started_at': yerel.toUtc().toIso8601String(),
      });
      final gruplar = katilimAylari([
        kayit(DateTime(2026, 11, 8, 9)),
        kayit(DateTime(2026, 11, 1, 0, 30)),
        kayit(DateTime(2026, 10, 31, 23, 30)),
        kayit(DateTime(2025, 12, 20)),
      ]);
      expect(gruplar.map((g) => g.$1), [
        DateTime(2026, 11),
        DateTime(2026, 10),
        DateTime(2025, 12),
      ]);
      expect(gruplar.map((g) => g.$2.length), [2, 1, 1]);
      final simdi = DateTime(2026, 11, 13);
      expect(katilimAyi(m, DateTime(2026, 11), simdi), 'Kasım');
      expect(katilimAyi(m, DateTime(2025, 12), simdi), 'Aralık 2025');
    });
  });

  group('katılım geçmişi', () {
    testWidgets('profil özeti son 3 kaydı ister, "Tümünü gör" çalışır', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = _doluTasima();
      var tumu = 0;
      await _ac(
        tester,
        Scaffold(
          body: KatilimOzeti(
            kullaniciId: benimId,
            bosMetin: arbMetni('arkadas_gecmis_kendi_bos'),
            onTumu: () => tumu++,
          ),
        ),
        tasima,
      );
      final istek = tasima.giden('GET', gecmisYolu).single;
      expect(istek.yolParametreleri['user_id'], benimId);
      expect(istek.sorgu['page_size'], '3');
      expect(find.byType(KatilimSatiri), findsNWidgets(2));
      await _dokun(tester, find.text(arbMetni('arkadas_gecmis_tumu')));
      expect(tumu, 1);
    });

    testWidgets('boşsa boş metni', (tester) async {
      ekranBoyutu(tester);
      await _ac(
        tester,
        Scaffold(
          body: KatilimOzeti(
            kullaniciId: benimId,
            bosMetin: arbMetni('arkadas_gecmis_kendi_bos'),
            onTumu: () {},
          ),
        ),
        arkadasTasimasi(),
      );
      expect(find.text(arbMetni('arkadas_gecmis_kendi_bos')), findsOneWidget);
      expect(find.text(arbMetni('arkadas_gecmis_tumu')), findsNothing);
    });

    testWidgets('tarih bu yılsa yılsız, değilse yıllı', (tester) async {
      ekranBoyutu(tester);
      late AppLocalizations m;
      await _ac(
        tester,
        Builder(
          builder: (context) {
            m = AppLocalizations.of(context);
            return const SizedBox.shrink();
          },
        ),
        arkadasTasimasi(),
      );
      final simdi = DateTime(2026, 11, 13);
      expect(katilimTarihi(m, DateTime(2026, 11, 8), simdi), '8 Kas');
      expect(katilimTarihi(m, DateTime(2025, 11, 8), simdi), '8 Kas 2025');
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

      yonlendirici.go(Adresler.katilimlarim);
      await tester.pumpAndSettle();
      expect(find.byType(KatilimlarimEkrani), findsOneWidget);
    });
  });
}
