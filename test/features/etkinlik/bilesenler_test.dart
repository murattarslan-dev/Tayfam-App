import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/realtime/realtime.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_detayi.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_sihirbazi.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_taslagi.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_bolumleri.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_durumu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_formu.dart';
import 'package:tayfam/features/etkinlik/bilesenler/bilesen_parametreleri.dart';
import 'package:tayfam/features/etkinlik/bilesenler/etkinlik_bileseni.dart';
import 'package:tayfam/features/etkinlik/data/etkinlik_deposu.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_detay_ekrani.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_sihirbazi_ekrani.dart';

import '../../core/katalog/sahte_katalog.dart';
import '../../core/realtime/sahte_soket.dart';
import '../../core/zaman_sahteleri.dart';
import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';
import 'sahteler.dart';

const List<ThemeMode> _temalar = [ThemeMode.light, ThemeMode.dark];

const String _tur = 'ornek_bilesenler';

const List<String> _modlar = ['random', 'balanced', 'manual'];

/// Test kaydı: temel buluşma noktası, isteğe bağlı yoklama ve seçimli
/// takım kurma. `manual` seçeneğinin adı yoktur (tanınmayan seçenek).
const List<EtkinlikBileseni> _kayit = [
  TemelBilesen('meeting_point'),
  SahteBilesen('roll_call'),
  SahteBilesen(
    'teams',
    param: 'mode',
    etiketler: {'random': 'Rastgele', 'balanced': 'Dengeli'},
  ),
];

const EtkinlikAnahtari _anahtar = (
  tayfaId: ornekTayfaId,
  etkinlikId: ornekEtkinlikId,
);

CatalogComponent _bilesen(String anahtar) =>
    turBilesenleri(testTuru(_tur))
        .firstWhere((b) => bilesenAnahtari(b) == anahtar);

Map<String, Object?> _durum({
  bool? yoklama = false,
  String mod = 'manual',
  bool kilitli = false,
  bool yonetebilir = false,
}) => bilesenlerJson(
  bilesenler: [
    bilesenDurumuJson('roll_call', acik: yoklama),
    bilesenDurumuJson('teams', secimler: {'mode': (mod, _modlar)}),
  ],
  kilitli: kilitli,
  yonetebilir: yonetebilir,
);

Future<void> _git(
  WidgetTester tester,
  SahteTayfaTasima tasima,
  String adres, {
  ThemeMode themeMode = ThemeMode.light,
  SahteBaglantiAcici? baglanti,
}) async {
  await uygulamayiAc(
    tester,
    themeMode: themeMode,
    tayfa: etkinlikOverridelari(
      tasima: tasima,
      baglanti: baglanti,
      bilesenler: _kayit,
    ),
  );
  yonlendiriciyiAl(tester).go(adres);
  await tester.pumpAndSettle();
}

