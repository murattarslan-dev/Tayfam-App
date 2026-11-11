import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:tayfam/app.dart';
import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/moduller/birebir_sikayet.dart';
import 'package:tayfam/core/tema/tayfam_theme.dart';
import 'package:tayfam/features/arkadas/arkadas.dart';
import 'package:tayfam/features/birebir/birebir.dart';
import 'package:tayfam/features/birebir/presentation/kisi_konusmasi_ekrani.dart';
import 'package:tayfam/features/birebir/presentation/konusma_ekrani.dart';
import 'package:tayfam/features/birebir/presentation/mesaj_istekleri_ekrani.dart';
import 'package:tayfam/features/birebir/presentation/reddedilenler_ekrani.dart';
import 'package:tayfam/features/sohbet/sohbet.dart';
import 'package:tayfam/l10n/app_localizations.dart';

import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';
import 'sahteler.dart';

Future<void> _ac(
  WidgetTester tester,
  Widget ekran,
  SahteTayfaTasima tasima, {
  ThemeMode tema = ThemeMode.light,
  List<Override> ek = const [],
}) => widgetAc(
  tester,
  ekran,
  themeMode: tema,
  tayfa: birebirEkranOverridelari(tasima),
  overrides: ek,
);

/// Konuşma 1: Deniz'den bir mesaj ve kullanıcının bir mesajı.
SahteTayfaTasima _konusmaTasimasi({
  String durum = 'active',
  String? karsi = karsiId,
  String? karsiOkundu,
  Map<String, TayfaYaniti> ek = const {},
}) => birebirTasimasi({
  'GET $konusmaYolu': (_) => konusmaJson(
    konusmaId1,
    durum: durum,
    karsi: karsi,
    karsiOkundu: karsiOkundu,
  ),
  'GET $mesajlarYolu': (_) => mesajListesiJson([
    mesajJson(
      mesajId2,
      gonderen: karsi,
      metin: 'Pazar geliyor musun?',
      zaman: '2026-11-10T11:00:00Z',
    ),
    mesajJson(mesajId1, gonderen: benId, metin: 'Merhaba'),
  ]),
  ...ek,
});

/// Şikâyet kancasına verilenler.
final class _SikayetKaydi {
  final List<(String, String)> cagrilar = [];

  Override get override => birebirMesajSikayetiProvider.overrideWithValue((
    context, {
    required mesajId,
    required metin,
  }) async {
    cagrilar.add((mesajId, metin));
  });
}

