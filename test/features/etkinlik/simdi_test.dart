import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tayfam/core/api/api_hatalari.dart';
import 'package:tayfam/core/api/gen/models.dart';
import 'package:tayfam/core/api/gen/problem_type.dart';
import 'package:tayfam/core/gezinme/adresler.dart';
import 'package:tayfam/core/zaman/zamanlayici.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_sihirbazi.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_taslagi.dart';
import 'package:tayfam/features/etkinlik/application/etkinlik_zamani.dart';
import 'package:tayfam/features/etkinlik/application/simdi_baslat.dart';
import 'package:tayfam/features/etkinlik/presentation/etkinlik_detay_ekrani.dart';
import 'package:tayfam/features/etkinlik/presentation/simdi/simdi_ekrani.dart';
import 'package:tayfam/features/etkinlik/presentation/simdi/suruyor.dart';
import 'package:tayfam/features/tayfa/tayfa.dart';
import 'package:tayfam/l10n/app_localizations.dart';

import '../../core/katalog/sahte_katalog.dart';
import '../../core/zaman_sahteleri.dart';
import '../../yardimcilar.dart';
import '../tayfa/sahteler.dart';
import 'sahteler.dart';

const List<ThemeMode> _temalar = [ThemeMode.light, ThemeMode.dark];

/// Anlık tayfanın örnek kimliği.
const String _anlikTayfaId = '4e3d2c1b-0a9f-4e8d-9c7b-6a5f4e3d2c1b';
const String _anlikYolu = '/v1/instant-events';
const String _bitirYolu = '/v1/tayfas/{tayfa_id}/events/{event_id}/finish';
const String _davetliId = '7a6b5c4d-3e2f-4a1b-9c8d-7e6f5a4b3c2d';

const LatLng _nokta = LatLng(lat: 40.6, lng: 31.28);

const SimdiAnahtari _tayfada = (tayfaId: ornekTayfaId, davetli: null);
const SimdiAnahtari _anlik = (tayfaId: null, davetli: null);

final AppLocalizations tr = lookupAppLocalizations(const Locale('tr'));

/// Sürmekte olan açık uçlu etkinlik: [sabitSimdi]'den 25 dakika önce
/// başlamış, en geç bitişi 12 saat sonra.
Map<String, Object?> _suren({bool yonetebilir = true}) => etkinlikJson(
  tur: 'general',
  baslik: 'Masa kuruldu',
  baslangic: sabitSimdi.subtract(const Duration(minutes: 25)),
  sure: const Duration(hours: 12),
  yonetebilir: yonetebilir,
  acikUclu: true,
);

Map<String, Object?> _anlikJson() => {
  'tayfa': tayfaJson(
    id: _anlikTayfaId,
    ad: 'Masa kuruldu',
    uyeSayisi: 1,
    tur: 'instant',
    anlikEtkinlikId: ornekEtkinlikId,
  ),
  'event': etkinlikJson(acikUclu: true),
};

ProviderContainer _kapsayici(SahteTayfaTasima tasima) {
  final c = ProviderContainer(overrides: etkinlikOverridelari(tasima: tasima));
  addTearDown(c.dispose);
  return c;
}

/// Şimdi notifier'ını tutar ve geçerli bir yüz yüze yerle doldurur.
SimdiNotifier _doldur(ProviderContainer c, SimdiAnahtari anahtar) {
  c.listen(simdiBaslatProvider(anahtar), (_, _) {});
  return c.read(simdiBaslatProvider(anahtar).notifier)
    ..noktaSec(_nokta, il: 'Bolu', ilce: 'Merkez');
}

Map<String, Object?> _govde(SahteTayfaTasima t, String yol) =>
    t.giden('POST', yol).single.govde! as Map<String, Object?>;