Future<void> _gorunurDokun(WidgetTester tester, Finder bulucu) async {
  await tester.scrollUntilVisible(
    bulucu,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(bulucu);
  await tester.pumpAndSettle();
}

Finder _formdaki(Type tur) => find.descendant(
  of: find.byType(BilesenFormBolumleri),
  matching: find.byType(tur),
);

void main() {
  group('etkinlik detayı', () {
    for (final tema in _temalar) {
      testWidgets('bileşenler tanımdaki sırayla; tanınmayan için güncelle '
          'kartı; kapalı bileşen çizilmez (${tema.name}, 2× yazı)', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final baglanti = SahteBaglantiAcici();
        final tasima = etkinlikTasimasi({
          'GET $etkinlikYolu': (_) => etkinlikJson(tur: _tur, cevap: 'going'),
          'GET $bilesenlerYolu': (_) => _durum(),
        });
        await _git(
          tester,
          tasima,
          Adresler.etkinlik(ornekTayfaId, ornekEtkinlikId),
          themeMode: tema,
          baglanti: baglanti,
        );

        expect(find.byType(EtkinlikDetayEkrani), findsOneWidget);
        expect(tester.takeException(), isNull);
        // Büyük yazıda bölümler ekranın altında kalır; liste oraya kadar
        // kaydırılınca çizilir.
        await tester.scrollUntilVisible(
          find.textContaining('bileşen teams'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        // Kayıttaki bileşen: rolü ve organizatörün seçimiyle. Kapalı
        // (optional, organizatör kapatmış) yoklama çizilmez.
        final cizilenler = tester
            .widgetList<Text>(find.textContaining('bileşen '))
            .map((metin) => metin.data)
            .toList();
        expect(cizilenler, [
          SahteBilesen.detayMetni('teams', BilesenRolu.katilimci, {
            'mode': 'manual',
          }),
        ]);
        // Tanınmayan bileşenlerin hepsi için tek kart.
        final kart = tester.widget<BilesenGuncelleKarti>(
          find.byType(BilesenGuncelleKarti),
        );
        expect(kart.sayi, 17);
        expect(
          find.text(arbMetni('bilesen_guncelle_aciklama')),
          findsOneWidget,
        );
        expect(tasima.giden('GET', bilesenlerYolu), hasLength(1));

        await _gorunurDokun(
          tester,
          find.text(arbMetni('bilesen_guncelle_magaza')),
        );
        expect(baglanti.adresler.single.host, 'play.google.com');
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('açılan bileşen çizilir; atanmış kullanıcı hakemdir', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = etkinlikTasimasi({
        'GET $etkinlikYolu': (_) => etkinlikJson(tur: _tur),
        'GET $bilesenlerYolu': (_) => _durum(yoklama: true, mod: 'uydurma'),
        'GET $hakemlerYolu': (_) => hakemlerJson([katilimciId]),
        'GET $hesapYolu': (_) => hesapJson(katilimciId),
      });
      await _git(
        tester,
        tasima,
        Adresler.etkinlik(ornekTayfaId, ornekEtkinlikId),
      );
      expect(
        find.text(SahteBilesen.detayMetni('roll_call', BilesenRolu.hakem)),
        findsOneWidget,
      );
      // Tanımda olmayan seçenek varsayılana çekilir.
      expect(
        find.text(
          SahteBilesen.detayMetni('teams', BilesenRolu.hakem, {
            'mode': 'balanced',
          }),
        ),
        findsOneWidget,
      );
    });

    testWidgets('durum okunamazsa hata; "Tekrar dene" ile gelir', (
      tester,
    ) async {
      ekranBoyutu(tester);
      var bagli = false;
      final tasima = etkinlikTasimasi({
        'GET $etkinlikYolu': (_) => etkinlikJson(tur: _tur),
        'GET $bilesenlerYolu': (_) => bagli ? _durum() : const ApiOffline(),
      });
      await _git(
        tester,
        tasima,
        Adresler.etkinlik(ornekTayfaId, ornekEtkinlikId),
      );
      expect(find.byType(EtkinlikDetayEkrani), findsOneWidget);
      expect(find.byType(BilesenGuncelleKarti), findsNothing);
      expect(find.textContaining('bileşen teams'), findsNothing);

      bagli = true;
      await _gorunurDokun(
        tester,
        find.descendant(
          of: find.byType(EtkinlikBilesenBolumleri),
          matching: find.text(arbMetni('etkinlik_tekrar_dene')),
        ),
      );
      expect(find.textContaining('bileşen teams'), findsOneWidget);
      expect(find.byType(BilesenGuncelleKarti), findsOneWidget);
    });

    testWidgets('Faz 1 türünde bileşen durumu okunmaz, kart çıkmaz', (
      tester,
    ) async {
      ekranBoyutu(tester);
      // Balık hâlâ Faz 1 türü (`BalikTuru`); `log` kayıtta yok.
      final tasima = etkinlikTasimasi({
        'GET $etkinlikYolu': (_) => etkinlikJson(tur: 'fishing'),
      });
      await _git(
        tester,
        tasima,
        Adresler.etkinlik(ornekTayfaId, ornekEtkinlikId),
      );
      expect(find.byType(EtkinlikDetayEkrani), findsOneWidget);
      expect(find.byType(BilesenGuncelleKarti), findsNothing);
      expect(tasima.giden('GET', bilesenlerYolu), isEmpty);
    });
  });

  group('sihirbazdaki bileşen bölümleri', () {
    Future<void> ac(
      WidgetTester tester, {
      ThemeMode tema = ThemeMode.light,
      BilesenSecimleri secimler = const {},
      bool kilitli = false,
      List<(String, bool)>? acKapa,
      List<(String, String, String)>? secim,
    }) => widgetAc(
      tester,
      Scaffold(
        body: SingleChildScrollView(
          child: BilesenFormBolumleri(
            tanim: testTuru(_tur),
            secimler: secimler,
            kilitli: kilitli,
            onAcKapa: (b, acik) => acKapa?.add((bilesenAnahtari(b), acik)),
            onSecim: (b, param, deger) =>
                secim?.add((bilesenAnahtari(b), param, deger)),
          ),
        ),
      ),
      themeMode: tema,
      tayfa: etkinlikOverridelari(
        tasima: etkinlikTasimasi(),
        bilesenler: _kayit,
      ),
    );

    for (final tema in _temalar) {
      testWidgets('optional aç/kapa satırı ve tek seçim '
          '(${tema.name}, 2× yazı)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final acKapa = <(String, bool)>[];
        final secim = <(String, String, String)>[];
        await ac(tester, tema: tema, acKapa: acKapa, secim: secim);
        expect(tester.takeException(), isNull);

        // Yoklama isteğe bağlı ve varsayılan kapalı: satır var, kapalı.
        expect(find.text('Sahte roll_call'), findsOneWidget);
        final anahtar = tester.widget<Switch>(find.byType(Switch));
        expect(anahtar.value, isFalse);
        // Takım kurma: tanınan seçenekler; varsayılan seçili.
        expect(find.text('Rastgele'), findsOneWidget);
        expect(find.text('manual'), findsNothing);
        expect(find.byType(ChoiceChip), findsNWidgets(2));
        expect(
          tester
              .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Dengeli'))
              .selected,
          isTrue,
        );
        expect(find.text(arbMetni('bilesen_secim_kilitli')), findsNothing);

        await tester.tap(find.byType(Switch));
        await tester.ensureVisible(find.text('Rastgele'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Rastgele'));
        await tester.pumpAndSettle();
        expect(acKapa, [('roll_call', true)]);
        expect(secim, [('teams', 'mode', 'random')]);
        expect(tester.takeException(), isNull);
      });

      testWidgets('seçim kilidi: salt okunur ve nedeni yazılı '
          '(${tema.name}, 2× yazı)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        final acKapa = <(String, bool)>[];
        final secim = <(String, String, String)>[];
        await ac(
          tester,
          tema: tema,
          kilitli: true,
          secimler: const {
            'roll_call': BilesenSecimi(acik: true),
            'teams': BilesenSecimi(secimler: {'mode': 'random'}),
          },
          acKapa: acKapa,
          secim: secim,
        );
        expect(tester.takeException(), isNull);
        expect(find.text(arbMetni('bilesen_secim_kilitli')), findsOneWidget);
        final anahtar = tester.widget<Switch>(find.byType(Switch));
        expect(anahtar.value, isTrue);
        expect(anahtar.onChanged, isNull);
        final cip = tester.widget<ChoiceChip>(
          find.widgetWithText(ChoiceChip, 'Rastgele'),
        );
        expect(cip.selected, isTrue);
        expect(cip.onSelected, isNull);

        await tester.tap(find.byType(Switch), warnIfMissed: false);
        await tester.pumpAndSettle();
        expect(acKapa, isEmpty);
        expect(secim, isEmpty);
      });
    }

    testWidgets('düzenleme ekranı: başlamış etkinlikte seçimler kilitli', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = etkinlikTasimasi({
        'GET $etkinlikYolu': (_) => etkinlikJson(tur: _tur, yonetebilir: true),
        'GET $bilesenlerYolu': (_) =>
            _durum(yoklama: true, kilitli: true, yonetebilir: true),
      });
      await _git(
        tester,
        tasima,
        Adresler.etkinlikDuzenle(ornekTayfaId, ornekEtkinlikId),
      );
      expect(find.byType(EtkinlikSihirbaziEkrani), findsOneWidget);
      await _gorunurDokun(tester, find.text(arbMetni('etkinlik_ileri')));
      await _gorunurDokun(tester, find.text(arbMetni('etkinlik_ileri')));

      await tester.scrollUntilVisible(
        find.text(arbMetni('bilesen_secim_kilitli')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.byType(BilesenFormBolumleri), findsOneWidget);
      expect(find.text(arbMetni('bilesen_secim_kilitli')), findsOneWidget);
      final anahtar = tester.widget<Switch>(_formdaki(Switch));
      expect(anahtar.value, isTrue);
      expect(anahtar.onChanged, isNull);
      expect(tasima.giden('PUT', bilesenYolu), isEmpty);
    });
  });

  group('sihirbaz', () {
    const nokta = LatLng(lat: 40.6, lng: 31.28);

    ProviderContainer kapsayici(SahteTayfaTasima tasima) {
      final c = ProviderContainer(
        overrides: etkinlikOverridelari(tasima: tasima, bilesenler: _kayit),
      );
      addTearDown(c.dispose);
      return c;
    }

    test('oluşturma: seçimler `components` ile gider; tür değişince '
        'bırakılır', () async {
      const SihirbazAnahtari anahtar = (
        tayfaId: ornekTayfaId,
        duzenlenen: null,
      );
      final tasima = etkinlikTasimasi({
        'POST $etkinliklerYolu': (_) => etkinlikJson(tur: _tur),
      });
      final c = kapsayici(tasima);
      c.listen(etkinlikSihirbaziProvider(anahtar), (_, _) {});
      final n = c.read(etkinlikSihirbaziProvider(anahtar).notifier);
      EtkinlikTaslagi t() => c.read(etkinlikSihirbaziProvider(anahtar));

      n
        ..turSec(testTuru(_tur))
        ..bilesenAcKapat(_bilesen('roll_call'), acik: true);
      expect(t().bilesenler, isNotEmpty);
      n.turSec(testTuru('general'));
      expect(t().bilesenler, isEmpty);
      // Seçilen türde olmayan bileşen yok sayılır.
      n.bilesenAcKapat(_bilesen('roll_call'), acik: true);
      expect(t().bilesenler, isEmpty);

      n
        ..turSec(testTuru(_tur))
        ..ileri()
        ..baslikAyarla('Turnuva')
        ..baslangicAyarla(ornekBaslangic)
        ..ileri()
        ..noktaSec(nokta, ad: 'Abant Gölü', il: 'Bolu', ilce: 'Merkez')
        ..ileri()
        ..bilesenAcKapat(_bilesen('roll_call'), acik: true)
        ..bilesenSec(_bilesen('teams'), 'mode', 'manual')
        ..bilesenSec(_bilesen('teams'), 'mode', 'uydurma')
        ..ileri();
      await n.gonder();

      expect(t().sonuc, ornekEtkinlikId);
      final govde =
          tasima.giden('POST', etkinliklerYolu).single.govde!
              as Map<String, Object?>;
      expect(govde['components'], [
        {'key': 'roll_call', 'enabled': true},
        {
          'key': 'teams',
          'choices': [
            {'param': 'mode', 'value': 'manual'},
          ],
        },
      ]);
    });

    ({
      EtkinlikSihirbaziNotifier n,
      EtkinlikTaslagi Function() t,
      SahteTayfaTasima tasima,
    })
    duzenleme(Map<String, Object?> durum, {Object? putYaniti}) {
      final eski = ornekEtkinlik(tur: _tur, yonetebilir: true);
      final SihirbazAnahtari anahtar = (
        tayfaId: ornekTayfaId,
        duzenlenen: eski,
      );
      final tasima = etkinlikTasimasi({
        'PUT $bilesenYolu': (_) => putYaniti ?? _durum(yoklama: true),
      });
      final c = kapsayici(tasima);
      c.listen(etkinlikSihirbaziProvider(anahtar), (_, _) {});
      final n = c.read(etkinlikSihirbaziProvider(anahtar).notifier);
      EtkinlikTaslagi t() => c.read(etkinlikSihirbaziProvider(anahtar));
      // Durum okunmadan seçim yapılamaz.
      n
        ..tanimGeldi(testTuru(_tur))
        ..bilesenAcKapat(_bilesen('roll_call'), acik: true);
      expect(t().bilesenlerOkundu, isFalse);
      expect(t().bilesenler, isEmpty);
      n.bilesenDurumuGeldi(EventComponentList.fromJson(durum));
      expect(t().bilesenlerOkundu, isTrue);
      expect(n.girdiVar, isFalse, reason: 'okunan durum girdi sayılmaz');
      return (n: n, t: t, tasima: tasima);
    }

    test('düzenleme: değişen seçim PUT ile gider, PATCH gitmez', () async {
      final (:n, :t, :tasima) = duzenleme(_durum(yonetebilir: true));
      expect(t().bilesenlerKilitli, isFalse);
      n
        ..bilesenAcKapat(_bilesen('roll_call'), acik: true)
        ..bilesenSec(_bilesen('teams'), 'mode', 'random');
      expect(n.girdiVar, isTrue);
      await n.gonder();

      expect(t().sonuc, ornekEtkinlikId);
      final istekler = tasima.giden('PUT', bilesenYolu);
      expect(istekler.map((i) => i.yolParametreleri['component_key']), [
        'roll_call',
        'teams',
      ]);
      expect(istekler[0].govde, {'enabled': true});
      expect(istekler[1].govde, {
        'choices': [
          {'param': 'mode', 'value': 'random'},
        ],
      });
      expect(tasima.giden('PATCH', etkinlikYolu), isEmpty);
    });

    test(
      'seçim kilidi: kilitli durumda seçim değişmez ve gönderilmez',
      () async {
        final (:n, :t, :tasima) = duzenleme(
          _durum(kilitli: true, yonetebilir: true),
        );
        expect(t().bilesenlerKilitli, isTrue);
        n
          ..bilesenAcKapat(_bilesen('roll_call'), acik: true)
          ..bilesenSec(_bilesen('teams'), 'mode', 'random');
        expect(n.girdiVar, isFalse);
        await n.gonder();
        expect(tasima.giden('PUT', bilesenYolu), isEmpty);
      },
    );

    test('yönetemeyen için de seçimler salt okunur', () {
      final (n: _, :t, tasima: _) = duzenleme(_durum());
      expect(t().bilesenlerKilitli, isTrue);
    });

    test(
      'sunucu component-locked derse hata gösterilir, PATCH gitmez',
      () async {
        final (:n, :t, :tasima) = duzenleme(
          _durum(yonetebilir: true),
          putYaniti: const ApiProblem(
            type: ProblemType.componentLocked,
            status: 409,
          ),
        );
        n
          ..baslikAyarla('Yeni başlık')
          ..bilesenAcKapat(_bilesen('roll_call'), acik: true);
        await n.gonder();
        expect(t().sonuc, isNull);
        expect(
          t().hata,
          isA<ApiProblem>().having(
            (p) => p.type,
            'type',
            ProblemType.componentLocked,
          ),
        );
        expect(tasima.giden('PATCH', etkinlikYolu), isEmpty);
      },
    );
  });

  group('canlı bileşen aboneliği', () {
    const BilesenKimligi takim = (
      tayfaId: ornekTayfaId,
      etkinlikId: ornekEtkinlikId,
      anahtar: 'teams',
    );

    test('ekran açıkken izlenir; çerçeve gelince REST\'ten yeniden okunur; '
        'kapanınca izleme bırakılır', () async {
      final tasima = etkinlikTasimasi();
      final zaman = SahteZamanlayici();
      final soketler = <SahteSoket>[];
      final realtime = RealtimeIstemcisi(
        adres: Uri.parse('wss://api.ornek.test/v1/realtime'),
        baglayici: (adres, basliklar) {
          final s = SahteSoket(adres, basliklar);
          soketler.add(s);
          return s;
        },
        tokenAl: () async => 'token',
        reddedildi: (_) async => 'token',
        oturumuKapat: () async {},
        zamanlayici: zaman.kur,
        rastgele: Random(1),
        gunluk: (_) {},
      );
      final c = ProviderContainer(
        overrides: [
          etkinlikDeposuProvider.overrideWithValue(EtkinlikDeposu(tasima)),
          realtimeIstemcisiProvider.overrideWithValue(realtime),
        ],
      );
      addTearDown(c.dispose);
      addTearDown(realtime.dispose);
      int okuma() => tasima.giden('GET', bilesenlerYolu).length;
      Future<void> bekle() async {
        await pumpEventQueue();
        await c.read(etkinlikBilesenleriProvider(_anahtar).future);
      }

      final durum = c.listen(etkinlikBilesenleriProvider(_anahtar), (_, _) {});
      final sayac = c.listen(bilesenDegisimiProvider(takim), (_, _) {});
      await bekle();
      expect(okuma(), 1);

      // Bağlanınca etkinlik bir kez izlenir ve kaçırılanlar için yeniden
      // okunur.
      realtime.baslat();
      await pumpEventQueue();
      final soket = soketler.single;
      await soket.ac();
      await bekle();
      expect(soket.tur('event.watch'), hasLength(1));
      expect(okuma(), 2);
      expect(sayac.read(), 1);

      // Anahtarsız çerçeve: seçimler ya da hakemler değişti.
      soket.cerceve('event.component_changed', {
        'tayfa_id': ornekTayfaId,
        'event_id': ornekEtkinlikId,
      });
      await bekle();
      expect(okuma(), 3);
      expect(sayac.read(), 1);

      // Bileşenin çerçevesi yalnızca o bileşenin sayacını artırır.
      soket
        ..cerceve('event.component_changed', {
          'tayfa_id': ornekTayfaId,
          'event_id': ornekEtkinlikId,
          'component_key': 'teams',
        })
        // Başka etkinliğin çerçevesi yok sayılır.
        ..cerceve('event.component_changed', {
          'tayfa_id': ornekTayfaId,
          'event_id': ikinciEtkinlikId,
          'component_key': 'teams',
        });
      await bekle();
      expect(okuma(), 3);
      expect(sayac.read(), 2);

      durum.close();
      sayac.close();
      await c.pump();
      await pumpEventQueue();
      expect(soket.tur('event.unwatch'), hasLength(1));
      expect(realtime.izlenenler, isEmpty);
    });
  });
}