void main() {
  group('konuşmalar', () {
    testWidgets('konuşmalar, istek girişi ve okunmamış rozeti', (tester) async {
      ekranBoyutu(tester, yukseklik: 1000);
      await _ac(
        tester,
        const Scaffold(body: BirebirSekmesi()),
        birebirTasimasi({
          'GET $konusmalarYolu': (_) => konusmaListesiJson([
            konusmaJson(konusmaId1, okunmamis: 120),
            konusmaJson(
              konusmaId2,
              karsi: digerId,
              durum: 'request_received',
              okunmamis: 1,
            ),
            konusmaJson(konusmaId3, karsi: null, durum: 'request_sent'),
          ]),
        }),
      );

      expect(find.text('Deniz'), findsOneWidget);
      // İstek ana listede değil, istek girişinde sayılır.
      expect(find.text('Ece'), findsNothing);
      expect(find.text(arbMetni('birebir_istekler_baslik')), findsOneWidget);
      expect(find.text(arbMetni('gezinme_rozet_cok')), findsOneWidget);
      expect(find.text(arbMetni('kullanici_silinmis')), findsOneWidget);
      expect(
        find.text(arbMetni('birebir_durum_istek_gonderildi')),
        findsOneWidget,
      );
    });

    testWidgets('konuşma yoksa boş durum', (tester) async {
      ekranBoyutu(tester);
      await _ac(tester, const Scaffold(body: BirebirSekmesi()), birebirTasimasi());
      expect(find.text(arbMetni('birebir_bos')), findsOneWidget);
    });

    testWidgets('okunamazsa hata satırı ve tekrar dene', (tester) async {
      ekranBoyutu(tester);
      var deneme = 0;
      await _ac(
        tester,
        const Scaffold(body: BirebirSekmesi()),
        birebirTasimasi({
          'GET $konusmalarYolu': (_) => deneme++ == 0
              ? const ApiOffline()
              : konusmaListesiJson([konusmaJson(konusmaId1)]),
        }),
      );
      expect(find.text(arbMetni('hata_baglanti_yok')), findsOneWidget);

      await tester.tap(find.text(arbMetni('birebir_tekrar_dene')));
      await tester.pumpAndSettle();
      expect(find.text('Deniz'), findsOneWidget);
    });
  });

  group('konuşma', () {
    testWidgets('mesajlar görünüyor ve konuşma okundu işaretleniyor', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = _konusmaTasimasi(karsiOkundu: mesajId1);
      await _ac(tester, const KonusmaEkrani(konusmaId: konusmaId1), tasima);

      expect(find.text('Deniz'), findsOneWidget);
      expect(find.text('Merhaba'), findsOneWidget);
      expect(find.text('Pazar geliyor musun?'), findsOneWidget);
      expect(find.text(arbMetni('birebir_goruldu')), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Merhaba')).dy,
        lessThan(tester.getTopLeft(find.text('Pazar geliyor musun?')).dy),
      );
      expect(tasima.giden('PUT', okunduYolu).single.govde, {
        'message_id': mesajId2,
      });
    });

    testWidgets('mesaj gönderiliyor ve alan temizleniyor', (tester) async {
      ekranBoyutu(tester);
      final tasima = _konusmaTasimasi(
        ek: {
          'POST $gonderYolu': (_) => {
            'message': mesajJson(
              mesajId3,
              gonderen: benId,
              metin: 'Geliyorum',
              zaman: '2026-11-10T12:00:00Z',
            ),
            'conversation': konusmaJson(konusmaId1),
          },
        },
      );
      await _ac(tester, const KonusmaEkrani(konusmaId: konusmaId1), tasima);

      await tester.enterText(find.byType(TextField), 'Geliyorum');
      await tester.tap(find.byTooltip(arbMetni('birebir_gonder')));
      await tester.pumpAndSettle();

      expect(find.text('Geliyorum'), findsOneWidget);
      expect(find.text(arbMetni('birebir_gonderiliyor')), findsNothing);
      final alan = tester.widget<TextField>(find.byType(TextField));
      expect(alan.controller!.text, isEmpty);
      expect(
        (tasima.giden('POST', gonderYolu).single.govde!
            as Map<String, Object?>)['body'],
        'Geliyorum',
      );
    });

    testWidgets('gönderilemeyen mesajda hata, tekrar dene ve sil', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = _konusmaTasimasi(
        ek: {
          'POST $gonderYolu': (_) => const ApiProblem(
            type: ProblemType.directMessageNotAllowed,
            status: 403,
          ),
        },
      );
      await _ac(tester, const KonusmaEkrani(konusmaId: konusmaId1), tasima);

      await tester.enterText(find.byType(TextField), 'Geliyorum');
      await tester.tap(find.byTooltip(arbMetni('birebir_gonder')));
      await tester.pumpAndSettle();

      expect(find.text(arbMetni('birebir_gonderilemedi')), findsOneWidget);
      expect(
        find.text(arbMetni('hata_direct_message_not_allowed')),
        findsOneWidget,
      );
      await tester.tap(find.text(arbMetni('birebir_bekleyeni_sil')));
      await tester.pumpAndSettle();
      expect(find.text('Geliyorum'), findsNothing);
    });

    testWidgets('kendi mesajını uzun basıp siliyor', (tester) async {
      ekranBoyutu(tester);
      final tasima = _konusmaTasimasi(ek: {'DELETE $mesajYolu': (_) => null});
      await _ac(tester, const KonusmaEkrani(konusmaId: konusmaId1), tasima);

      await tester.longPress(find.text('Merhaba'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(arbMetni('birebir_mesaji_sil')));
      await tester.pumpAndSettle();
      expect(find.text(arbMetni('birebir_sil_onay_baslik')), findsOneWidget);
      await tester.tap(find.text(arbMetni('birebir_sil')));
      await tester.pumpAndSettle();

      expect(tasima.giden('DELETE', mesajYolu), hasLength(1));
      expect(find.text('Merhaba'), findsNothing);
      expect(find.text(arbMetni('birebir_mesaj_silindi')), findsOneWidget);
    });

    testWidgets('gelen mesaj şikâyet kancasına açık metniyle gidiyor', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final kayit = _SikayetKaydi();
      await _ac(
        tester,
        const KonusmaEkrani(konusmaId: konusmaId1),
        _konusmaTasimasi(),
        ek: [kayit.override],
      );

      await tester.longPress(find.text('Pazar geliyor musun?'));
      await tester.pumpAndSettle();
      // Başkasının mesajı silinemez.
      expect(find.text(arbMetni('birebir_mesaji_sil')), findsNothing);
      await tester.tap(find.text(arbMetni('birebir_sikayet_et')));
      await tester.pumpAndSettle();

      expect(kayit.cagrilar, [(mesajId2, 'Pazar geliyor musun?')]);
    });

    testWidgets('şikâyet kancası yoksa gelen mesajda işlem yok', (
      tester,
    ) async {
      ekranBoyutu(tester);
      await _ac(
        tester,
        const KonusmaEkrani(konusmaId: konusmaId1),
        _konusmaTasimasi(),
      );
      await tester.longPress(find.text('Pazar geliyor musun?'));
      await tester.pumpAndSettle();
      expect(find.text(arbMetni('birebir_sikayet_et')), findsNothing);
    });

    testWidgets('gelen istek bandı; kabul edince kalkıyor', (tester) async {
      ekranBoyutu(tester);
      final tasima = _konusmaTasimasi(
        durum: 'request_received',
        ek: {'POST $kabulYolu': (_) => konusmaJson(konusmaId1)},
      );
      await _ac(tester, const KonusmaEkrani(konusmaId: konusmaId1), tasima);

      expect(find.text(arbMetni('birebir_istek_geldi_bilgi')), findsOneWidget);
      await tester.tap(find.text(arbMetni('birebir_kabul_et')));
      await tester.pumpAndSettle();

      expect(tasima.giden('POST', kabulYolu), hasLength(1));
      expect(find.text(arbMetni('birebir_istek_geldi_bilgi')), findsNothing);
    });

    testWidgets('gönderilen istekte bilgi bandı', (tester) async {
      ekranBoyutu(tester);
      await _ac(
        tester,
        const KonusmaEkrani(konusmaId: konusmaId1),
        _konusmaTasimasi(durum: 'request_sent'),
      );
      expect(
        find.text(arbMetni('birebir_istek_bekliyor_bilgi')),
        findsOneWidget,
      );
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('silinmiş hesapta yazma alanı yok', (tester) async {
      ekranBoyutu(tester);
      await _ac(
        tester,
        const KonusmaEkrani(konusmaId: konusmaId1),
        _konusmaTasimasi(karsi: null),
      );
      expect(find.text(arbMetni('birebir_silinmis_bilgi')), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('konuşma bulunamazsa hata satırı', (tester) async {
      ekranBoyutu(tester);
      await _ac(
        tester,
        const KonusmaEkrani(konusmaId: konusmaId1),
        birebirTasimasi({
          'GET $konusmaYolu': (_) => const ApiProblem(
            type: ProblemType.conversationNotFound,
            status: 404,
          ),
        }),
      );
      expect(
        find.text(arbMetni('hata_conversation_not_found')),
        findsOneWidget,
      );
    });
  });

  group('istekler ve reddedilenler', () {
    testWidgets('mesaj istekleri yalnızca gelen istekleri gösteriyor', (
      tester,
    ) async {
      ekranBoyutu(tester);
      await _ac(
        tester,
        const MesajIstekleriEkrani(),
        birebirTasimasi({
          'GET $konusmalarYolu': (_) => konusmaListesiJson([
            konusmaJson(konusmaId1),
            konusmaJson(konusmaId2, karsi: digerId, durum: 'request_received'),
          ]),
        }),
      );
      expect(find.text('Ece'), findsOneWidget);
      expect(find.text('Deniz'), findsNothing);
      expect(find.text(arbMetni('birebir_reddedilenler')), findsOneWidget);
    });

    testWidgets('istek yokken boş durum', (tester) async {
      ekranBoyutu(tester);
      await _ac(tester, const MesajIstekleriEkrani(), birebirTasimasi());
      expect(find.text(arbMetni('birebir_istekler_bos')), findsOneWidget);
    });

    testWidgets('reddedilen listeden çıkarılıyor', (tester) async {
      ekranBoyutu(tester);
      final tasima = birebirTasimasi({
        'GET $reddedilenlerYolu': (_) => reddedilenlerJson([konusmaId2]),
        'DELETE $reddedilenYolu': (_) => null,
      });
      await _ac(tester, const ReddedilenlerEkrani(), tasima);
      expect(find.text('Ece'), findsOneWidget);

      await tester.tap(find.text(arbMetni('birebir_listeden_cikar')));
      await tester.pumpAndSettle();

      expect(tasima.giden('DELETE', reddedilenYolu).single.yolParametreleri, {
        'conversation_id': konusmaId2,
      });
      expect(find.text('Ece'), findsNothing);
      expect(find.text(arbMetni('birebir_listeden_cikarildi')), findsOneWidget);
    });
  });

  group('kişiyle konuşma', () {
    testWidgets('konuşma yoksa ilk mesaj yazılıyor ve konuşmaya geçiliyor', (
      tester,
    ) async {
      ekranBoyutu(tester);
      var gonderildi = false;
      final tasima = _konusmaTasimasi(
        ek: {
          'POST $gonderYolu': (_) {
            gonderildi = true;
            return {
              'message': mesajJson(mesajId1, gonderen: benId, metin: 'Selam'),
              'conversation': konusmaJson(konusmaId1, durum: 'request_sent'),
            };
          },
          'GET $mesajlarYolu': (_) => mesajListesiJson([
            if (gonderildi)
              mesajJson(mesajId1, gonderen: benId, metin: 'Selam'),
          ]),
          'GET $konusmaYolu': (_) =>
              konusmaJson(konusmaId1, durum: 'request_sent'),
        },
      );
      await _ac(
        tester,
        const KisiKonusmasiEkrani(kullaniciId: karsiId),
        tasima,
      );
      expect(
        find.text(arbMetni('birebir_yeni_konusma_aciklama')),
        findsOneWidget,
      );

      await tester.enterText(find.byType(TextField), 'Selam');
      await tester.tap(find.byTooltip(arbMetni('birebir_gonder')));
      await tester.pumpAndSettle();

      expect(find.byType(KonusmaEkrani), findsOneWidget);
      expect(find.text('Selam'), findsOneWidget);
      expect(
        find.text(arbMetni('birebir_istek_bekliyor_bilgi')),
        findsOneWidget,
      );
    });

    testWidgets('konuşma varsa doğrudan açılıyor', (tester) async {
      ekranBoyutu(tester);
      await _ac(
        tester,
        const KisiKonusmasiEkrani(kullaniciId: karsiId),
        _konusmaTasimasi(
          ek: {
            'GET $konusmalarYolu': (_) =>
                konusmaListesiJson([konusmaJson(konusmaId1)]),
          },
        ),
      );
      expect(find.byType(KonusmaEkrani), findsOneWidget);
      expect(find.text('Merhaba'), findsOneWidget);
    });
  });

  group('gezinme', () {
    testWidgets('Sohbet sekmesinden konuşma ve istekler açılıyor', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = _konusmaTasimasi(
        ek: {
          'GET $konusmalarYolu': (_) =>
              konusmaListesiJson([konusmaJson(konusmaId1)]),
        },
      );
      await uygulamayiAc(
        tester,
        birebir: [...birebirOverridelari(tasima), profilAdlari],
        overrides: [
          birebirBolumuProvider.overrideWithValue(
            (context) => const BirebirSekmesi(),
          ),
        ],
      );
      yonlendiriciyiAl(tester).go('/sohbet');
      await tester.pumpAndSettle();
      await tester.tap(find.text(arbMetni('sohbet_sekme_birebir')));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Deniz'));
      await tester.pumpAndSettle();
      expect(find.byType(KonusmaEkrani), findsOneWidget);
      expect(
        yonlendiriciyiAl(tester).routerDelegate.currentConfiguration.uri.path,
        '/sohbet/birebir/$konusmaId1',
      );
    });

    testWidgets('geçersiz kimlik Sohbet sekmesine dönüyor', (tester) async {
      ekranBoyutu(tester);
      await uygulamayiAc(tester);
      yonlendiriciyiAl(tester).go('/sohbet/birebir/gecersiz');
      await tester.pumpAndSettle();
      expect(
        yonlendiriciyiAl(tester).routerDelegate.currentConfiguration.uri.path,
        '/sohbet',
      );
      yonlendiriciyiAl(tester).go('/sohbet/kisi/gecersiz');
      await tester.pumpAndSettle();
      expect(find.byType(SohbetEkrani), findsOneWidget);
    });

    testWidgets('"Mesaj gönder" kişiyle konuşmanın adresine gidiyor', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final yonlendirici = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const Scaffold(
              body: Center(child: MesajGonderDugmesi(kullaniciId: karsiId)),
            ),
          ),
          GoRoute(
            path: '/sohbet/kisi/:id',
            builder: (context, state) =>
                Text('kisi-${state.pathParameters['id']}'),
          ),
        ],
      );
      addTearDown(yonlendirici.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          locale: TayfamApp.yerelAyar,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: TayfamTheme.acik(),
          routerConfig: yonlendirici,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(arbMetni('birebir_mesaj_gonder')));
      await tester.pumpAndSettle();
      expect(find.text('kisi-$karsiId'), findsOneWidget);
    });

    testWidgets('kişi profili eylemi arkadaşa ya da ortak tayfadakine', (
      tester,
    ) async {
      late BuildContext baglam;
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            baglam = context;
            return const SizedBox.shrink();
          },
        ),
      );
      KisiProfiliBilgisi kisi({bool arkadas = false, bool ortak = false}) =>
          KisiProfiliBilgisi(
            kullaniciId: karsiId,
            gorunenAd: 'Deniz',
            arkadas: arkadas,
            ortakTayfaVar: ortak,
          );
      expect(mesajGonderEylemi(baglam, kisi()), isNull);
      expect(
        mesajGonderEylemi(baglam, kisi(arkadas: true)),
        isA<MesajGonderDugmesi>(),
      );
      expect(
        mesajGonderEylemi(baglam, kisi(ortak: true)),
        isA<MesajGonderDugmesi>(),
      );
    });

    testWidgets('istek reddedilince mesaj isteklerine dönülüyor', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = _konusmaTasimasi(
        durum: 'request_received',
        ek: {
          'POST $retYolu': (_) => null,
          'GET $konusmalarYolu': (_) => konusmaListesiJson(const []),
        },
      );
      await uygulamayiAc(
        tester,
        birebir: [...birebirOverridelari(tasima), profilAdlari],
      );
      yonlendiriciyiAl(tester).go('/sohbet/birebir/$konusmaId1');
      await tester.pumpAndSettle();

      await tester.tap(find.text(arbMetni('birebir_reddet')));
      await tester.pumpAndSettle();
      expect(find.text(arbMetni('birebir_reddet_onay_baslik')), findsOneWidget);
      await tester.tap(find.text(arbMetni('birebir_reddet')).last);
      await tester.pumpAndSettle();

      expect(tasima.giden('POST', retYolu), hasLength(1));
      expect(find.byType(MesajIstekleriEkrani), findsOneWidget);
      expect(find.text(arbMetni('birebir_reddedildi')), findsOneWidget);
    });
  });

  for (final tema in [ThemeMode.light, ThemeMode.dark]) {
    group('${tema.name} temada 2× yazı ve 320 dp', () {
      testWidgets('konuşmalar taşmıyor', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await _ac(
          tester,
          const Scaffold(body: BirebirSekmesi()),
          birebirTasimasi({
            'GET $konusmalarYolu': (_) => konusmaListesiJson([
              konusmaJson(konusmaId1, okunmamis: 5),
              konusmaJson(konusmaId2, karsi: digerId, durum: 'request_sent'),
              konusmaJson(konusmaId3, durum: 'request_received'),
            ]),
          }),
          tema: tema,
        );
        expect(tester.takeException(), isNull);
      });

      testWidgets('istek konuşması ve gönderilemeyen mesaj taşmıyor', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await _ac(
          tester,
          const KonusmaEkrani(konusmaId: konusmaId1),
          _konusmaTasimasi(
            durum: 'request_received',
            ek: {
              'POST $gonderYolu': (_) => const ApiProblem(
                type: ProblemType.messageRequestLimit,
                status: 429,
              ),
            },
          ),
          tema: tema,
        );
        await tester.enterText(find.byType(TextField), 'Geliyorum');
        await tester.tap(find.byTooltip(arbMetni('birebir_gonder')));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });

      testWidgets('istekler, reddedilenler ve yeni konuşma taşmıyor', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final tasima = birebirTasimasi({
          'GET $konusmalarYolu': (_) => konusmaListesiJson([
            konusmaJson(konusmaId2, karsi: digerId, durum: 'request_received'),
          ]),
          'GET $reddedilenlerYolu': (_) => reddedilenlerJson([konusmaId3]),
        });
        for (final ekran in const <Widget>[
          MesajIstekleriEkrani(),
          ReddedilenlerEkrani(),
          KisiKonusmasiEkrani(kullaniciId: karsiId),
        ]) {
          // Her ekran kendi kapsamında açılır.
          await tester.pumpWidget(const SizedBox.shrink());
          await _ac(tester, ekran, tasima, tema: tema);
          expect(tester.takeException(), isNull, reason: '$ekran');
        }
      });
    });
  }
}