void main() {
  group('adres girdisi', () {
    test('tayfa ve davetli UUID biçiminde olmalı', () {
      expect(simdiAnahtariCoz(ornekTayfaId, null), _tayfada);
      expect(simdiAnahtariCoz(null, _davetliId), (
        tayfaId: null,
        davetli: _davetliId,
      ));
      for (final kotu in ['kimlik', '../t', 'https://kotu.example/x', '']) {
        expect(simdiAnahtariCoz(kotu, kotu), _anlik);
      }
    });

    test('tayfada davetli yok sayılır', () {
      expect(simdiAnahtariCoz(ornekTayfaId, _davetliId), _tayfada);
    });

    test('adres: /simdi, sorgu parametreleriyle', () {
      expect(Adresler.simdi(), '/simdi');
      expect(Adresler.simdi(tayfaId: ornekTayfaId), '/simdi?tayfa=$ornekTayfaId');
      expect(Adresler.simdi(davetli: _davetliId), '/simdi?davetli=$_davetliId');
    });
  });

  group('şimdi notifier\'ı', () {
    test('varsayılan tür Genel; girilen yok', () {
      final c = _kapsayici(etkinlikTasimasi());
      c.listen(simdiBaslatProvider(_tayfada), (_, _) {});
      final t = c.read(simdiBaslatProvider(_tayfada));
      expect(t.tur, simdiVarsayilanTur);
      expect(t.istekKimligi, sahteEtkinlikIstekKimligi);
      expect(t.baslik, isEmpty);
    });

    test('tayfada gönderim: starts_now, zaman ve tekrar yok, varsayılan '
        'başlık', () async {
      final tasima = etkinlikTasimasi({
        'POST $etkinliklerYolu': (_) => etkinlikJson(acikUclu: true),
      });
      final c = _kapsayici(tasima);
      final n = _doldur(c, _tayfada);
      await n.gonder(varsayilanBaslik: "Ayşe'nin Genel");

      final govde = _govde(tasima, etkinliklerYolu);
      expect(govde['starts_now'], isTrue);
      expect(govde['title'], "Ayşe'nin Genel");
      expect(govde['type'], 'general');
      expect(govde['mode'], 'in_person');
      expect(govde['meeting_point'], {'lat': 40.6, 'lng': 31.28});
      expect(govde['city'], 'Bolu');
      expect(govde['district'], 'Merkez');
      expect(govde['client_request_id'], sahteEtkinlikIstekKimligi);
      for (final yok in [
        'starts_at',
        'ends_at',
        'recurrence',
        'discoverable',
        'cover_upload_id',
        'online_url',
      ]) {
        expect(govde.containsKey(yok), isFalse, reason: yok);
      }
      expect(tasima.giden('POST', _anlikYolu), isEmpty);
      final t = c.read(simdiBaslatProvider(_tayfada));
      expect(t.sonuc, ornekEtkinlikId);
      expect(c.read(sonSimdiTurleriProvider), ['general']);
    });

    test('girilen başlık kırpılır', () async {
      final tasima = etkinlikTasimasi({
        'POST $etkinliklerYolu': (_) => etkinlikJson(acikUclu: true),
      });
      final c = _kapsayici(tasima);
      final n = _doldur(c, _tayfada)..baslikAyarla('  Masa kuruldu ');
      await n.gonder(varsayilanBaslik: 'Genel');
      expect(_govde(tasima, etkinliklerYolu)['title'], 'Masa kuruldu');
    });

    test('yer eksikse gönderilmez, hatalar gösterilir', () async {
      final tasima = etkinlikTasimasi();
      final c = _kapsayici(tasima);
      c.listen(simdiBaslatProvider(_tayfada), (_, _) {});
      final n = c.read(simdiBaslatProvider(_tayfada).notifier);
      await n.gonder(varsayilanBaslik: 'Genel');
      final t = c.read(simdiBaslatProvider(_tayfada));
      expect(
        t.hatalar,
        containsAll([TaslakHatasi.nokta, TaslakHatasi.il, TaslakHatasi.ilce]),
      );
      expect(tasima.giden('POST', etkinliklerYolu), isEmpty);

      // Düzeltilen alanın hatası kalkar.
      n.noktaSec(_nokta, il: 'Bolu', ilce: 'Merkez');
      expect(c.read(simdiBaslatProvider(_tayfada)).hatalar, isEmpty);
    });

    test('zorunlu katalog alanı boşsa gönderilmez', () async {
      final tasima = etkinlikTasimasi();
      final c = _kapsayici(tasima);
      final n = _doldur(c, _tayfada)..turSec(testTuru('sports'));
      expect(simdiAlanlari(testTuru('sports')), isNotEmpty);
      await n.gonder(varsayilanBaslik: 'Spor');
      expect(
        c.read(simdiBaslatProvider(_tayfada)).hatalar,
        contains(TaslakHatasi.alanlar),
      );
      expect(tasima.giden('POST', etkinliklerYolu), isEmpty);
    });

    test('emekli tür seçilemez', () {
      final c = _kapsayici(etkinlikTasimasi());
      final n = _doldur(c, _tayfada)..turSec(testTuru('eski_tur'));
      expect(c.read(simdiBaslatProvider(_tayfada)).tur, simdiVarsayilanTur);
      n.turSec(testTuru('board_game_night'));
      expect(c.read(simdiBaslatProvider(_tayfada)).tur, 'board_game_night');
    });

    test('now-limit-reached: girilenler kalır, tekrar denemede aynı istek '
        'kimliği', () async {
      var deneme = 0;
      final tasima = etkinlikTasimasi({
        'POST $etkinliklerYolu': (_) => deneme++ == 0
            ? const ApiProblem(status: 429, type: ProblemType.nowLimitReached)
            : etkinlikJson(acikUclu: true),
      });
      final c = _kapsayici(tasima);
      final n = _doldur(c, _tayfada)..baslikAyarla('Masa');
      await n.gonder(varsayilanBaslik: 'Genel');
      var t = c.read(simdiBaslatProvider(_tayfada));
      expect((t.hata! as ApiProblem).type, ProblemType.nowLimitReached);
      expect(t.baslik, 'Masa');
      expect(t.sonuc, isNull);

      await n.gonder(varsayilanBaslik: 'Genel');
      t = c.read(simdiBaslatProvider(_tayfada));
      expect(t.sonuc, ornekEtkinlikId);
      final kimlikler = [
        for (final i in tasima.giden('POST', etkinliklerYolu))
          (i.govde! as Map<String, Object?>)['client_request_id'],
      ];
      expect(kimlikler, [sahteEtkinlikIstekKimligi, sahteEtkinlikIstekKimligi]);
    });

    test('tayfasız: POST /v1/instant-events, event.starts_now; gizli tayfa '
        'listeye eklenir', () async {
      final tasima = etkinlikTasimasi({'POST $_anlikYolu': (_) => _anlikJson()});
      final c = _kapsayici(tasima);
      final n = _doldur(c, _anlik);
      await n.gonder(varsayilanBaslik: 'Genel');
      final govde = _govde(tasima, _anlikYolu);
      expect(govde.containsKey('invitee_user_ids'), isFalse);
      final etkinlik = govde['event']! as Map<String, Object?>;
      expect(etkinlik['starts_now'], isTrue);
      expect(etkinlik.containsKey('starts_at'), isFalse);
      expect(etkinlik.containsKey('ends_at'), isFalse);
      expect(etkinlik.containsKey('discoverable'), isFalse);
      expect(tasima.giden('POST', etkinliklerYolu), isEmpty);
      final t = c.read(simdiBaslatProvider(_anlik));
      expect(t.anlikSonuc?.tayfa.id, _anlikTayfaId);
      final liste = c.read(tayfalarimProvider).value!;
      expect(liste.any((x) => x.tayfaId == _anlikTayfaId), isTrue);
    });

    test('"Boşum"dan gelen davetli invitee_user_ids ile gider', () async {
      final tasima = etkinlikTasimasi({'POST $_anlikYolu': (_) => _anlikJson()});
      final c = _kapsayici(tasima);
      const SimdiAnahtari anahtar = (tayfaId: null, davetli: _davetliId);
      final n = _doldur(c, anahtar);
      await n.gonder(varsayilanBaslik: 'Genel');
      expect(_govde(tasima, _anlikYolu)['invitee_user_ids'], [_davetliId]);
    });

    test('son türler en çok 6, en yeni önce, yinelenmez', () {
      final c = _kapsayici(etkinlikTasimasi());
      final n = c.read(sonSimdiTurleriProvider.notifier);
      for (final t in ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'b']) {
        n.kullanildi(t);
      }
      expect(c.read(sonSimdiTurleriProvider), ['b', 'g', 'f', 'e', 'd', 'c']);
    });
  });

  group('sürüyor hali', () {
    final bas = DateTime.utc(2026, 11, 20, 18);
    Event etkinlik({bool acikUclu = true, bool iptal = false}) =>
        Event.fromJson(
          etkinlikJson(
            baslangic: bas,
            sure: const Duration(hours: 12),
            acikUclu: acikUclu,
            iptal: iptal,
          ),
        );

    test('yalnızca açık uçlu, başlamış, bitmemiş ve iptal edilmemişse', () {
      final simdi = bas.add(const Duration(minutes: 5));
      expect(acikUcluSuruyor(etkinlik(), simdi), isTrue);
      expect(acikUcluSuruyor(etkinlik(acikUclu: false), simdi), isFalse);
      expect(acikUcluSuruyor(etkinlik(iptal: true), simdi), isFalse);
      expect(
        acikUcluSuruyor(etkinlik(), bas.subtract(const Duration(minutes: 1))),
        isFalse,
      );
      // 12 saatlik otomatik bitişten sonra open_ended hâlâ true.
      expect(
        acikUcluSuruyor(etkinlik(), bas.add(const Duration(hours: 12))),
        isFalse,
      );
    });

    test('geçen süre metni ve okunuşu', () {
      expect(gecenSureMetni(tr, const Duration(minutes: 25)), '25 dk');
      expect(gecenSureMetni(tr, const Duration(minutes: 65)), '1 sa 5 dk');
      expect(gecenSureOkunusu(tr, const Duration(minutes: 0)), '0 dakika');
      expect(
        gecenSureOkunusu(tr, const Duration(minutes: 125)),
        '2 saat 5 dakika',
      );
    });

    testWidgets('etiket dakikada bir güncellenir; bitişte kaybolur', (
      tester,
    ) async {
      var saat = bas.add(const Duration(minutes: 25, seconds: 20));
      final zamanlayici = SahteZamanlayici();
      await widgetAc(
        tester,
        Scaffold(body: SuruyorEtiketi(etkinlik: etkinlik())),
        overrides: [
          etkinlikSaatiProvider.overrideWithValue(() => saat),
          zamanlayiciProvider.overrideWithValue(zamanlayici.kur),
        ],
      );
      expect(find.textContaining('25 dk'), findsOneWidget);
      expect(
        find.bySemanticsLabel(tr.simdi_suruyor_okunus('25 dakika')),
        findsOneWidget,
      );
      // Bir sonraki dakika başına kadar tek zamanlayıcı; saniye yok.
      expect(zamanlayici.etkin.single.sure, const Duration(seconds: 40));

      saat = saat.add(const Duration(seconds: 40));
      zamanlayici.calistir();
      await tester.pump();
      expect(find.textContaining('26 dk'), findsOneWidget);
      expect(zamanlayici.etkin.single.sure, const Duration(minutes: 1));

      saat = bas.add(const Duration(hours: 12));
      zamanlayici.calistir();
      await tester.pump();
      expect(find.textContaining('dk'), findsNothing);
      expect(zamanlayici.etkin, isEmpty);
    });
  });

  group('açık uçlu etkinliğin düzenlenmesi', () {
    test('zaman değiştirilemez ve gönderilmez', () {
      final eski = Event.fromJson(_suren());
      final c = _kapsayici(etkinlikTasimasi());
      final anahtar = (tayfaId: ornekTayfaId, duzenlenen: eski);
      c.listen(etkinlikSihirbaziProvider(anahtar), (_, _) {});
      final n = c.read(etkinlikSihirbaziProvider(anahtar).notifier);
      expect(n.zamanKilitli, isTrue);
      n
        ..baslangicAyarla(ornekBaslangic)
        ..bitisAyarla(ornekBaslangic.add(const Duration(hours: 2)))
        ..baslikAyarla('Masa kuruldu, gel');
      final t = c.read(etkinlikSihirbaziProvider(anahtar));
      expect(t.baslangic, eski.startsAt);
      final istek = duzenlemeIstegi(
        t.kopya(bitis: ornekBaslangic.add(const Duration(hours: 2))),
        eski,
      )!.toJson();
      expect(istek['title'], 'Masa kuruldu, gel');
      expect(istek.containsKey('starts_at'), isFalse);
      expect(istek.containsKey('ends_at'), isFalse);
    });
  });

  group('etkinlik detayında sürüyor bandı', () {
    Future<SahteTayfaTasima> ac(
      WidgetTester tester, {
      required String ben,
      ThemeMode tema = ThemeMode.light,
    }) async {
      final tasima = etkinlikTasimasi({
        'GET $etkinlikYolu': (_) => _suren(),
        'GET $hesapYolu': (_) => hesapJson(ben),
        'POST $_bitirYolu': (_) => etkinlikJson(
          tur: 'general',
          baslik: 'Masa kuruldu',
          baslangic: sabitSimdi.subtract(const Duration(minutes: 25)),
          sure: const Duration(minutes: 25),
          yonetebilir: true,
        ),
      });
      await uygulamayiAc(
        tester,
        themeMode: tema,
        tayfa: etkinlikOverridelari(tasima: tasima),
        overrides: [
          zamanlayiciProvider.overrideWithValue(SahteZamanlayici().kur),
        ],
      );
      yonlendiriciyiAl(
        tester,
      ).go(Adresler.etkinlik(ornekTayfaId, ornekEtkinlikId));
      await tester.pumpAndSettle();
      return tasima;
    }

    for (final tema in _temalar) {
      testWidgets('organizatöre bant ve Bitir (${tema.name}, 2× yazı, 320 dp)', (
        tester,
      ) async {
        ekranBoyutu(tester, genislik: 320, yukseklik: 2400);
        ikiKatYazi(tester);
        await ac(tester, ben: organizatorId, tema: tema);
        expect(tester.takeException(), isNull);
        expect(find.byType(EtkinlikDetayEkrani), findsOneWidget);
        expect(find.text(arbMetni('simdi_bant_baslik')), findsOneWidget);
        expect(find.text(arbMetni('simdi_bitir')), findsOneWidget);
        expect(
          find.textContaining(tr.simdi_suruyor_etiketi('25 dk')),
          findsOneWidget,
        );
        expect(find.textContaining('en geç'), findsOneWidget);
      });
    }

    testWidgets('Bitir onayla gönderilir; bant kalkar', (tester) async {
      ekranBoyutu(tester, yukseklik: 2400);
      final tasima = await ac(tester, ben: organizatorId);
      await tester.ensureVisible(find.text(arbMetni('simdi_bitir')));
      await tester.tap(find.text(arbMetni('simdi_bitir')));
      await tester.pumpAndSettle();
      expect(find.text(arbMetni('simdi_bitir_onay_baslik')), findsOneWidget);

      // Vazgeç: istek gitmez.
      await tester.tap(find.text(arbMetni('etkinlik_vazgec')));
      await tester.pumpAndSettle();
      expect(tasima.giden('POST', _bitirYolu), isEmpty);

      await tester.tap(find.text(arbMetni('simdi_bitir')));
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text(arbMetni('simdi_bitir')),
        ),
      );
      await tester.pumpAndSettle();
      final istek = tasima.giden('POST', _bitirYolu).single;
      expect(istek.yolParametreleri['event_id'], ornekEtkinlikId);
      expect(istek.govde, isNull);
      expect(find.text(arbMetni('simdi_bant_baslik')), findsNothing);
    });

    testWidgets('organizatör olmayana bant var, Bitir yok', (tester) async {
      ekranBoyutu(tester, yukseklik: 2400);
      await ac(tester, ben: katilimciId);
      expect(find.text(arbMetni('simdi_bant_baslik')), findsOneWidget);
      expect(find.text(arbMetni('simdi_bitir')), findsNothing);
    });
  });

  group('şimdi ekranı', () {
    Future<SahteTayfaTasima> ac(
      WidgetTester tester, {
      ThemeMode tema = ThemeMode.light,
      String? tayfaId = ornekTayfaId,
    }) async {
      final tasima = etkinlikTasimasi({
        'POST $etkinliklerYolu': (_) => etkinlikJson(acikUclu: true),
        'GET $hesapYolu': (_) => hesapJson(organizatorId),
      });
      await uygulamayiAc(
        tester,
        themeMode: tema,
        tayfa: etkinlikOverridelari(tasima: tasima),
        overrides: [
          zamanlayiciProvider.overrideWithValue(SahteZamanlayici().kur),
        ],
      );
      yonlendiriciyiAl(tester).go(Adresler.simdi(tayfaId: tayfaId));
      await tester.pumpAndSettle();
      return tasima;
    }

    for (final tema in _temalar) {
      testWidgets('tek ekran (${tema.name}, 2× yazı, 320 dp)', (tester) async {
        ekranBoyutu(tester, genislik: 320);
        ikiKatYazi(tester);
        await ac(tester, tema: tema);
        expect(tester.takeException(), isNull);
        expect(find.byType(SimdiEkrani), findsOneWidget);
        expect(find.text(arbMetni('simdi_tur_baslik')), findsOneWidget);
        expect(find.text(arbMetni('simdi_gonder')), findsOneWidget);
        // Varsayılan başlık organizatörün adıyla ("Ayşe'nin …").
        expect(find.textContaining("Ayşe'nin"), findsOneWidget);
      });
    }

    testWidgets('konumla yer seçilir, gönderilir, detay açılır', (
      tester,
    ) async {
      ekranBoyutu(tester, yukseklik: 2400);
      final tasima = await ac(tester);
      await tester.tap(find.text(arbMetni('simdi_nokta_sec')));
      await tester.pumpAndSettle();
      // Seçici cihaz konumuyla açıldı; nokta onaylanır.
      await tester.tap(find.text(arbMetni('simdi_harita_sec')));
      await tester.pumpAndSettle();
      expect(find.text(arbMetni('etkinlik_nokta_secildi')), findsOneWidget);

      final alanlar = find.byType(TextField);
      await tester.enterText(alanlar.at(1), 'Bolu');
      await tester.enterText(alanlar.at(2), 'Merkez');
      await tester.pumpAndSettle();
      await tester.tap(find.text(arbMetni('simdi_gonder')));
      await tester.pumpAndSettle();

      final govde = _govde(tasima, etkinliklerYolu);
      expect(govde['starts_now'], isTrue);
      expect(govde['title'], "Ayşe'nin ${testTuru('general').labels['tr']}");
      expect(govde['meeting_point'], sahteKonum.toJson());
      expect(govde['city'], 'Bolu');
      expect(find.byType(EtkinlikDetayEkrani), findsOneWidget);
    });

    testWidgets('yer seçilmeden gönderilmez', (tester) async {
      ekranBoyutu(tester, yukseklik: 2400);
      final tasima = await ac(tester);
      await tester.tap(find.text(arbMetni('simdi_gonder')));
      await tester.pumpAndSettle();
      expect(find.text(arbMetni('etkinlik_nokta_hata')), findsOneWidget);
      expect(tasima.giden('POST', etkinliklerYolu), isEmpty);
    });
  });

  group('giriş noktaları', () {
    testWidgets('etkinlik listesinde "Şimdi başlat" ayardaki rol ve üstüne', (
      tester,
    ) async {
      ekranBoyutu(tester);
      final tasima = etkinlikTasimasi();
      await uygulamayiAc(tester, tayfa: etkinlikOverridelari(tasima: tasima));
      yonlendiriciyiAl(tester).go(Adresler.etkinlikler(ornekTayfaId));
      await tester.pumpAndSettle();
      expect(find.text(arbMetni('simdi_baslat_dugmesi')), findsOneWidget);
      await tester.tap(find.text(arbMetni('simdi_baslat_dugmesi')));
      await tester.pumpAndSettle();
      expect(find.byType(SimdiEkrani), findsOneWidget);
    });

    test('rol sırası: ayardaki rol ve üstü', () {
      Tayfa tayfa(String rol) =>
          Tayfa.fromJson(tayfaJson(id: ornekTayfaId, simdiRolu: rol));
      bool baslatir(String ayar, Role rol) =>
          TayfaOzeti(tayfa: tayfa(ayar), rol: rol).simdiBaslatabilir;
      expect(baslatir('member', Role.member), isTrue);
      expect(baslatir('moderator', Role.member), isFalse);
      expect(baslatir('moderator', Role.moderator), isTrue);
      expect(baslatir('admin', Role.moderator), isFalse);
      expect(baslatir('admin', Role.admin), isTrue);
      expect(
        TayfaOzeti(
          tayfa: tayfa('member'),
          rol: Role.admin,
          tur: TayfaKind.instant,
        ).simdiBaslatabilir,
        isFalse,
        reason: 'anlık tayfa',
      );
    });
  });
}
